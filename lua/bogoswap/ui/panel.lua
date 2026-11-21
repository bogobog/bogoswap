-- The ImGui control panel.
-- Rules: clicks on selectables come from ImGui.IsItemClicked(), and tooltips are
-- built with BeginTooltip/EndTooltip, never SetTooltip (MacroQuest formats its text).
local log = require('bogoswap.core.log')
local config = require('bogoswap.core.config')
local commands = require('bogoswap.core.commands')
local game = require('bogoswap.core.game')
local swap = require('bogoswap.core.swap')

local M = {}

local function text(s)
    s = tostring(s)
    if ImGui.TextUnformatted then
        ImGui.TextUnformatted(s)
    else
        ImGui.Text((s:gsub('%%', '%%%%')))
    end
end

local function tip(s)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        text(s)
        ImGui.EndTooltip()
    end
end

-- Friendly labels for the panel. Commands, the config file, chat and the TLO keep the
-- canonical names, and each field's tooltip names its canonical key.
local LABELS = {
    TriggerEffectName = 'Trigger Effect',
    SwapEquipmentSlot = 'Equipment Slot',
    MatchItemName = 'Trigger Found Item',
    NoMatchItemName = 'Trigger Missing Item',
}
M.LABELS = LABELS

local DESCRIPTIONS = {
    TriggerEffectName = 'Buff or song to watch for (exact name). Press Enter to apply.',
    SwapEquipmentSlot = 'Equipment slot to swap items into.',
    MatchItemName = 'Item to equip while the trigger effect is on you. Lists items in your bags that fit the slot.',
    NoMatchItemName = 'Item to equip while the trigger effect is not on you. Lists items in your bags that fit the slot.',
}

local TIPS = {}
for key, desc in pairs(DESCRIPTIONS) do
    TIPS[key] = string.format('%s\nSetting: %s  (/bogoswap set %s <value>)', desc, key, key)
end

-- Replaces canonical setting names in text shown in the panel with their labels.
-- NoMatchItemName goes first because it contains MatchItemName.
local LABEL_ORDER = { 'NoMatchItemName', 'MatchItemName', 'TriggerEffectName', 'SwapEquipmentSlot' }
local function friendly(s)
    for _, key in ipairs(LABEL_ORDER) do
        s = s:gsub('%f[%w]' .. key .. '%f[%W]', LABELS[key])
    end
    return s
end
M.friendly = friendly

-- MacroQuest's ImGui bindings may return a size as two numbers or as an ImVec2.
local function xOf(a)
    if type(a) == 'number' then return a end
    return a and a.x or 0
end

-- Width of the label column: the widest label plus a gap.
local function labelColumnWidth()
    if not ImGui.CalcTextSize then return 150 end
    local w = 0
    for _, label in pairs(LABELS) do
        local x = xOf(ImGui.CalcTextSize(label))
        if x > w then w = x end
    end
    return w + 16
end

-- Draws a row's label on the left and leaves the cursor where the field starts.
-- fieldWidth is passed to SetNextItemWidth: -1 fills the row, -n leaves n pixels free.
local function rowLabel(key, fieldWidth)
    if ImGui.AlignTextToFramePadding then ImGui.AlignTextToFramePadding() end
    text(LABELS[key])
    tip(TIPS[key])
    ImGui.SameLine(labelColumnWidth())
    ImGui.SetNextItemWidth(fieldWidth or -1)
end

-- Why the configured item might not be swappable, shown next to it in the picker.
local function itemMarker(state, key)
    local name, slot = state.cfg[key], state.cfg.SwapEquipmentSlot
    if name == '' or slot == '' or not (state.snap and state.snap.inGame) then return '' end
    local it = game.findItem(name, slot)
    if not it then return ' (not in inventory)' end
    if it.canWear == false then return " (can't be worn in " .. slot .. ')' end
    if not it.canUse then return " (you can't use it)" end
    return ''
end

local function scan(state, why)
    local slot = state.cfg.SwapEquipmentSlot
    local items = game.equipCandidates(slot)
    state.ui.candidates = { slot = slot, items = items }
    local n = log.nextAction()
    log.debug('ui', n, 'scanned inventory for %s: %d eligible item(s) (%s)', slot, #items, why)
end

local function choose(state, key, name)
    local ok, err = commands.setValue(state, key, name, 'ui')
    if not ok then log.err('%s', err) end
end

-- Item picker for MatchItemName / NoMatchItemName. The inventory is scanned each time
-- the dropdown opens, never while it's closed.
local function drawPicker(state, key)
    local ui = state.ui
    local slot = state.cfg.SwapEquipmentSlot
    local cur = state.cfg[key]
    local label = '##pick_' .. key
    rowLabel(key)
    if slot == '' then
        local canDisable = ImGui.BeginDisabled ~= nil
        if canDisable then ImGui.BeginDisabled(true) end
        local preview = (cur ~= '' and (cur .. ' ') or '') .. '(choose an equipment slot first)'
        if ImGui.BeginCombo(label, preview) then ImGui.EndCombo() end
        if canDisable then ImGui.EndDisabled() end
        ui.pickerOpen[key] = false
        return
    end
    if ImGui.BeginCombo(label, (cur ~= '' and cur or '(none)') .. itemMarker(state, key)) then
        if not ui.pickerOpen[key] or not ui.candidates or ui.candidates.slot ~= slot then
            scan(state, 'opened ' .. key .. ' picker')
        end
        ui.pickerOpen[key] = true
        ImGui.Selectable('(none)##pick_' .. key .. '_none', cur == '')
        if ImGui.IsItemClicked() then choose(state, key, '') end
        for _, it in ipairs(ui.candidates.items) do
            local tag = (slot == 'mainhand' and swap.isTwoHander(it)) and ' (2H)' or ''
            ImGui.Selectable(it.name .. tag .. '##pick_' .. key .. '_' .. it.name,
                it.name:lower() == cur:lower())
            if ImGui.IsItemClicked() then choose(state, key, it.name) end
        end
        if #ui.candidates.items == 0 then
            text('Nothing in your bags fits ' .. slot .. '.')
        end
        ImGui.EndCombo()
    else
        ui.pickerOpen[key] = false
    end
    tip(TIPS[key])
end

-- Pause button colours: green while running, blue while paused.
-- Each list is normal, hovered, active (RGBA, 0-1).
local BUTTON_COLS = { 'Button', 'ButtonHovered', 'ButtonActive' }
local BUTTON_RUNNING = { { 0.13, 0.55, 0.13, 1 }, { 0.18, 0.68, 0.18, 1 }, { 0.10, 0.45, 0.10, 1 } }
local BUTTON_PAUSED = { { 0.15, 0.35, 0.75, 1 }, { 0.22, 0.45, 0.88, 1 }, { 0.11, 0.27, 0.62, 1 } }
M.BUTTON_RUNNING = BUTTON_RUNNING
M.BUTTON_PAUSED = BUTTON_PAUSED

-- Wraps a button in the running/paused colours. Returns whether it was clicked.
local function stateButton(state, label)
    local colors = state.paused and BUTTON_PAUSED or BUTTON_RUNNING
    for i, col in ipairs(BUTTON_COLS) do
        local c = colors[i]
        ImGui.PushStyleColor(ImGuiCol[col], c[1], c[2], c[3], c[4])
    end
    local clicked = ImGui.Button(label)
    ImGui.PopStyleColor(#BUTTON_COLS)
    return clicked
end

local STOP_WIDTH = 60
local MINIMIZE_WIDTH = 24
local BUTTON_GAP = 8 -- ImGui's default horizontal item spacing

local function setMinimized(state, minimized)
    state.ui.minimized = minimized
    local n = log.nextAction()
    log.debug('ui', n, minimized and 'minimized to the BS button' or 'restored the window from the BS button')
end

-- [_] and [Stop] sit on the Pause/Resume row, against the right edge of the window.
-- Both are placed explicitly, so the gap between them doesn't depend on SameLine spacing.
local function drawRightButtons(state)
    ImGui.SameLine()
    local avail = xOf(ImGui.GetContentRegionAvail())
    local total = MINIMIZE_WIDTH + BUTTON_GAP + STOP_WIDTH
    local start = ImGui.GetCursorPosX()
    if avail > total then start = start + avail - total end
    ImGui.SetCursorPosX(start)
    if ImGui.Button('_##minimize', MINIMIZE_WIDTH, 0) then setMinimized(state, true) end
    tip('Minimize to a small BS button.')
    ImGui.SameLine()
    ImGui.SetCursorPosX(start + MINIMIZE_WIDTH + BUTTON_GAP)
    if ImGui.Button('Stop##stop', STOP_WIDTH, 0) then
        commands.quit(state, 'ui')
        log.info('Stopping (Stop button).')
    end
    tip('Stop BogoSwap entirely, like /bogoswap quit.')
end

-- Minimized: a small window with no title bar that holds only the BS button. ImGui
-- remembers where you drag it; the first time it opens near the top-left of the screen.
local function miniFlags()
    local f = ImGuiWindowFlags
    if not f then return nil end
    -- Distinct single-bit flags, so adding them is the same as OR-ing them.
    return (f.NoTitleBar or 0) + (f.NoResize or 0) + (f.NoScrollbar or 0)
        + (f.NoCollapse or 0) + (f.AlwaysAutoResize or 0)
end

local RIGHT_MOUSE = (ImGuiMouseButton and ImGuiMouseButton.Right) or 1

local function drawMini(state)
    if ImGui.SetNextWindowPos and ImVec2 and ImGuiCond then
        ImGui.SetNextWindowPos(ImVec2(20, 20), ImGuiCond.FirstUseEver)
    end
    local _, show = ImGui.Begin('BogoSwap Mini###BogoSwapMini', true, miniFlags())
    if show then
        -- Left click (Button) restores; right click (IsItemClicked) toggles pause.
        if stateButton(state, 'BS##bogoswap_restore') then setMinimized(state, false) end
        if ImGui.IsItemClicked(RIGHT_MOUSE) then
            commands.setPaused(state, not state.paused, 'ui (right-click BS)')
        end
        tip(string.format('BogoSwap (%s). Click to restore the window. Right-click to %s.',
            state.paused and 'paused' or 'running', state.paused and 'resume' or 'pause'))
    end
    ImGui.End()
end

local function drawInput(state, key)
    local ui = state.ui
    if ui.seen[key] ~= state.cfg[key] then
        ui.seen[key] = state.cfg[key]
        ui.edit[key] = state.cfg[key]
    end
    local dirty = ui.edit[key] ~= state.cfg[key]
    rowLabel(key, dirty and -110 or -1)  -- leave room for the "(Enter to apply)" hint
    local v, entered = ImGui.InputText('##' .. key, ui.edit[key],
        ImGuiInputTextFlags.EnterReturnsTrue)
    if v ~= nil then ui.edit[key] = v end
    tip(TIPS[key])
    if entered then
        local ok, err = commands.setValue(state, key, ui.edit[key], 'ui')
        if not ok then log.err('%s', err) end
        ui.edit[key] = state.cfg[key]
        ui.seen[key] = state.cfg[key]
    end
    if ui.edit[key] ~= state.cfg[key] then
        ImGui.SameLine()
        text('(Enter to apply)')
    end
end

local function drawSlot(state)
    local cur = state.cfg.SwapEquipmentSlot
    rowLabel('SwapEquipmentSlot')
    if ImGui.BeginCombo('##slot', cur ~= '' and cur or '(none)') then
        for _, slot in ipairs(config.SLOTS) do
            ImGui.Selectable(slot .. '##slot_' .. slot, slot == cur)
            if ImGui.IsItemClicked() then
                local ok, err = commands.setValue(state, 'SwapEquipmentSlot', slot, 'ui')
                if not ok then log.err('%s', err) end
            end
        end
        ImGui.EndCombo()
    end
    tip(TIPS.SwapEquipmentSlot)
end

-- One collapsible section. Its header is the Status line, so collapsing it leaves only
-- Status showing; expanding it adds the details. The ### id keeps the open/closed
-- state stable while the status text changes. It starts open.
local function drawStatus(state)
    local cfg = state.cfg
    local s = state.snap or {}
    local status = friendly(state.waiting or (state.decision and state.decision.reason) or 'starting')
    -- '##' in the visible text would cut the label short.
    local header = 'Status: ' .. status:gsub('##', '# #') .. '###bogoswap_status'
    if not ImGui.CollapsingHeader(header, ImGuiTreeNodeFlags.DefaultOpen) then return end
    tip('Click to show or hide the details.')
    if s.inGame then
        text(string.format('Effect: %s', s.effectWindow and ('present (' .. s.effectWindow .. ')') or 'absent'))
        text(string.format('%s holds: %s', cfg.SwapEquipmentSlot ~= '' and cfg.SwapEquipmentSlot or 'Equipment Slot',
            s.slotItem and s.slotItem.name or 'nothing'))
        text(string.format('Wanted: %s', (s.wantName and s.wantName ~= '') and s.wantName or '(not set)'))
    end
    if cfg.State.StashedOffhandItem ~= '' then
        text('Remembered offhand: ' .. cfg.State.StashedOffhandItem)
    end
    if state.lastAction then
        text(string.format('Last action: #%d %s', state.lastAction.n, friendly(state.lastAction.text)))
    end
end

function M.draw(state)
    local ui = state.ui
    if not ui.open then return end
    if ui.minimized then
        drawMini(state)
        return
    end
    local open, show = ImGui.Begin('BogoSwap###BogoSwap', ui.open)
    if open == false then
        ui.open = false
        local n = log.nextAction()
        log.debug('ui', n, 'window closed; /bogoswap ui reopens it')
    end
    if show then
        if stateButton(state, state.paused and 'Resume##pause' or 'Pause##pause') then
            commands.setPaused(state, not state.paused, 'ui')
        end
        tip(state.paused and 'BogoSwap is paused. Click to start swapping.'
            or 'Click to stop swapping. BogoSwap keeps watching.')
        ImGui.SameLine()
        text(state.paused and 'PAUSED: taking no action' or 'Running')
        drawRightButtons(state)
        ImGui.Separator()
        drawStatus(state)
        ImGui.Separator()
        for _, key in ipairs(config.KEYS) do
            if key == 'SwapEquipmentSlot' then
                drawSlot(state)
            elseif key == 'TriggerEffectName' then
                drawInput(state, key)
            else
                drawPicker(state, key)
            end
        end
    end
    ImGui.End()
end

return M

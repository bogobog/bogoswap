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

local TIPS = {
    TriggerEffectName = 'Buff or song to watch for (exact name). Press Enter to apply.',
    SwapEquipmentSlot = 'Equipment slot to swap items into.',
    MatchItemName = 'Item to equip while the effect is present. Lists items in your bags that fit the slot.',
    NoMatchItemName = 'Item to equip while the effect is absent. Lists items in your bags that fit the slot.',
}

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
    state.ui.search[key] = ''
end

-- Item picker for MatchItemName / NoMatchItemName. The inventory is scanned when the
-- dropdown opens and when Refresh is clicked, never while it's closed.
local function drawPicker(state, key)
    local ui = state.ui
    local slot = state.cfg.SwapEquipmentSlot
    local cur = state.cfg[key]
    local label = key .. '##pick_' .. key
    if slot == '' then
        local canDisable = ImGui.BeginDisabled ~= nil
        if canDisable then ImGui.BeginDisabled(true) end
        if ImGui.BeginCombo(label, cur ~= '' and cur or '(none)') then ImGui.EndCombo() end
        if canDisable then ImGui.EndDisabled() end
        ImGui.SameLine()
        text('Choose SwapEquipmentSlot first.')
        ui.pickerOpen[key] = false
        return
    end
    if ImGui.BeginCombo(label, (cur ~= '' and cur or '(none)') .. itemMarker(state, key)) then
        if not ui.pickerOpen[key] or not ui.candidates or ui.candidates.slot ~= slot then
            scan(state, 'opened ' .. key .. ' picker')
        end
        ui.pickerOpen[key] = true
        local s = ImGui.InputText('Search##search_' .. key, ui.search[key] or '')
        if s ~= nil then ui.search[key] = s end
        ImGui.SameLine()
        if ImGui.Button('Refresh##refresh_' .. key) then scan(state, 'Refresh clicked') end
        ImGui.Selectable('(none)##pick_' .. key .. '_none', cur == '')
        if ImGui.IsItemClicked() then choose(state, key, '') end
        local filter = (ui.search[key] or ''):lower()
        local shown = 0
        for _, it in ipairs(ui.candidates.items) do
            if filter == '' or it.name:lower():find(filter, 1, true) then
                shown = shown + 1
                local tag = (slot == 'mainhand' and swap.isTwoHander(it)) and ' (2H)' or ''
                ImGui.Selectable(it.name .. tag .. '##pick_' .. key .. '_' .. it.name,
                    it.name:lower() == cur:lower())
                if ImGui.IsItemClicked() then choose(state, key, it.name) end
            end
        end
        if shown == 0 then
            text(#ui.candidates.items == 0 and ('Nothing in your bags fits ' .. slot .. '.') or 'No match.')
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

local STOP_WIDTH = 60

-- MacroQuest's ImGui bindings may return a size as two numbers or as an ImVec2.
local function xOf(a)
    if type(a) == 'number' then return a end
    return a and a.x or 0
end

-- Stop sits on the same row as Pause/Resume, against the right edge of the window.
local function drawStop(state)
    ImGui.SameLine()
    local avail = xOf(ImGui.GetContentRegionAvail())
    if avail > STOP_WIDTH then
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + avail - STOP_WIDTH)
    end
    if ImGui.Button('Stop##stop', STOP_WIDTH, 0) then
        commands.quit(state, 'ui')
        log.info('Stopping (Stop button).')
    end
    tip('Stop BogoSwap entirely, like /bogoswap quit.')
end

local function drawInput(state, key)
    local ui = state.ui
    if ui.seen[key] ~= state.cfg[key] then
        ui.seen[key] = state.cfg[key]
        ui.edit[key] = state.cfg[key]
    end
    local v, entered = ImGui.InputText(key .. '##' .. key, ui.edit[key],
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
    if ImGui.BeginCombo('SwapEquipmentSlot##slot', cur ~= '' and cur or '(none)') then
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

local function drawStatus(state)
    local cfg = state.cfg
    local s = state.snap or {}
    if s.inGame then
        text(string.format('Effect: %s', s.effectWindow and ('present (' .. s.effectWindow .. ')') or 'absent'))
        text(string.format('%s holds: %s', cfg.SwapEquipmentSlot ~= '' and cfg.SwapEquipmentSlot or 'Slot',
            s.slotItem and s.slotItem.name or 'nothing'))
        text(string.format('Wanted: %s', (s.wantName and s.wantName ~= '') and s.wantName or '(not set)'))
    end
    if cfg.State.StashedOffhandItem ~= '' then
        text('Remembered offhand: ' .. cfg.State.StashedOffhandItem)
    end
    text('Status: ' .. (state.waiting or (state.decision and state.decision.reason) or 'starting'))
    if state.lastAction then
        text(string.format('Last action: #%d %s', state.lastAction.n, state.lastAction.text))
    end
end

function M.draw(state)
    local ui = state.ui
    if not ui.open then return end
    local open, show = ImGui.Begin('BogoSwap###BogoSwap', ui.open)
    if open == false then
        ui.open = false
        local n = log.nextAction()
        log.debug('ui', n, 'window closed; /bogoswap ui reopens it')
    end
    if show then
        local colors = state.paused and BUTTON_PAUSED or BUTTON_RUNNING
        for i, col in ipairs(BUTTON_COLS) do
            local c = colors[i]
            ImGui.PushStyleColor(ImGuiCol[col], c[1], c[2], c[3], c[4])
        end
        local clicked = ImGui.Button(state.paused and 'Resume##pause' or 'Pause##pause')
        ImGui.PopStyleColor(#BUTTON_COLS)
        if clicked then
            commands.setPaused(state, not state.paused, 'ui')
        end
        tip(state.paused and 'BogoSwap is paused. Click to start swapping.'
            or 'Click to stop swapping. BogoSwap keeps watching.')
        ImGui.SameLine()
        text(state.paused and 'PAUSED: taking no action' or 'Running')
        drawStop(state)
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

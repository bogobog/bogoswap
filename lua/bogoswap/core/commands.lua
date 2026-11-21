-- /bogoswap (alias /bswap) and the setters the UI shares with it.
local log = require('bogoswap.core.log')
local config = require('bogoswap.core.config')
local game = require('bogoswap.core.game')
local swap = require('bogoswap.core.swap')

local M = {}

local function trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function unquote(s)
    local inner = s:match('^"(.*)"$') or s:match("^'(.*)'$")
    return inner or s
end

local TRUE = { on = true, yes = true, ['true'] = true, ['1'] = true }
local FALSE = { off = true, no = true, ['false'] = true, ['0'] = true }

local function onOff(v) return v and 'on' or 'off' end

-- Warnings about the current config that don't block saving it.
function M.validate(state)
    local cfg = state.cfg
    local out = {}
    local slot = cfg.SwapEquipmentSlot
    if cfg.MatchItemName ~= '' and cfg.MatchItemName:lower() == cfg.NoMatchItemName:lower() then
        out[#out + 1] = 'MatchItemName and NoMatchItemName are the same item.'
    end
    if slot ~= '' and game.inGame() then
        for _, key in ipairs({ 'MatchItemName', 'NoMatchItemName' }) do
            local name = cfg[key]
            if name ~= '' then
                local it = game.findItem(name, slot)
                if it and it.canWear == false then
                    out[#out + 1] = string.format("%s '%s' can't be worn in %s.", key, it.name, slot)
                end
            end
        end
    end
    return out
end

-- Returns true, or false and an error message.
function M.setValue(state, key, value, source)
    local k = config.canonicalKey(key)
    if not k then
        return false, string.format('Unknown setting "%s". Settings: %s',
            tostring(key), table.concat(config.allKeys(), ', '))
    end
    value = unquote(trim(value))
    if config.isOption(k) then
        local lv = value:lower()
        local on
        if TRUE[lv] then
            on = true
        elseif FALSE[lv] then
            on = false
        else
            return false, string.format('Use: /bogoswap set %s on|off (also yes/no, true/false, 1/0)', k)
        end
        local old = state.cfg[k]
        state.cfg[k] = on
        config.save(state.cfg, state.cfgPath)
        local n = log.nextAction()
        log.debug('config', n, '%s set %s: %s -> %s', source, k, onOff(old), onOff(on))
        log.info('%s = %s', k, onOff(on))
        log.resetNote('status')
        return true
    end
    if k == 'SwapEquipmentSlot' and value ~= '' then
        local s = config.normalizeSlot(value)
        if not s then
            return false, string.format('Unknown slot "%s". Slots: %s', value, table.concat(config.SLOTS, ', '))
        end
        value = s
    end
    local old = state.cfg[k]
    state.cfg[k] = value
    config.save(state.cfg, state.cfgPath)
    local n = log.nextAction()
    log.debug('config', n, '%s set %s: "%s" -> "%s"', source, k, old, value)
    log.info('%s = "%s"', k, value)
    for _, w in ipairs(M.validate(state)) do log.warn('%s', w) end
    log.resetNote('status')
    return true
end

function M.setPaused(state, paused, source)
    if state.paused == paused then
        log.info(paused and 'Already paused.' or 'Already running.')
        return
    end
    state.paused = paused
    local n = log.nextAction()
    log.debug('cmd', n, '%s %s BogoSwap', source, paused and 'paused' or 'resumed')
    log.info(paused and 'Paused. Watching, but taking no action.' or 'Resumed.')
    log.resetNote('status')
end

-- Ends the main loop; init.lua then unbinds commands, removes the TLO and exits.
function M.quit(state, source)
    state.running = false
    local n = log.nextAction()
    log.debug(source == 'ui' and 'ui' or 'cmd', n, 'quit requested by %s', source)
end

local HELP = {
    'Usage: /bogoswap <command>   (alias /bswap)',
    '  set <Setting> <value>   set TriggerEffectName, SwapEquipmentSlot, MatchItemName or NoMatchItemName (no value clears it)',
    '  set OnlyInCombat on|off only swap while in combat',
    '  swapnow                 evaluate once right now, even while paused, waiting to retry or out of combat',
    '  show                    print settings and current state',
    '  pause | resume | toggle stop or start taking action (the script keeps running)',
    '  ui [on|off|min]         show, hide or minimize the window (ui alone toggles; it also restores from minimized)',
    '  debug [<channel>|all on|off]  list or switch debug channels: swap, guard, config, cmd, ui',
    '  quit                    stop BogoSwap',
    '  help                    this text',
}

local function show(state)
    local cfg = state.cfg
    log.info('BogoSwap v%s: %s', state.version, state.paused and 'PAUSED' or 'running')
    for _, k in ipairs(config.KEYS) do log.info('  %s = "%s"', k, cfg[k]) end
    for _, k in ipairs(config.OPTIONS) do log.info('  %s = %s', k, onOff(cfg[k])) end
    local s = state.snap
    if cfg.OnlyInCombat and s and s.inGame then
        log.info('  Combat state: %s', swap.combatText(s))
    end
    if s and s.inGame then
        log.info('  Effect: %s; %s holds: %s; wanted: %s',
            s.effectWindow and ('present (' .. s.effectWindow .. ')') or 'absent',
            cfg.SwapEquipmentSlot ~= '' and cfg.SwapEquipmentSlot or '(no slot)',
            s.slotItem and s.slotItem.name or 'nothing', s.wantName ~= '' and s.wantName or '(not set)')
    end
    if cfg.State.StashedOffhandItem ~= '' then
        log.info('  Remembered offhand: %s', cfg.State.StashedOffhandItem)
    end
    local status = state.waiting or (state.decision and state.decision.reason) or 'starting'
    log.info('  Status: %s', status)
    if state.lastAction then log.info('  Last action: #%d %s', state.lastAction.n, state.lastAction.text) end
    local on = log.enabledChannels()
    log.info('  Debug channels on: %s', #on > 0 and table.concat(on, ', ') or 'none')
    log.info('  Config file: %s', state.cfgPath)
end

local function debugCmd(state, ch, onoff)
    if not ch then
        local on = log.enabledChannels()
        log.info('Debug channels: %s. On: %s', table.concat(log.CHANNELS, ', '),
            #on > 0 and table.concat(on, ', ') or 'none')
        return
    end
    ch = ch:lower()
    if ch ~= 'all' and not log.isChannel(ch) then
        log.err('Unknown debug channel "%s". Channels: %s, all', ch, table.concat(log.CHANNELS, ', '))
        return
    end
    local v = onoff and onoff:lower()
    local on
    if v == 'on' or v == 'yes' or v == 'true' or v == '1' then
        on = true
    elseif v == 'off' or v == 'no' or v == 'false' or v == '0' then
        on = false
    elseif v == nil and ch ~= 'all' then
        on = not log.channelEnabled(ch)
    else
        log.err('Use: /bogoswap debug <channel>|all on|off')
        return
    end
    local list = ch == 'all' and log.CHANNELS or { ch }
    for _, c in ipairs(list) do
        log.setChannel(c, on)
        state.cfg.Debug[c] = on
    end
    config.save(state.cfg, state.cfgPath)
    local n = log.nextAction()
    log.debug('cmd', n, 'debug %s %s', ch, on and 'on' or 'off')
    log.info('Debug %s: %s', ch, on and 'on' or 'off')
end

function M.handle(state, ...)
    local a = { ... }
    local sub = (a[1] or 'help'):lower()
    if sub == 'set' then
        if not a[2] then
            log.err('Use: /bogoswap set <Setting> <value>. Settings: %s', table.concat(config.allKeys(), ', '))
            return
        end
        local ok, err = M.setValue(state, a[2], table.concat(a, ' ', 3), 'command')
        if not ok then log.err('%s', err) end
    elseif sub == 'show' or sub == 'status' then
        show(state)
    elseif sub == 'pause' then
        M.setPaused(state, true, 'command')
    elseif sub == 'resume' or sub == 'unpause' then
        M.setPaused(state, false, 'command')
    elseif sub == 'toggle' then
        M.setPaused(state, not state.paused, 'command')
    elseif sub == 'swapnow' then
        state.force = true
        local n = log.nextAction()
        log.debug('cmd', n, 'swapnow requested; next pass ignores pause and retry wait')
        log.info('Evaluating now.')
    elseif sub == 'ui' then
        -- ui / ui on restore the full window (even when minimized), ui off hides
        -- everything, ui min shows only the BS button.
        local ui = state.ui
        local v = a[2] and a[2]:lower()
        if v == 'on' then
            ui.open, ui.minimized = true, false
        elseif v == 'off' then
            ui.open = false
        elseif v == 'min' or v == 'minimize' then
            ui.open, ui.minimized = true, true
        elseif v == nil then
            if ui.open and not ui.minimized then
                ui.open = false
            else
                ui.open, ui.minimized = true, false
            end
        else
            log.err('Use: /bogoswap ui [on|off|min]')
            return
        end
        local n = log.nextAction()
        log.debug('ui', n, 'window %s by command', not ui.open and 'hidden'
            or ui.minimized and 'minimized' or 'shown')
    elseif sub == 'debug' then
        debugCmd(state, a[2], a[3])
    elseif sub == 'quit' or sub == 'stop' or sub == 'exit' then
        M.quit(state, 'command')
    elseif sub == 'help' then
        for _, line in ipairs(HELP) do log.info('%s', line) end
    else
        log.err('Unknown command "%s". Try /bogoswap help', sub)
    end
end

return M

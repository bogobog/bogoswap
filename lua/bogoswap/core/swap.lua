-- The swap loop: snapshot the game, decide (pure), execute, verify.
local log = require('bogoswap.core.log')
local config = require('bogoswap.core.config')
local game = require('bogoswap.core.game')

local M = {}

M.ACTIONS = { exchange = true, unequip = true, clearstash = true }

local function q(s) return "'" .. tostring(s) .. "'" end

local function same(a, b)
    return a ~= nil and b ~= nil and tostring(a):lower() == tostring(b):lower()
end

function M.isTwoHander(item)
    return item ~= nil and type(item.type) == 'string' and item.type:sub(1, 2) == '2H'
end

function M.wantedName(cfg, s)
    if s.effectWindow then return cfg.MatchItemName end
    return cfg.NoMatchItemName
end

-- Reads everything decide() needs, so decide() itself touches no game state.
function M.snapshot(cfg)
    local s = { inGame = game.inGame() }
    if not s.inGame then return s end
    local slot = cfg.SwapEquipmentSlot
    s.charState = game.charState()
    s.casting = game.casting()
    s.isBard = game.isBard()
    s.cursor = game.cursorItem()
    s.exchangeLoaded = game.exchangeLoaded()
    s.freeInventory = game.freeInventory()
    s.effectWindow = game.effectWindow(cfg.TriggerEffectName)
    s.slotItem = game.slotItem(slot)
    s.mainhand = game.slotItem('mainhand')
    s.offhand = game.slotItem('offhand')
    s.wantName = M.wantedName(cfg, s)
    s.want = game.findItem(s.wantName, slot)
    if not s.want then s.wantInBank = game.inBank(s.wantName) end
    local stash = cfg.State.StashedOffhandItem
    if stash ~= '' then s.stash = game.findItem(stash, 'offhand') end
    return s
end

local function effectText(cfg, s)
    if s.effectWindow then
        return string.format('%s present (%s)', q(cfg.TriggerEffectName), s.effectWindow)
    end
    return string.format('%s absent', q(cfg.TriggerEffectName))
end

local function blocked(reason, level)
    return { kind = 'blocked', channel = 'guard', level = level, reason = reason }
end

-- Returns a decision: { kind, reason, channel?, level?, item?, slot?, stash?, restore? }.
-- kind is one of idle, paused, blocked, missing, ok (no action) or exchange,
-- unequip, clearstash (actions).
function M.decide(cfg, s, paused)
    local complete, missing = config.isComplete(cfg)
    if not complete then
        return { kind = 'idle', channel = 'config',
            reason = 'Not configured yet: set ' .. table.concat(missing, ', ') }
    end
    if same(cfg.MatchItemName, cfg.NoMatchItemName) then
        return { kind = 'idle', channel = 'config', level = 'warn',
            reason = 'MatchItemName and NoMatchItemName are the same item; nothing to swap' }
    end
    if not s.inGame then return blocked('not in game') end
    if paused then
        return { kind = 'paused', channel = 'swap',
            reason = string.format('paused; %s, would want %s in %s',
                effectText(cfg, s), q(s.wantName), cfg.SwapEquipmentSlot) }
    end
    if not s.exchangeLoaded then
        return { kind = 'idle', channel = 'guard', level = 'warn',
            reason = 'MQ2Exchange is not loaded, and BogoSwap needs it to swap. Load it with /plugin mq2exchange' }
    end
    local cs = s.charState
    if cs == 'DEAD' or cs == 'HOVER' then return blocked('dead') end
    if cs == 'STUN' then return blocked('stunned') end
    if cs == 'FEIGN' then return blocked('feigning death') end
    if s.casting and not s.isBard then return blocked('casting ' .. q(s.casting)) end
    if s.cursor then return blocked('item on cursor: ' .. q(s.cursor)) end

    local slot = cfg.SwapEquipmentSlot
    local cur = s.slotItem
    local eff = effectText(cfg, s)

    if cur and same(cur.name, s.wantName) then
        local stash = cfg.State.StashedOffhandItem
        if slot == 'mainhand' and stash ~= '' and not M.isTwoHander(cur) then
            if s.offhand then
                return { kind = 'clearstash', reason = string.format(
                    'offhand already holds %s; forgetting remembered offhand %s', q(s.offhand.name), q(stash)) }
            end
            if not s.stash then
                return { kind = 'clearstash', level = 'warn', reason = string.format(
                    'remembered offhand %s is no longer in inventory; forgetting it', q(stash)) }
            end
            return { kind = 'exchange', item = s.stash.name, slot = 'offhand', restore = true,
                reason = string.format('%s is one-handed; restoring remembered offhand %s',
                    q(cur.name), q(s.stash.name)) }
        end
        return { kind = 'ok', channel = 'swap',
            reason = string.format('%s; %s holds %s as wanted', eff, slot, q(cur.name)) }
    end

    local want = s.want
    if not want then
        return { kind = 'missing', channel = 'swap', level = 'warn', reason = string.format(
            '%s; want %s in %s but it %s', eff, q(s.wantName), slot,
            s.wantInBank and 'is in the bank, not in inventory' or 'is not in inventory') }
    end
    if want.canWear == false then
        return blocked(string.format("%s can't be worn in %s", q(want.name), slot), 'warn')
    end
    if slot == 'offhand' and M.isTwoHander(s.mainhand) then
        return blocked(string.format('offhand is blocked by two-hander %s in mainhand',
            q(s.mainhand.name)), 'warn')
    end
    if slot == 'mainhand' and M.isTwoHander(want) and s.offhand then
        if (s.freeInventory or 0) < 1 then
            return blocked(string.format(
                'no free inventory slot to hold offhand %s while two-hander %s is equipped',
                q(s.offhand.name), q(want.name)), 'warn')
        end
        return { kind = 'unequip', slot = 'offhand', stash = s.offhand.name,
            reason = string.format('%s; %s is two-handed, so offhand %s comes off first',
                eff, q(want.name), q(s.offhand.name)) }
    end
    return { kind = 'exchange', item = want.name, slot = slot, reason = string.format(
        '%s; %s holds %s, want %s', eff, slot, cur and q(cur.name) or 'nothing', q(want.name)) }
end

local function verified(p, s)
    if not s.inGame then return false end
    if p.kind == 'exchange' then
        local cur = p.slot == 'offhand' and s.offhand or p.slot == 'mainhand' and s.mainhand or s.slotItem
        return cur ~= nil and same(cur.name, p.item)
    elseif p.kind == 'unequip' then
        return s.offhand == nil
    end
    return true
end

local function execute(state, d, now)
    local cfg = state.cfg
    local n = log.nextAction()
    log.resetNote('status')
    local reason = d.reason
    if state.retryOf then
        reason = string.format('retry of #%d: %s', state.retryOf, reason)
        state.retryOf = nil
    end
    log.debug('swap', n, '%s', reason)
    if d.kind == 'exchange' then
        local c = game.exchange(d.item, d.slot)
        log.debug('swap', n, 'command: %s', c)
        state.pending = { n = n, kind = 'exchange', item = d.item, slot = d.slot,
            restore = d.restore, time = now }
    elseif d.kind == 'unequip' then
        cfg.State.StashedOffhandItem = d.stash
        config.save(cfg, state.cfgPath)
        log.debug('swap', n, 'remembering offhand %s to restore later', q(d.stash))
        local c = game.unequip(d.slot)
        log.debug('swap', n, 'command: %s', c)
        state.pending = { n = n, kind = 'unequip', slot = d.slot, time = now }
    elseif d.kind == 'clearstash' then
        cfg.State.StashedOffhandItem = ''
        config.save(cfg, state.cfgPath)
        if d.level == 'warn' then log.warn('#%d %s', n, reason) end
    end
    state.lastAction = { n = n, text = reason }
end

-- One pass of the loop. force (from /bogoswap swapnow) skips the retry wait and the
-- pause check for this pass only.
function M.tick(state, now, force)
    local cfg = state.cfg
    local s = M.snapshot(cfg)
    state.snap = s
    state.waiting = nil

    local p = state.pending
    if p then
        if verified(p, s) then
            if p.kind == 'exchange' then
                log.debug('swap', p.n, 'verified: %s now holds %s', p.slot, q(p.item))
            else
                log.debug('swap', p.n, 'verified: %s is now empty', p.slot)
            end
            if p.restore then
                cfg.State.StashedOffhandItem = ''
                config.save(cfg, state.cfgPath)
            end
            state.pending = nil
        else
            local age = now - p.time
            if age < cfg.SettleMs then
                state.waiting = string.format('waiting for #%d to take effect', p.n)
                return
            end
            if not p.reported then
                p.reported = true
                log.debug('swap', p.n, 'not confirmed after %d ms; will retry after %d ms', age, cfg.RetryMs)
            end
            if age < cfg.RetryMs and not force then
                state.waiting = string.format('#%d did not take effect; retrying soon', p.n)
                return
            end
            state.retryOf = p.n
            state.pending = nil
        end
    end

    local d = M.decide(cfg, s, state.paused and not force)
    state.decision = d
    if M.ACTIONS[d.kind] then
        execute(state, d, now)
    else
        state.retryOf = nil
        log.note('status', d.channel or 'swap', d.level, d.reason)
    end
end

return M

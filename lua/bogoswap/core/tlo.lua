-- ${BogoSwap} TLO: read-only state for macros and other scripts.
local mq = require('mq')
local log = require('bogoswap.core.log')

local M = {}

local NAME = 'BogoSwap'

local function str(v)
    if v == nil or v == '' then return 'string', 'NULL' end
    return 'string', tostring(v)
end

function M.members(state)
    local function snap() return state.snap or {} end
    return {
        Version = function(param, self) return str(state.version) end,
        Paused = function(param, self) return 'bool', state.paused == true end,
        State = function(param, self)
            if state.paused then return 'string', 'paused' end
            return str(state.decision and state.decision.kind)
        end,
        Status = function(param, self)
            return str(state.waiting or (state.decision and state.decision.reason))
        end,
        TriggerEffectName = function(param, self) return str(state.cfg.TriggerEffectName) end,
        SwapEquipmentSlot = function(param, self) return str(state.cfg.SwapEquipmentSlot) end,
        MatchItemName = function(param, self) return str(state.cfg.MatchItemName) end,
        NoMatchItemName = function(param, self) return str(state.cfg.NoMatchItemName) end,
        EffectPresent = function(param, self) return 'bool', snap().effectWindow ~= nil end,
        WantedItem = function(param, self) return str(snap().wantName) end,
        LastAction = function(param, self)
            local la = state.lastAction
            if not la then return 'string', 'NULL' end
            return 'string', string.format('#%d %s', la.n, la.text)
        end,
    }
end

function M.register(state)
    if not (mq.DataType and mq.DataType.new and mq.AddTopLevelObject) then
        log.warn('This MacroQuest build has no Lua TLO support; ${%s} is unavailable.', NAME)
        return false
    end
    local dataType = mq.DataType.new('BogoSwapType', {
        Members = M.members(state),
        ToString = function(self)
            return state.paused and 'paused' or 'running'
        end,
    })
    mq.AddTopLevelObject(NAME, function(param)
        return dataType, state
    end)
    state.tloRegistered = true
    return true
end

function M.unregister(state)
    if state.tloRegistered and mq.RemoveTopLevelObject then
        mq.RemoveTopLevelObject(NAME)
        state.tloRegistered = false
    end
end

return M

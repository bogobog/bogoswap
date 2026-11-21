-- Logging: user-facing messages plus debug channels with a shared action number.
--
-- Every decision or action BogoSwap takes gets a number from nextAction(); every line
-- logged about that action carries the same number, so "why did it do that" can be
-- followed through decide -> command -> verify.
local M = {}

M.CHANNELS = { 'swap', 'guard', 'config', 'cmd', 'ui' }

local known = {}
for _, c in ipairs(M.CHANNELS) do known[c] = true end

local PREFIX = '\at[BogoSwap]\ax '
local counter = 0
local enabled = {}
local lastNote = {}

local function emit(s)
    print(s)
end

-- Formats only when arguments are given, so a message containing '%' and no
-- arguments is printed as is.
local function fmt(f, ...)
    if select('#', ...) == 0 then return tostring(f) end
    return string.format(f, ...)
end

function M.isChannel(c) return known[c] == true end

function M.setChannel(c, on) enabled[c] = on and true or false end

function M.channelEnabled(c) return enabled[c] == true end

function M.applyChannels(t)
    for _, c in ipairs(M.CHANNELS) do enabled[c] = (t and t[c]) == true end
end

function M.enabledChannels()
    local on = {}
    for _, c in ipairs(M.CHANNELS) do
        if enabled[c] then on[#on + 1] = c end
    end
    return on
end

function M.info(f, ...) emit(PREFIX .. fmt(f, ...)) end

function M.warn(f, ...) emit(PREFIX .. '\ay' .. fmt(f, ...) .. '\ax') end

function M.err(f, ...) emit(PREFIX .. '\ar' .. fmt(f, ...) .. '\ax') end

function M.nextAction()
    counter = counter + 1
    return counter
end

function M.debug(ch, n, f, ...)
    assert(known[ch], 'unknown log channel ' .. tostring(ch))
    if not enabled[ch] then return end
    emit(string.format('%s\am#%d %s\ax %s', PREFIX, n, ch, fmt(f, ...)))
end

-- Logs a status message under a new action number, but only when it differs from
-- the last message logged under the same key. Keeps a guard that blocks every tick
-- from flooding the log. level 'warn' shows it to the user even with debug off.
function M.note(key, ch, level, msg)
    if lastNote[key] == msg then return nil end
    lastNote[key] = msg
    local n = M.nextAction()
    if level == 'warn' then
        M.warn('#%d %s', n, msg)
    else
        M.debug(ch, n, '%s', msg)
    end
    return n
end

function M.resetNote(key) lastNote[key] = nil end

return M

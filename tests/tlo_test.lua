local setup = require('setup')

local function nparams(fn) return debug.getinfo(fn, 'u').nparams end

test('callbacks have the parameters MacroQuest requires', function(m, t)
    m.start()
    local handler = m.tlos.BogoSwap
    t.ok(handler, 'registered')
    t.eq(nparams(handler), 1, 'handler(param)')
    local dt = handler('')
    t.eq(nparams(dt.def.ToString), 1, 'ToString(self)')
    for name, fn in pairs(dt.def.Members) do
        t.eq(nparams(fn), 2, name .. '(param, self)')
    end
end)

test('every member returns a type and a value', function(m, t)
    m.start()
    m.run(500)
    local dt, value = m.tlos.BogoSwap('')
    t.ok(value ~= nil, 'handler returns a value')
    for name, fn in pairs(dt.def.Members) do
        local ty, v = fn('', value)
        t.eq(type(ty), 'string', name .. ' type')
        t.ok(v ~= nil, name .. ' value')
    end
end)

test('members report state, NULL when empty', function(m, t)
    setup.swords(m)
    m.start()
    m.run(500)
    local dt, value = m.tlos.BogoSwap('')
    local M = dt.def.Members
    local function get(name) return select(2, M[name]('', value)) end
    t.eq(get('Paused'), true)
    t.eq(get('State'), 'paused')
    t.eq(get('MatchItemName'), 'Fine Steel Sword')
    t.eq(get('EffectPresent'), false)
    t.eq(get('WantedItem'), 'Rusty Sword')
    t.eq(get('LastAction'), 'NULL')
    t.eq(dt.def.ToString(value), 'paused')
    m.command('/bogoswap resume')
    m.run(500)
    t.eq(get('Paused'), false)
    t.contains(get('LastAction'), "want 'Rusty Sword'")
    m.command('/bogoswap set MatchItemName')
    t.eq(get('MatchItemName'), 'NULL')
end)

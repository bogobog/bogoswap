test('pause defaults to on', function(m, t)
    local args = require('bogoswap.core.args')
    local o, w = args.parse({})
    t.eq(o.pause, true)
    t.eq(#w, 0)
end)

test('pause accepts yes/no style values in any case', function(m, t)
    local args = require('bogoswap.core.args')
    for _, v in ipairs({ 'no', 'false', 'off', '0', 'n', 'NO', 'Off' }) do
        t.eq(args.parse({ 'pause=' .. v }).pause, false, v)
    end
    for _, v in ipairs({ 'yes', 'true', 'on', '1', 'y', 'TRUE' }) do
        t.eq(args.parse({ 'pause=' .. v }).pause, true, v)
    end
    t.eq(args.parse({ 'Pause=no' }).pause, false, 'key case')
end)

test('bad values and unknown arguments warn and keep the default', function(m, t)
    local args = require('bogoswap.core.args')
    local o, w = args.parse({ 'pause=maybe', 'speed=fast' })
    t.eq(o.pause, true)
    t.eq(#w, 2)
    t.contains(w[1], 'pause=maybe')
    t.contains(w[2], 'speed=fast')
end)

test('startup with pause=off says it is running', function(m, t)
    m.start('pause=off')
    t.contains(m.output(), 'started and running (pause=off)')
end)

test('minimize defaults to off', function(m, t)
    local args = require('bogoswap.core.args')
    local o, w = args.parse({})
    t.eq(o.minimize, false)
    t.eq(o.minimizeSource, 'default')
    t.eq(#w, 0)
end)

test('minimize accepts yes/no style values and a bare minimize', function(m, t)
    local args = require('bogoswap.core.args')
    for _, v in ipairs({ 'yes', 'true', 'on', '1', 'y', 'YES' }) do
        t.eq(args.parse({ 'minimize=' .. v }).minimize, true, v)
    end
    for _, v in ipairs({ 'no', 'false', 'off', '0', 'n', 'Off' }) do
        t.eq(args.parse({ 'minimize=' .. v }).minimize, false, v)
    end
    local o, w = args.parse({ 'minimize' })
    t.eq(o.minimize, true, 'bare')
    t.eq(o.minimizeSource, 'minimize')
    t.eq(#w, 0)
    t.eq(args.parse({ 'Minimize' }).minimize, true, 'bare, any case')
end)

test('minimize and pause combine in either order', function(m, t)
    local args = require('bogoswap.core.args')
    for _, list in ipairs({ { 'pause=no', 'minimize' }, { 'minimize=on', 'pause=no' } }) do
        local o, w = args.parse(list)
        t.eq(o.pause, false)
        t.eq(o.minimize, true)
        t.eq(#w, 0)
    end
end)

test('a bad minimize value warns and keeps the full window; bare pause is still unknown', function(m, t)
    local args = require('bogoswap.core.args')
    local o, w = args.parse({ 'minimize=maybe', 'pause' })
    t.eq(o.minimize, false)
    t.eq(o.pause, true)
    t.eq(#w, 2)
    t.contains(w[1], 'Ignoring "minimize=maybe"')
    t.contains(w[2], 'Supported: pause=yes|no, minimize=yes|no.')
end)

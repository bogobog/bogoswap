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

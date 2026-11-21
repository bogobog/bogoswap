local setup = require('setup')

local MINI = 'BogoSwap Mini###BogoSwapMini'
local MAIN = 'BogoSwap###BogoSwap'

local function windowNames(m)
    local names = {}
    for _, w in ipairs(m.ui.windows) do names[#names + 1] = w.name end
    return table.concat(names, ',')
end

local function sameColor(a, b)
    for i = 1, 4 do if a[i] ~= b[i] then return false end end
    return true
end

test('the _ button sits just left of Stop at the right edge', function(m, t)
    m.start()
    m.frame()
    local x = m.ui.buttonX
    t.eq(x['Stop##stop'], m.ui.windowWidth - 60, 'Stop still flush right')
    t.eq(x['_##minimize'], x['Stop##stop'] - 8 - 24, 'one gap left of Stop')
    t.ok(x['_##minimize'] > x['Resume##pause'], 'right of Pause')
end)

test('_ replaces the window with a BS button, and BS restores it', function(m, t)
    m.start()
    m.ui.hover = '_##minimize'
    m.frame()
    t.contains(table.concat(m.ui.texts, '\n'), 'Minimize to a small BS button.')
    m.ui.clicks['_##minimize'] = true
    m.frame()
    m.frame()
    t.eq(windowNames(m), MINI, 'only the mini window is drawn')
    t.eq(table.concat(m.ui.calls, ','), 'Button:BS##bogoswap_restore', 'it holds a single BS button')
    m.ui.clicks['BS##bogoswap_restore'] = true
    m.frame()
    m.frame()
    t.eq(windowNames(m), MAIN, 'full window back')
    t.eq(m.ui.calls[1], 'Button:Resume##pause')
end)

test('the BS window has no title bar, sizes to fit, and opens top-left the first time', function(m, t)
    m.start()
    m.command('/bogoswap ui min')
    m.frame()
    local w = m.ui.windows[1]
    local f = ImGuiWindowFlags
    t.eq(w.flags, f.NoTitleBar + f.NoResize + f.NoScrollbar + f.NoCollapse + f.AlwaysAutoResize)
    t.eq(w.pos.x, 20)
    t.eq(w.pos.y, 20)
    t.eq(w.pos.cond, ImGuiCond.FirstUseEver, 'ImGui keeps where you drag it')
end)

test('BS is blue while paused and green while running, with a state tooltip', function(m, t)
    local panel = require('bogoswap.ui.panel')
    m.start()
    m.command('/bogoswap ui min')
    m.ui.hover = 'BS##bogoswap_restore'
    m.frame()
    t.ok(sameColor(m.ui.lastButtonColor, panel.BUTTON_PAUSED[1]), 'blue while paused')
    t.contains(table.concat(m.ui.texts, '\n'), 'BogoSwap (paused). Click to restore the window.')
    m.command('/bogoswap resume')
    m.frame()
    t.ok(sameColor(m.ui.lastButtonColor, panel.BUTTON_RUNNING[1]), 'green while running')
    t.contains(table.concat(m.ui.texts, '\n'), 'BogoSwap (running).')
end)

test('right-clicking BS toggles pause and stays minimized', function(m, t)
    setup.swords(m, { Debug = { cmd = true } })
    local panel = require('bogoswap.ui.panel')
    m.start()
    m.command('/bogoswap ui min')
    m.frame()
    m.ui.rightClicks['BS##bogoswap_restore'] = true
    m.frame()
    t.contains(m.output(), 'Resumed.')
    t.contains(m.output(), 'ui (right-click BS) resumed BogoSwap')
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'swapping after right-click resume')
    m.frame()
    t.eq(windowNames(m), MINI, 'still minimized')
    t.ok(sameColor(m.ui.lastButtonColor, panel.BUTTON_RUNNING[1]), 'BS turned green')
    m.ui.rightClicks['BS##bogoswap_restore'] = true
    m.frame()
    t.contains(m.output(), 'Paused. Watching, but taking no action.')
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'no swap after right-click pause')
    m.frame()
    t.ok(sameColor(m.ui.lastButtonColor, panel.BUTTON_PAUSED[1]), 'BS turned blue')
    t.eq(windowNames(m), MINI, 'right-click never restores')
end)

test('the BS tooltip explains both clicks', function(m, t)
    m.start()
    m.command('/bogoswap ui min')
    m.ui.hover = 'BS##bogoswap_restore'
    m.frame()
    t.contains(table.concat(m.ui.texts, '\n'), 'Click to restore the window. Right-click to resume.')
    m.command('/bogoswap resume')
    m.frame()
    t.contains(table.concat(m.ui.texts, '\n'), 'Right-click to pause.')
end)

test('swapping carries on while minimized', function(m, t)
    setup.swords(m)
    m.start('pause=no')
    m.ui.clicks['_##minimize'] = true
    m.frame()
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(1000)
    m.frame()
    t.eq(m.world.slots.mainhand, 'Fine Steel Sword')
    t.eq(windowNames(m), MINI)
end)

test('/bogoswap ui: alone or "on" restores, "off" hides both, "min" minimizes', function(m, t)
    m.start()
    m.command('/bogoswap ui min')
    m.frame()
    t.eq(windowNames(m), MINI, 'ui min')
    m.command('/bogoswap ui')
    m.frame()
    t.eq(windowNames(m), MAIN, 'ui restores from minimized')
    m.command('/bogoswap ui')
    m.frame()
    t.eq(windowNames(m), '', 'ui toggles the full window off')
    m.command('/bogoswap ui min')
    m.command('/bogoswap ui off')
    m.frame()
    t.eq(windowNames(m), '', 'ui off hides the BS button too')
    m.command('/bogoswap ui on')
    m.frame()
    t.eq(windowNames(m), MAIN, 'ui on shows the full window')
    m.command('/bogoswap ui sideways')
    t.contains(m.output(), 'Use: /bogoswap ui [on|off|min]')
end)

test('minimizing and restoring are logged; nothing is saved', function(m, t)
    setup.writeConfig(m, { Debug = { ui = true } })
    m.start()
    m.ui.clicks['_##minimize'] = true
    m.frame()
    m.ui.clicks['BS##bogoswap_restore'] = true
    m.frame()
    t.contains(m.output(), 'ui minimized to the BS button')
    t.contains(m.output(), 'ui restored the window from the BS button')
    local cfg = setup.readConfig(m)
    t.eq(cfg.Minimized, nil)
    t.eq(cfg.minimized, nil)
end)

test('a restart always opens the full window', function(m, t)
    m.start()
    m.command('/bogoswap ui min')
    m.command('/bogoswap quit')
    m.step(2)
    t.ok(m.finished)
    m.finished = nil
    m.start()
    m.frame()
    t.eq(windowNames(m), MAIN)
end)

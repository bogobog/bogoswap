local setup = require('setup')

local function texts(m) return table.concat(m.ui.texts, '\n') end

local HATER = { type = 'Auto Hater', id = 4242 }

test('OnlyInCombat is off by default, and swaps happen out of combat', function(m, t)
    setup.swords(m)
    m.start('pause=no')
    m.run(1000)
    t.eq(setup.readConfig(m).OnlyInCombat, false)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    t.eq(m.xtargetReads, 0, 'extended target not read while the option is off')
end)

test('OnlyInCombat blocks swaps until COMBAT, then swaps', function(m, t)
    setup.swords(m, { OnlyInCombat = true, Debug = { guard = true } })
    m.start('pause=no')
    for _, cs in ipairs({ 'ACTIVE', 'RESTING', 'COOLDOWN' }) do
        m.world.combatState = cs
        m.run(1000)
        t.eq(#m.cmds, 0, cs .. ' should block')
        t.eq(setup.count(m.output(), 'not in combat (OnlyInCombat is on; combat state ' .. cs .. ')'), 1,
            cs .. ' logged once')
    end
    m.world.combatState = 'COMBAT'
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'swaps in combat')
    m.world.combatState = 'ACTIVE'
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(2000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'no swap after combat ends')
    t.eq(#m.cmds, 1)
end)

test('DEBUFFED counts only while an auto hater is on extended target', function(m, t)
    setup.swords(m, { OnlyInCombat = true, Debug = { guard = true } })
    m.world.combatState = 'DEBUFFED'
    m.world.xtarget = { { type = 'Manual', id = 77 }, { type = 'Auto Hater', id = 0 } }
    m.start('pause=no')
    m.run(1000)
    t.eq(#m.cmds, 0, 'fight over, still debuffed: no swap')
    t.contains(m.output(), 'DEBUFFED, 0 auto hater(s) on extended target')
    m.world.xtarget[2] = HATER
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'debuffed during a fight swaps')
    m.world.xtarget[2] = { type = 'Auto Hater', id = 0 }
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(2000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'haters gone: no swap')
end)

test('extended target is read only while DEBUFFED', function(m, t)
    setup.swords(m, { OnlyInCombat = true })
    m.world.combatState = 'COMBAT'
    m.world.xtarget = { HATER }
    m.start('pause=no')
    m.run(1000)
    t.eq(m.xtargetReads, 0)
end)

test('swapnow overrides OnlyInCombat and says so', function(m, t)
    setup.swords(m, { OnlyInCombat = true, Debug = { swap = true } })
    m.start('pause=no')
    m.run(1000)
    t.eq(#m.cmds, 0)
    m.command('/bogoswap swapnow')
    m.step(1)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    t.contains(m.output(), '(swapnow overrides OnlyInCombat; combat state ACTIVE)')
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(2000)
    t.eq(#m.cmds, 1, 'back to waiting for combat')
end)

test('forgetting a remembered offhand waits for combat too', function(m, t)
    setup.swords(m, { OnlyInCombat = true, State = { StashedOffhandItem = 'Round Shield' } })
    m.world.slots = { mainhand = 'Rusty Sword', offhand = 'Fine Steel Sword' }
    m.world.bags = {}
    m.start('pause=no')
    m.run(1000)
    t.eq(setup.readConfig(m).State.StashedOffhandItem, 'Round Shield', 'kept out of combat')
    m.world.combatState = 'COMBAT'
    m.run(1000)
    t.eq(setup.readConfig(m).State.StashedOffhandItem, '', 'forgotten in combat')
end)

test('set OnlyInCombat takes on/off words and rejects others', function(m, t)
    setup.swords(m, { Debug = { config = true } })
    m.start()
    m.command('/bogoswap set onlyincombat on')
    t.eq(setup.readConfig(m).OnlyInCombat, true)
    t.contains(m.output(), 'OnlyInCombat = on')
    t.contains(m.output(), 'command set OnlyInCombat: off -> on')
    for _, w in ipairs({ 'no', 'false', '0', 'off' }) do
        m.command('/bogoswap set OnlyInCombat yes')
        m.command('/bogoswap set OnlyInCombat ' .. w)
        t.eq(setup.readConfig(m).OnlyInCombat, false, w)
    end
    m.command('/bogoswap set OnlyInCombat maybe')
    t.contains(m.output(), 'Use: /bogoswap set OnlyInCombat on|off')
    m.command('/bogoswap set OnlyInCombat')
    t.eq(setup.readConfig(m).OnlyInCombat, false, 'blank is rejected, not cleared')
    m.command('/bogoswap set Colour red')
    t.contains(m.output(), 'NoMatchItemName, OnlyInCombat')
end)

test('show, help and the TLO report OnlyInCombat', function(m, t)
    setup.swords(m, { OnlyInCombat = true })
    m.world.combatState = 'DEBUFFED'
    m.start()
    m.run(500)
    m.command('/bogoswap show')
    t.contains(m.output(), 'OnlyInCombat = on')
    t.contains(m.output(), 'Combat state: DEBUFFED, 0 auto hater(s) on extended target')
    m.command('/bogoswap help')
    t.contains(m.output(), 'set OnlyInCombat on|off')
    local dt, value = m.tlos.BogoSwap('')
    local ty, v = dt.def.Members.OnlyInCombat('', value)
    t.eq(ty, 'bool')
    t.eq(v, true)
end)

test('Options sits under Status, starts collapsed, and holds the OnlyInCombat checkbox', function(m, t)
    setup.swords(m)
    m.start()
    m.run(500)
    m.frame()
    t.eq(m.ui.headers.bogoswap_options, 'Options')
    t.eq(m.ui.headerFlags.bogoswap_options, nil, 'no DefaultOpen flag')
    t.eq(m.ui.checkboxes['OnlyInCombat##opt_OnlyInCombat'], nil, 'collapsed: checkbox hidden')
    local order = {}
    for i, s in ipairs(m.ui.texts) do order[s] = order[s] or i end
    t.ok(order['Options'] > order['Wanted: Rusty Sword'], 'below the status details')
    t.ok(order['Options'] < order['Trigger Effect'], 'above the settings')
    m.ui.headerOpen.bogoswap_options = true
    m.frame()
    t.eq(m.ui.checkboxes['OnlyInCombat##opt_OnlyInCombat'], false)
end)

test('the OnlyInCombat checkbox saves, and the status shows the combat state', function(m, t)
    setup.swords(m)
    m.start()
    m.run(500)
    m.ui.headerOpen.bogoswap_options = true
    m.ui.clicks['OnlyInCombat##opt_OnlyInCombat'] = true
    m.frame()
    t.eq(setup.readConfig(m).OnlyInCombat, true)
    m.run(500)
    m.frame()
    t.eq(m.ui.checkboxes['OnlyInCombat##opt_OnlyInCombat'], true)
    t.contains(texts(m), 'Combat state: ACTIVE')
    m.ui.hover = 'OnlyInCombat##opt_OnlyInCombat'
    m.frame()
    t.contains(texts(m), 'Setting: OnlyInCombat  (/bogoswap set OnlyInCombat on|off)', 'tooltip')
    m.ui.clicks['OnlyInCombat##opt_OnlyInCombat'] = true
    m.frame()
    t.eq(setup.readConfig(m).OnlyInCombat, false, 'unchecked')
    m.run(500)
    m.frame()
    t.notContains(texts(m), 'Combat state:')
end)

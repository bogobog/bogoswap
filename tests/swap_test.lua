local setup = require('setup')

test('starts paused and takes no action', function(m, t)
    setup.swords(m)
    m.start()
    m.run(3000)
    t.eq(#m.cmds, 0, 'commands while paused')
    t.contains(m.output(), 'started PAUSED')
    t.contains(m.output(), 'pause=no')
end)

test('pause=no starts running and equips NoMatchItemName', function(m, t)
    setup.swords(m)
    m.start('pause=no')
    m.run(1000)
    t.eq(m.cmds[1], '/exchange "Rusty Sword" mainhand')
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    t.eq(#m.cmds, 1, 'only one swap')
end)

test('swaps on buff, back on fade, with debug log', function(m, t)
    setup.swords(m, { Debug = setup.ALL_DEBUG })
    m.start('pause=no')
    m.run(1000)
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Fine Steel Sword')
    m.world.buffs = {}
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    m.command('/bogoswap quit')
    m.step(2)
    t.ok(m.finished, 'script ended')
    t.snapshot('buff_cycle', m.output())
end)

test('an effect in the song window counts', function(m, t)
    setup.swords(m)
    m.world.songs = { 'Spirit of Wolf' }
    m.start('pause=no')
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Fine Steel Sword')
end)

test('guards block swaps and are logged once per reason', function(m, t)
    setup.swords(m, { Debug = { guard = true } })
    local cases = {
        { 'casting', function() m.world.casting = 'Complete Heal' end, function() m.world.casting = nil end, "casting 'Complete Heal'" },
        { 'cursor', function() m.world.cursor = 'Bread' end, function() m.world.cursor = nil end, "item on cursor: 'Bread'" },
        { 'dead', function() m.world.charState = 'HOVER' end, function() m.world.charState = 'STAND' end, 'dead' },
        { 'stunned', function() m.world.charState = 'STUN' end, function() m.world.charState = 'STAND' end, 'stunned' },
        { 'feign', function() m.world.charState = 'FEIGN' end, function() m.world.charState = 'STAND' end, 'feigning death' },
    }
    cases[1][2]()
    m.start('pause=no')
    for i, c in ipairs(cases) do
        if i > 1 then c[2]() end
        m.run(2000)
        t.eq(#m.cmds, 0, c[1] .. ' should block')
        t.eq(setup.count(m.output(), c[4]), 1, c[1] .. ' logged once')
        c[3]()
    end
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'swaps once guards clear')
end)

test('bards are not blocked by casting', function(m, t)
    setup.swords(m)
    m.world.class = 'BRD'
    m.world.casting = 'Selo`s Accelerando'
    m.start('pause=no')
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
end)

test('a missing item warns once', function(m, t)
    setup.swords(m)
    m.world.bags = { 'Fine Steel Sword' }
    m.start('pause=no')
    m.run(5000)
    t.eq(#m.cmds, 0)
    t.eq(setup.count(m.output(), "want 'Rusty Sword' in mainhand but it is not in inventory"), 1)
end)

test('an item in the bank says so', function(m, t)
    setup.swords(m)
    m.world.bags = {}
    m.world.bank = { 'Rusty Sword' }
    m.start('pause=no')
    m.run(1000)
    t.contains(m.output(), 'is in the bank, not in inventory')
end)

test('a swap that does not take effect is retried after RetryMs', function(m, t)
    setup.swords(m, { Debug = { swap = true } })
    m.world.simulate = false
    m.start('pause=no')
    m.run(2500)
    t.eq(#m.cmds, 1, 'no retry before RetryMs')
    t.contains(m.output(), 'not confirmed after')
    m.run(1000)
    t.eq(#m.cmds, 2, 'retried')
    t.contains(m.output(), 'retry of #')
end)

test('swapnow skips the retry wait and works while paused', function(m, t)
    setup.swords(m)
    m.start()
    m.run(1000)
    t.eq(#m.cmds, 0)
    m.command('/bogoswap swapnow')
    m.step(1)
    t.eq(#m.cmds, 1, 'one swap while paused')
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(2000)
    t.eq(#m.cmds, 1, 'still paused after swapnow')
end)

test('two-hander: offhand comes off first and is restored', function(m, t)
    setup.items(m)
    setup.writeConfig(m, {
        TriggerEffectName = 'Spirit of Wolf', SwapEquipmentSlot = 'mainhand',
        MatchItemName = 'Greatstaff', NoMatchItemName = 'Fine Steel Sword',
        Debug = setup.ALL_DEBUG,
    })
    m.world.slots = { mainhand = 'Fine Steel Sword', offhand = 'Round Shield' }
    m.world.bags = { 'Greatstaff' }
    m.start('pause=no')
    m.run(1000)
    t.eq(#m.cmds, 0, 'nothing to do yet')
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(2000)
    t.eq(m.cmds[1], '/unequip offhand')
    t.eq(m.cmds[2], '/exchange "Greatstaff" mainhand')
    t.eq(m.world.slots.mainhand, 'Greatstaff')
    t.eq(setup.readConfig(m).State.StashedOffhandItem, 'Round Shield', 'stash saved')
    m.world.buffs = {}
    m.run(2000)
    t.eq(m.cmds[3], '/exchange "Fine Steel Sword" mainhand')
    t.eq(m.cmds[4], '/exchange "Round Shield" offhand')
    t.eq(m.world.slots.offhand, 'Round Shield')
    m.run(1000)
    t.eq(setup.readConfig(m).State.StashedOffhandItem, '', 'stash cleared')
    t.eq(#m.cmds, 4)
    t.snapshot('two_hander', m.output())
end)

test('two-hander with no free inventory is blocked', function(m, t)
    setup.items(m)
    setup.writeConfig(m, {
        TriggerEffectName = 'Spirit of Wolf', SwapEquipmentSlot = 'mainhand',
        MatchItemName = 'Greatstaff', NoMatchItemName = 'Fine Steel Sword',
    })
    m.world.slots = { mainhand = 'Fine Steel Sword', offhand = 'Round Shield' }
    m.world.bags = { 'Greatstaff' }
    m.world.freeInventory = 0
    m.world.buffs = { 'Spirit of Wolf' }
    m.start('pause=no')
    m.run(2000)
    t.eq(#m.cmds, 0)
    t.contains(m.output(), "no free inventory slot to hold offhand 'Round Shield'")
end)

test('offhand swaps are blocked by a two-hander in mainhand', function(m, t)
    setup.items(m)
    setup.writeConfig(m, {
        TriggerEffectName = 'Spirit of Wolf', SwapEquipmentSlot = 'offhand',
        MatchItemName = 'Round Shield', NoMatchItemName = 'Rusty Sword',
    })
    m.world.slots = { mainhand = 'Greatstaff' }
    m.world.bags = { 'Round Shield', 'Rusty Sword' }
    m.start('pause=no')
    m.run(2000)
    t.eq(#m.cmds, 0)
    t.contains(m.output(), "offhand is blocked by two-hander 'Greatstaff'")
end)

test("an item that can't be worn in the slot is blocked", function(m, t)
    setup.swords(m, { NoMatchItemName = 'Lucky Charm' })
    m.world.bags = { 'Fine Steel Sword', 'Lucky Charm' }
    m.start('pause=no')
    m.run(2000)
    t.eq(#m.cmds, 0)
    t.contains(m.output(), "'Lucky Charm' can't be worn in mainhand")
end)

test('a remembered offhand survives a restart', function(m, t)
    setup.swords(m, { State = { StashedOffhandItem = 'Round Shield' } })
    m.world.slots = { mainhand = 'Rusty Sword' }
    m.world.bags = { 'Fine Steel Sword', 'Round Shield' }
    m.start('pause=no')
    m.run(1000)
    t.eq(m.cmds[1], '/exchange "Round Shield" offhand')
    m.run(1000)
    t.eq(setup.readConfig(m).State.StashedOffhandItem, '')
end)

test('a remembered offhand is forgotten when the offhand is already filled', function(m, t)
    setup.swords(m, { State = { StashedOffhandItem = 'Round Shield' } })
    m.world.slots = { mainhand = 'Rusty Sword', offhand = 'Fine Steel Sword' }
    m.world.bags = { 'Round Shield' }
    m.start('pause=no')
    m.run(1000)
    t.eq(#m.cmds, 0)
    t.eq(setup.readConfig(m).State.StashedOffhandItem, '')
end)

test('without MQ2Exchange nothing is swapped and the user is told', function(m, t)
    setup.swords(m)
    m.world.plugins = {}
    m.start('pause=no')
    m.run(3000)
    t.eq(#m.cmds, 0)
    t.contains(m.output(), '/plugin mq2exchange')
end)

test('an incomplete config does nothing and does not warn', function(m, t)
    setup.items(m)
    setup.writeConfig(m, { TriggerEffectName = 'Spirit of Wolf' })
    m.world.bags = { 'Rusty Sword' }
    m.start('pause=no')
    m.run(3000)
    t.eq(#m.cmds, 0)
    t.notContains(m.output(), 'Not configured')
end)

test('the same item for both settings warns', function(m, t)
    setup.swords(m, { MatchItemName = 'Rusty Sword' })
    m.start('pause=no')
    m.run(2000)
    t.eq(#m.cmds, 0)
    t.contains(m.output(), 'MatchItemName and NoMatchItemName are the same item')
end)

test('waits until in game before starting', function(m, t)
    setup.swords(m)
    m.world.gameState = 'CHARSELECT'
    m.start('pause=no')
    m.run(3000)
    t.contains(m.output(), 'Waiting until you are in game')
    t.eq(#m.cmds, 0)
    m.world.gameState = 'INGAME'
    m.run(2000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
end)

test('item names with % are logged safely', function(m, t)
    m.item('Blade of 100% Doom', '1H Slashing', { 'mainhand' })
    setup.swords(m, { NoMatchItemName = 'Blade of 100% Doom', Debug = setup.ALL_DEBUG })
    m.world.bags = { 'Blade of 100% Doom' }
    m.start('pause=no')
    m.run(1000)
    t.eq(m.cmds[1], '/exchange "Blade of 100% Doom" mainhand')
    t.contains(m.output(), "want 'Blade of 100% Doom'")
end)

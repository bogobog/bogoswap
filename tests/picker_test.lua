local setup = require('setup')

local MATCH = 'MatchItemName##pick_MatchItemName'
local NOMATCH = 'NoMatchItemName##pick_NoMatchItemName'

-- Item names offered in the open picker for key, without tags or ImGui ids.
local function offered(m, key)
    local prefix = '##pick_' .. key .. '_'
    local out = {}
    for _, label in ipairs(m.ui.selectables) do
        local shown, id = label:match('^(.-)(##.*)$')
        if id and id:sub(1, #prefix) == prefix and id ~= prefix .. 'none' then out[#out + 1] = shown end
    end
    return table.concat(out, ', ')
end

local function bagsAndCharm(m)
    setup.swords(m)
    m.world.bags = { 'Rusty Sword', 'Round Shield', 'Lucky Charm', 'Greatstaff', 'Rusty Sword', 'Fine Steel Sword' }
end

test('lists only items that fit the slot, deduplicated and sorted, with 2H tagged', function(m, t)
    bagsAndCharm(m)
    m.start()
    m.ui.openCombo = MATCH
    m.frame()
    t.eq(offered(m, 'MatchItemName'), 'Fine Steel Sword, Greatstaff (2H), Rusty Sword')
end)

test('the list follows the chosen slot', function(m, t)
    bagsAndCharm(m)
    m.start()
    m.command('/bogoswap set SwapEquipmentSlot offhand')
    m.ui.openCombo = NOMATCH
    m.frame()
    t.eq(offered(m, 'NoMatchItemName'), 'Fine Steel Sword, Round Shield, Rusty Sword', 'no 2H tag outside mainhand')
    m.command('/bogoswap set SwapEquipmentSlot charm')
    m.ui.openCombo = nil
    m.frame()
    m.ui.openCombo = NOMATCH
    m.frame()
    t.eq(offered(m, 'NoMatchItemName'), 'Lucky Charm')
end)

test('includes the worn item and loose inventory items; skips unusable ones', function(m, t)
    setup.swords(m)
    m.item('Holy Mace', '1H Blunt', { 'mainhand' }, { canUse = false })
    m.item('Pitchfork', '2H Piercing', { 'mainhand' })
    m.world.slots = { mainhand = 'Fine Steel Sword' }
    m.world.bags = { 'Holy Mace' }
    m.world.loose = { [27] = 'Pitchfork' }
    m.start()
    m.ui.openCombo = MATCH
    m.frame()
    t.eq(offered(m, 'MatchItemName'), 'Fine Steel Sword, Pitchfork (2H)')
end)

test('picking an item saves it; (none) clears it', function(m, t)
    bagsAndCharm(m)
    m.start()
    m.ui.openCombo = MATCH
    m.ui.clicks['Greatstaff (2H)##pick_MatchItemName_Greatstaff'] = true
    m.frame()
    t.eq(setup.readConfig(m).MatchItemName, 'Greatstaff')
    m.ui.clicks['(none)##pick_MatchItemName_none'] = true
    m.frame()
    t.eq(setup.readConfig(m).MatchItemName, '')
end)

test('the search box narrows the list', function(m, t)
    bagsAndCharm(m)
    m.start()
    m.ui.openCombo = MATCH
    m.ui.inputs['Search##search_MatchItemName'] = { 'SWORD', true }
    m.frame()
    t.eq(offered(m, 'MatchItemName'), 'Fine Steel Sword, Rusty Sword')
    m.ui.inputs['Search##search_MatchItemName'] = { 'zzz', true }
    m.frame()
    t.eq(offered(m, 'MatchItemName'), '')
    t.contains(table.concat(m.ui.texts, '\n'), 'No match.')
end)

test('an empty list says nothing fits', function(m, t)
    setup.swords(m)
    m.world.bags = { 'Round Shield' }
    m.start()
    m.command('/bogoswap set SwapEquipmentSlot ammo')
    m.ui.openCombo = MATCH
    m.frame()
    t.contains(table.concat(m.ui.texts, '\n'), 'Nothing in your bags fits ammo.')
end)

test('the inventory is scanned on open and on Refresh only', function(m, t)
    bagsAndCharm(m)
    m.start()
    m.run(500)
    m.frame()
    m.frame()
    t.eq(m.packScans, 0, 'no scan while closed')
    m.ui.openCombo = MATCH
    m.frame()
    m.frame()
    m.frame()
    t.eq(m.packScans, 1, 'one scan while open')
    table.insert(m.world.bags, 'Pitchfork')
    m.item('Pitchfork', '2H Piercing', { 'mainhand' })
    m.ui.clicks['Refresh##refresh_MatchItemName'] = true
    m.frame()
    t.eq(m.packScans, 2, 'Refresh rescans')
    m.frame()
    t.contains(offered(m, 'MatchItemName'), 'Pitchfork (2H)')
    m.ui.openCombo = nil
    m.frame()
    m.ui.openCombo = MATCH
    m.frame()
    t.eq(m.packScans, 3, 'reopening rescans')
end)

test('the current value is shown and marked when it is not swappable', function(m, t)
    setup.swords(m)
    m.item('Holy Mace', '1H Blunt', { 'mainhand' }, { canUse = false })
    m.world.bags = { 'Fine Steel Sword', 'Lucky Charm', 'Holy Mace' }
    m.start()
    m.run(500)
    m.frame()
    t.eq(m.ui.previews[MATCH], 'Fine Steel Sword')
    t.eq(m.ui.previews[NOMATCH], 'Rusty Sword (not in inventory)')
    m.command('/bogoswap set NoMatchItemName Lucky Charm')
    m.frame()
    t.eq(m.ui.previews[NOMATCH], "Lucky Charm (can't be worn in mainhand)")
    m.command('/bogoswap set NoMatchItemName Holy Mace')
    m.frame()
    t.eq(m.ui.previews[NOMATCH], "Holy Mace (you can't use it)")
    m.command('/bogoswap set NoMatchItemName')
    m.frame()
    t.eq(m.ui.previews[NOMATCH], '(none)')
end)

test('without a slot the pickers are disabled with a hint', function(m, t)
    setup.items(m)
    m.world.bags = { 'Rusty Sword' }
    m.start()
    m.ui.openCombo = MATCH
    m.frame()
    t.ok(m.ui.disabledUsed, 'BeginDisabled used')
    t.eq(offered(m, 'MatchItemName'), '', 'does not open')
    t.eq(m.packScans, 0, 'no scan')
    t.contains(table.concat(m.ui.texts, '\n'), 'Choose SwapEquipmentSlot first.')
end)

test('scans are logged in the ui channel', function(m, t)
    bagsAndCharm(m)
    setup.writeConfig(m, {
        TriggerEffectName = 'Spirit of Wolf', SwapEquipmentSlot = 'mainhand',
        Debug = { ui = true },
    })
    m.start()
    m.ui.openCombo = MATCH
    m.frame()
    t.contains(m.output(), 'ui scanned inventory for mainhand: 3 eligible item(s) (opened MatchItemName picker)')
end)

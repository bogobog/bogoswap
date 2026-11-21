local setup = require('setup')

local function texts(m) return table.concat(m.ui.texts, '\n') end

test('the window shows paused state and status', function(m, t)
    setup.swords(m)
    m.start()
    m.run(500)
    m.frame()
    t.eq(m.ui.calls[1], 'Button:Resume##pause')
    t.contains(texts(m), 'PAUSED: taking no action')
    t.contains(texts(m), 'Effect: absent')
    t.contains(texts(m), 'Wanted: Rusty Sword')
end)

test('fields have friendly labels on the left and fill the row', function(m, t)
    setup.swords(m)
    m.start()
    m.frame()
    local shown = texts(m)
    for _, label in ipairs({ 'Trigger Effect', 'Equipment Slot', 'Trigger Found Item', 'Trigger Missing Item' }) do
        t.contains(shown, label)
    end
    for _, key in ipairs({ 'TriggerEffectName', 'SwapEquipmentSlot', 'MatchItemName', 'NoMatchItemName' }) do
        t.notContains(shown, key, 'canonical names only in tooltips')
    end
    -- Each label is drawn before its field, and the widgets carry no visible label.
    local order = {}
    for i, s in ipairs(m.ui.texts) do order[s] = i end
    t.ok(order['Trigger Effect'] < order['Equipment Slot'], 'label order')
    t.eq(table.concat(m.ui.order, ','), '##slot,##pick_MatchItemName,##pick_NoMatchItemName')
    for _, id in ipairs({ '##TriggerEffectName', '##slot', '##pick_MatchItemName', '##pick_NoMatchItemName' }) do
        t.eq(m.ui.widths[id], -1, id .. ' fills the row')
    end
end)

test('label tooltips name the canonical setting', function(m, t)
    setup.swords(m)
    m.start()
    for label, key in pairs({ ['Trigger Effect'] = 'TriggerEffectName', ['Equipment Slot'] = 'SwapEquipmentSlot',
        ['Trigger Found Item'] = 'MatchItemName', ['Trigger Missing Item'] = 'NoMatchItemName' }) do
        m.ui.hover = 'text:' .. label
        m.frame()
        t.contains(texts(m), 'Setting: ' .. key .. '  (/bogoswap set ' .. key .. ' <value>)', label)
    end
end)

test('an edited effect name leaves room for the Enter hint', function(m, t)
    m.start()
    m.ui.inputs['##TriggerEffectName'] = { 'Hast', false }
    m.frame()
    m.frame()
    t.eq(m.ui.widths['##TriggerEffectName'], -110)
    t.contains(texts(m), '(Enter to apply)')
end)

test('panel status uses the friendly labels; chat and the TLO keep canonical names', function(m, t)
    m.start()
    m.run(500)
    m.frame()
    t.contains(texts(m),
        'Status: Not configured yet: set Trigger Effect, Equipment Slot, Trigger Found Item, Trigger Missing Item')
    local dt, value = m.tlos.BogoSwap('')
    t.contains(select(2, dt.def.Members.Status('', value)), 'set TriggerEffectName, SwapEquipmentSlot')
    local panel = require('bogoswap.ui.panel')
    t.eq(panel.friendly('MatchItemName and NoMatchItemName are the same item'),
        'Trigger Found Item and Trigger Missing Item are the same item')
    t.eq(panel.friendly("'NoMatchItemNameX' stays"), "'NoMatchItemNameX' stays", 'whole words only')
end)

test('status details collapse to just the Status line', function(m, t)
    setup.swords(m, { State = { StashedOffhandItem = 'Round Shield' } })
    m.world.slots = { mainhand = 'Rusty Sword' }
    m.world.bags = { 'Fine Steel Sword', 'Round Shield' }
    m.world.simulate = false -- the restore never lands, so the shield stays remembered
    m.start('pause=no')
    m.run(500)
    m.frame()
    local open = texts(m)
    t.eq(m.ui.headers.bogoswap_status:sub(1, 8), 'Status: ', 'header is the Status line')
    for _, want in ipairs({ 'Effect: absent', 'mainhand holds: ', 'Wanted: Rusty Sword',
        'Remembered offhand: Round Shield', 'Last action: #' }) do
        t.contains(open, want, 'expanded')
    end
    t.eq(setup.count(open, 'Status: '), 1, 'Status shown once')
    m.ui.headerOpen.bogoswap_status = false
    m.frame()
    local closed = texts(m)
    t.contains(closed, 'Status: ')
    for _, gone in ipairs({ 'Effect:', 'holds:', 'Wanted:', 'Remembered offhand:', 'Last action:' }) do
        t.notContains(closed, gone, 'collapsed')
    end
    t.contains(closed, 'Running', 'rest of the window still drawn')
end)

test('the status header keeps its id when the text changes', function(m, t)
    setup.swords(m)
    m.start()
    m.run(500)
    m.frame()
    local before = m.ui.headers.bogoswap_status
    m.command('/bogoswap resume')
    m.run(500)
    m.frame()
    t.ok(m.ui.headers.bogoswap_status ~= before, 'text changed: ' .. before)
end)

test('the pause button toggles', function(m, t)
    setup.swords(m)
    m.start()
    m.ui.clicks['Resume##pause'] = true
    m.frame()
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'running after Resume')
    m.frame()
    t.eq(m.ui.calls[1], 'Button:Pause##pause')
    m.ui.clicks['Pause##pause'] = true
    m.frame()
    m.world.buffs = { 'Spirit of Wolf' }
    m.run(1000)
    t.eq(m.world.slots.mainhand, 'Rusty Sword', 'paused again')
end)

test('the pause button is blue while paused and green while running', function(m, t)
    local panel = require('bogoswap.ui.panel')
    local function same(a, b)
        for i = 1, 4 do if a[i] ~= b[i] then return false end end
        return true
    end
    m.start()
    m.frame()
    t.ok(same(m.ui.lastButtonColor, panel.BUTTON_PAUSED[1]), 'blue while paused')
    m.command('/bogoswap resume')
    m.frame()
    t.ok(same(m.ui.lastButtonColor, panel.BUTTON_RUNNING[1]), 'green while running')
    m.ui.clicks['Pause##pause'] = true
    m.frame()
    m.frame()
    t.ok(same(m.ui.lastButtonColor, panel.BUTTON_PAUSED[1]), 'blue after clicking Pause')
end)

test('Stop sits at the right edge, on the Pause row', function(m, t)
    m.start()
    m.frame()
    t.eq(m.ui.calls[1], 'Button:Resume##pause')
    t.eq(m.ui.calls[2], 'Button:Stop##stop', 'Stop is the next widget after Pause')
    t.eq(m.ui.buttonX['Stop##stop'], m.ui.windowWidth - 60, 'right-aligned')
    t.ok(m.ui.buttonX['Stop##stop'] > m.ui.buttonX['Resume##pause'], 'right of Pause')
end)

test('the Stop button ends BogoSwap like /bogoswap quit', function(m, t)
    setup.swords(m)
    m.start('pause=no')
    m.run(500)
    m.ui.clicks['Stop##stop'] = true
    m.frame()
    m.step(2)
    t.ok(m.finished, 'script ended')
    t.eq(m.binds['/bogoswap'], nil, 'command unbound')
    t.eq(m.tlos.BogoSwap, nil, 'TLO removed')
    t.contains(m.output(), 'Stopping (Stop button).')
    t.contains(m.output(), 'Stopped.')
end)

test('text inputs apply on Enter only', function(m, t)
    m.start()
    m.ui.inputs['##TriggerEffectName'] = { 'Haste', false }
    m.frame()
    t.eq(setup.readConfig(m).TriggerEffectName, '', 'not applied while typing')
    t.contains(texts(m), '(Enter to apply)')
    m.ui.inputs['##TriggerEffectName'] = { 'Haste', true }
    m.frame()
    t.eq(setup.readConfig(m).TriggerEffectName, 'Haste')
end)

test('a slash command change refreshes the input', function(m, t)
    m.start()
    m.frame()
    m.command('/bogoswap set TriggerEffectName Haste')
    m.frame()
    t.notContains(texts(m), '(Enter to apply)')
end)

test('slot picker uses IsItemClicked', function(m, t)
    m.start()
    m.ui.openCombo = '##slot'
    m.ui.clicks['offhand##slot_offhand'] = true
    m.frame()
    t.eq(setup.readConfig(m).SwapEquipmentSlot, 'offhand')
end)

test('tooltips use BeginTooltip, never SetTooltip', function(m, t)
    setup.swords(m)
    m.start()
    m.ui.hover = 'Resume##pause'
    m.frame()
    t.contains(texts(m), 'Click to start swapping')
    m.ui.hover = '##pick_MatchItemName'
    m.frame()
    t.contains(texts(m), 'Item to equip while the trigger effect is on you')
end)

test('closing the window hides it until /bogoswap ui', function(m, t)
    m.start()
    m.ui.closeWindow = true
    m.frame()
    m.frame()
    t.eq(#m.ui.calls, 0)
    m.command('/bogoswap ui')
    m.frame()
    t.ok(#m.ui.calls > 0)
end)

test('item names with % display', function(m, t)
    m.item('Blade of 100% Doom', '1H Slashing', { 'mainhand' })
    setup.swords(m, { NoMatchItemName = 'Blade of 100% Doom' })
    m.start()
    m.run(500)
    m.frame()
    t.contains(texts(m), 'Wanted: Blade of 100% Doom')
end)

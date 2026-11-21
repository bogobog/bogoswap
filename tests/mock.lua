-- A mock MacroQuest: just enough of mq, its TLOs and ImGui for BogoSwap's code paths.
-- It can't prove game behavior; game-facing assumptions go in docs/ingame-checks.md.
local lfs = require('lfs')

local M = {}

local function lower(s) return s and tostring(s):lower() or nil end

local function serialize(v, indent)
    indent = indent or ''
    local t = type(v)
    if t == 'string' then return string.format('%q', v) end
    if t == 'number' or t == 'boolean' then return tostring(v) end
    if t ~= 'table' then error('cannot pickle ' .. t) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local inner = indent .. '    '
    local parts = {}
    for _, k in ipairs(keys) do
        local ks = type(k) == 'string' and k:match('^[%a_][%w_]*$') and k or ('[' .. serialize(k) .. ']')
        parts[#parts + 1] = inner .. ks .. ' = ' .. serialize(v[k], inner) .. ','
    end
    return '{\n' .. table.concat(parts, '\n') .. '\n' .. indent .. '}'
end

local function rmtree(path)
    for f in lfs.dir(path) do
        if f ~= '.' and f ~= '..' then
            local p = path .. '/' .. f
            if lfs.attributes(p, 'mode') == 'directory' then rmtree(p) else os.remove(p) end
        end
    end
    lfs.rmdir(path)
end

function M.new()
    local env = { out = {}, cmds = {}, binds = {}, tlos = {}, now = 1000000 }

    local tmp = os.tmpname()
    os.remove(tmp)
    assert(lfs.mkdir(tmp))
    env.tmpdir = tmp

    -- The game world. Tests change these fields directly.
    local world = {
        gameState = 'INGAME', server = 'testserver', name = 'Tester', class = 'WAR',
        charState = 'STAND', casting = nil, cursor = nil, freeInventory = 10,
        buffs = {}, songs = {},
        slots = {},   -- slot -> item name
        bags = {},    -- list of item names in inventory bags
        loose = {},   -- general inventory slot number (24-34) -> item name not in a bag
        bank = {},    -- list of item names in the bank
        items = {},   -- item name -> { type = '1H Slashing', slots = { mainhand = true } }
        plugins = { mq2exchange = true },
        simulate = true, -- whether /exchange and /unequip take effect
    }
    env.world = world

    -- opts.canUse = false: the character's class/race/level can't use it.
    function env.item(name, itype, slots, opts)
        local set = {}
        for _, s in ipairs(slots) do set[s] = true end
        world.items[name] = { type = itype, slots = set, canUse = not (opts and opts.canUse == false) }
    end
    env.packScans = 0

    local function lookup(name)
        if not name then return nil end
        for k, v in pairs(world.items) do
            if k:lower() == name:lower() then return k, v end
        end
        return nil
    end
    local function indexIn(list, name)
        for i, n in ipairs(list) do
            if n:lower() == name:lower() then return i end
        end
        return nil
    end
    local function has(list, name)
        local i = indexIn(list, name)
        return i and list[i] or nil
    end
    local function wornAnywhere(name)
        for _, n in pairs(world.slots) do
            if n:lower() == name:lower() then return true end
        end
        return false
    end
    local function looseAnywhere(name)
        for _, n in pairs(world.loose) do
            if n:lower() == name:lower() then return true end
        end
        return false
    end
    local function isTwoHander(name)
        local _, def = lookup(name)
        return def ~= nil and def.type:sub(1, 2) == '2H'
    end

    local function itemNode(name)
        local real, def = lookup(name)
        return setmetatable({
            Name = function() return real end,
            ID = function() return real and 1001 or nil end,
            Type = function() return def and def.type end,
            WornSlot = function(slot) return function() return def ~= nil and def.slots[slot] == true end end,
            CanUse = function() return def ~= nil and def.canUse end,
            Container = function() return 0 end,
            Item = function() return itemNode(nil) end,
        }, { __call = function() return real end })
    end

    -- General inventory: slot 23 is a backpack holding world.bags; 24-34 hold world.loose[i].
    local function packNode(i)
        if i ~= 23 then return itemNode(world.loose[i]) end
        env.packScans = env.packScans + 1
        return setmetatable({
            Name = function() return 'Backpack' end,
            Type = function() return 'Container' end,
            Container = function() return math.max(10, #world.bags) end,
            Item = function(j) return itemNode(world.bags[j]) end,
            WornSlot = function() return function() return false end end,
            CanUse = function() return true end,
        }, { __call = function() return 'Backpack' end })
    end

    local TLO = {
        MacroQuest = { GameState = function() return world.gameState end },
        EverQuest = { Server = function() return world.server end },
        Me = {
            CleanName = function() return world.name end,
            State = function() return world.charState end,
            Casting = function() return world.casting end,
            FreeInventory = function() return world.freeInventory end,
            Class = { ShortName = function() return world.class end },
            Buff = function(n) return function() return has(world.buffs, n) end end,
            Song = function(n) return function() return has(world.songs, n) end end,
            Inventory = function(slot)
                if type(slot) == 'number' then return packNode(slot) end
                return itemNode(world.slots[slot])
            end,
        },
        Cursor = { Name = function() return world.cursor end },
        Plugin = function(n) return { IsLoaded = function() return world.plugins[lower(n)] == true end } end,
        FindItem = function(q)
            local name = q:gsub('^=', '')
            if indexIn(world.bags, name) or wornAnywhere(name) or looseAnywhere(name) then return itemNode(name) end
            return itemNode(nil)
        end,
        FindItemBank = function(q)
            local name = q:gsub('^=', '')
            return function() return has(world.bank, name) end
        end,
    }

    local function simulate(c)
        if not world.simulate then return end
        local item, slot = c:match('^/exchange "(.-)" (%S+)$')
        if item then
            local real = lookup(item)
            local i = real and indexIn(world.bags, real)
            if not i then return end
            if slot == 'mainhand' and isTwoHander(real) and world.slots.offhand then return end
            if slot == 'offhand' and world.slots.mainhand and isTwoHander(world.slots.mainhand) then return end
            local old = world.slots[slot]
            table.remove(world.bags, i)
            world.slots[slot] = real
            if old then table.insert(world.bags, old) end
            return
        end
        local s = c:match('^/unequip (%S+)$')
        if s and world.slots[s] and world.freeInventory > 0 then
            table.insert(world.bags, world.slots[s])
            world.slots[s] = nil
        end
    end

    local mq = {
        TLO = TLO,
        configDir = tmp,
        luaDir = './lua',
        imgui = { init = function(name, fn) env.draw = fn end },
        DataType = { new = function(name, def) return { name = name, def = def } end },
    }
    function mq.cmd(...)
        local c = table.concat({ ... })
        env.cmds[#env.cmds + 1] = c
        simulate(c)
    end
    function mq.cmdf(f, ...) mq.cmd(string.format(f, ...)) end
    function mq.delay(ms)
        env.now = env.now + (tonumber(ms) or 0)
        if coroutine.running() then coroutine.yield('delay') end
    end
    function mq.gettime() return env.now end
    function mq.bind(name, fn) env.binds[name] = fn end
    function mq.unbind(name) env.binds[name] = nil end
    function mq.AddTopLevelObject(name, fn) env.tlos[name] = fn end
    function mq.RemoveTopLevelObject(name) env.tlos[name] = nil end
    function mq.pickle(path, t)
        local f = assert(io.open(path, 'w'))
        f:write('return ', serialize(t), '\n')
        f:close()
    end
    env.mq = mq

    -- ImGui: env.ui scripts what the next frame's widgets return.
    local ui = { clicks = {}, inputs = {}, texts = {}, calls = {}, colorStack = {},
        buttonX = {}, cursorX = 8, windowWidth = 400, headers = {}, headerOpen = {},
        openCombo = nil, hover = nil, closeWindow = false }
    env.ui = ui
    local lastItem
    local function consume(label)
        if label and ui.clicks[label] then ui.clicks[label] = nil return true end
        return false
    end
    local function noop() end
    local ImGui = {
        Begin = function(name, open)
            lastItem = name
            if ui.closeWindow then ui.closeWindow = false return false, true end
            return true, true
        end,
        SameLine = function() ui.cursorX = 150 end,
        End = noop, Separator = noop, BeginTooltip = noop, EndTooltip = noop, EndCombo = noop,
        Button = function(label, w, h)
            lastItem = label
            ui.calls[#ui.calls + 1] = 'Button:' .. label
            ui.buttonX[label] = ui.cursorX
            return consume(label)
        end,
        -- A fixed-size window: 400 wide, and everything before SameLine uses 150 of it.
        GetCursorPosX = function() return ui.cursorX end,
        SetCursorPosX = function(x) ui.cursorX = x end,
        GetContentRegionAvail = function() return { x = ui.windowWidth - ui.cursorX, y = 300 } end,
        TextUnformatted = function(s) ui.texts[#ui.texts + 1] = s end,
        Text = function(s, ...)
            if select('#', ...) > 0 then s = string.format(s, ...) end
            ui.texts[#ui.texts + 1] = s
        end,
        InputText = function(label, buf, flags)
            lastItem = label
            local i = ui.inputs[label]
            if i then ui.inputs[label] = nil return i[1], i[2] end
            return buf, false
        end,
        BeginCombo = function(label, preview)
            lastItem = label
            ui.previews[label] = preview
            return ui.openCombo == label and not ui.disabledDepth
        end,
        -- Open unless the test sets ui.headerOpen[id] = false; DefaultOpen is required.
        CollapsingHeader = function(label, flags)
            lastItem = label
            local shown, id = label:match('^(.-)###(.*)$')
            assert(id, 'CollapsingHeader label needs a ### id: ' .. label)
            assert(flags == _G.ImGuiTreeNodeFlags.DefaultOpen, 'CollapsingHeader should start open')
            ui.texts[#ui.texts + 1] = shown
            ui.headers[id] = shown
            return ui.headerOpen[id] ~= false
        end,
        BeginDisabled = function() ui.disabledDepth = true; ui.disabledUsed = true end,
        EndDisabled = function() ui.disabledDepth = nil end,
        Selectable = function(label, selected)
            lastItem = label
            ui.selectables[#ui.selectables + 1] = label
            return false
        end,
        IsItemClicked = function() return consume(lastItem) end,
        IsItemHovered = function() return ui.hover ~= nil and ui.hover == lastItem end,
        SetTooltip = function() error('ImGui.SetTooltip must not be used (MacroQuest formats its text)') end,
        PushStyleColor = function(idx, r, g, b, a)
            assert(type(idx) == 'number', 'PushStyleColor needs an ImGuiCol value')
            ui.colorStack[#ui.colorStack + 1] = { idx, r, g, b, a }
        end,
        PopStyleColor = function(count)
            count = count or 1
            assert(count <= #ui.colorStack, 'PopStyleColor pops more than was pushed')
            for _ = 1, count do
                local c = table.remove(ui.colorStack)
                if c[1] == _G.ImGuiCol.Button then ui.lastButtonColor = { c[2], c[3], c[4], c[5] } end
            end
        end,
    }
    env.ImGui = ImGui

    -- Install into the global environment for this test.
    package.loaded.mq = mq
    package.loaded.ImGui = ImGui
    _G.ImGui = ImGui
    _G.ImGuiInputTextFlags = { EnterReturnsTrue = 32 }
    _G.ImGuiCol = { Button = 21, ButtonHovered = 22, ButtonActive = 23 }
    _G.ImGuiTreeNodeFlags = { DefaultOpen = 32 }
    env.savedPrint = print
    _G.print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        env.out[#env.out + 1] = table.concat(parts, '\t')
    end

    -- Runs lua/bogoswap/init.lua in a coroutine; each mq.delay is one step.
    function env.start(...)
        local chunk = assert(loadfile('lua/bogoswap/init.lua'))
        local a = { ... }
        env.co = coroutine.create(function() chunk(unpack(a)) end)
        env.resume()
    end
    function env.resume()
        if env.finished then return end
        local ok, err = coroutine.resume(env.co)
        if not ok then error(debug.traceback(env.co, tostring(err)), 0) end
        if coroutine.status(env.co) == 'dead' then env.finished = true end
    end
    function env.step(n)
        for _ = 1, n or 1 do env.resume() end
    end
    -- Advance at least ms of game time.
    function env.run(ms)
        local stop = env.now + ms
        while env.now < stop and not env.finished do env.resume() end
    end
    function env.command(line)
        local words = {}
        for w in line:gmatch('%S+') do words[#words + 1] = w end
        local fn = env.binds[table.remove(words, 1)]
        assert(fn, 'no binding for ' .. line)
        fn(unpack(words))
    end
    function env.frame()
        ui.texts = {}
        ui.calls = {}
        ui.colorStack = {}
        ui.lastButtonColor = nil
        ui.buttonX = {}
        ui.cursorX = 8
        ui.previews = {}
        ui.selectables = {}
        ui.headers = {}
        ui.disabledUsed = false
        assert(env.draw, 'no imgui callback registered')
        env.draw()
        assert(#ui.colorStack == 0, 'PushStyleColor without matching PopStyleColor')
    end
    function env.output()
        local lines = {}
        for _, l in ipairs(env.out) do lines[#lines + 1] = (l:gsub('\a%-?.', '')) end
        return table.concat(lines, '\n')
    end
    function env.clear()
        env.out = {}
        env.cmds = {}
    end
    function env.cleanup()
        _G.print = env.savedPrint
        rmtree(tmp)
    end

    return env
end

M.serialize = serialize

return M

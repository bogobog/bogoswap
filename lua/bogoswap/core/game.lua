-- The only module that reads MacroQuest TLOs or issues game commands.
-- Tests replace these TLOs with tests/mock.lua.
local mq = require('mq')

local M = {}

local function nz(v)
    if v == nil or v == '' or v == 'NULL' then return nil end
    return v
end

function M.inGame() return mq.TLO.MacroQuest.GameState() == 'INGAME' end

function M.server() return nz(mq.TLO.EverQuest.Server()) or 'unknown' end

function M.charName() return nz(mq.TLO.Me.CleanName()) or 'unknown' end

-- STAND, SIT, DUCK, BIND, FEIGN, DEAD, STUN, HOVER, MOUNT ...
function M.charState() return nz(mq.TLO.Me.State()) end

function M.casting() return nz(mq.TLO.Me.Casting()) end

function M.isBard() return mq.TLO.Me.Class.ShortName() == 'BRD' end

function M.cursorItem() return nz(mq.TLO.Cursor.Name()) end

function M.freeInventory() return tonumber(mq.TLO.Me.FreeInventory()) or 0 end

function M.exchangeLoaded() return mq.TLO.Plugin('mq2exchange').IsLoaded() == true end

-- Returns 'buff', 'song' or nil.
function M.effectWindow(name)
    if not name or name == '' then return nil end
    if nz(mq.TLO.Me.Buff(name)()) then return 'buff' end
    if nz(mq.TLO.Me.Song(name)()) then return 'song' end
    return nil
end

-- Returns { name, type } for the item worn in slot, or nil.
function M.slotItem(slot)
    if not slot or slot == '' then return nil end
    local it = mq.TLO.Me.Inventory(slot)
    local name = nz(it.Name())
    if not name then return nil end
    return { name = name, type = nz(it.Type()) }
end

-- Exact (case-insensitive) search of inventory. Returns { name, type, canWear } or nil;
-- canWear is only set when slot is given.
function M.findItem(name, slot)
    if not name or name == '' then return nil end
    local it = mq.TLO.FindItem('=' .. name)
    local real = nz(it.Name())
    if not real then return nil end
    local r = { name = real, type = nz(it.Type()), canUse = it.CanUse() ~= false }
    if slot and slot ~= '' then r.canWear = it.WornSlot(slot)() == true end
    return r
end

-- General inventory slots: pack1 (23) to pack12 (34). Each holds a bag or a loose item.
M.FIRST_PACK, M.LAST_PACK = 23, 34

-- Items in your bags (plus the item worn in slot) that fit slot and that you can use.
-- One entry per name, sorted. Returns a list of { name, type }.
function M.equipCandidates(slot)
    local seen, list = {}, {}
    local function consider(it)
        local name = nz(it.Name())
        if not name or seen[name:lower()] then return end
        if it.WornSlot(slot)() ~= true or it.CanUse() == false then return end
        seen[name:lower()] = true
        list[#list + 1] = { name = name, type = nz(it.Type()) }
    end
    consider(mq.TLO.Me.Inventory(slot))
    for i = M.FIRST_PACK, M.LAST_PACK do
        local pack = mq.TLO.Me.Inventory(i)
        if nz(pack.Name()) then
            local size = tonumber(pack.Container()) or 0
            if size > 0 then
                for j = 1, size do consider(pack.Item(j)) end
            else
                consider(pack)
            end
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function M.inBank(name)
    if not name or name == '' then return false end
    return nz(mq.TLO.FindItemBank('=' .. name)()) ~= nil
end

-- Commands are built here and sent with mq.cmd (not cmdf), so a '%' in an item
-- name is never treated as a format directive. Each returns the command text for logging.
function M.exchange(item, slot)
    local c = string.format('/exchange "%s" %s', item, slot)
    mq.cmd(c)
    return c
end

function M.unequip(slot)
    local c = '/unequip ' .. slot
    mq.cmd(c)
    return c
end

return M

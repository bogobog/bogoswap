-- Configuration: one file per character in <MQ config>/BogoSwap/, written with mq.pickle.
local mq = require('mq')
local log = require('bogoswap.core.log')

local M = {}

M.KEYS = { 'TriggerEffectName', 'SwapEquipmentSlot', 'MatchItemName', 'NoMatchItemName' }

-- Optional on/off settings, shown in the panel's Options section. Not needed for isComplete.
M.OPTIONS = { 'OnlyInCombat' }

-- MacroQuest inventory slot names, in paperdoll order.
M.SLOTS = {
    'charm', 'leftear', 'head', 'face', 'rightear', 'neck', 'shoulder', 'arms', 'back',
    'leftwrist', 'rightwrist', 'ranged', 'hands', 'mainhand', 'offhand', 'leftfinger',
    'rightfinger', 'chest', 'legs', 'feet', 'waist', 'powersource', 'ammo',
}
local SLOT_ALIASES = { primary = 'mainhand', secondary = 'offhand' }
local SLOT_SET = {}
for _, s in ipairs(M.SLOTS) do SLOT_SET[s] = true end

-- Must match config/bogoswap/defaults.lua (a test checks this).
M.BUILTIN_DEFAULTS = {
    TriggerEffectName = '',
    SwapEquipmentSlot = '',
    MatchItemName = '',
    NoMatchItemName = '',
    OnlyInCombat = false,
    TickMs = 250,
    SettleMs = 750,
    RetryMs = 3000,
    Debug = { swap = false, guard = false, config = false, cmd = false, ui = false },
    State = { StashedOffhandItem = '' },
}

M.DIR_NAME = 'BogoSwap'

local function deepcopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepcopy(v) end
    return out
end

-- Keeps only keys known in base; a value from over is used when its type matches.
local function merge(base, over)
    local out = {}
    for k, v in pairs(base) do
        local o = over and over[k]
        if type(v) == 'table' then
            out[k] = merge(v, type(o) == 'table' and o or nil)
        elseif o ~= nil and type(o) == type(v) then
            out[k] = o
        else
            out[k] = v
        end
    end
    return out
end
M.merge = merge

local function exists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

local function loadTable(path)
    local chunk, err = loadfile(path)
    if not chunk then return nil, err end
    local ok, t = pcall(chunk)
    if not ok then return nil, t end
    if type(t) ~= 'table' then return nil, 'file does not return a table' end
    return t
end
M.loadTable = loadTable

local function sanitize(s)
    return (tostring(s or 'unknown'):gsub('[^%w%-]', '_'))
end

function M.dir() return mq.configDir .. '/' .. M.DIR_NAME end

function M.charFile(server, name)
    return M.dir() .. '/' .. sanitize(server) .. '_' .. sanitize(name) .. '.lua'
end

local function ensureDir()
    local ok, lfs = pcall(require, 'lfs')
    if ok and lfs then lfs.mkdir(M.dir()) end
end

-- Defaults come from <MQ config>/BogoSwap/defaults.lua; if that file is missing it is
-- written from the built-in copy.
function M.defaults()
    ensureDir()
    local path = M.dir() .. '/defaults.lua'
    if exists(path) then
        local t, err = loadTable(path)
        if t then return merge(M.BUILTIN_DEFAULTS, t), path end
        log.warn('Could not read %s (%s); using built-in defaults.', path, tostring(err))
        return deepcopy(M.BUILTIN_DEFAULTS), 'built-in'
    end
    mq.pickle(path, M.BUILTIN_DEFAULTS)
    return deepcopy(M.BUILTIN_DEFAULTS), path
end

local function clamp(cfg)
    if cfg.TickMs < 50 then cfg.TickMs = 50 end
    if cfg.SettleMs < 0 then cfg.SettleMs = 0 end
    if cfg.RetryMs < cfg.SettleMs then cfg.RetryMs = cfg.SettleMs end
    if cfg.SwapEquipmentSlot ~= '' then
        local s = M.normalizeSlot(cfg.SwapEquipmentSlot)
        if not s then
            log.warn('SwapEquipmentSlot "%s" in the config file is not a slot name; clearing it.',
                cfg.SwapEquipmentSlot)
        end
        cfg.SwapEquipmentSlot = s or ''
    end
end

-- Returns cfg, path.
function M.load(server, name)
    local defaults, source = M.defaults()
    local path = M.charFile(server, name)
    local n = log.nextAction()
    local cfg
    if exists(path) then
        local saved, err = loadTable(path)
        if saved then
            cfg = merge(defaults, saved)
            log.debug('config', n, 'loaded %s', path)
        else
            local bad = path .. '.bad'
            os.remove(bad)
            os.rename(path, bad)
            log.err('Could not read %s (%s). Moved it to %s and started from defaults.',
                path, tostring(err), bad)
            cfg = defaults
        end
    else
        cfg = defaults
        log.info('Created %s from %s.', path, source)
        log.debug('config', n, 'no file for this character; created %s from %s', path, source)
    end
    clamp(cfg)
    M.save(cfg, path)
    return cfg, path
end

function M.save(cfg, path)
    mq.pickle(path, cfg)
end

function M.canonicalKey(s)
    if not s then return nil end
    local l = tostring(s):lower()
    for _, k in ipairs(M.KEYS) do
        if k:lower() == l then return k end
    end
    for _, k in ipairs(M.OPTIONS) do
        if k:lower() == l then return k end
    end
    return nil
end

function M.isOption(key)
    for _, k in ipairs(M.OPTIONS) do
        if k == key then return true end
    end
    return false
end

-- Every setting name /bogoswap set accepts.
function M.allKeys()
    local out = {}
    for _, k in ipairs(M.KEYS) do out[#out + 1] = k end
    for _, k in ipairs(M.OPTIONS) do out[#out + 1] = k end
    return out
end

function M.normalizeSlot(s)
    if not s then return nil end
    local l = tostring(s):lower()
    l = SLOT_ALIASES[l] or l
    if SLOT_SET[l] then return l end
    return nil
end

-- Returns true, or false and the list of keys still blank.
function M.isComplete(cfg)
    local missing = {}
    for _, k in ipairs(M.KEYS) do
        if cfg[k] == nil or cfg[k] == '' then missing[#missing + 1] = k end
    end
    return #missing == 0, missing
end

return M

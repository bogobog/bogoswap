-- Startup arguments: /lua run bogoswap pause=no minimize
local M = {}

local TRUE = { yes = true, ['true'] = true, on = true, ['1'] = true, y = true }
local FALSE = { no = true, ['false'] = true, off = true, ['0'] = true, n = true }

-- Arguments that take yes/no style values, and their defaults.
local BOOLS = { pause = true, minimize = false }
-- Arguments that may also be given alone, meaning yes.
local BARE = { minimize = true }

local SUPPORTED = 'Supported: pause=yes|no, minimize=yes|no.'

-- Returns options and a list of warning strings for arguments that were ignored.
-- Each option also gets a <name>Source saying where its value came from.
function M.parse(list)
    local opts = {}
    for k, def in pairs(BOOLS) do opts[k], opts[k .. 'Source'] = def, 'default' end
    local warnings = {}
    for _, a in ipairs(list or {}) do
        local s = tostring(a)
        local k, v = s:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        local bare = not k and s:match('^%s*([%w_]+)%s*$')
        local key = (k or bare or ''):lower()
        if bare and BARE[key] then
            -- A bare name (no "=value") turns the option on.
            opts[key], opts[key .. 'Source'] = true, bare
        elseif k and BOOLS[key] ~= nil then
            local lv = v:lower()
            if TRUE[lv] then
                opts[key], opts[key .. 'Source'] = true, key .. '=' .. v
            elseif FALSE[lv] then
                opts[key], opts[key .. 'Source'] = false, key .. '=' .. v
            else
                warnings[#warnings + 1] = string.format(
                    'Ignoring "%s=%s": use yes/no, true/false, on/off or 1/0.', key, v)
            end
        else
            warnings[#warnings + 1] = string.format(
                'Ignoring unknown startup argument "%s". %s', s, SUPPORTED)
        end
    end
    return opts, warnings
end

return M

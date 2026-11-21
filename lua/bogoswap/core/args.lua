-- Startup arguments: /lua run bogoswap pause=no
local M = {}

local TRUE = { yes = true, ['true'] = true, on = true, ['1'] = true, y = true }
local FALSE = { no = true, ['false'] = true, off = true, ['0'] = true, n = true }

-- Returns options and a list of warning strings for arguments that were ignored.
function M.parse(list)
    local opts = { pause = true, pauseSource = 'default' }
    local warnings = {}
    for _, a in ipairs(list or {}) do
        local k, v = tostring(a):match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if k and k:lower() == 'pause' then
            local lv = v:lower()
            if TRUE[lv] then
                opts.pause, opts.pauseSource = true, 'pause=' .. v
            elseif FALSE[lv] then
                opts.pause, opts.pauseSource = false, 'pause=' .. v
            else
                warnings[#warnings + 1] = string.format(
                    'Ignoring "pause=%s": use yes/no, true/false, on/off or 1/0.', v)
            end
        else
            warnings[#warnings + 1] = string.format(
                'Ignoring unknown startup argument "%s". Supported: pause=yes|no.', tostring(a))
        end
    end
    return opts, warnings
end

return M

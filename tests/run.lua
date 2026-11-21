-- Test runner. From the repository root:
--   luajit tests/run.lua                 everything
--   luajit tests/run.lua swap_test       one test file
--   luajit tests/run.lua --update        record snapshots
package.path = './lua/?.lua;./lua/?/init.lua;./tests/?.lua;' .. package.path

local lfs = require('lfs')
local mock = require('mock')

local UPDATE = false
local filters = {}
for _, a in ipairs(arg) do
    if a == '--update' then UPDATE = true else filters[#filters + 1] = a end
end

local files = {}
for f in lfs.dir('tests') do
    if f:match('_test%.lua$') then
        local base = f:gsub('%.lua$', '')
        local keep = #filters == 0
        for _, flt in ipairs(filters) do
            if base == flt or base == flt .. '_test' then keep = true end
        end
        if keep then files[#files + 1] = base end
    end
end
table.sort(files)
if #files == 0 then
    io.stderr:write('No tests match ' .. table.concat(filters, ' ') .. '\n')
    os.exit(1)
end

local function readFile(p)
    local f = io.open(p, 'r')
    if not f then return nil end
    local s = f:read('*a')
    f:close()
    return s
end

local function asserts(base, caseName)
    local t = {}
    function t.eq(actual, expected, msg)
        if actual ~= expected then
            error(string.format('%sexpected %s, got %s', msg and (msg .. ': ') or '',
                tostring(expected), tostring(actual)), 2)
        end
    end
    function t.ok(v, msg)
        if not v then error(msg or 'expected a true value', 2) end
    end
    function t.contains(s, sub, msg)
        if not tostring(s):find(sub, 1, true) then
            error(string.format('%sexpected to find %q in:\n%s', msg and (msg .. ': ') or '', sub, tostring(s)), 2)
        end
    end
    function t.notContains(s, sub, msg)
        if tostring(s):find(sub, 1, true) then
            error(string.format('%sdid not expect %q in:\n%s', msg and (msg .. ': ') or '', sub, tostring(s)), 2)
        end
    end
    function t.raises(fn, sub)
        local ok, err = pcall(fn)
        if ok then error('expected an error', 2) end
        if sub then t.contains(err, sub) end
    end
    -- Compares text with tests/fixtures/<test file>/<name>.txt.
    function t.snapshot(name, text)
        local dir = 'tests/fixtures/' .. base
        local path = dir .. '/' .. name .. '.txt'
        text = text .. '\n'
        if UPDATE then
            lfs.mkdir('tests/fixtures')
            lfs.mkdir(dir)
            local f = assert(io.open(path, 'w'))
            f:write(text)
            f:close()
            return
        end
        local want = readFile(path)
        if not want then error('missing snapshot ' .. path .. '; run with --update', 2) end
        if want ~= text then
            local wl, gl = {}, {}
            for l in want:gmatch('([^\n]*)\n') do wl[#wl + 1] = l end
            for l in text:gmatch('([^\n]*)\n') do gl[#gl + 1] = l end
            for i = 1, math.max(#wl, #gl) do
                if wl[i] ~= gl[i] then
                    error(string.format('snapshot %s differs at line %d:\n  want: %s\n  got:  %s\n(run with --update if intended)',
                        path, i, tostring(wl[i]), tostring(gl[i])), 2)
                end
            end
        end
    end
    return t
end

local function resetModules()
    for k in pairs(package.loaded) do
        if k:match('^bogoswap') or k == 'mq' or k == 'ImGui' then package.loaded[k] = nil end
    end
end

local passed, failed = 0, 0
for _, base in ipairs(files) do
    local cases = {}
    _G.test = function(name, fn) cases[#cases + 1] = { name = name, fn = fn } end
    dofile('tests/' .. base .. '.lua')
    for _, c in ipairs(cases) do
        resetModules()
        local env = mock.new()
        local ok, err = xpcall(function() c.fn(env, asserts(base, c.name)) end, debug.traceback)
        env.cleanup()
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            io.write(string.format('FAIL %s: %s\n  %s\n', base, c.name, tostring(err):gsub('\n', '\n  ')))
        end
    end
end
_G.test = nil

io.write(string.format('%d passed, %d failed%s\n', passed, failed, UPDATE and ' (snapshots updated)' or ''))
os.exit(failed == 0 and 0 or 1)

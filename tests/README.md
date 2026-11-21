# Tests

From the repository root, with LuaJIT and `luafilesystem`:

    luajit tests/run.lua                 # everything
    luajit tests/run.lua swap_test       # one file (the _test suffix is optional)
    luajit tests/run.lua --update        # record snapshots

## Pieces

- `run.lua`: finds `tests/*_test.lua`, runs each case with a fresh mock and freshly loaded modules, and prints failures.
- `mock.lua`: a fake MacroQuest. It provides `mq` (TLOs, `cmd`, `delay`, `bind`, `pickle`, `imgui`, `DataType`, TLO registration) and `ImGui`, all driven by `m.world`. `/exchange` and `/unequip` change the world the way the game should, unless `m.world.simulate = false`. `ImGui.SetTooltip` throws, and `ImGui.Selectable` always returns false, so the UI is forced to use `IsItemClicked`.
- `setup.lua`: standard items, plus writing and reading the character config.
- `fixtures/<test file>/<name>.txt`: snapshots.

## Writing a test

```lua
local setup = require('setup')

test('what it checks', function(m, t)
    setup.swords(m)              -- items + config: mainhand, Spirit of Wolf, two swords
    m.start('pause=no')          -- runs lua/bogoswap/init.lua; each mq.delay is one step
    m.run(1000)                  -- advance 1000 ms of game time
    m.world.buffs = { 'Spirit of Wolf' }
    m.command('/bogoswap show')  -- call a bound slash command
    m.frame()                    -- draw one ImGui frame (m.ui.clicks / inputs / hover script it)
    t.eq(m.world.slots.mainhand, 'Rusty Sword')
    t.contains(m.output(), 'text')   -- printed output, colour codes stripped
    t.snapshot('name', m.output())   -- compare with fixtures; record with --update
end)
```

Each case gets its own temporary `mq.configDir`, which is deleted afterwards.

The mock can't prove game behavior. Anything game-facing it assumes belongs in `docs/ingame-checks.md`.

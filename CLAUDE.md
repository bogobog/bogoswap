# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## BogoSwap

BogoSwap is a MacroQuest Lua automation tool for EverQuest. It runs inside MacroQuest's LuaJIT, one instance per character. The user-facing documentation is `lua/bogoswap/README.md`.

**Status: v0.1.0 implemented, not yet verified in game.** `docs/concept.md` is the spec; `docs/ingame-checks.md` lists what still needs checking in game.

@docs/concept.md

The config keys in `docs/concept.md` (`TriggerEffectName`, `SwapEquipmentSlot`, `MatchItemName`, `NoMatchItemName`) are canonical: slash commands, the ImGui panel and the config file all use these exact names.

## How to work with me

- **Before generating code, present a list of the features and behaviors it will include,** so I can pick which to omit. Ask about real design decisions as numbered options with a recommendation. Don't ask about things that are already clear.
- After a change, summarize what changed, how it was tested, and anything that can only be verified in game.
- Keep `lua/bogoswap/README.md` in step with behavior changes, and bump `VERSION` in `lua/bogoswap/init.lua` (patch for fixes, minor for features).

## Hard rules (each was learned the hard way)

- **Target LuaJIT (Lua 5.1 syntax).** No `//` integer division, no `goto`, no bitwise operators, no 5.3+ library calls. Use `math.floor(a / b)`.
- **ImGui selectables:** detect clicks with `ImGui.IsItemClicked()` after the widget, not with the return value of `ImGui.Selectable`.
- **ImGui tooltips:** never `ImGui.SetTooltip` directly. MacroQuest runs `SetTooltip`'s text through `string.format`, so a `%` in it shows "invalid option '%' to 'format'".
- **TLO datatypes:** every member is declared `function(param, self)`, `ToString` is `function(self)`, and the TLO handler is `function(param)`. Every member must return a type and a value; return `'string', 'NULL'` for "nothing". Callbacks declared without parameters are rejected by MacroQuest.
- **Every action that does something logs why** in a debug channel, with a shared action number.
- **BogoSwap's files live in `<MQ config>/BogoSwap/`**

## Testing

Run the suite from the repository root with LuaJIT, plus `luafilesystem`:

    luajit tests/run.lua                 # everything
    luajit tests/run.lua swap_test       # one test
    luajit tests/run.lua --update        # record snapshots (first run, or after an intended output change)

The tests use a mock MacroQuest (`tests/mock.lua` and per-test mocks), so they can't prove game behavior. Anything game-facing that hasn't been checked belongs in `docs/ingame-checks.md`. See `tests/README.md` for how to add a test.

## Layout

- `lua/bogoswap/init.lua`: startup, the main loop.
- `lua/bogoswap/core/`: shared systems.
- `lua/bogoswap/ui/`: the control panel.
- `config/bogoswap/`: default configuration files, which are copied to `<MQ config>/BogoSwap/` at runtime.
- `tests/`: the runner, the mock, the test scripts and the fixtures.

# BogoSwap

BogoSwap is a [MacroQuest](https://www.macroquest.org/) Lua script for EverQuest that keeps the right item in one of your equipment slots, depending on whether a buff is on you.
For example, it can equip one weapon while *Avatar* is up and a different one when it fades.

It watches your buffs and songs, swaps the item when the buff appears or fades, checks that each swap worked, and can be paused at any time.
You can configure it with slash commands or a small ImGui window.

## Requirements

- EverQuest with **MacroQuest**, with Lua support (MacroQuest's built-in LuaJIT).
- The **MQ2Exchange** plugin, which ships with MacroQuest. Load it with `/plugin mq2exchange`.

## Installing

1. Download the latest `bogoswap-<version>.zip` from the [Releases](https://github.com/bogobog/bogoswap/releases) page.
2. Extract it into your MacroQuest folder, so that the script ends up at `<MacroQuest>/lua/bogoswap/`.

BogoSwap saves its settings in `<MQ config>/BogoSwap/`, which it creates the first time it runs.

## Running

Run one copy per character:

    /lua run bogoswap            starts paused, so nothing is swapped before you check the settings
    /lua run bogoswap pause=no   starts running

Then tell it what to watch for and what to swap:

    /bogoswap set TriggerEffectName Spirit of Wolf
    /bogoswap set SwapEquipmentSlot mainhand
    /bogoswap set MatchItemName Fine Steel Sword
    /bogoswap set NoMatchItemName Rusty Sword
    /bogoswap resume

`/bogoswap help` lists every command, and `/bogoswap quit` stops the script.

See [lua/bogoswap/README.md](lua/bogoswap/README.md) for the full guide: all settings and options, the window, two-handed weapons, the debug log and the `${BogoSwap}` TLO.

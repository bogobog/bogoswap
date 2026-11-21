# BogoSwap

BogoSwap swaps an item into one of your equipment slots depending on whether a buff is on you.
For example: equip one weapon while *Spirit of Wolf* is up, and a different one when it fades.

It runs inside MacroQuest, one copy per character.

## Requirements

- MacroQuest with Lua.
- The **MQ2Exchange** plugin, which ships with MacroQuest: `/plugin mq2exchange`.
  BogoSwap warns you at startup and in its status if the plugin isn't loaded.

## Starting and stopping

    /lua run bogoswap            starts PAUSED
    /lua run bogoswap pause=no   starts running
    /bogoswap quit               stops it (or the window's Stop button, or /lua stop bogoswap)

BogoSwap **starts paused** so that it never swaps anything before you've checked its settings.
The startup message says so, and the window shows a **Resume** button.
`pause=` also accepts `false`, `off`, `0` and `n` (or `yes`, `true`, `on`, `1`, `y` to keep the default).

## Settings

| Setting | Meaning |
|---|---|
| `TriggerEffectName` | The buff to watch for. Both the buff window and the song window count. |
| `SwapEquipmentSlot` | The equipment slot to swap into, such as `mainhand`, `offhand`, `range` or `charm` (`primary` and `secondary` also work). |
| `MatchItemName` | The item to equip while the effect is on you. |
| `NoMatchItemName` | The item to equip while it isn't. |

Item and effect names must match exactly; capitalization doesn't matter.
Set them with `/bogoswap set` or in the window (press Enter after typing the effect name; the items and the slot are picked from lists).
Setting names aren't case-sensitive in the command.

    /bogoswap set TriggerEffectName Spirit of Wolf
    /bogoswap set SwapEquipmentSlot mainhand
    /bogoswap set MatchItemName Fine Steel Sword
    /bogoswap set NoMatchItemName Rusty Sword

`/bogoswap set <Setting>` with no value clears that setting. BogoSwap warns you if an item can't be worn in the chosen slot.

Settings are saved per character in `<MQ config>/BogoSwap/<server>_<character>.lua`.
New characters start from `<MQ config>/BogoSwap/defaults.lua`, which BogoSwap creates the first time it runs.
That file also has timing settings you can edit:

- `TickMs`: how often BogoSwap checks (default 250 ms).
- `SettleMs`: how long it waits before checking a swap worked (default 750 ms).
- `RetryMs`: how long after a swap that didn't work before it tries again (default 3000 ms).

## What it does

While running, BogoSwap keeps the slot holding the right item. If anything else ends up in the slot (because a swap failed, or because you swapped by hand), it swaps back. **Pause BogoSwap if you want to change that slot yourself.**

It does not swap:

- while you're casting (bards are exempt, since they're always singing),
- while you have something on your cursor,
- while you're dead, stunned or feigning death,
- while you're zoning or not in game,
- when the item isn't in your bags (it tells you if the item is in the bank instead),
- when the item can't be worn in that slot.

After each swap it checks that the swap worked. If not, it tries again after `RetryMs`.

### Two-handed weapons

When the slot is `mainhand` and the item to equip is two-handed, BogoSwap first takes off whatever is in your offhand and remembers it. When a one-hander goes back into mainhand, it puts the remembered offhand item back. The remembered item is saved, so this still works after a restart. BogoSwap forgets it if something else is already in your offhand, or if the item is no longer in your inventory.

Taking off the offhand item needs a free inventory slot. If you have none, BogoSwap waits and tells you why.

When the slot is `offhand` and a two-hander is in mainhand, BogoSwap can't swap, and says so.

## Commands

`/bogoswap` or `/bswap`:

| Command | Effect |
|---|---|
| `set <Setting> <value>` | Change a setting (no value clears it). |
| `show` | Print settings, the current state and the config file path. |
| `pause`, `resume`, `toggle` | Stop or start taking action. BogoSwap keeps watching while paused. |
| `swapnow` | Check and swap once right now, even while paused or waiting to retry. |
| `ui [on\|off]` | Show or hide the window. |
| `debug [<channel>\|all] [on\|off]` | List or switch debug channels. |
| `quit` | Stop BogoSwap. |
| `help` | List commands. |

## The window

The window has:

- a Pause/Resume button, green while BogoSwap is running and blue while it's paused,
- a Stop button at the right of the same row, which stops BogoSwap entirely, like `/bogoswap quit`,
- the effect's state, what the slot holds, and what BogoSwap wants there,
- the current status and the last action,
- the four settings. `MatchItemName` and `NoMatchItemName` are item pickers:
  - Each lists the items in your bags, plus the item worn in the slot, that fit `SwapEquipmentSlot` and that your character can use.
  - Duplicates appear once, and two-handers are tagged "(2H)" when the slot is `mainhand`.
  - Type in the search box at the top to narrow the list. "(none)" clears the setting.
  - Your bags are read each time you open a picker. Click **Refresh** if they change while it's open.
  - If the chosen item isn't in your bags, can't be worn in the slot, or you can't use it, the picker says so next to its name.
  - Choose a slot first; until then the pickers are greyed out.
  - To set an item that isn't in your bags right now, use `/bogoswap set`.

Closing the window doesn't stop BogoSwap; `/bogoswap ui` brings it back.

## Debug log

Every decision and action BogoSwap takes is numbered, and every log line about it carries the same number (`#12`). That lets you follow a swap from the reason for it, through the command it sent, to the check that it worked. Channels are off by default, and their on/off settings are saved.

- `swap`: decisions, commands, verification
- `guard`: why a swap is being held back
- `config`: setting changes and config loading
- `cmd`: slash commands and pause changes
- `ui`: window events

Problems you need to act on, such as a missing item or MQ2Exchange not loaded, are always shown, once per change.

## `${BogoSwap}` TLO

For macros and other scripts. All members are read-only.

| Member | Type | Value |
|---|---|---|
| `Version` | string | BogoSwap version |
| `Paused` | bool | whether it's paused |
| `State` | string | `paused`, `ok`, `blocked`, `missing`, `idle`, `exchange`, `unequip`, `clearstash` |
| `Status` | string | current status text |
| `TriggerEffectName`, `SwapEquipmentSlot`, `MatchItemName`, `NoMatchItemName` | string | settings (`NULL` if blank) |
| `EffectPresent` | bool | whether the effect is on you |
| `WantedItem` | string | the item BogoSwap wants in the slot right now |
| `LastAction` | string | `#n` and the reason for the last action |

`${BogoSwap}` itself returns `paused` or `running`.

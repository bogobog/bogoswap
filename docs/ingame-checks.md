# In-game checks

The tests run against a mock MacroQuest, so each of these assumptions still needs checking in game.
Tick each one off once it's confirmed, and note anything that turned out different.

## MQ2Exchange
- [ ] `/exchange "Item Name" mainhand` swaps an item from a **closed** bag into the slot, and the old item goes to a bag.
- [ ] `/exchange` works for other slots BogoSwap offers (`range`, `charm`, `leftfinger`, `ammo`, `powersource`, ...).
- [ ] `/unequip offhand` moves the offhand item into a bag.
- [ ] What `/exchange` does with a two-hander while the offhand is filled (BogoSwap avoids it by unequipping first).
- [ ] `${Plugin[mq2exchange].IsLoaded}` is TRUE when loaded and FALSE/NULL when not.

## Detecting the effect
- [ ] `${Me.Buff[name]}` matches the exact name. Find out whether it also matches partial names (e.g. "Spirit" matching "Spirit of Wolf").
- [ ] `${Me.Song[name]}` finds short-duration effects in the song window.
- [ ] Name matching is case-insensitive.

## Items and slots
- [ ] `${FindItem[=name]}` matches exactly, case-insensitively, and searches bags (and worn slots).
- [ ] `${FindItemBank[=name]}` finds bank items.
- [ ] `${FindItem[=name].WornSlot[mainhand]}` takes slot names and returns TRUE/FALSE.
- [ ] Two-handers report `Type` starting with "2H" ("2H Slashing", "2H Blunt", "2H Piercing").
- [ ] `${Me.Inventory[mainhand].Name}` is NULL for an empty slot.

## Guards
- [ ] `${Me.State}` reports DEAD/HOVER, STUN and FEIGN as expected.
- [ ] `${Me.Casting}` is NULL when not casting. Bards: check that swapping mid-song is harmless (BogoSwap doesn't block bards on casting).
- [ ] `${Cursor.Name}` is NULL with an empty cursor.
- [ ] During zoning `${MacroQuest.GameState}` is not INGAME, or swaps are otherwise held back.

## Lua and MacroQuest APIs
- [ ] `mq.pickle` writes the config, and `lfs.mkdir` creates `<MQ config>/BogoSwap/` on a fresh install.
- [ ] `/lua run bogoswap pause=no` passes `pause=no` to the script as a single argument.
- [ ] `/bogoswap set MatchItemName "Fine Steel Sword"`: find out how MacroQuest splits quoted arguments (BogoSwap rejoins them and strips the quotes).
- [ ] The `${BogoSwap}` TLO registers with `mq.DataType.new` / `mq.AddTopLevelObject`. `${BogoSwap.Paused}` and `${BogoSwap.MatchItemName}` give the right values, and `${BogoSwap}` gives paused/running.
- [ ] The TLO is removed after `/bogoswap quit`.

## ImGui
- [ ] `ImGui.Begin` with an open flag returns `open, show`, and the close button hides the window.
- [ ] `ImGui.TextUnformatted` exists. An item name containing `%` displays correctly.
- [ ] `InputText` with `EnterReturnsTrue` returns the text being typed plus `true` on Enter.
- [ ] Clicking an entry in the slot combo selects it (detected with `IsItemClicked`).
- [ ] Tooltips appear on hover.

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
- [ ] The Stop button sits at the right edge of the Pause/Resume row and stays there when the window is resized. This depends on `GetContentRegionAvail` (BogoSwap accepts it returning a number or an ImVec2), `GetCursorPosX`/`SetCursorPosX`, and `Button(label, width, height)`.
- [ ] Item pickers:
  - [ ] General inventory is `${Me.Inventory[23]}` to `${Me.Inventory[34]}` (pack1 to pack12). Bags report `Container` greater than 0, and `.Item[n]` reads their contents even when the bag is closed. Loose items in those slots report `Container` 0.
  - [ ] `${Me.Inventory[n].Item[j].WornSlot[mainhand]}` and `.CanUse` work on bag contents. `CanUse` is FALSE for items your class, race or level can't use.
  - [ ] Opening a picker with full bags doesn't cause a noticeable hitch.
  - [ ] An item added to your bags shows up the next time you open the picker.
  - [ ] `ImGui.BeginDisabled` / `EndDisabled` exist, and the disabled pickers can't be opened.
- [ ] The status section:
  - [ ] `ImGui.CollapsingHeader(label, ImGuiTreeNodeFlags.DefaultOpen)` starts open.
  - [ ] Collapsing it leaves only the Status line.
  - [ ] It stays collapsed while the status text changes (the label uses the stable id `###bogoswap_status`).
  - [ ] A long status line is readable in the header, and an item name containing `%` shows correctly in it.
- [ ] Setting rows:
  - [ ] Labels sit to the left in one column that's wide enough for "Trigger Missing Item" (sized with `CalcTextSize`, falling back to 150 px).
  - [ ] Labels are vertically centred on their fields (`AlignTextToFramePadding`), and the fields fill the rest of the row (`SetNextItemWidth(-1)`).
  - [ ] While the effect name is being edited, its field shrinks so "(Enter to apply)" fits on the row.
  - [ ] Hovering a label or its field shows a two-line tooltip naming the setting.
- [ ] Minimize:
  - [ ] `_` sits just left of Stop with a normal gap. This assumes 8 px item spacing; check it under your ImGui style.
  - [ ] Clicking `_` hides the panel and shows only the BS button. Clicking BS brings the panel back where it was.
  - [ ] The BS window has no title bar, fits snugly around the button, and can be dragged. It reopens where it was left, including after a restart.
  - [ ] `ImGui.Begin(name, true, flags)` works with the flags, and `SetNextWindowPos(ImVec2(20, 20), ImGuiCond.FirstUseEver)` is accepted (on first use it opens near the top-left).
  - [ ] BS is green while running and blue while paused.
  - [ ] Right-clicking BS toggles pause (`IsItemClicked(ImGuiMouseButton.Right)` after the button), turns it green or blue, and doesn't restore the window. A left click still restores it.
- [ ] Clicking Stop ends the script cleanly: the window closes, `/bogoswap` is unbound, and `${BogoSwap}` is gone.
- [ ] `ImGui.PushStyleColor(ImGuiCol.Button, r, g, b, a)` (four floats) is accepted. The pause button is blue while paused and green while running, with lighter/darker shades on hover/click, and nothing else in the window changes colour.

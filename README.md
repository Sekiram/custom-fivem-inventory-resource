# ps-inventory

A standalone (no framework required) FiveM inventory resource with drag & drop,
right-click actions (Drop / Split / Separate / Give), weight limits, and a
hunger/thirst survival system.

## Installation

1. Copy the `ps-inventory` folder into your server's `resources` directory.
2. Add this line to your `server.cfg`:
   ```
   ensure ps-inventory
   ```
3. Start (or restart) your server. That's it — no database required, player
   data is stored in `ps-inventory/data/players.json` automatically.

## Controls

- **TAB** — open / close the inventory (rebindable in FiveM's keybind settings
  under "FiveM", look for "Open Inventory").
- **Left click + drag** — move an item between slots (or into an opened ground
  bag).
- **Right click** an item — Drop / Split / Separate / Give menu.
- **Double click** a food/drink/medical item — use/consume it.
- **E** — while standing near a dropped bag, opens it as a secondary
  inventory.

## Features

- 45 kg max carry weight per player (configurable).
- Every item has its own weight; the weight bar fills as you get heavier.
- Right click menu:
  - **Drop** — drop a chosen amount on the ground as a physical bag other
    players can loot.
  - **Split** — instantly splits a stack in half into a free slot.
  - **Separate** — type an exact amount to peel off into a new slot
    (e.g. 3 water bottles → separate 1 → slots of 1 and 2).
  - **Give** — opens a list of nearby players (with distance) and lets you
    choose how much of the stack to hand over. Blocked if the target can't
    carry the extra weight or is too far away.
- New characters automatically receive: 1 Phone, 3 Bread, 3 Bottles of Water.
- Hunger and thirst drain in the background:
  - Thirst empties in ~1.5 hours.
  - Hunger empties in ~3 hours.
  - Warnings are shown at 50%, 25% and 10%.
  - Reaching 0% on either stat starts damaging you until you die if you don't
    eat/drink.
- Data automatically saves on disconnect, every 5 minutes, and on resource
  stop.

## Configuration

Everything is tunable in `config.lua`: max weight, slot count, deplete
timers, starter items, the full item list (label/weight/icon/stack size),
and distances for give/drop interactions.

## Exports (for shops, drug labs, jobs, etc.)

```lua
exports['ps-inventory']:AddItem(source, 'water_bottle', 5)
exports['ps-inventory']:RemoveItem(source, 'water_bottle', 2)
exports['ps-inventory']:GetItemCount(source, 'water_bottle')
exports['ps-inventory']:HasItem(source, 'water_bottle', 1)
exports['ps-inventory']:GetInventory(source)
```

## Admin command

```
/additem [player id] [item name] [amount]
```
Requires the `command.additem` ACE permission (console always allowed).

## Notes on the UI

The HUD/UI is plain HTML/CSS/JS (no frameworks), designed to look like a
lightweight game UI rather than a web app: flat dark panels, subtle borders,
and a small teal accent — no glossy gradients. `backdrop-filter` is only ever
applied to top-level panels (never nested) and always paired with its
`-webkit-` prefix and a semi-transparent `rgba()` background so the blur
actually renders correctly in the CEF browser FiveM uses.

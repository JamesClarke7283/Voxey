# Enchanting offers and experience

Reference: `/home/impulse/.minetest/games/mineclonia`, read 2026-10-24.
The [completed registry audit](enchanting-registry-source.md) now supplies actual
registered item eligibility and definitions. The exported data and algorithms retain Mineclonia's
GPL-3.0-or-later attribution. File hashes are recorded in
`assets/data/enchanting.json` and `assets/data/enchanting_reference.json`.

## Source behavior now implemented

- `ITEMS/mcl_enchanting/engine.lua`: source-sorted weighted selection, primary
  versus secondary eligibility, treasure/tradable rules, one-way incompatibility
  checks, material enchantability, power perturbation, inclusive power ranges,
  halved continuation powers and the first-enchantment hint. A failed first
  power match leaves a table slot empty; it does not retry or guarantee
  Unbreaking.
- `ITEMS/mcl_enchanting/enchantments.lua` and `ITEMS/mcl_armor/register.lua`:
  all 39 active definitions. The disabled Aqua Affinity and Sweeping Edge
  definitions remain readable on existing items but are excluded from random
  offers. Secondary-only Depth Strider and Punch cannot appear directly on
  table-enchanted boots/bows. Mace primaries remain eligible even when flagged
  treasure. Curse of Binding, Soul Speed and Wind Burst are excluded from random treasure books
  by their nontradable flags; the explicit vault Wind Burst reward remains.
- `ITEMS/mcl_enchanting/init.lua`: the exact 32 bookshelf positions and their
  individual air-gap positions, capped at 15 power. Even a torch blocks its
  paired gap. Three offers use the source base roll and fractional input
  powers, with per-offer level requirements and costs of 1–3 levels and lapis.
- Offers are cached per player, shelf count and item type. Returning to an item,
  closing the panel or loading a save cannot reroll it. Successful purchases
  clear that player's complete cache. Stale UI tokens and failed purchases do
  not spend resources or reset offers. Creative consumes lapis while waiving XP.
- `HUD/mcl_experience/init.lua`: the three-piece level/total-XP curve and
  fractional-bar-preserving level subtraction. Existing saved XP totals remain
  unchanged and now display through this curve.
- Hosted-player snapshots and reconnect records retain XP and cached offers,
  including when the host world is saved to disk.
- Fishing and powered vault equipment share the same engine. Loot retries an
  empty initial roll. Fishing books and vault equipment use the source's
  unrestricted continuation flag; fishing bows and rods use its probability
  cutoff. Uniform random books also use the active source eligibility list.

The game stages purchases before committing. Wear and item metadata survive.
Enchanting a stack of books converts one copy, puts the remainder back, and
fails without cost when it cannot fit. Equipped pouch contents are updated.

## Native boundaries and remaining work

Voxey retains its inventory picker and shows the hint directly on each offer
button. Mineclonia's formspec, dedicated item/lapis slots, hover presentation,
glyph textures, particles and book animation are not copied. Nine glyph draws
per valid offer are retained in the random stream and save data. The persistent
32-bit native random stream does not promise identical offers for a particular
Luanti world seed; controlled-stream oracle tests verify the selection rules.

This change does not claim full enchantment parity. [Mending, armor wear and Thorns](defensive-enchantments-source.md) now have a real-engine reference implementation. Other combat/effect differences need separate audits. Anvil costs and repairs are now covered by
the [source anvil implementation](anvil-source.md).
The defensive loot retry limit is 256 attempts; supported source loot has valid
outcomes, while a future impossible custom item returns no result rather than
hanging forever. Existing legacy enchantments are preserved.

## Validation

`tools/export_enchanting.py` loads the supplied game in Luanti, extracts the
completed registry and runs the actual Lua selection functions with a controlled
random stream. `tools/export_enchanting_reference.py` delegates to that exporter. `tests/enchanting_reference_checks.gd`
compares 720 single-item rolls and 144 three-offer cases, including treasure and
unrestricted continuation, exact outputs and random-stream consumption. It also
checks XP boundaries, material abilities and eligibility exceptions.

`tests/enchanting_checks.gd` exercises real inventory purchases, bookshelf gaps,
cache invalidation, per-player isolation, creative mode, book splitting, pouch
metadata, UI offers and disk reloads. Run it with:

```sh
godot --headless --path . --script res://tests/enchanting_reference_checks.gd
godot --headless --path . --script res://tests/lifecycle_runner.gd -- enchanting
```

The source comparisons also pass from the exported Linux resource pack. The
focused enchanting/fishing/trial/grindstone/anvil run passed 191 checks; the
expanded enchanting persistence/UI run passed 32. Live host/client tests verify
that reconnecting preserves exact offers and XP. Both exported source datasets
reproduce byte for byte. The UI was inspected at large and small window sizes.
The final survival run passed all 534 checks. The bamboo follow-up passed 347
checks after removing its duplicated door entry from the item catalog.

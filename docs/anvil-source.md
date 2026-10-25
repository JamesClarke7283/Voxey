# Anvil combining, repairs and names

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
The behavior comes from `mods/ITEMS/mcl_anvils/init.lua` and
`mods/ITEMS/mcl_enchanting/engine.lua`. Source hashes and GPL-3.0-or-later
attribution are stored in `assets/data/anvil_reference.json`.

`Anvils.plan` computes a result without editing inventory. `AnvilWorkbench`
shows both chosen inputs, the output, and its complete XP-level cost. Applying
the preview checks the current inputs and anvil, stages the inventory exchange,
and only then commits the result and XP payment. Unaffordable operations and
stale previews cannot change enchantments or consume either input. Equipped
pouch contents are synchronized after the transaction.

## Source rules

- Combining starts with `2^pwp - 1` for **each** input. Equal enchantment levels
  increase by one up to the definition's maximum; unequal levels retain the
  higher value. Only modified enchantments add their new level multiplied by
  the source's book/item factor. Each rejected conflicting enchantment adds one
  level when another enchantment can apply. The result's prior-work counter is
  `max(first, second) + 1`.
- Anvil combining checks incompatibilities on books too. This differs from
  table-generated books, which may contain incompatible enchantments together.
  Source-disabled definitions do not become newly combinable.
- When combining tools changes an enchantment, the result also adds both
  remaining durability values and a 12% bonus. An actual wear improvement adds
  two levels. The active source returns no result when combining changes no
  enchantment, even for two worn tools; its help text is broader than its code.
- Material repairs consume one to four matching materials, restoring
  25/50/75/100%. They cost that material count plus both prior-work penalties,
  and raise the repaired tool's counter by one. Either input order works. Wood
  and cobble group variants are accepted. Gold tools use gold; shields use
  planks; maces use breeze rods. This source registers no elytra repair material.
- Rename-only operations cost one level for the whole stack and do not raise
  its prior-work counter. Renaming can accompany a repair/combine for one extra
  level. Empty names remove a name; signed books retain their no-rename rule.
- No forty-level cost ceiling is present in this source. Payment uses the
  [source XP curve](enchanting-source.md) and retains fractional progress.
  Creative operations consume inputs but spend no XP and never damage anvils.
- Each successful survival use has the source's integer 12-in-100 damage roll.
  The third damage stage destroys the anvil without returning an anvil item.
- Flint and steel, both steering sticks, and screwdrivers can receive supported
  book enchantments at the anvil but cannot be enchanted at the table.

The source's take handler determines consumption separately from its preview.
Voxey preserves that rule, including its treatment of an enchanted book as the
material operand of a repairable tool. A multi-book target consumes one book
and returns one enchanted book without discarding the rest of the stack.

## Native boundaries

Voxey keeps inputs in the player's inventory and uses two selectors instead of
the source's placed-container slots. The preview is transient; items remain in
their saved inventory if the panel closes or its anvil disappears. Native
rendering and sounds remain. Names preserve complete UTF-8 characters within
the existing 50-byte limit and replace line breaks with spaces.

For repair calculations, an exact normalized-wear checkpoint is used when
available; otherwise native wear is mapped to the source's 0–65535 scale
with flooring, the source's integer/ceiling boosts are applied, and the result
maps back with ceiling so a partly used durability unit remains used. Source
counter costs beyond native integer capacity are saturated above any playable
level; there is no ordinary gameplay cost cap. Other enchantment combat effects
and the wider Mineclonia parity goal remain separate work.

## Verification

`tools/export_anvil_reference.py` runs the actual Lua anvil update **and take**
handlers with mocked item metadata, inventory, and presentation APIs. The 358
fixtures cover both input orders, partial/full material repairs, names, source
weights, conflicts, books, tool combines, and exact consumption.
`tests/anvil_reference_checks.gd` compares the native plan with those outputs.
The fixture exporter is reproducible and the JSON is included in game exports.

`tests/anvil_work_checks.gd` exercises payments, failures, stale previews, live
buttons, creative mode, pouch metadata, real disk reloads and final-stage anvil
destruction. Existing anvil, name-tag and alchemy checks remain regressions.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_anvil_reference.py
godot --headless --path . --script res://tests/anvil_reference_checks.gd
godot --headless --path . --script res://tests/lifecycle_runner.gd -- anvil_work anvil name_tag
```

The combined anvil/name-tag/enchanting run passed 199 checks; the alchemy/pouch
suite passed 239. The source fixture exporter reproduced byte-identical JSON.
The result preview and unaffordable state were visually inspected at two window
sizes, including 800×600.
The final survival suite passed all 534 checks. The Linux resource pack also
passed all 358 source-handler comparisons using its bundled scripts and JSON.

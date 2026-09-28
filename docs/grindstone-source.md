# Grindstone repair

Voxey follows `ITEMS/mcl_grindstone/init.lua` in the supplied Mineclonia checkout.
The implementation is original GDScript using the source as a behavioural
reference.

## The missing half

Voxey's grindstone disenchanted a single item for a flat three experience. The
source's grindstone is also a **repair bench**:

- `calculate_repair` (`:133-137`) combines two identical damaged pieces. The 5%
  bonus multiplies the **second** term only, so input order is observable:
  `251 - ((251-200) + (251-150)*1.05)` is **93**, while the reverse order gives 96.
- Curses transfer from **both** inputs; ordinary enchantments are dropped.
- `calculate_xp` (`:66-77`) pays `random(7,13) * level` per non-curse enchantment
  on the sacrificed item, and `:282-283` **throws** it at the grindstone as orbs.

`scripts/grindstone_repair.gd` reproduces all three, expressed in Voxey's own wear
units — the source works on the normalised 0..65535 scale, Voxey on
`Nodes.durability(id)`, so every fraction is taken of the item's own span.
`village_survival.gd`'s grindstone branch now runs the repair combine **before**
the enchantment test, because a damaged pair with no enchantments must still
repair, and pays the per-level experience instead of the flat three.

## Recorded differences

- Requiring both pieces to be damaged is stricter than the source, which tests only
  the item type and the stripped name. It follows this project's existing station
  rule ("This item needs no repair") and is asserted in the check.
- `combine` accepts an `rng` to match the requested signature but draws nothing:
  the source's wear arithmetic has no random component.
- The screen shows one item at a time, so the partner is whichever other carried
  slot is compatible, and the branch still works in place on one slot — which is
  how the whole grindstone branch already behaved for a stack of enchanted books.
- `Inventory.clean_slot` needed **no** new key: the result writes only
  `custom_name` and `enchantments`, both already allow-listed.

## Verification

`tests/grindstone_repair_checks.gd` (46 checks) hand-computes the wear for both
input orders, asserts the result never reaches full durability, checks curse
transfer from the second piece and the dropping of ordinary enchantments, proves
`xp_for` against a mirrored generator with the same seed (including that a curse
draws no roll), and runs the whole operation on a real inventory pair asserting the
thrown orbs carry 21..39.

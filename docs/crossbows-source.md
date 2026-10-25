# Crossbow drawing, loading and firing

`scripts/crossbow_use.gd` follows the installed
`/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_bows/crossbow.lua`.
The source is covered by the repository's
[Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Hold right-click or Z to draw, release a full draw to load, and press Attack
(left mouse; the mining control on touch) to fire. Right-clicking a loaded
crossbow can still interact with a block and does not fire it. Incomplete pulls
consume nothing. A loaded chamber survives switching slots, dropping, storage,
save/reload through normal item metadata.

- Pull stages change at 350,000 and 900,000 microseconds. Quick Charge subtracts
  65,000 microseconds per level from the first threshold and 130,000 from the
  full threshold. Level III loads in 0.51 seconds. The source advances at most
  one stage per hold callback, which this implementation preserves.
- Drawing multiplies movement by `1.295 / 4.317`. It has no bow-style FOV zoom.
  Releasing, switching, dropping or entering a menu removes the slowdown.
- The first compatible main-inventory arrow is consumed when loading, not when
  beginning the pull. Creative loads a default arrow without inventory ammo.
  Infinity does not preserve crossbow ammunition. Fireworks in this checkout
  are elytra boosters and do not have the crossbow-ammo group.
- Every fired arrow is critical, has base damage 2 and speed multiplier 63,
  and starts at the eye position minus 0.1 vertically. Piercing is transferred
  to the projectile. Power, Punch and Flame are not crossbow effects.
- One triangular perturbation is added to the look direction without
  normalization. Multishot rotates that same direction with the source's Euler
  expressions, including pitched shots, then emits left, right and center.
  All three projectiles are collectible in the source, including creative.
- Shooting applies `floor(65535 / (385 * (Unbreaking + 1) / 3))` normalized wear.
  The source tests the numeric result of `get_enchantment("multishot")` as a
  boolean. Lua considers zero true, so this triple-wear branch also applies
  without Multishot. The fixture confirms 510 wear for an ordinary shot.
- The recipe's central ingredient is an arrow, not the previously used bow.

Native items use one stable ID. `crossbow_loaded` distinguishes the loaded
and unloaded forms; `loaded_arrow` and `loaded_arrow_data` retain the last
projectile's identity and metadata. Firing clears the loaded flag but retains
that metadata, as the source retains its `arrow` field when changing names.
Legacy items with `loaded_arrow` and no flag become loaded; their former
countdown is discarded, preserving already-consumed ammunition. Incomplete
draw state is transient and is never saved into an item. Loaded models appear
in the hand, inventory, drops and item frames. Fired arrows also retain their
item metadata on pickup and while saved in the world.

`tools/export_crossbow_reference.py` invokes the real source hold, release and
press callbacks in a temporary localhost Luanti world. It exports 144 load
cases and 1,440 firing cases, covering all supported Quick Charge and
Unbreaking levels, ammunition availability, creative mode, Multishot,
Piercing, existing wear, breakage and five look directions. The source RNG
sample stream is fixed so the actual spread and Euler rotation can be compared.
The fixture records hashes of its four source files. Run
`tests/crossbow_reference_checks.gd` and the `crossbow` lifecycle group for the
source comparison and actual input/storage/reload paths. `crossbow_tour.gd`
renders all five visual forms.

Validation on 2026-10-24: all 1,584 source cases, 191 combined crossbow/bow/
projectile/spyglass checks, 903 village checks, 239 alchemy checks and 534
survival checks passed. Import, Linux export and visual inspection also passed.

This closes the player crossbow draw/load/fire path; [arrow flight](arrow-flight-source.md) now also covers drag, liquid and impact
state. [Pillager crossbow combat](mob-crossbows-source.md) now has its own
source comparison. Full knockback and remote projectile synchronization remain
open. Audio and artwork remain native procedural assets.

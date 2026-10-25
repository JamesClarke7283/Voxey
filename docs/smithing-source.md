# Smithing table

Reference: the supplied Mineclonia checkout's `ITEMS/mcl_smithing_table/init.lua`
and `ITEMS/mcl_armor/{init,api,trims}.lua`, inspected 2026-10-24. Source-derived
behavior and registry data retain GPL-3.0-or-later attribution. Art is original.

The table now has three real inputs—equipment, mineral and template—and a
virtual output. Players choose each input. The former automatic bag search and
ordinary-repair action are removed from this table.

## Registered rules

Equipment insertion uses the source armor/tool/sword groups and its blacklist.
Elytra cannot be inserted. The mineral slot uses the actual registered trim-color
property: eleven source minerals, including quartz and resin brick. Netherite
scrap is not a mineral; older scrap trims retain their saved appearance.

The template slot accepts registered trim and upgrade templates. The source
registers fifteen trim patterns. The existing Host and Raiser patterns remain
native additions; they are not included in claims of source registration parity.
The sorter used by Shift transfer routes templates first, then minerals, then
eligible equipment, and limits insertion to the destination's actual space.

A Netherite ingot and upgrade template convert registered diamond equipment.
The item keeps its exact normalized wear, name, enchantments, prior-work penalty,
trim and other supported metadata. Changing material recalculates the native wear
display from the preserved 0–65,535 value; it does not apply a second rounding to
that value.

Trim templates apply to registrations with an armor element, preserving the rest
of the item. Reapplying the same pattern and material produces no output. The
native inventory shows the trim in the mineral's color, including on the result
preview. Full trim presentation on worn third-person armor remains part of the
broader armor work.

## Inventory and achievements

Previewing never consumes inputs. Taking an output consumes one item from each
input and immediately recomputes the next preview. This is the source callback's
per-take rule, including its retained output-stack count for stackable equipment.
Breaking the table drops the three real inputs only. Stored inputs and output
survive saving, and the table remains the toolsmith's jobsite. The source does
not register this workstation as a hopper/comparator container.

Only a Netherite **hoe** triggers Serious Dedication. Trimming triggers Crafting
a New Look. Smithing with Style needs the exact source set: Spire, Snout, Rib,
Ward, Silence, Vex, Tide and Wayfinder. Repeating a pattern or using another
pattern does not advance that requirement. Existing unlocked achievements remain
unlocked; an active smithing counter drops unrelated legacy entries when it
records a required pattern.

Guests use host-owned previews and transactions. The resulting achievements
belong to the guest, and their achievement state is saved with the player's
inventory and restored when reconnecting.

## Related corrections

The registration comparison also corrected flint-and-steel stacks to one and
recovery-compass stacks to 64. Existing oversized flint stacks remain readable.
The reference's ancient debris uses `pickaxey=4`, so iron picks can harvest it;
the older diamond-only guide and test expectation were corrected to the actual
source. Its runtime harvest rule was already correct.

## Verification

`tools/export_smithing_reference.py` runs the actual loaded game and captures
6,110 smithing transactions, 1,373 bound item profiles, fifteen templates,
eleven minerals, permissions and sorter callbacks. It records all 633 Lua source
hashes. `tests/smithing_reference_checks.gd` compares previews, metadata,
consumption, regenerated output, achievement events, registered slot filters,
all template duplication recipes and all twelve wood variants of the table
recipe.

The lifecycle suite exercises the real UI, exact wear, mineral filtering,
Shift sorting, achievement requirements, save/load and destruction. Multiplayer
checks exercise a guest upgrade and persistent achievement. The interface,
source texture representation and protected-area integration use native systems.

Validation on 2026-10-24: all 55,463 source comparisons pass, including template
recipes and mineral colors. The 108 focused workstation checks, 535 survival
checks and 23 bastion checks pass. The complete network protocol/host/guest suite
passes, including guest smithing, inventory preservation and achievement
reconnection. All 633 source hashes match. Upgrade, trim, compact and invalid-input
screens were visually reviewed, and the Linux pack exports successfully.

The corrected full parity regression also passes all 71 checks. Its armor hit
now supplies the physical-mob reason explicitly; the source generic reason
bypasses armor and had invalidated the following travel checks.

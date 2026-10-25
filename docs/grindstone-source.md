# Grindstone

Reference: `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_grindstone/init.lua`,
inspected 2026-10-24. Source-derived behavior retains GPL-3.0-or-later attribution;
artwork and the interface are native.

The workstation has two real input slots and one virtual output. It no longer
selects a partner from elsewhere in the player's inventory or modifies a carried
item in place. Inputs may contain any item; incompatible inputs produce no result.
The completed source registry determines which items count as tools, including
armor, elytra and the non-damageable spyglass.

## Repair and disenchantment

Two tools with the same source item name combine, including undamaged pairs.
The calculation uses exact normalized wear, from 0 to 65,535:

`new_wear = clamp(65535 - ((65535 - first_wear) + (65535 - second_wear) * 1.05))`

The engine truncates the result. The five percent bonus applies only to the
second input's remaining durability, so input order can change the result. The
result retains the first input's custom name and curses from both inputs. Other
enchantments, prior-work penalties, armor trims and unrelated metadata are removed.
The existing exact-wear metadata preserves rounding across saves and transfers.

A single enchanted tool or enchanted book can be disenchanted in either slot.
Its wear and custom name survive; curses remain. A book with no remaining curse
becomes a normal book. Curse-only items still produce a result and award no XP.
The source creates one output item even when the input is a stack of books.

Previewing consumes nothing. Taking a combined result consumes one item from
each input. Taking a single-item result consumes the number of output items taken
from its input. Every positive non-curse enchantment contributes an independent
uniform `random(7,13) * level` XP award. XP appears as physical orbs beside the
workstation. Taking output leaves it empty until an input changes or the player
reopens the workstation, matching the source callback order.

## Placement, persistence and networking

The recipe uses two sticks, one **stone slab**, and two planks of any species.
The previous full-stone shortcut is removed. The source's floor, ceiling and wall
placement branches and all 24 screwdriver orientations are represented by the
canonical item 527 and hidden states 15400–15422. Five oriented source boxes
supply rendering, selection and collision. Every state remains a weaponsmith
jobsite and drops the canonical item.

Inputs and preview survive saves; reopening recalculates the preview. Breaking
the workstation drops only its real inputs, preventing virtual-output duplication.
The source does not register it as a hopper/comparator container.

Guest transactions are validated and applied by the host. The host also simulates
XP orbs, broadcasts their appearance and movement, and awards XP only when a
living player collects one. Guests run Mending on the authoritative pickup award.
An orb may be collected by another nearby player; withdrawing output itself
credits no XP.

## Verification

`tools/export_grindstone_reference.py` runs the real installed game. Its fixture
records 591 repair, disenchantment and inventory callback cases, 1,358 bound
item profiles, all 24 orientations, 24 placement cases and protected-inventory
permissions. The source comparisons also cover empty and incompatible inputs,
normalized-wear boundaries, stacked books, custom names and metadata removal.

`tests/grindstone_reference_checks.gd` compares those outcomes and all twelve
wood materials in both possible recipe rows. `tests/grindstone_repair_checks.gd`
uses the real workstation UI, checks physical XP and unchosen inventory items,
and exercises saving, reloading, rotation and destruction. The network suite
checks guest preview/withdrawal and the resulting physical XP pickup.

The UI, textures, engine input gestures and protected-area integration use
Voxey's native systems. Broader sound, mob navigation and multiplayer parity
remain separate work.

Validation on 2026-10-24: 3,744 source comparisons, 190 combined
workstation/XP/furnace/piston checks and 535 survival checks pass. All 633 Lua
source hashes match the exported reference. The host/guest protocol and
inventory suites pass, including physical XP pickup and reconnect regressions.
The workshop, normal and compact interfaces and unavailable-input screen have
been visually reviewed, and the Linux resource pack exports successfully.

The additional host/guest/observer world-sync run also passes, covering streamed
chunks, remote edits, entity movement, removal and stale-packet handling.

# Composters and farmer workstations

Voxey follows the installed Mineclonia checkout's
`mods/ITEMS/mcl_composters/init.lua`, the item `compostability` groups and the
farmer workstation methods in `mods/ENTITIES/mobs_mc/villager.lua`. The native
implementation is original GDScript. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

A composter is crafted from seven wooden slabs in a U; the existing ingredient
group accepts mixed wood species. Seeds and kelp have a 30% chance to add a
layer, vines 50%, wheat and apples 65%, bread 85%, and cake or pumpkin pie 100%.
All mapped items now read their actual registered source chance, including
flowers, fungi, Nether plants and moss variants. The original fallback covers
native items without a source mapping. Accepted items are consumed on a failed
roll as well as a successful one. Creative insertion preserves the held item.
Sneaking bypasses composter use.

Levels zero through six accept ingredients. At level seven, a one-second timer
matures the compost into ready level eight. Manual harvest produces one bone
meal pickup and clears the composter. A downward hopper above feeds one accepted
item per transfer; a hopper below extracts the ready bone meal. A full output
hopper leaves it in place. Comparators read zero through eight. Breaking a
composter discards its contents and returns the empty block. It has the source's
fifteen-second fuel time and is flammable.

The collision shape now matches all five source boxes: four narrow walls and
a floor whose height rises from 1/16 to 15/16 with the compost level. Selection
remains a full block, as in the source. The hollow space in the existing visual
model can now be entered physically.

A full composter restarts its one-second maturation timer when its chunk or
world loads, following the source load callback. Native version-two station
records distinguish this from old immediate-output saves: a legacy level seven
with no maturation field becomes ready level eight. Partial and ready states
remain unchanged. Unloaded chunks and paused worlds do not mature.

## Farmer integration

Villagers have eight persistent private inventory slots. They pick up bread,
carrots, potatoes and beetroot; farmers also collect wheat, wheat seeds,
beetroot seeds and bone meal. Pickup requires an item at least one second old,
within 1.95 blocks, and room for its entire stack in a single slot. Once admitted,
the source insertion algorithm fills slots in order. Stack metadata survives
pickup and saving. Profession changes preserve the inventory. The source's
infected-villager identity export omits this inventory, so curing does not restore
consumed or lost goods from the previous life.

An adult farmer at its valid workstation can begin a work visit on a one-in-two
check with a fifteen-second timer. The visit lasts ten to twenty seconds and
ends if the farmer moves at least 1.73 blocks away. Native scheduling uses the
existing workday and nearby-threat checks. A working farmer pauses its travel.

Each visit processes at most twenty surplus seeds in inventory order, retaining
ten wheat seeds and ten beetroot seeds separately. Farmer insertion intentionally
bypasses maturation: trying to insert into a full or ready composter first
empties it and releases a bone meal pickup, then processes the new seed. This
can cycle several times within one work visit. Afterwards, a farmer with fewer
than 37 bread makes up to three bread from up to nine wheat. Output goes into
its inventory, with overflow dropped into the world. Source removal semantics
also apply when wheat stacks carry different item metadata; they are not
combined into one removable stack. The visit also performs
the normal trade-restock check.

The private inventory and source workstation transactions are implemented.
The later [field-work batch](farmer-fields-source.md) adds separate harvesting,
inventory-based planting, fertilizing and weighted activity selection. Native
scheduling and route selection remain separate work; [food sharing and breeding](villager-social-source.md)
are covered by a later batch; this does not claim complete villager parity.
Area protection and multiplayer inventory replication are also outside this
local implementation.

## Verification

`tools/export_composter_reference.py` runs the actual source callbacks in a
local Luanti world. The fixture includes 1,080 manual/farmer input cases, 240
farmer compost sequences, 99 bread crafts, 108 pickup cases and nine collision
states. `tests/composter_reference_checks.gd` also verifies 2,333 mapped item
chances. The exported data includes hashes of 32 input source files used by the exporter.

`tests/farmer_work_checks.gd` and `tests/composter_checks.gd` exercise live pickup,
workstation use, reserve and budget limits, collision, mixed-slab crafting,
comparators, hopper transactions, source timer restart, legacy migration, world
save/reload and infection inventory handling. The farmer work timer is transient;
the private inventory is saved in the village record.

Validation on 2026-10-24: all 1,536 callback/geometry cases and 2,333 mapped-item
checks pass. The focused composter/farmer, zombie-target and zombie-villager
lifecycle run passes 125 checks; the village and alchemy runs pass another 903
and 239. A final 46-check focused run includes the current metadata-aware item
removal. The composter/working-farmer preview was rendered and reviewed, and the
Linux pack exports successfully. Source hashes match the supplied checkout.

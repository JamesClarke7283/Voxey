# Spyglass

Reference: local Mineclonia `mods/ITEMS/mcl_spyglass/init.lua`, inspected 2026-09-16. Attribution: Mineclonia and MineClone contributors; adapted behavior follows [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Source SHA-256: `98b0f63aab050144c0d6b3d1555146799ed27323e2d67561b59460ddb9df2d89`.

One amethyst shard above two copper ingots in a crafting table makes one
spyglass. It stacks to one, has no durability cost and is not consumed by use.
Amethyst comes from [natural geodes](amethyst-source.md).

Hold right click or Z while wielding it to set the camera to the source's
absolute eight-degree field of view. Touch players hold Use. The normal held
item is hidden until both controls are released. Changing items, opening a
menu or dying also clears the transient scope. Sprint camera effects cannot
override it. A node's normal right-click action has priority: opening a chest
or toggling a lever consumes that click and blocks zoom for its duration;
sneaking bypasses the node interaction. Looking away during that same hold
does not accidentally start zoom or repeat the interaction.

The circular mask and copper/lens item sprite are original procedural Voxey
art. Existing HUD status and touch controls remain visible over the mask.
There is no copied scope texture, sound or model. Menu cancellation is a Voxey
interface adaptation; the local source has no corresponding inventory/menu
callback. Scope state is runtime-only and cannot persist into a loaded world.

`tests/spyglass_checks.gd` exercises actual mouse/keyboard and touch holds,
dual-control release, crafting, lens art, sprint FOV, chest/lever priority,
sneak bypass, menu/death/item changes and item preservation.

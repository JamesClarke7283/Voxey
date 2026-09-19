# Ender chests and shulker boxes

The local reference is `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_chests/init.lua`. The Ender chest implementation begins around line 1086; the shulker inventory, placement, destruction, dyeing and crafting implementations occupy approximately lines 1282–1664. Existing shell acquisition comes from the shulker mob, whose upstream drop is defined in `mods/ENTITIES/mobs_mc/shulker.lua`.

Voxey uses stable block IDs 1180–1196: one Ender chest and sixteen shulker colors in the same order as its dyes. The original shell item remains `Nodes.SHULKER_SHELL` (278). These additions do not allocate a competing shell item or change previously saved IDs.

## Implemented behavior

- An Ender chest opens the player's 27-slot personal inventory. Every Ender chest in every dimension accesses that same inventory. Breaking the block, changing dimension, dying, or recovering a death chest does not empty it. An opaque block directly above prevents opening; transparent glass permits it.
- The Ender chest recipe uses eight obsidian around one Eye of Ender. Mining with a pickaxe normally returns eight obsidian; Silk Touch returns the chest. Its source hardness is 22.5 and blast resistance is 3000. Its contents are never block drops.
- Two shulker shells above and below a chest craft a purple shulker box. Place and use the box to open its 27 slots. Boxes hold one item per stack. Mining with any tool or by hand returns one box carrying its entire inventory, including names, book text, enchantments, durability and other supported item metadata.
- Dye plus any box creates the dye's color without losing its name or cargo. All sixteen dye colors are supported.
- Destruction by an explosion preserves the packed box instead of scattering its individual cargo. Creative breaking preserves filled boxes; empty creative boxes are removed without an extra item. Placing a filled box in creative consumes that item, preventing cargo cloning.
- Shulkers cannot contain shulkers. Voxey's own pouches can carry boxes, and boxes can carry pouches, but a container may not contain another container of its own kind through the other kind. The same restriction applies to mouse transfers, shift transfers, pickup into equipped pouch pages, automation and save restoration.

## Persistence and ownership

Placed shulker inventories use the existing per-dimension station map. The portable item holds a deep copy under `data.contents`; the original station is removed when it becomes a drop. Recoloring carries that metadata forward. Contents are normalized to exactly 27 slots and validated through the normal item sanitizer, with nested container restrictions propagated through both container types.

The active player's Ender station is saved at the save root under `ender_storage`, outside the per-dimension station map. Legacy saves receive an empty 27-slot inventory. A new world initializes a fresh personal inventory. Voxey currently has one local player; this state follows that player and must be keyed by authenticated player identity if multiplayer storage is introduced.

## Representation limits

Voxey currently renders these blocks with procedural cube textures. Mineclonia's animated meshes, opening sounds, particles, oriented shulker lids, and Ender chest light emission are not reproduced by this module. The source itself only checks overhead obstruction when opening the Ender chest; its shulker right-click callback opens directly. No additional shulker obstruction behavior has been inferred.

The source marks Ender chests immovable and shulkers as destroyed by piston contact. Voxey initially treats both as protected storage blocks that pistons cannot move; piston-triggered packed shulker destruction remains a separate parity task. Ender inventories cannot be accessed by hoppers or comparators. Shulker inventories participate in ordinary container automation and comparator fullness.

## Verification

`tests/storage_checks.gd` covers acquisition, slot limits, cargo metadata, JSON round trips, dyeing between non-purple colors, nested storage rejection, independent placement data, packed breaking and explosion drops, creative cargo preservation, shared Ender access, obstruction, Silk Touch, and the root save payload. It is designed to run from a game-backed test suite so it exercises the actual inventory, HUD, world and game hooks.

Shulker dye can now be washed off in a water cauldron, retaining its cargo and name. See [cauldron rules](cauldrons-source.md).

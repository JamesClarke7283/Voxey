# Item names and persistent creature tags

Reference files in `/home/impulse/.minetest/games/mineclonia`:

- `mods/ITEMS/mcl_anvils/init.lua`: changed names cost one level; unchanged names have no output; item names are limited to 50 bytes; creative renaming is free.
- `mods/ENTITIES/mcl_mobs/init.lua`: creature tags use the item's name, reject empty names, limit names to 30 bytes, and consume one tag outside creative.
- `mods/ENTITIES/mcl_mobs/spawning.lua`: named creatures are exempt from ordinary despawning.
- `mods/ENTITIES/mobs_mc/ender_dragon.lua`: dragons ignore name tags.
- `mods/ITEMS/mcl_books/init.lua`: signed books have `no_rename=1`.
- `mods/ITEMS/mcl_mobitems/init.lua`: paper and a metal nugget produce a name tag in either diagonal. Fishing treasure acquisition is described in `fishing-source.md`.

At an anvil, choose an inventory stack, enter its name, then use **Set name** or Enter. Naming or removing a name costs one XP level for the entire stack in survival. An unchanged name spends nothing; empty stacks and invalid selections cannot spend XP. Creative renaming is free. Signed books retain their authored title. Existing cargo, enchantments, charge and wear stay on the item. Item names appear in inventory tooltips and above the hotbar.

Use a named tag on a living creature to show its name above its head. Each survival use consumes one tag, including renaming an already named creature. Blank tags do not consume anything. Dragons and end crystals cannot be named; crystals are world entities rather than source mobs. Byte limits preserve complete Unicode characters instead of cutting a UTF-8 sequence in half. Newlines become spaces. The same limits apply when restoring saved item and creature names.

Names persist through the appropriate entity record: farm and generic named creatures, villages and golems, horses, alchemy creatures, and Nether residents. Naming a naturally or manually spawned piglin creates a durable resident identity if needed. Named Nether residents restore in any dimension, retaining barter state. Village profession changes retain names. Named creatures are protected from ordinary distance/daylight despawn but can still die from damage.

Lead saves retain farm, villager and Nether resident identities. Restoration reuses the named creature already restored by its own subsystem, preventing duplicate animals or piglins. Dead resident records do not resurrect.

The anvil editor uses Voxey's existing XP curve and inventory selection UI. Falling anvils, wear stages and the source's 12% use-damage chance are separate missing anvil mechanics. Specialized name Easter eggs such as the source rabbit's Toast appearance remain separate work.

`tests/name_tag_checks.gd` exercises both real UI submit paths, XP and blank/invalid input handling, byte limits, metadata preservation, excluded targets, save writing and the actual final loading phase for every currently registered nameable creature kind. It also checks named lead deduplication, piglin barter state and dead-record handling.

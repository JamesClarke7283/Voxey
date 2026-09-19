# Constructed iron and snow golems

Reference: the installed Mineclonia source at `/home/impulse/.minetest/games/mineclonia`:

- `mods/ENTITIES/mobs_mc/iron_golem.lua`: construction patterns, creator flag, targeting, repair, damage, drops and crack thresholds.
- `mods/ENTITIES/mobs_mc/snowman.lua`: construction, shearing, snow trails, heat sensitivity and ranged attacks.
- `mods/ENTITIES/mcl_mobs/{combat,physics,breeding}.lua`: retaliation, water/rain damage, fire/lava damage, default ranged interval and dispenser shearing.
- `mods/ITEMS/mcl_farming/pumpkin.lua`: carved-pumpkin and jack-o'-lantern placement callbacks; carving does not call them.
- `mods/ITEMS/REDSTONE/mcl_dispensers/init.lua`: dispenser pumpkin placement uses `set_node`, without the placement callback.
- `mods/ITEMS/mcl_potions/functions.lua`: water-sensitive creatures take one damage from water splash effects.

The source mob files credit maikerumine and state WTFPL for code unless otherwise noted in their readmes. This implementation follows the mechanics using Voxey's existing controllers and original procedural models; no source meshes, textures or sounds were copied.

## Survival construction

Place a **carved pumpkin or jack o'lantern last**. Raw pumpkins do not summon anything, and carving a raw pumpkin already in the structure does not summon a golem. Existing pumpkin farming, shears, snow-block crafting and iron-block crafting provide the survival ingredients.

Iron consumes four iron blocks and the head. All eight source patterns are recognized in source order: upright and upside-down T shapes in either vertical plane, plus four horizontal T shapes. The four source corner cells must be literal air, so water, plants and top snow do not satisfy that check. The feet location follows the source pattern, including its upside-down exceptions. Snow consumes two full snow blocks and the head, recognizing the six axial arrangements. Snow has no iron-style corner checks.

Construction checks the complete pattern before mutation. As a deliberate safety adaptation, the resulting creature's body must also fit in loaded space after the construction blocks disappear. An obstructed body leaves the structure intact; it cannot consume materials into an embedded creature. Successful construction consumes its blocks without item drops and repeated callbacks cannot duplicate the golem.

Dispensers place carved pumpkin blocks but do **not** construct golems: the installed source omits `after_place_node` in that path. This differs from some Minecraft descriptions. Raw pumpkins and jack o'lanterns retain ordinary dispenser behavior.

## Iron golems

Constructed iron golems retain the existing `VillageMob` integration, alongside naturally generated village golems. They have 100 health, source 0.7 horizontal collision radius and 2.69 height, full knockback resistance, no fall/drowning damage, and take ordinary fire/lava damage. One iron ingot repairs 25 health, capped at 100; full-health interactions consume nothing, and creative repair does not consume iron. Original procedural cracks appear below 75, 50 and 25 health.

Iron attacks nearby monsters except creepers, with source 7.5–21.5 randomized melee damage and 16 upward target velocity when damage succeeds. Natural golems can also target a survival player whose reputation is below −100 with a nearby villager. A saved creator flag suppresses that reputation rule for constructed golems. **The installed source still allows retaliation against the creator after a direct attack**: its generic retaliation rule has no creator exclusion. Player melee and known projectile throwers preserve attribution; creative players are excluded. Environmental damage is not treated as a player attack.

Death drops 3–5 iron ingots and 0–2 poppies once. Health, creator, custom name, player retaliation and potion effects live in the existing per-dimension village records; constructed golems also restore outside the Overworld. Natural village generation remains restricted to the Overworld.

## Snow golems

Snow golems have 4 health and their own persistent identity. They fire the existing physical snowball projectile at visible monsters, including creepers, within 10 blocks, at the source default one-second interval. Snowballs retain existing source behavior: three damage to blazes, zero health damage plus provocation/knockback against ordinary creatures. Projectiles collide with walls and retain their golem thrower.

Using shears once reveals an original snow face and drops one carved pumpkin, including creative mode; only survival use wears the tool. Repeated shearing does nothing. Source dispenser shearing wears the shears and removes the head **without** dropping a pumpkin; this distinction is preserved. A sheared head does not regrow.

Every half-second, water or exposed rain deals one damage. Hot-biome temperature above 1 deals one fire-type damage on the same interval; fire resistance prevents heat damage. Voxey's reduced biome map represents hot source climates with its desert and the Nether. Its snowy biome receives snow rather than damaging rain, and a roof protects against rain. Ordinary fire and lava damage apply; snow golems do not take fall or freezing damage. Water-potion effects also damage them.

After more than half a second, a living snow golem leaves one top-snow layer in a replaceable non-liquid cell above a full solid cube. Slabs and other partial supports are rejected. The saved `mobGriefing` rule disables this placement when false. Source trail placement itself has no temperature condition; a fire-resistant snow golem may place trails in a hot biome. Source snow melting remains a separate world system.

Snow identity, position, health, sheared state, creator, custom name, environmental/trail clock and effects are saved with the dimension. Loaded-area streaming hibernates distant golems and restores the same record. Leads and boat passengers resolve that identity rather than duplicating a generic creature. Boat passengers still receive environmental damage while their own movement controller is suspended. Death drops 0–15 snowballs once and removes the persistent record.

## Remaining AI differences

Voxey uses its existing bounded pathfinding and local movement speeds, not Mineclonia's full navigation/task scheduler. Village POI heat seeking, ten-second villager flower offerings and the complete village reputation/witness simulation are not implemented. Existing generic hostile creatures still use Voxey's player-focused pursuit, so a snowball's provocation does not introduce the full source mob-versus-mob retaliation scheduler. Projectile flight uses Voxey's existing throwables trajectory and a simple ballistic aim. Source soul-fire environmental damage has no standalone soul-fire block dependency in this game; ordinary fire, lava, campfires and source heat damage are supported.

These are golem construction and survival interactions, not a claim of complete mob-AI parity.

## Validation

`tests/golem_checks.gd` exercises all 14 source construction patterns, exact block consumption, repeat/no-op construction, corner/body obstruction, actual player head placement, carving and dispenser distinctions, repair and shearing inventories, crack stages, retaliation/reputation, iron damage and creeper exclusion, real snowballs, snow trails and climate damage, and actual world JSON reload plus lead identity and distance hibernation. The fixture restores the prior lifecycle world afterward.

Focused isolated checks: **83 passed, 0 failed**, with no script errors (`/tmp/voxey-golems-final.log`).

The rendered `tests/farm_golem_tour.gd` also verifies crop stages, wet/dry furrows and lowered soil, both construction patterns, constructed/sheared golem models and farming inventory icons. Images are written to `/tmp/voxey-farm-golem-shots/` using isolated temporary saves.

# Ordinary animal farming

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-09-16. The installed copy has no Git metadata. The rules below were ported into Voxey's existing creature controller and procedural models; reference license: `docs/licenses/Mineclonia-GPL-3.0.txt`.

`mods/ENTITIES/mcl_mobs/breeding.lua` supplies the common lifecycle: 15-second love mode, a visible compatible mate within eight blocks, more than 3.5 seconds courting and less than three blocks separation at birth, five-minute cooldown for both parents, and twenty minutes of loaded simulation for a baby to grow. Feeding heals four health first; a healthy baby instead loses ten percent of its remaining growth time, and a healthy eligible adult enters love. Creative feeding preserves the item. A successful pair produces one baby and 1–7 XP. Voxey also awards its new Parrots and Bats achievement without adding extra XP.

Species food definitions and right-click restrictions come from `mods/ENTITIES/mobs_mc/{cow+mooshroom,sheep,pig,chicken,rabbit}.lua`:

| Animal | Available breeding and temptation food |
| --- | --- |
| Cow, sheep | Wheat |
| Pig | Carrot, potato, beetroot |
| Chicken | Wheat, beetroot, pumpkin and melon seeds |
| Rabbit | Carrot, golden carrot |

Right-clicking an animal with its food uses the normal ray-targeted interaction. Ineligible adults consume nothing. Food held within ten blocks attracts animals while they can see the player; babies follow nearby adults of their species. Mating and movement use Voxey's collision and visibility checks. Baby models and collision boxes are half size with proportionally larger heads. Growth waits if the larger body would intersect a solid block. Babies cannot produce milk, be sheared, lay eggs, or drop ordinary meat/items/XP on death. Pink particles show love mode and births.

`scripts/farming.gd` assigns stable IDs and stores animals in each dimension's `adventure.farm_animals` save records. Health, position, heading, age, love, cooldown, names, shearing, coat color, grazing animation/consumption state, egg timers, and potion effects survive saves. Lead records refer to the same ID, avoiding a second copy when both records load. Animals outside loaded columns or beyond the simulation range become dormant records and return once the player approaches; dormant timers stay frozen. Death removes the record. Legacy rabbit saves migrate through the existing animal loader. Existing horse save records remain separate.

The same registry preserves named generic creatures, including Expedition creatures, with slime size/health and shulker guard identity. Village, Nether resident, Alchemy and horse records retain their separate persistence systems. Named creatures are exempt from incidental random distance/daylight despawn, but can still die normally from damage, daylight burning or explosions. Name-tag rules and specialized record deduplication are tested separately in `tests/name_tag_checks.gd`.

Sheep use the reference natural coat distribution (about 81.836% white, 5% each light grey/grey/black, 3% brown and 0.164% pink), retaining Voxey's existing wool palette. All sixteen existing dyes work through ordinary right-click, consume one dye in survival, and can color babies. Bare sheep reject dye without consumption. Shearing drops 1–3 matching wool; an adult killed with a coat drops one matching wool, and a sheared adult drops none. Two parents pass down a dye-craft-compatible color (for example red + blue → purple), otherwise a random parent's color. The nine two-dye combinations come from `mods/ITEMS/mcl_dyes/init.lua`.

Sheep regain wool by grazing instead of a fixed timer. Source attempts are scaled to timestep: 1/1000 per 0.05 seconds for adults, 1/50 for babies. A successful attempt starts a two-second head-lowering animation, and consumes the grass block into dirt during its last 0.4 seconds. Grazing restores the same wool color and advances a baby's growth by sixty seconds. Temptation, mating, herding, panic and leads take priority. Terrain consumption is recorded once, including when a save resumes an in-progress graze. Old `wool_timer` data remains readable for compatibility but no longer regrows a coat on a stone floor. Adult chicken eggs now use the source's randomly selected 300–600-second interval; baby timers remain frozen. Existing saved egg countdowns finish before adopting the new interval.

Remaining scope:

- Tallgrass, fern and dry-grass plant nodes are absent, so this batch supports the source grass-block grazing branch. [Nearby grass now spreads back onto grazed dirt](pasture-source.md) under the source light and cover conditions. A configurable mob-griefing toggle remains separate work.
- Pumpkin and melon seeds now join chicken food via the [fruit crop system](fruit-crops-source.md). Rabbit dandelion feeding and carrot-on-a-stick steering remain separate integration gaps.
- Rabbit coat variants and special names, horse breeding/genetics, pig saddling, mooshrooms and chicken jockeys remain separate work.
- Movement uses Voxey's existing local steering and jump collision handling. It does not reproduce Mineclonia's complete pathfinding/navigation or exact species speed bonuses. Source mate/herd search uses bounding boxes; Voxey uses bounded distance searches.

`tests/farming_checks.gd` exercises actual mouse right-click feeding and baby milk refusal, source food/timer rules, single births, XP/achievement, growth/collision restrictions, baby drops/eggs/shearing, temptation and herding, blocked mating, real disk save/load, lead deduplication, partially used absorption, named damaged slime state, dormant restoration and permanent death. It also covers all dye interactions, natural color boundaries, colored wool acquisition, source offspring mixing, automatic grazing initiation, animation and grass consumption, interrupted/resumed grazing, growth bonuses, and source egg timing.

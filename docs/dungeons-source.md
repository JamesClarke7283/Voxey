# Cave dungeons and working mob spawners

Reference: local Mineclonia `mods/MAPGEN/mcl_dungeons/init.lua`,
`mods/ITEMS/mcl_mobspawners/init.lua`,
`mods/ENTITIES/mcl_mobs/spawning.lua`, and
`mods/ENTITIES/mobs_mc/spawning.lua`. Mineclonia's source code is GPLv3.
The cage and miniature use original Voxey art; no source textures are copied.

Natural Overworld terrain now generates actual cave dungeons, giving the source
Chirp record a survival acquisition route. Plans use world-coordinate seeded
randomness, so requesting neighboring columns in a different order produces
the same room and halo. Candidate attempts preserve the source volume density
of one per 8192 nodes; Voxey uses bounded 32×32 planning regions and its existing
terrain and seed functions rather than pretending to reproduce Luanti's map.

Each candidate has a 5×5, 5×7, 7×5 or 7×7 interior. The current Lua reference sets
`dim.y=4`: four clear cells above the floor, with the natural ceiling at floor+5.
Every interior floor and ceiling cell must be solid, and the wall must have
1–5 two-cell-high cave openings. A cave entering only at a corner is widened.
Floors are 75% mossy cobblestone and 25% cobblestone. The existing ceiling is kept;
no extra cobblestone roof is invented. Non-geological nodes and bedrock are
protected. Qualification excludes strongholds and the actual modified village
pad volume, so a cave plan cannot carve a village house or rely on a roof that
village flattening removed. Player edits always apply after generation.

Up to two chests are selected along the inner walls, including the source's
second chance when both choices collide. Each chest gets independent source
loot from these three pools:

| Pool | Rolls | Weight total | Implemented contents |
| --- | ---: | ---: | --- |
| Treasure | 1–3 | 145 | Name tag, leather, 13/Far/Chirp records, golden apple, enchanted book |
| Supplies | 1–4 | 125 | Wheat, bread, coal, redstone, beetroot/pumpkin/melon seeds, iron, bucket, gold |
| Remains | exactly 3 | 40 | Bones, gunpowder, rotten flesh, string |

All source weights and quantity ranges are retained. Enchanted books uniformly
choose among available enchantments except Soul Speed, matching the source
exclusion. Copper/iron/gold/diamond horse armor and enchanted golden apples do not yet
have functional Voxey items. Their source weights remain zero-output rolls; available items and records are **not**
renormalized upward. Those missing items are an explicit acquisition gap.

Adjacent chest halves are initialized independently in 27-slot staging
inventories before merging. A saved per-coordinate initialization ledger protects
fully looted halves, shared containers and player-added items. Legacy existing
single and paired chests are conservatively marked initialized, even when
empty. Repeated generation, alternate column arrival order and actual save/load
cannot refill or overwrite them. Generated dungeon chests bypass the old
stronghold-loot fallback.

The central spawner chooses zombie 50%, spider 25% or skeleton 25%. Its saved station
retains the species and remaining timer. It starts after 2 seconds, retries after
2 seconds when no player is within 15 nodes, and checks the number of that species
within 8 nodes. Four or more block the attempt and schedule a 5–20 second retry.
Otherwise it shuffles all 243 positions in a 9×3×9 volume, placing up to four mobs,
then waits 10–39.95 seconds. The cap is checked before the wave, so three existing
mobs can legitimately be joined by four more, as in the source.

Spawn candidates must be loaded, have collision clearance and contain no liquid
or damaging fire/cactus. The current source monster rules require artificial
light 0, natural light at most 6, and natural light no greater than a uniform 0–31
roll. Source spawner spawning bypasses the ordinary solid-floor requirement;
a clear position above air is valid. Existing species behavior, health and
combat are preserved. Mineclonia's 5% baby-zombie variant is not implemented,
because Voxey currently has no corresponding hostile baby species.

To avoid a cold lighting scan stalling a frame, at most eight positions across
all spawners are checked per update. Each spawner can have one pending attempt;
its post-attempt countdown pauses until that attempt finishes. A queued attempt
rechecks the population cap when it begins, preserving the source order when
nearby spawners fire together. This spreads a worst-case unsuccessful attempt
over multiple frames without accumulating stale waves during low frame rates.
Unloading removes queued work and the miniature while retaining the saved
countdown. World/dimension reset removes runtime references. Loading restores
one visual and the saved timer, without an extra immediate wave.

The cage is a full collision cube with open visual bars and a rotating miniature
of the selected original Voxey mob. It has hardness 5, cannot be piston-moved,
drops no spawner even with Silk Touch, and cannot be placed through the ordinary
inventory. Current source `on_destruct` awards a uniform 15–43 XP; Voxey uses its
existing immediate XP accounting. Privileged source spawner editing and spawn
egg reconfiguration are not exposed by this batch. Existing Nether Blaze
spawners retain their separate implementation.

`tests/dungeon_checks.gd` covers source room constraints, source probabilities,
real generated cross-column terrain and Chirp loot, editing precedence, village
preservation, live spawning and collision/light suppression, queue limits,
nearby spawners, mining, paired chest initialization and actual file save/load.
The focused run completed 51 checks including harness loading. A reproducible
natural Chirp chest for seed 8675309 is at `(-140,-10,-12)`.

Planning stays on terrain workers and its cache is limited to 32 regions. The
main thread consumes only returned spawner/chest positions and saved state.
An isolated 81-column overlay profile measured cold worker calls at 16.19 ms
median, 20.10 ms p95 and 20.34 ms maximum; repeating them with cached plans
measured 0.009 ms median and 0.512 ms p95. The raw results are recorded in
`/tmp/voxey-dungeon-profile.log`. These are worker overlay timings, not frame
latency; rendered streaming is verified by the parent integration run.

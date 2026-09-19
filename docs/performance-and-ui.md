# Performance and interface update

The renderer uses the GPU for drawing, lighting and shaders. The Linux playtest reports **NVIDIA GeForce RTX 5090**, `gl_compatibility`, OpenGL 3.3. F3 now shows the active GPU and renderer. CPU terrain generation and meshing run in Godot's worker pool; scene objects and GPU mesh uploads stay on the main thread.

## Measured CPU changes

Median milliseconds across columns `(0,0)`, `(1,0)`, `(0,1)`, `(1,1)`, seed 8675309, Godot 4.7.2. These are headless CPU measurements, not GPU timings or a guarantee for every world.

| Operation | Overworld before | Overworld after | Nether before | Nether after |
| --- | ---: | ---: | ---: | ---: |
| Generate and mesh a column | 589.22 | 287.86 | 389.85 | 226.26 |
| Apply column on main thread | 152.05 | 1.08 | 111.06 | 0.69 |
| Copy remesh neighborhood | 10.84 | 0.53 | 10.35 | 0.52 |

The expensive full-column gameplay scan now runs on the worker. Results include indexes of circuits, structure chests, fire and fluids that need a reaction. The main thread reconciles newer edits and activates only relevant nodes. The mesher classifies tile properties once per tile type and uses array strides for face checks. Remeshing resolves 27 neighboring blocks once and copies rows directly. Streaming requests are sorted when the player crosses a column boundary or changes view distance, instead of searching the full view area every frame. Nether columns reuse their horizontal biome and height measurements. Existing edits already present in worker output no longer trigger redundant remeshing. Achievement inventory scans run once per second.

`tests/world_benchmark.gd` reproduces the CPU measurements. `tests/streaming_benchmark.gd` measures rendered frame times while moving through a world at view distance 4. The UI/rendering tour at distance 2 held the 60 FPS cap with 25 columns, 300 map blocks and 91 draw calls in its lava/torch scene.

The rendered movement benchmark covered 72.6 blocks in 12 seconds at view distance 4 while new columns were still generating. It recorded 721 frames: median 16.664 ms, 95th percentile 16.976 ms, maximum 19.188 ms, and 60 FPS at the configured cap. This measures this machine and route, not every scene. [Raw measurements](performance-measurements.json) retain the samples and renderer details.

## Behavior

- Menus, panels, slots and touch controls use neutral gray. Pause actions fit in rows and the panel scales to the window.
- The recipe guide uses five columns of item icons, with search, craftable outlines and larger texture/name previews on hover. Clicking an icon still shows its recipe and supports Fill grid.
- Deep sheltered caves keep fixed ambient light and fog through dusk, night and weather changes. The follow-up [environment fix](environment-update.md) preserves daylight in excavated pits and near outdoor openings.
- Lava's atlas coordinates are rounded before emissive classification, avoiding unstable floating-point equality tests. Its texture uses broad seamless pools. Torch inventory sprites have a transparent background, and torch models have correctly oriented sides and end caps.
- Torches attach to the floor or any of four walls. Their orientation persists in saves; removing the support drops the torch and removes its light.
- A broken tool is replaced in its original hotbar position by a carried tool with the same ID and metadata, including name and enchantments. The spare retains its own wear. Equipped pouch pages participate in the search.
- Furnaces reject input insertion while output is occupied, including clicks, swaps, Shift transfers, hoppers and droppers. Fuel insertion and item extraction remain available.
- `/gamerule keepInventory true` keeps inventory pages, pouches, armor and XP on death. It defaults to `false`, persists per world across dimensions, and can be queried with `/gamerule keepInventory`. Disabling it restores recovery chests and bone drops.
- Select a world and choose **Delete…** to open a confirmation naming that world. **Cancel** or Escape returns to the list. **Delete world** removes the world's data and backups. Deletion never follows mod-created symlinks into external files, and deleted legacy imports are not recreated on startup.

## Verification

The existing four suites passed 931 checks after the performance changes. `tests/polish_runner.gd` adds 64 checks covering snapshot equivalence, lighting, tool and pouch transactions, furnace insertion paths, torches, gamerule persistence/deaths, search and confirmed world deletion. `tests/polish_tour.gd` checks the rendered menus, tooltip and lava/torch scene. Tests use isolated save directories and do not delete user worlds.

![Searchable gray recipe grid with a larger torch preview](polish-inventory.png)

The final environment update, including stair/masonry content and active fluid support, measured median column generation at 323.69 ms in the Overworld and 234.04 ms in the Nether. Main-thread application remained 1.09 ms and 0.73 ms respectively; neighborhood snapshots were about 0.51 ms. These four-column CPU samples are retained under `environment_cpu` in the raw measurements.

The completed fluid update’s rendered route covered 72.57 blocks in 12 seconds at view distance 4: 721 frames, median 16.667 ms, 95th percentile 16.836 ms, maximum 17.298 ms and 60 FPS at the configured cap. There were 319 draw calls and no unintended kelp drops. This route measures normal streaming with fluid simulation enabled; the separate environment tour verifies active waterfalls. The complete regression run passed 1,175 checks.

## Habitat streaming, 2026-09-16

The habitat update adds pasture simulation, sheep lifecycle changes, barriers, daylight detectors, targets and expanded cauldron behavior. A longer 40-second route crosses multiple unload boundaries and the first 30-second grass-spread interval. It exposed a repeated scan of all loaded grass/light entries for each departing column: median frames remained near 16.67 ms, but the worst frame reached 245.411 ms. Profiling localized the stalls to world processing at column boundaries.

Pasture now records membership by column for removal, and scans simulation candidates incrementally within its frame budget. The same 40-second rendered route then covered 240.58 blocks over 2,401 frames: median **16.666 ms**, 95th percentile **17.060 ms**, maximum **19.594 ms**, and **60 FPS** at the configured cap. No frame exceeded 33.33 ms or 100 ms. The final scene had 87 loaded columns, 1,044 map blocks and 4,292 pasture cells. These figures describe this machine and route; the longer route is not directly equivalent to the older 12-second benchmarks.

Reproduce it with `godot --path <isolated-project> --script res://tests/streaming_benchmark.gd -- 40`; omitting the duration keeps the original 12-second run. Both measurements are retained under `habitat_streaming_2026_09_16` in the [raw measurements](performance-measurements.json). The benchmark also reports counts of frames over 33.33 ms and 100 ms so rare stalls remain visible alongside percentiles.

## Travel and building streaming, 2026-09-16

The boat/map/trapdoor/snow update was checked on the same 40-second route, with a fixed camera and 60 FPS cap. The harness now explicitly draws the scene each frame because the desktop compositor can otherwise suppress drawing in an obscured window; a zero-draw run was discarded. The accepted final frame was visually checked and contained 448 draw calls and 239,632 primitives.

This run covered 240.52 blocks over 2,400 frames: median **16.660 ms**, 95th percentile **17.182 ms**, and maximum **45.181 ms**. One frame exceeded 33.33 ms; none exceeded 100 ms. Other headless validation was running concurrently. The changed explicit-draw harness means these are new baseline measurements, rather than evidence of a precise speedup or slowdown relative to earlier runs. This warm-biome route contained no snow candidates; separate snow regressions exercise bounded melting scans and generated Frostpine terrain.

Map capture also runs in background column jobs: its dedicated fixture measured 8.009 seconds to finish a mostly unseen survey, with a 0.574 ms maximum main-thread update. See [map scheduling](maps-source.md) and [raw measurements](performance-measurements.json).

## Classic trees and home features, 2026-09-16

The same rendered 40-second route, at the same 60 FPS cap and fixed camera, covered 240.57 blocks over 2,399 frames with the new tree/leaf simulation. Median frame time was **16.678 ms**, 95th percentile **17.499 ms**, maximum **33.342 ms**; one frame exceeded 33.33 ms and none exceeded 100 ms. The final image was visually checked and contained 322 draw calls and 186,922 primitives. Other headless validation ran concurrently.

The final loaded world contained 64 columns, 768 map blocks, 854 tracked leaves, zero orphan leaves and 25 queued leaf checks. Natural tree geometry and loaded column counts differ from the previous procedural-tree route, so these figures do not isolate a speedup or slowdown. Focused tests separately exercise unsupported leaf decay and bounded queue processing; this route measures ordinary streaming. The data is retained as `home_streaming_2026_09_16` in the raw measurements.

## Music and mechanisms, 2026-09-16

The 40-second rendered route with dungeon generation and the new mechanisms covered 240.57 blocks over 2,390 frames. Median frame time was **16.669 ms**, 95th percentile **17.700 ms**, maximum **34.121 ms**, at the 60 FPS cap. Six frames exceeded 33.33 ms; none exceeded 100 ms. The final scene had 53 columns, 636 map blocks, 364 draw calls and 146,770 primitives. Concurrent headless validation and different loaded geometry limit comparisons with earlier runs. The report is retained as `mechanisms_rendered` in the raw measurements.

Pressure plates share one spatial entity index per circuit tick. Dungeon generation runs on workers; active spawners limit collision/light candidates to eight per frame. The sixteen original note tones are generated offline and loaded from assets; a cold-load probe measured 2.7 ms for all sixteen, avoiding synthesis during live playback. The exported content smoke test loaded all eight music recordings, sixteen tones, tree data and music attribution from a standalone resource pack.

`tests/mechanism_tour.gd` checks rendered buttons, pressure plates, note blocks, jukeboxes, compressed ice, bone axes, spawner cages, inventory icons and the field guide's music credits. It uses an isolated save directory.

## Crops, honey and crystals, 2026-09-16

The same 40-second rendered route covered 240.56 blocks over 2,397 frames at the 60 FPS cap. Median frame time was **16.686 ms**, 95th percentile **17.404 ms**, and maximum **50.183 ms**. One frame exceeded 33.33 ms; none exceeded 100 ms. The final frame was visually inspected: 45 columns, 540 map blocks, 344 draw calls and 132,710 primitives. Full headless regression ran concurrently, and loaded geometry differs from earlier batches. These measurements do not isolate a speedup or slowdown; the raw report is `nature_rendered`.

Geode planning stays on generation workers. In a sampled geode area, planning the 25 neighboring candidates cost about 73 ms cold, including approximately 14 ms of structure checks and 50 ms of geometry planning. The generator-local cache makes repeated direct calls inexpensive, but normal streaming creates a fresh generator for each worker job and therefore still pays cold planning costs. No main-thread or cross-thread cache speedup is claimed. Hive simulation shares a 128-sample budget among production jobs; seven due hives took 1.056 ms in the focused check.

`tests/nature_tour.gd` visually checks all stem stages, fruit and carved faces, hive honey levels, transparent honey/tinted glass, all crystal attachment directions, inventory icons, actual held/dropped transparent models, the pumpkin helmet mask, the spyglass aperture and a cutaway of an actual seeded geode. It uses temporary saves. The initial render exposed invalid crystal icon polygons and the pumpkin mask's missing eye cutouts; both were fixed and the clean tour repeated. A separate review found empty held/dropped meshes for the two new transparent blocks; their mesh surface and material selection were corrected and visually verified.

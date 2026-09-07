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
- Underground ambient light and fog stay fixed through dusk, night and weather changes. Surface lighting returns when leaving the cave.
- Lava's atlas coordinates are rounded before emissive classification, avoiding unstable floating-point equality tests. Its texture uses broad seamless pools. Torch inventory sprites have a transparent background, and torch models have correctly oriented sides and end caps.
- Torches attach to the floor or any of four walls. Their orientation persists in saves; removing the support drops the torch and removes its light.
- A broken tool is replaced in its original hotbar position by a carried tool with the same ID and metadata, including name and enchantments. The spare retains its own wear. Equipped pouch pages participate in the search.
- Furnaces reject input insertion while output is occupied, including clicks, swaps, Shift transfers, hoppers and droppers. Fuel insertion and item extraction remain available.
- `/gamerule keepInventory true` keeps inventory pages, pouches, armor and XP on death. It defaults to `false`, persists per world across dimensions, and can be queried with `/gamerule keepInventory`. Disabling it restores recovery chests and bone drops.
- Select a world and choose **Delete…** to open a confirmation naming that world. **Cancel** or Escape returns to the list. **Delete world** removes the world's data and backups. Deletion never follows mod-created symlinks into external files, and deleted legacy imports are not recreated on startup.

## Verification

The existing four suites passed 931 checks after the performance changes. `tests/polish_runner.gd` adds 64 checks covering snapshot equivalence, lighting, tool and pouch transactions, furnace insertion paths, torches, gamerule persistence/deaths, search and confirmed world deletion. `tests/polish_tour.gd` checks the rendered menus, tooltip and lava/torch scene. Tests use isolated save directories and do not delete user worlds.

![Searchable gray recipe grid with a larger torch preview](polish-inventory.png)

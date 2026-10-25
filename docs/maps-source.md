# Persistent maps and cartography

Voxey's `ExplorationMaps` ports the snapshot and copying rules from the local Mineclonia sources below. The source is GPL-3.0-or-later; see [the included license](licenses/Mineclonia-GPL-3.0.txt).

| Source, relative to `/home/impulse/.minetest/games/mineclonia/mods` | SHA-256 |
| --- | --- |
| `ITEMS/mcl_maps/init.lua` | `3d6a9bc98e16a4cb8c52190acc963758aef9387ded6af380be9dfd12fc039109` |
| `ITEMS/mcl_maps/colors.json` | `a486415cc4bc37961f9bffabe2f5998937f199a18fb7cdd6ba300f4bc6b7790e` |
| `ITEMS/mcl_cartography_table/init.lua` | `04f941d47dec0f8096bbd950b54bd6c3919a9d78319e0ee77e455877be46cdcd` |

## Implemented behavior

An empty map costs eight paper around a compass. Using one consumes one empty map, including in creative as in the source, assigns a stable per-world ID, and captures an aligned 128×128×128 cube. Every coordinate is floored to a multiple of 128, including negative coordinates and Y. The map renders one block per pixel; terrain outside its vertical cube is excluded. Empty sky is black.

The image is a permanent snapshot, not a live terrain view. Actual loaded voxel data and player edits are captured at creation. Unseen columns use the same seeded terrain generator as the normal world, including structures and vegetation. Pending saves retain the captured edits and seed so later construction does not enter the old map when generation resumes. Finished saves store a 128×128 PNG as base64 in the global map registry; item metadata stores only identity, origin, dimension and creation time. Copies therefore share one saved image. Registry ownership spans dimension travel and resets for a different world.

Pixels use the source's top-to-bottom alpha accumulation, ground estimate after opacity exceeds 0.70, and previous-Z-column height shading bounded to ±32. Source pixels are encoded as 5-bit RGB TGA; Voxey preserves its existing 8-bit PNG storage. Voxey uses its own block palette rather than Mineclonia's texture-average RGB catalogue. Matching basic water, glass, oak leaves, flowers, cane, wheat, saplings and mushrooms retain source alpha values; other plants use generic coverage. That palette is a rendering adaptation, not an expansion to Minecraft's zoom/locking/exploration-map behavior, which this source does not implement.

Holding a filled map displays its saved region; using it opens a larger view. The player's marker follows horizontal position, snaps facing to quarter turns and changes to a clamped edge dot outside the map. Vertical travel does not re-center the image. As in the reference, markers remain visible across dimension changes; the original image and recorded dimension remain unchanged. Position rounding uses the engine’s nearest-integer rule, including negative half coordinates, and facing uses the source’s quarter-turn rule. Newly captured images place maximum Z at the top, matching the source TGA origin. Existing images without the orientation flag retain their previous row order. Item frames display the actual saved image rather than the generic map item icon.

One filled map plus one empty map produces two filled maps with identical metadata, including custom names. The recipe works through both the crafting guide and manual shapeless grid. The existing Voxey cartography workstation offers the same metadata-preserving copy transaction and fails without consuming ingredients when capacity is insufficient. Mineclonia's cartography table only registers its block and paper/wood recipe, explicitly noting that its GUI is still missing; the workstation interface is retained as a Voxey adaptation. Both empty and filled maps use the actual registered stack limit of 64, despite the source help text saying otherwise. Copies with identical metadata stack together; independently surveyed maps keep separate identities. Using the last empty map replaces it in the same hand slot. With a larger stack, the result enters the bag or drops at the player’s position when full.

Legacy filled maps had no identity or recorded pixels. The first time one is held, opened, copied through cartography or placed in a frame, it receives one survey at the current location. Subsequent operations reuse that identity. Existing item metadata is preserved. A legacy map must first be opened/migrated before manual grid copying can produce meaningful copies.

## Scheduling and persistence

Only one low-priority survey task is active at a time. Each task samples one 16×16 column; PNG composition and encoding also run on a worker. Main-thread updates collect one completed result and start the next task. The optional `TerrainGenerator.generate_column(..., map_only=true)` path returns the identical raw voxel blocks and omits render meshes and active simulation indexes. Normal world generation retains its existing default path.

Hosted games allocate identities and render snapshots on the host. A guest receives only the record metadata and PNG, with a completion update if the image is still pending. Holding, opening, copying or framing a guest map requests the existing host record. Clearing a guest cache or reconnecting retrieves that same image; unknown identities stay unavailable and never start local terrain generation. Copy transactions validate the reachable table and modify the host-owned inventory.

Changing worlds retires the active task without waiting on the main thread. Its captured data stays isolated, and its result cannot enter the new world's map registry. Pending images resume from their saved capture rather than resampling current edits. Completed images never require terrain generation after loading.

## Validation

`tools/export_maps_reference.py` runs the installed Mineclonia callbacks in Luanti and records 72 three-dimensional origins, six empty-map inventory cases, nine metadata copy cases, 392 marker cases, and a 16,384-column synthetic voxel scene. `tests/maps_reference_checks.gd` compares the real compositor with the source palette injected, separating its algorithm from the native palette/PNG adaptation. The fixture records all 633 Lua source hashes; all 33,733 source and cache-validation assertions pass. It also checks host-record identity, image dimensions, delayed pending replies and restored guest caches.

`tests/network_runner.gd` exercises host allocation, pending-image delivery, two immutable surveys across an edit, stacking copies, rejection of an unreachable table, unknown IDs, cache replacement and reconnecting. The protocol, host and guest runs all finish with zero failures. The reconnect case also checks the loading-boundary request ordering, when the map request can reach the server before the world-ready message. `tests/maps_tour.gd` captures the full and compact map views and copy/view table.

`tests/maps_checks.gd` exercises signed three-dimensional alignment, metadata validation and JSON normalization, raw/full generator equivalence, capture-time edits, pending-save completion, vertical clipping, immutable images, marker movement and dimensions, crafting and cartography copies, full-inventory rollback, legacy migration, frame textures, and actual world save/reload. It restores the lifecycle fixture's original world afterwards. Run it through `tests/lifecycle_runner.gd -- maps`; all 54 checks pass, alongside the 535-check survival regression. Full/compact map views and the copy/view table were visually reviewed, and the Linux pack exports cleanly.

The independent headless benchmark surveyed a mostly unseen ground region in 8.009 seconds on a worker; initial capture took 0.088 ms and the largest main-thread update took 0.574 ms. The resulting image was inspected and included ordinary terrain, water, trees and village geometry. These timings describe this fixture and machine, not a fixed performance guarantee.

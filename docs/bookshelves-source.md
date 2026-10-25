# Chiseled bookshelves

Reference: the supplied Mineclonia `mods/ITEMS/mcl_books/chiseled_bookshelf.lua`, `mods/CORE/mcl_util/environment.lua` and `mods/CORE/mcl_explosions/init.lua`. The native code and artwork are original; the reference runner calls the installed Lua callbacks using real node inventories and ItemStacks.

A shelf stores six individual books: ordinary, writable, written or enchanted. Placement saves one of four horizontal orientations. Only the front face accepts interaction. The selected third and row follow the source's facing-dependent coordinate calculation.

Clicking an occupied slot removes its book even when the hand holds another book. An empty or matching hand receives it; an incompatible or full hand leaves its contents unchanged and the removed book drops in front of the shelf. The backpack is not used as an alternate destination. Insertion takes one item, including in creative mode. Authors, names, text, generation and enchantments survive transfers. Written books now use the source's stack limit of sixteen, and inventory cleanup retains their authors.

Comparators read the one-based index of the last changed slot, including removals. Observers receive book-change notifications. An untouched shelf reads zero. The visible front shows the six occupied positions, and rotation moves the display and interaction face together.

Hoppers facing into a shelf insert the first eligible book into its first empty slot. A hopper beneath a shelf extracts its first occupied slot. If that first book cannot fit, extraction stops instead of skipping to a later book. All transfers retain metadata and the shelf's last-slot reading.

The recipe is six interchangeable wood planks surrounding three interchangeable wooden half slabs. Mixed species and upper slabs are accepted by the shared material-group recipe handling.

Ordinary digging drops the stored books and no bookshelf item. Applicable Silk Touch also returns one empty shelf. The source's `after_dig_node` releases its books in creative mode and during the explosion engine's `dig_node` path as well. Removal clears the station, so replacing and breaking the block cannot recover the former books again. Direct node replacement clears metadata without inventing drops. Pistons move the books, facing and last-slot value with the block.

The same state is persisted in world saves and synchronized to clients. Placement, front-face interaction and screwdriver rotation have server-side inventory and reach validation. Item pickup and retrieval preserve the original authored book.

Validation:

- `tools/export_bookshelf_reference.py` records the source hashes and exports 7,680 clicks across all 64 occupancy masks, four orientations, six positions and five hand conditions; 192 extraction cases and 320 insertion cases bring the total to 8,192.
- `tests/bookshelf_reference_checks.gd` compares quantities, metadata, slot contents and comparator readings against those real-source results.
- `tests/bookshelf_lifecycle_checks.gd` covers actual placement, observer/comparator circuits, hopper transfers, piston movement, drops and a disk save followed by a real world reload.
- `tests/network_runner.gd` covers guest placement, insertion, rotation, retrieval and harvesting. `tests/bookshelf_tour.gd` renders shelves with zero, two, four and six filled slots for visual inspection.

Rendering uses one native block ID and a saved occupancy mask rather than the source's 64 node variants. Native procedural wood and book textures represent the same occupied positions.

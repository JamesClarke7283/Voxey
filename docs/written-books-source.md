# Written books

Reference: the supplied Mineclonia `mods/ITEMS/mcl_books/init.lua`, `mods/CORE/mcl_util/misc.lua`, `mods/ITEMS/mcl_hoppers/init.lua` and `mods/ITEMS/REDSTONE/mcl_dispensers/init.lua`. `WrittenBooks` implements the source's writing, signing, copying and description rules in the native game.

A book and quill costs a book, feather and ink sac. Draft edits save into that book's inventory slot. Signing records the player's name, Unix date and generation zero, uses “Nameless Book” for an empty title, and makes the contents read-only. The source limits text to 12,800 and titles to 64 using its UTF-8 and escaped-character accounting; these are not simple character-count limits for non-ASCII text.

One written book and one to eight writable books produce one to eight copies. The original stack stays intact, including all sixteen originals if the input slot contains a full stack. Copies preserve the original title, text, author, date and name while advancing generation to one or two. A copy of a copy cannot be copied again. Negative legacy generation values advance to one, matching the installed source. Copies only stack with books whose metadata is identical.

The recipe guide supports all eight copy recipes. Hand crafting supports recipes that fit its four cells; larger recipes need the crafting table. Manual crafting, cursor output, inventory output and direct recipe crafting preserve the original and roll back when output cannot fit. The old nested copy-metadata format is flattened when loaded, recovering its title, contents, author and date.

The native editor presents one scrolling text field, rather than a Luanti formspec. The reader shows the title, author and copy generation with the same readable text contrast as the editor. Tooltips use the source's original/copy/tattered-book descriptions. Source translator control sequences for the generated default title are compared as their displayed English text.

## Verification

- `tools/export_written_books.py` runs the installed Luanti craft prediction, craft completion, form and plain-shelf callbacks. It extracts private text-cap and transfer functions verbatim and records the four source-file hashes in `assets/data/written_books_reference.json`.
- `tests/written_books_reference_checks.gd` compares 1,296 copy cases, 28 UTF-8 boundary cases, six signatures and 21 plain-shelf cases, including all input positions, full original stacks, invalid generations and blank/multilingual titles.
- `tests/written_books_checks.gd` exercises the actual editor and Sign button, all eight recipe-guide layouts, hand crafting, output rollback, original retention, legacy migration and cursor metadata separation.
- `tests/network_runner.gd` copies a book carried by a guest, reconnects, and checks the saved original/copy metadata. `tests/written_books_tour.gd` renders draft, signed and copied books at two window sizes.

## Plain bookshelves

Plain shelves have 27 stack slots. The inventory screen accepts ordinary books, writable books, written books and enchanted books; other items cannot be inserted or withdrawn by hand. The same validation applies to shift-clicking, swapping and host-authoritative multiplayer actions. Existing non-book contents from older saves are preserved and can be recovered by breaking the shelf.

The installed source assigns plain shelves container group one. Its hopper push path only accepts groups two through six, and its automatic extraction path has no source inventory list for group one. Consequently, hoppers and droppers leave plain-shelf contents unchanged. This differs from the six-slot chiseled shelf, which explicitly implements hopper callbacks. Plain shelves still provide inventory fullness to comparators.

The 21 source cases cover seven item types and three stack sizes, checking manual put/take, hopper push/pull and dropper behavior. `tests/plain_bookshelf_checks.gd` compares these results in the native world and exercises the actual inventory controls and legacy-content recovery. Multiplayer checks cover rejection, authored-book storage and retrieval. The chiseled shelf's six-slot behavior is documented in [bookshelves](bookshelves-source.md).

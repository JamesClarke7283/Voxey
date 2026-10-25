# Banners

Reference: `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_banners/{init,items,patterncraft}.lua` and `mods/ITEMS/mcl_loom/init.lua`. This is original GDScript and original procedural artwork. `assets/data/banner_reference.json` records hashes of the exact source files exercised by `tools/export_banner_reference.py`.

The installed reference permits **12 craftable layers**, with six listed in tooltips and an additional-layer count. Stored designs may have more layers; those cannot be copied or extended. New banner stacks are limited to sixteen; older overfull saved stacks are retained to avoid item loss. This differs from the previous native six-layer approximation.

The crafting table supports all 32 exact, absolute dye layouts. All dyes must share a colour; the banner may occupy any unused cell. The ten special designs use one dye, one banner and their source signature ingredient. Thing and Skull use their pattern items. Creeper, Flower, Bricks and Bordure Indented use their raw ingredients. Globe, Piglin, Flow and Guster use their pattern items.

Only six pattern items are craftable from paper: Thing requires an **enchanted** golden apple, followed by Skull, Creeper, Flower, Bricks and Bordure Indented. Flow and Guster already come from the native trial loot tables. Globe comes from the master cartographer and Piglin from the native legacy-bulwark loot table. Earlier reward IDs migrate to the working loom items. Paper cannot duplicate an existing pattern item.

Copying requires two banners with the same base colour, exactly one decorated and one plain. The output inherits the source's ordered design and name. The decorated source remains in the grid; one plain banner is consumed. Two decorated banners cannot be combined.

The visual loom selects a carried banner and dye, shows previews of all 42 designs and consumes one banner and one dye. Special designs additionally consume **one pattern item**, matching this installation's `mcl_loom` callback. A full inventory leaves every input untouched. The remaining banner stack retains its original design.

Placement tries a floor banner first, then a wall attachment for horizontal clicks. Floor rotation has sixteen steps; walls record the supporting face. Designs and names appear on the placed cloth, item icons, the held item, dropped items and framed banners. Digging, explosions and support removal return the exact stored item once. Creative digging avoids duplicate items. Banner stations migrate older direct-layer records, persist in world saves and synchronize to multiplayer guests. Host-authoritative placement and screwdriver rotation preserve the guest's inventory and metadata. Banners are immovable by pistons.

Using a banner on a water cauldron removes its latest layer. The source also spends a water portion when the banner is already plain; native washing now does the same.

Validation: 1,708 real Luanti craft results compare the pattern definitions, layout placement, metadata, copying, retained inputs and layer boundaries. Live lifecycle tests cover placement on each wall face, standing orientation, support loss, harvested items, save snapshots, selection boxes and loom transactions. The two-peer network test covers guest placement, rotation, harvesting and reconnect persistence. `tests/banner_tour.gd` renders the visual loom at desktop and compact window sizes.

Remaining differences: artwork and geometry are native procedural representations rather than Mineclonia's textures and animated B3D models. [Shield decoration](shields-source.md), Globe trades and the legacy Piglin loot route are implemented. Raid-specific ominous-banner semantics and the newer `mcl_levelgen` bastion remain open.

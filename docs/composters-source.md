# Composters

Voxey follows the supplied Mineclonia 0.123.1 `mods/ITEMS/mcl_composters/init.lua` for the probability roll, seven fill levels, one second maturation, ready state, harvesting, comparator output and vertical hopper input/output. Item chances come from the source modules registering each food or plant (`mcl_farming`, `mcl_core`, `mcl_trees`, `mcl_ocean`, `mcl_flowers`, `mcl_mushrooms`, `mcl_cocoas`, `mcl_nether`). The implementation is original GDScript using the source as a behavioral reference.

Craft a composter from seven oak slabs in a U. Use a plant or food on it: seeds and kelp have a 30% chance to add a layer, cactus and vines 50%, wheat and apples 65%, bread 85%, and cake or pumpkin pie 100%. Every accepted item is consumed even when it adds no layer. At seven layers wait one active second, then use the composter to release one bone meal pickup. Creative insertion keeps the held ingredient.

A downward hopper above can supply ingredients; a hopper below can collect the bone meal. A full output hopper leaves the ready compost untouched. Comparators read 0–8 for empty through ready. Fill state and remaining maturation time persist with station data. Unloaded chunks and paused worlds do not mature. Breaking the composter loses its compost and returns the empty block.

`tests/composter_checks.gd` covers probability boundaries, rejected inputs, maturation/save round trip, crafting, comparator signal, hopper transactions and manual interaction. Remaining differences: no farmer-villager composting AI, oak-only slab crafting, and full-cube collision around the hollow visual model.

# Deeper worlds and item dropping

## Drop controls

- **Q in the world:** throws one item from your selected hotbar slot. One keypress drops one item; holding the key does not empty the stack.
- **Q in inventory:** drops one item from the carried stack, or the slot under the mouse when nothing is carried. Q still types normally in recipe search.
- **Drag outside + Escape:** press an inventory item to carry it, move outside the inventory panel, then press Escape. The entire carried stack drops into the world and the inventory closes.
- **Click outside:** left-click drops the carried stack; right-click drops one item.
- **Escape inside:** closes the inventory and returns the carried stack and unused crafting ingredients to your bag. Overflow becomes a ground pickup.

Manual drops travel forward and cannot be picked up again for 1.5 active seconds. This avoids immediately pulling a thrown item back into your inventory. Books, enchantments, durability, and stack counts stay attached to drops. Touch dropping uses the same behavior.

## World depth

The Overworld now extends to **Y −128**, matching [Mineclonia’s documented lower boundary](https://mineclonia.codeberg.page/wiki/intros/voxelibre-guide.html). Voxey keeps its current Overworld ceiling at Y 63 and its existing surface coordinates; this change matches depth, not Mineclonia's much higher build ceiling. The Nether has also expanded from 64 to 128 blocks tall, with a ceiling at Y 127.

Existing worlds gain terrain under their former generated bedrock at Y 0. Surface terrain, player builds, inventory, and saved node edits stay at their existing coordinates. Generated bedrock at zero is replaced by mineable material; the protected new floor is at −128. Deep terrain is regenerated deterministically from the world seed, and modifications, stations, items, and player positions below zero are saved normally.

## Underground additions

| Addition | Behavior |
| --- | --- |
| Deepslate | A gradual transition begins near Y −24, becoming deepslate below −64. It takes longer to mine than stone and drops cobbled deepslate. |
| Caverns | Larger caves and winding tunnels extend through the negative levels. Lava occupies the deepest cave floors at or below Y −112. |
| Deep ores | Deepslate variants of diamond, iron, gold, lapis, coal, and copper retain the regular ore's required tool and drops. Diamonds occur below −48; coal and copper become less common at depth. |
| Building blocks | Four cobbled deepslate make four polished deepslate; four polished deepslate make four deepslate bricks. Cobbled deepslate can also be smelted back to deepslate. |
| Cave mobs | Underground enemies can spawn during the day, using nearby dry floors at the player's depth. Torchlight suppresses their spawning. |
| Cave lighting | Ambient light fades underground so torches matter. Saved torch lights are restored after dimension travel as well as loading. |
| Lava furnace fuel | A lava bucket supplies 1,000 active furnace seconds and leaves an empty bucket in the fuel slot. Deep iron, gold, and copper ores can be smelted directly. |
| Furnace input fixes | The interface accepts the same fuels and ingredients as the furnace simulation, including charcoal, coal blocks, clay, and deep ores. |

Run `./tests/run_tests.sh` for the complete gameplay suite. `tests/depth_checks.gd` covers this update. `tests/depth_tour.gd` additionally exercises the actual mouse-press → drag outside → Escape flow in a rendered window and captures a naturally generated deep cavern.

The latest source bounds and ore comparison are in [the world-generation notes](mineclonia-world-source.md). The Overworld building ceiling is now Y 30927; unoccupied upper space uses implicit air.

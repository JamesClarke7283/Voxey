# Rails and minecarts

Voxey follows the supplied Mineclonia `mods/ENTITIES/mcl_minecarts/{init,functions,rails}.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Rails

Nine items are registered: seven rail nodes (`Rail`, `Powered rail`, `Powered rail (on)`, `Detector rail`, `Detector rail (on)`, `Activator rail`, `Activator rail (on)`) and five carts (`Minecart`, and the chest, furnace, hopper and TNT variants). Rails stack to 64 and carts stack singly. All seven rails share the source hardness of 0.7, are not solid, drop by hand and break into their unpowered item.

### Shape resolution

Luanti gives rails the engine `raillike` drawtype and resolves their shape from neighbours every time it meshes. Voxey has no such drawtype, so the engine's own tables are transcribed and evaluated in GDScript. From `src/mapnode.cpp`:

- `rail_direction[4] = {(0,0,1), (0,0,-1), (-1,0,0), (1,0,0)}` — the bit order of the 4-bit neighbour code is therefore +Z, -Z, -X, +X.
- `rail_slope_angle[4] = {0, 180, 90, -90}`.
- `rail_kinds[16]` maps each neighbour code to a shape (`straight`, `curved`, `junction`, `cross`) and a turn angle.

A direction counts when the same rail sits at `dir`, `dir+(0,1,0)` or `dir+(0,-1,0)`. When any `dir+(0,1,0)` is a rail the node is **sloped**: the engine always draws the straight texture and tilts the mesh by `rail_slope_angle[dir]`, and it lets the **last** matching direction set the angle. Voxey reproduces all three behaviours, including that last-one-wins ordering.

Rails carry **no** stored metadata in the source, so none is stored here either: the shape is derived from the world each time it is needed. The chunk mesher resolves the shape from its own padded 18³ array, so rails render through the same neighbour data as every other block.

### Placement and support

A rail is placed onto a face like any block, but only when it has support: a solid block below, or the rail below it — the latter is what makes the upper end of a slope legal. Removing that support breaks the rail and drops its item. Placement stores the plain rail node; no facing or shape is written.

### Redstone

`propagate_golden_rail_power` is reproduced exactly. A directly powered golden rail stores level 8; power then travels one level per golden rail over 12 directions (4 lateral, 4 diagonal-up, 4 diagonal-down), and a diagonal step is skipped when its obstructing node is opaque. Only golden rails carry power.

- **Powered rail** — on while its input is non-zero, and emits its stored level in every direction. A rail that has just turned on pushes every stationary cart on it, as the source's `push_minecart` does.
- **Detector rail** — plain on/off. A cart entering the cell swaps it on; the cell the cart leaves swaps back off. An on detector rail strongly powers the block below it only.
- **Activator rail** — plain on/off, and while on it activates every cart standing on it.

The three pairs are registered as one family each so a state swap keeps the block's circuit state.

## Carts

Source carts are `physical = false` with all movement in Lua, so this is the source formula rather than engine physics. One step is:

- Direction comes from `get_rail_direction`: forward, then left, then right, then backwards, where a probe tries the same horizontal cell, then one up, then one down. A driver's left/right keys steer at a junction and latch a switch.
- The acceleration is `dir.y * -1.8 - 0.4`, a powered rail adds +4 or an unpowered golden rail −3 (each replacing the friction term), and furnace fuel adds 0.6.
- Turning transfers the speed across axes; velocity that reverses the last direction stops the cart outright; horizontal speeds under 0.9 snap to zero.
- Each axis is clamped to 10.

A cart is spawned at the rail's own node position, so it rounds onto that rail. Carts are never dropped for leaving their rail — the source comments on this explicitly — so a cart off its rail simply rolls to a stop. Carts pass through players and are only blocked by terrain.

| Variant | Storage | Interaction |
|---|---|---|
| Minecart | — | Right-click to ride; W/S push it |
| Chest cart | 27 slots | Right-click opens the cargo |
| Furnace cart | — | Fuel with coal or charcoal for 180 seconds each |
| Hopper cart | 5 slots | Collects one dropped item per step within 1.25 nodes |
| TNT cart | — | Ignited by flint and steel for 4 seconds, or by an activator rail for 2 |

Sneak-use picks a cart up, returning the cart and any cargo. A hopper or chest cart's cargo survives saves, unloading and reloading under the same cart identity.

## Persistence

Carts are owned by a dedicated service, mirroring boats. Records live in `adventure_state.carts`, keyed by a stable cart id, and deliberately not in `stations`, whose values are all typed station dictionaries. A cart outside streaming range leaves the live index while its record stays, and is woken — with its cargo — when its column reloads.

## Structure placement

Mine shaft generation is documented separately in [mineshaft-source.md](mineshaft-source.md).

## Recorded source gaps

These are not repaired, because the reference has no behaviour to port:

- Carts have no water or lava handling at all in the checkout, so there is no buoyancy to port.
- Carts do not push each other.
- Command-block carts are registered inert with no recipe, so none is added.
- Structure placement is covered separately in [the mineshaft notes](mineshaft-source.md). Mineclonia ships two mineshaft generators and only one runs by default; that document records which and why.

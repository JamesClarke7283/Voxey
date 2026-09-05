# VoxeyAPI Reference

Every mod receives one `VoxeyAPI` instance in `_api_ready(api)`. All methods
are safe to call from hooks and startup code. Calls that touch the world
(`set_node`, `teleport_player`) are main-thread actions executed by the game.

`VoxeyAPI` is a global class in `scripts/voxey_api.gd`.

---

## Content registration

### `register_node(node_name: String, properties: Dictionary = {}) -> int`

Register a new voxel node type. Returns the numeric node id, or `0` if the
name is taken or the custom-node limit (22) is reached.

| Property | Type | Default | Meaning |
| --- | --- | --- | --- |
| `color` | `"#rrggbb"` | `"#ffffff"` | Node color; generates a noise-textured atlas tile |
| `transparent` | `bool` | `false` | Non-solid: player and mobs pass through; light not blocked |
| `hardness` | `float` | `1.0` | Seconds to break bare-handed |
| `unobtainable` | `bool` | `false` | Hidden from the creative catalog (still `/give`-able) |

```gdscript
var glowstone: int = api.register_node("Glowstone", {"color": "#e8d170", "hardness": 0.8})
```

### `register_item(item_name: String, properties: Dictionary = {}) -> int`

Register an inventory item (not placeable). Returns the id, or `0` on failure
(name taken, or 40-item limit reached).

| Property | Type | Default | Meaning |
| --- | --- | --- | --- |
| `color` | `"#rrggbb"` | `"#ffffff"` | Icon and held-item color |
| `food` | `int` | `0` | Hunger restored when eaten (0–20) |

```gdscript
var cider: int = api.register_item("Cider", {"color": "#b45a1e", "food": 6})
```

---

## World

### `get_node(pos: Vector3i) -> int`
The node id at a world position. Unloaded chunks return `Nodes.AIR`.

### `set_node(pos: Vector3i, id: int) -> bool`
Change a node and settle anything above it (sand falls, etc.). Returns
`false` when the position is out of range (y 1–63) or the map block is not
loaded.

```gdscript
func _on_node_placed(pos: Vector3i, id: int) -> void:
    if id == Nodes.WATER and api.get_node(pos + Vector3i.UP) == Nodes.AIR:
        pass # water-adjacent logic
```

### `find_node(origin: Vector3, wanted: int, reach: float = 24.0) -> Vector3i`
Scan loaded nodes near `origin` for the first match. Returns
`Vector3i(999999, 999999, 999999)` when nothing matches in range.

### `player_position() -> Vector3`
The player's feet position.

### `teleport_player(destination: Vector3) -> void`
Teleport the player. Distant destinations stream in first, then arrive.

---

## Entities

### `spawn_drop(pos: Vector3, id: int, amount: int = 1) -> void`
Spawn an item pickup.

### `spawn_creature(kind: String, pos: Vector3) -> Creature`
Spawn a creature by kind (`sheep`, `cow`, `pig`, `chicken`, `zombie`,
`skeleton`, `spider`, `creeper`). Returns `null` for unknown kinds. The
returned node is read-only through the API; do not store it beyond the hook.

---

## Inventory

### `count_item(id: int) -> int`
How many of an item the player carries.

### `give_item(id: int, amount: int = 1) -> int`
Give items; the overflow becomes a world drop. Returns how many fit in the bag.

```gdscript
if api.count_item(Nodes.LOG) >= 4:
    api.give_item(Nodes.PLANKS, 4)
```

### `take_item(id: int, amount: int = 1) -> bool`
Remove items from the bag. Returns `true` only when everything was taken.

---

## Presentation

### `toast(message: String) -> void`
HUD toast, prefixed with the mod name: `[my_mod] message`.

### `sound(kind: String) -> void`
Play a synthesized sound globally. Kinds: `step`, `dig`, `break`, `place`,
`pickup`, `craft`, `hurt`, `eat`, `click`, `equip`, `thud`.

### `log_line(message: String) -> void`
Append a line to the in-game console, attributed to the mod.

---

## Hook emission (advanced)

Hooks are fired by the engine; mods normally only *subscribe*. These emitters
exist for mods that wrap the API further and are listed for completeness:
`emit_player_hurt`, `emit_node_broken`, `emit_node_placed`,
`emit_player_died`.

---

## Static registries

`Nodes` (global class) exposes the content registry used by the API:

- `Nodes.custom_nodes` — registered node ids → property dictionaries
- `Nodes.custom_items` — registered item ids → property dictionaries
- `Nodes.custom_tiles` — node id → atlas tile index (42+)
- `Nodes.title(id)`, `Nodes.color(id)`, `Nodes.solid(id)`, `Nodes.food(id)`,
  `Nodes.hardness(id)`, `Nodes.lookup(name)` all accept mod ids transparently.

`VoxeyMods` (global class, `scripts/voxey_mods.gd`) is the loader:

- `VoxeyMods.loaded` — entries: `{name, version, path, api, instance}` or `{name, error}`
- `VoxeyMods.is_loaded(name) -> bool`
- `VoxeyMods.connect_hook(hook, callable) -> bool`
- `VoxeyMods.mod_names() -> Array`
- `VoxeyMods.errors() -> Array`
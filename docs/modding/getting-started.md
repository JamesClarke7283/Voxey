# Voxey Modding — Getting Started

Voxey has a first-class modding API. Mods are GDScript packages that receive an
`api` object at startup and can register new nodes/items, query and change the
world, manipulate the player's inventory, and subscribe to gameplay hooks.

Mods are **sandboxed**: they only ever see the documented API surface. They
cannot touch the file system, spawn scene nodes directly, or reach into engine
internals. A broken mod logs an error and is skipped — it never blocks the
game from starting.

## 1. Where mods live

Voxey scans two folders at startup:

| Location | Purpose |
| --- | --- |
| `res://mods/<mod_name>/` | Mods shipped inside the game project |
| `~/.voxey/mods/<mod_name>/` | User-installed mods (per machine) |

Each mod is a folder containing at least:

```
mods/my_mod/
├── mod.json     # manifest
└── main.gd      # entry script (any name; referenced by the manifest)
```

The manifest (`mod.json`):

```json
{
    "name": "my_mod",
    "version": "1.0.0",
    "description": "Adds copper lanterns.",
    "entry": "main.gd"
}
```

## 2. The entry script

The entry script must be a `RefCounted` (or any Object) with an
`_api_ready(api)` method. Voxey creates one instance per mod and calls
`_api_ready` once at startup:

```gdscript
extends RefCounted

var api: VoxeyAPI

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    var lantern: int = api.register_node("Copper lantern", {"color": "#c98a3d"})
    api.connect_hook("on_node_placed", _on_node_placed)
    api.toast("my_mod loaded")

func _on_node_placed(pos: Vector3i, id: int) -> void:
    if id == lantern:
        api.sound("place")
```

`VoxeyAPI` is a global class — no preload needed. The shipped
`mods/survival_tweaks/` folder is a complete working example.

## 3. Registering content

### Nodes (voxels you can place)

```gdscript
var id: int = api.register_node("Copper lantern", {
    "color": "#c98a3d",     # tile color; a noise-textured atlas tile is generated
    "hardness": 1.2,        # seconds to break by hand (default 1.0)
    "transparent": false,   # true = non-solid (player walks through)
    "unobtainable": false   # true = hidden from the creative catalog
})
```

Returns the node id, or `0` when the name is already taken or the custom-node
limit (22 per game session) is reached. Registered nodes appear in the
creative catalog and the console (`/give copper_lantern`), can be mined with
their configured hardness, and persist in world saves like any other node.

### Items (inventory-only)

```gdscript
var id: int = api.register_item("Sweet berries", {
    "color": "#b83a4a",
    "food": 3               # hunger restored on right-click, 0-20
})
```

Returns the item id, or `0` on failure (name taken, or the 40-item limit
reached). Items with `food > 0` can be eaten with right-click. Give them with
`/give sweet_berries`.

> **Limits.** Node ids live at 200+ and item ids at 120+. Registration happens
> once at startup in mod-load order, so ids are stable across saves. Avoid
> registering content based on runtime state; ids must mean the same thing
> every session.

## 4. Hooks

Subscribe with `api.connect_hook(hook_name, callable)`. Each hook accepts up
to 8 subscribers and fires at most **5 times per second** (flood guard):

| Hook | Arguments | Fired when |
| --- | --- | --- |
| `on_node_broken` | `pos: Vector3i, id: int` | a node is mined |
| `on_node_placed` | `pos: Vector3i, id: int` | a node is placed |
| `on_player_hurt` | `amount: float, source: String` | the player takes damage (post-armor) |
| `on_player_died` | *(none)* | the player dies |
| `on_creature_killed` | `kind: String, pos: Vector3` | any creature dies |
| `on_world_entered` | `world_name: String, seed: int` | a world finishes loading |

## 5. Testing your mod

Run the game and check the console/log output for `Voxey mod loaded: my_mod`
or `Voxey mod error: ...` lines. Use `api.log_line(...)` to trace hook firing
in the console (`/` or `T` in game).

## Next

- [API reference](api.md) — every method with signatures and examples
- [Hooks](hooks.md) — hook contracts and recipes
- [Examples](examples.md) — complete mods, from toast to dungeon
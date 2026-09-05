# Mod Examples

Complete, copy-pasteable mods. Each goes in `mods/<folder>/` with the
manifest shown first.

---

## 1. Hello, mod (toast + log)

`mods/hello/mod.json`

```json
{
    "name": "hello",
    "version": "1.0.0",
    "entry": "main.gd"
}
```

`mods/hello/main.gd`

```gdscript
extends RefCounted

var api: VoxeyAPI

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    api.connect_hook("on_world_entered", _hello)

func _hello(world_name: String, seed: int) -> void:
    api.toast("Welcome to %s (seed %d), traveler." % [world_name, seed])
    api.log_line("hello mod says hi.")
```

Demonstrates: manifest, `_api_ready`, hooks, `toast`, `log_line`.

---

## 2. Copper lantern (custom node + reaction)

`mods/lantern/mod.json`

```json
{
    "name": "lantern",
    "version": "1.0.0",
    "description": "Adds a copper lantern node that reacts when placed.",
    "entry": "main.gd"
}
```

`mods/lantern/main.gd`

```gdscript
extends RefCounted

var api: VoxeyAPI
var lantern: int = 0

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    lantern = api.register_node("Copper lantern", {
        "color": "#c98a3d",
        "hardness": 1.2
    })
    api.connect_hook("on_node_placed", _on_placed)

func _on_placed(pos: Vector3i, id: int) -> void:
    if id == lantern:
        api.sound("place")
        api.log_line("A copper lantern glows at %s." % [pos])
```

Demonstrates: `register_node`, per-placement reaction, sound.

---

## 3. Ration pack (custom food + starter kit)

`mods/rations/mod.json`

```json
{
    "name": "rations",
    "version": "1.0.0",
    "description": "Hard mode: hunger bites and only rations help.",
    "entry": "main.gd"
}
```

`mods/rations/main.gd`

```gdscript
extends RefCounted

var api: VoxeyAPI
var ration: int = 0

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    ration = api.register_item("Field ration", {"color": "#7a8f4c", "food": 2})
    api.connect_hook("on_world_entered", _starter)

func _starter(_name: String, _seed: int) -> void:
    api.give_item(ration, 2)
    api.toast("You carry two field rations. Make them last.")
```

Demonstrates: `register_item` with `food`, `give_item`, inventory effects.

---

## 4. Waypoint beacon (world query + teleport)

A watchful beacon: when the player stands near their placed beacon, offer a
teleport home. Shows `get_node`, `find_node`, `player_position`, and
`teleport_player` through a custom console command-like hook flow.

```gdscript
extends RefCounted

var api: VoxeyAPI
var beacon: int = 0
var beacons: Array = []

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    beacon = api.register_node("Waypoint beacon", {"color": "#63d5c5", "hardness": 2.5})
    api.connect_hook("on_node_placed", _on_placed)
    api.connect_hook("on_node_broken", _on_broken)

func _on_placed(pos: Vector3i, id: int) -> void:
    if id == beacon:
        beacons.append(pos)
        api.toast("Beacon #%d anchored." % [beacons.size()])

func _on_broken(pos: Vector3i, id: int) -> void:
    if id == beacon:
        beacons.erase(pos)

# Call from any hook (e.g. on_player_hurt) to retreat to the oldest beacon.
func retreat() -> void:
    if beacons.is_empty(): return
    var home: Vector3i = beacons[0]
    api.teleport_player(Vector3(home) + Vector3.UP)
```

Demonstrates: world queries, id filtering, teleport.

---

## 5. Hunt quest (creature kills → reward)

```gdscript
extends RefCounted

var api: VoxeyAPI
var kills: Dictionary = {}
const TARGET = 5

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    api.connect_hook("on_creature_killed", _on_kill)

func _on_kill(kind: String, _pos: Vector3) -> void:
    if not kind in ["zombie", "skeleton", "spider", "creeper"]: return
    kills[kind] = int(kills.get(kind, 0)) + 1
    if int(kills[kind]) == TARGET:
        api.toast("%d %ss slain — bounty paid." % [TARGET, kind])
        api.give_item(Nodes.DIAMOND, 1)
```

Demonstrates: per-kind counting, conditional rewards with `give_item`.

---

## 6. Testing checklist

1. Run the game; the log prints `Voxey mod loaded: <name>` or a specific error.
2. In game, open the console (`/`) — `api.log_line` output appears there.
3. `mods/survival_tweaks` ships as a live reference; compare its folder
   against yours when something misbehaves.
4. Remove a mod folder and re-run: the game starts cleanly without it.
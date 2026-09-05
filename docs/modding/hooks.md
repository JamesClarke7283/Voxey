# Hooks Reference

Hooks let mods react to gameplay without patching game scripts. Subscribe in
`_api_ready` with:

```gdscript
api.connect_hook("on_node_placed", _on_node_placed)
```

## Contracts

Every hook receives typed arguments and runs on the main thread, once per
event. Handler failures print a script error but do not break the game.

### `on_node_broken(pos: Vector3i, id: int)`
A node was mined and removed. Fired after the drop/particles, so the world
already has `AIR` at `pos`.

### `on_node_placed(pos: Vector3i, id: int)`
A node was placed by the player. Fired after settling — if the placed node
was sand over air, it has already fallen (and you will also see
`on_node_broken` for its original spot… actually no: settling moves the node
via entities; you get exactly one `on_node_placed` per player placement).

### `on_player_hurt(amount: float, source: String)`
The player took damage. `amount` is the **post-armor** damage that landed.
`source` is empty for generic damage (falling, drowning, starving) or the
rounded attacker position for knockback sources. Fires at most once per
damage-cooldown window (0.65 s), so burst damage is throttled.

### `on_player_died()`
The player died. The death screen is already up; drops exist.

### `on_creature_killed(kind: String, pos: Vector3)`
Any creature died (player kill, environment, explosion). `kind` is one of the
`Creature.KINDS` keys.

### `on_world_entered(world_name: String, seed: int)`
A world finished loading and play resumed. Fires once per session start.

## Guard rails

- **Subscriber cap:** 8 callables per hook; `connect_hook` returns `false`
  beyond that.
- **Flood guard:** each hook fires at most **5 times per second**. Sub-second
  event storms (explosions breaking hundreds of nodes) are silently throttled.
- **Unknown hooks:** `connect_hook` returns `false` for names outside the
  registry — typos fail fast at load time.

## Recipes

**Block-break reward** — pay out experience for mined ore:

```gdscript
func _api_ready(a: VoxeyAPI) -> void:
    api = a
    api.connect_hook("on_node_broken", _on_broken)

func _on_broken(pos: Vector3i, id: int) -> void:
    if id == Nodes.DIAMOND_ORE:
        api.toast("Diamond! The earth glitters at %s." % [pos])
        api.sound("pickup")
```

**Low-health warning** — heartbeat sound when badly hurt:

```gdscript
func _on_player_hurt(amount: float, _source: String) -> void:
    if api.player_health_low():   # example; check health via hooks/logic
        api.sound("hurt")
```

(Reading health directly is not exposed; track it from `on_player_hurt`
amounts, or use a `/heal`-watching command if needed.)

**Creature census** — count mob deaths to drive achievements:

```gdscript
var slain: int = 0

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    api.connect_hook("on_creature_killed", _on_kill)

func _on_kill(kind: String, _pos: Vector3) -> void:
    slain += 1
    if slain == 10: api.toast("Ten beasts down.")
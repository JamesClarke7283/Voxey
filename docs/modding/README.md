# Voxey Modding

Voxey ships a first-class, sandboxed modding API. Mods are GDScript packages
in `mods/<name>/` that receive an `api: VoxeyAPI` object at startup and can:

- register new **nodes** (placeable voxels) and **items** (food/decor),
- query and modify the **world**,
- manipulate the player's **inventory**,
- react to gameplay through **hooks**,
- show **toasts**, play **sounds**, and write to the in-game console.

Mods never touch the file system or the scene tree; a broken mod logs an
error and is skipped — the game always starts.

## Documents

| File | Contents |
| --- | --- |
| [getting-started.md](getting-started.md) | Folder layout, manifest, entry script, registration, limits |
| [api.md](api.md) | Full `VoxeyAPI` method reference |
| [hooks.md](hooks.md) | Hook contracts, guard rails, recipes |
| [examples.md](examples.md) | Six complete mods, from toast to bounty hunter |

## Quick start

```
mods/my_mod/
├── mod.json   → { "name": "my_mod", "version": "1.0.0", "entry": "main.gd" }
└── main.gd    → extends RefCounted, defines _api_ready(api)
```

```gdscript
extends RefCounted

var api: VoxeyAPI

func _api_ready(a: VoxeyAPI) -> void:
    api = a
    api.register_node("Copper lantern", {"color": "#c98a3d"})
    api.toast("my_mod loaded")
```

`mods/survival_tweaks/` ships with the game as a working reference.
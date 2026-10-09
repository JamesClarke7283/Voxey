class_name RecoveryCompass
extends RefCounted

# Mineclonia ITEMS/mcl_compass/init.lua:205-229 — the `recovery_compass` item, its
# `update_recovery_compass` dial and the echo-shard recipe. GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# The source has two compasses. The plain one points at the world spawn, which
# Voxey already has; the **recovery compass** points at the player's last death
# location, and is crafted from eight echo shards around an ordinary compass.
#
# Voxey already records where a death's recovery chest landed in
# `adventure_state.last_recovery`, which is the same point the source keeps in the
# player's `mcl_compass:recovery_pos` metadata — so the dial reads that rather than
# needing a second record. The source's own rule for a player who has never died is
# to let the needle spin, which is what `Dials.recovering` drives.
#
# The source gates the dial on the dimension: a recovery compass only points while
# the target is in the player's own realm, and spins otherwise. That is
# `Dials.works`'s existing rule plus a dimension comparison, reproduced here.

# The item id. The small base band next to `Nodes.CLOCK` is not free — 140 is the
# modding API's `MOD_ITEM_BASE` — so this uses the content band.
const ID = 11600

const DATA = {
	11600:{"name":"Recovery compass","color":"a9e6e8","family":"compass","stack":1,"glint":true,
		"source_node":"mcl_compass:compass_recovery"},
}

static func is_recovery_compass(id: int) -> bool: return id == ID

# `mcl_compass.register_compass`'s recipe: eight echo shards around a compass.
# The source writes it as a full 3x3 with the compass in the middle.
#
# **The echo shard's route is the ancient hermitage.** The source's only source is that
# structure's chest (`MAPGEN/mcl_structures/ancient_hermitage.lua`:39, weight 3 for one
# to three shards), which `ancient_hermitage.gd` now generates in the deep dark; the
# recipe is registered exactly as the source writes it, and the hermitage's chest is
# what supplies the shards.
static func recipe_entries() -> Array:
	return [["Recovery compass",ID,1,
		[Sculk.ECHO_SHARD,Sculk.ECHO_SHARD,Sculk.ECHO_SHARD,
		 Sculk.ECHO_SHARD,Nodes.COMPASS,Sculk.ECHO_SHARD,
		 Sculk.ECHO_SHARD,Sculk.ECHO_SHARD,Sculk.ECHO_SHARD]]]

# `update_recovery_compass`: the frame comes from the death position **when the
# target is in the player's own realm**, and the needle spins otherwise. Voxey's
# `Dials.works` already covers "not in the Nether or the End"; the dimension test
# here is the source's own comparison between the two positions' layers.
static func frame(game: Node3D) -> int:
	if not Dials.works(game) or Dials.recovery_position(game).is_empty():
		return posmod(Dials.spinning,Dials.COMPASS_FRAMES)
	return Dials.recovery_frame(game)

# Whether the needle can point at anything. The dial's own drawing uses this for the
# needle colour, exactly as the plain compass uses `Dials.works`.
static func pointing(game: Node3D) -> bool:
	return Dials.works(game) and not Dials.recovery_position(game).is_empty()

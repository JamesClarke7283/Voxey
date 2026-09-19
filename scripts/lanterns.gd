class_name Lanterns
extends RefCounted

# Mineclonia ITEMS/mcl_lanterns/init.lua and register.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference; all art is original
# procedural code.
#
# Two things were missing from Voxey's lantern family, and a third from the copper
# chain's own gap list:
#
#   * **Soul lanterns** — a lantern lit by a soul torch, dimmer than an iron one
#     (light 10 against the full 14) and in the source's own `soul_firelike`
#     group. They are the light source for a soul-themed build.
#   * **Chains** — a thin metal column. The source registers a chain as a node you
#     can **hang things from**: placing a lantern or another block against a chain
#     attaches it below, which is what makes a hanging lantern possible.
#
# The copper family's own notes record that its **lanterns and chains** were absent
# because they belong to this module rather than to `mcl_copper`. This batch closes
# that gap for the iron and soul variants; the copper-coloured ones need the
# oxidation chains re-registered for lantern nodes and are recorded as still open.

# A soul lantern's light, from the source's `light_level = 10`. The plain lantern
# is already registered with the engine's maximum.
const SOUL_LIGHT = 10
# The source's `soul_firelike` group, which soul fire and soul campfires also carry.
const SOUL_GROUP = true
# A chain is a sixteenth of a block wide, which is the source's collision box.
const CHAIN_WIDTH = 0.0625

# --- soul lantern ------------------------------------------------------------

static func is_soul_lantern(id: int) -> bool: return id == VillageContent.SOUL_LANTERN

# The item a lantern is made from, which decides whether it is a soul lantern.
static func from_torch(id: int) -> int:
	return VillageContent.SOUL_LANTERN if id == Nodes.SOUL_TORCH else VillageContent.LANTERN

# --- chains ------------------------------------------------------------------

static func is_chain(id: int) -> bool: return id == VillageContent.CHAIN

# Whether a block can hang from a chain. The source lets a chain hold another
# chain, a lantern, or any block that attaches to a base, which is what makes a
# hanging lantern reachable.
static func hangs_from_chain(id: int) -> bool:
	if id == VillageContent.CHAIN: return true
	if id in [VillageContent.LANTERN,VillageContent.SOUL_LANTERN]: return true
	# The source's own condition is the `attaches_to_base` group, which covers
	# lanterns and a few decorative blocks.
	return id in [VillageContent.BELL,VillageContent.LANTERN,VillageContent.SOUL_LANTERN]

# The source places a new chain *below* the chain it was placed against, so a
# chain grows downward from where the player aims.
static func chain_placement(target: Dictionary) -> Vector3i:
	return target.get("replace",target.pos+target.normal)

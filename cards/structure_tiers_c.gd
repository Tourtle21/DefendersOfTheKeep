extends RefCounted
## Tier abilities of the sentry towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower, Sunspire, the Magma Wall and the
## menders Healing Grove and Phoenix Shrine (designs: docs/card_tiers/<card id>.md). It plugs into the hooks of StructureTiers
## (cards/structure_tiers.gd), which delegate here for the ids in OWN. Everything runs on the host; visuals go through
## WeaponFx.spawn / Sfx.play, and what a client must draw is a public var of Structure.

const OWN := ["crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine"]

static func world_of(st) -> Node:
	return st.get_parent()

# ---------------------------------------------------------------- hooks (dispatch)

static func tick(st, delta: float) -> void:
	pass

static func on_gnaw(st, e) -> void:
	pass

static func interval_mult(st) -> float:
	return 1.0

static func shot_mult(st, target) -> float:
	return 1.0

static func on_shot(st, target) -> void:
	pass

static func budget_mult(st) -> float:
	return 1.0

static func on_setup(st) -> void:
	pass

static func on_promote(st, new_tier: int) -> void:
	pass

static func on_expire(st) -> void:
	pass

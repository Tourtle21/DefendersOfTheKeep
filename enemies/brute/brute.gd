extends Enemy
## Brute: big, slow and very tanky. Shrugs off small hits, so burst it down or kite it.

func _ready() -> void:
	max_health = 24.0
	speed = 14
	keep_dps = 4.0
	armor = 2.0               # shrugs off weak hits: use heavy single hits or piercing damage
	knockback_strength = 120.0
	super()
	scale = Vector2(1.5, 1.5)

## Ground slam: when it has you close it rears up (a red ring shows where it lands), then smashes the ring.
func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		if _winding(delta, Color(1.0, 0.45, 0.35)):
			return true
		WeaponFx.spawn(Game.world, "ring", global_position, Color(1.0, 0.7, 0.3), {"radius": 44.0, "life": 0.3})
		for p in get_tree().get_nodes_in_group("player"):
			if _valid_target(p) and p.global_position.distance_to(global_position) <= 44.0:
				p.take_damage(global_position, 24.0)
		return false
	if ability_cd <= 0.0 and dist <= 50.0:
		_wind = 0.75
		ability_cd = 6.0
		WeaponFx.spawn(Game.world, "ring", global_position, Color(1.0, 0.3, 0.25, 0.8), {"radius": 44.0, "life": 0.75})
		return true
	return false

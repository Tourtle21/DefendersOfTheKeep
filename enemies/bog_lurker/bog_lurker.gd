extends Enemy
## Bog lurker (swamp): regenerates and is immune to poison, but dry fire cooks it.
## Burst it down before it heals.

var regen := 1.2

func _ready() -> void:
	max_health = 20.0
	speed = 16
	keep_dps = 3.0
	resist = {"poison": 0.1, "fire": 1.6}
	super()
	scale = Vector2(1.3, 1.3)

func _physics_process(delta: float) -> void:
	if health < max_health and !dead:
		health = minf(max_health, health + regen * delta)
		$ColorRect/Health.size.x = ($ColorRect.size.x - 2) * clampf(health / max_health, 0.0, 1.0)
	super(delta)

## Tongue: it lashes out (a green line shows it) and drags you a few steps towards it.
func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		if _winding(delta, Color(0.6, 0.95, 0.4)):
			return true
		WeaponFx.spawn(Game.world, "line", global_position, Color(0.6, 0.95, 0.4), {"dir": _dash_dir, "length": 110.0, "width": 4.0, "life": 0.2})
		for p in get_tree().get_nodes_in_group("player"):
			if _valid_target(p):
				var rel: Vector2 = p.global_position - global_position
				if rel.length() <= 110.0 and rel.normalized().dot(_dash_dir) > 0.95:
					p.take_damage(global_position, 8.0)
					p.blink(-rel.normalized() * minf(rel.length() - 14.0, 46.0))          # pulled in
		return false
	if ability_cd <= 0.0 and dist >= 40.0 and dist <= 110.0:
		_wind = 0.6
		ability_cd = 7.0
		_dash_dir = (t.global_position - global_position).normalized()
		WeaponFx.spawn(Game.world, "line", global_position, Color(0.6, 0.95, 0.4, 0.6), {"dir": _dash_dir, "length": 110.0, "width": 3.0, "life": 0.6})
		return true
	return false

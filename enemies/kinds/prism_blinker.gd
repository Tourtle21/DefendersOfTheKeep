extends Enemy
## Prism Blinker (caverns): a fast shard-skinned runner that vanishes in a flash and reappears next to you. A purple ring marks where
## it will land for a moment before it does: be somewhere else, then punish it, it is fragile.

const ART := "res://enemies/kinds/prism_blinker.png"
var _dest := Vector2.ZERO

func _ready() -> void:
	max_health = 4.0
	contact_damage = 8.0
	speed = 52
	keep_dps = 1.2
	resist = {"earth": 1.5}
	super()

func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		aggro_left = maxf(aggro_left, 0.5)            # a move in progress is not interrupted when the fight times out
	if _wind > 0.0:
		if _winding(delta, Color(0.85, 0.55, 1.0)):
			return true
		var from := global_position
		WeaponFx.spawn(Game.world, "burst", from, Color(0.85, 0.6, 1.0), {"radius": 16.0, "life": 0.25})
		global_position = _dest
		WeaponFx.spawn(Game.world, "burst", _dest, Color(0.9, 0.7, 1.0), {"radius": 26.0, "life": 0.3})
		for p in get_tree().get_nodes_in_group("player"):
			if _valid_target(p) and p.global_position.distance_to(_dest) <= 30.0:
				p.take_damage(_dest, 22.0 * power)
		_recover = 0.9
		return true
	if ability_cd <= 0.0 and dist > 50.0 and dist < 190.0:
		var d := Vector2.from_angle(randf() * TAU) * 34.0
		_dest = t.global_position + d
		var tries := 0
		while !Game.in_playable(_dest) and tries < 6:
			_dest = t.global_position - d * 0.5
			tries += 1
		_wind = 0.7
		ability_cd = 5.0
		WeaponFx.spawn(Game.world, "ring", _dest, Color(0.8, 0.55, 1.0, 0.9), {"radius": 30.0, "life": 0.7})
		return true
	return false

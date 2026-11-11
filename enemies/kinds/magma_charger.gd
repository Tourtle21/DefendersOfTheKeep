extends Enemy
## Magma Charger (volcano): a hulking brute that paws the ground (a red lane shows where), then charges down it. Sidestep the lane and it
## thunders past, then stands winded for a moment: that is when to hit it.

const ART := "res://enemies/kinds/magma_charger.png"
var _hit := false

func _ready() -> void:
	max_health = 12.0
	contact_damage = 16.0
	speed = 15
	keep_dps = 3.5
	armor = 0.5
	knockback_strength = 120.0
	resist = {"fire": 0.3}
	super()
	ability_cd = 0.6                                 # it charges almost at once, while you are still at a distance

func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0 or _dash_left > 0.0:
		aggro_left = maxf(aggro_left, 0.5)            # a move in progress is not interrupted when the fight times out
	if _wind > 0.0:
		if _winding(delta, Color(1.0, 0.35, 0.2)):
			return true
		_dash_left = 0.55
		_dash_speed = 280.0
		_hit = false
		return _dashing(delta)
	if _dash_left > 0.0:
		var more := _dashing(delta)
		if !_hit:
			for p in get_tree().get_nodes_in_group("player"):
				if _valid_target(p) and p.global_position.distance_to(global_position) < 20.0:
					_hit = true
					p.take_damage(global_position, 28.0 * power)
		if _dash_left <= 0.0:
			_recover = 1.6                           # winded: a long window to punish it
		return more
	if ability_cd <= 0.0 and dist > 26.0 and dist < 170.0:
		_wind = 1.0
		ability_cd = 7.0
		_dash_dir = (t.global_position - global_position).normalized()
		WeaponFx.spawn(Game.world, "line", global_position, Color(1.0, 0.3, 0.2, 0.7), {"dir": _dash_dir, "length": 155.0, "width": 16.0, "life": 1.0})
		return true
	return false

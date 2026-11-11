extends Enemy
## Venom Burrower (swamp): a scarab that dives into the mud when you are close, untouchable, and tunnels toward you. Where it will
## surface a green ring appears for a moment: step out of it, then hit it while it is stuck in the open.

var _dive := 0.0
var _spot := Vector2.ZERO
var _locked := false

func _ready() -> void:
	max_health = 5.0
	contact_damage = 8.0
	speed = 34
	keep_dps = 1.2
	resist = {"poison": 0.2}
	super()
	ability_cd = 1.0                                 # it dives soon after it notices you

func _ability(delta: float, t, dist: float) -> bool:
	if _dive > 0.0:
		aggro_left = maxf(aggro_left, 0.5)            # a move in progress is not interrupted when the fight times out
	if _dive > 0.0:
		_dive -= delta
		if !_locked and _dive > 0.7:
			Game.move_on_map(self, (t.global_position - global_position).normalized() * 95.0, delta)       # tunnels toward you
		elif !_locked:
			_locked = true
			_spot = global_position
			WeaponFx.spawn(Game.world, "ring", _spot, Color(0.45, 0.9, 0.3, 0.9), {"radius": 30.0, "life": 0.7})
		if _dive <= 0.0:
			_surface()
		return true
	if ability_cd <= 0.0 and dist < 130.0 and dist > 14.0:
		_dive = 1.5
		_locked = false
		ability_cd = 7.0
		ghost = true
		modulate = Color(1, 1, 1, 0.18)
		return true
	return false

func _surface() -> void:
	ghost = false
	modulate = Color.WHITE
	WeaponFx.spawn(Game.world, "burst", global_position, Color(0.5, 0.9, 0.3), {"radius": 30.0, "life": 0.3})
	for p in get_tree().get_nodes_in_group("player"):
		if _valid_target(p) and p.global_position.distance_to(global_position) <= 30.0:
			p.take_damage(global_position, 22.0 * power)
	_recover = 1.3                                   # stuck on the surface for a moment

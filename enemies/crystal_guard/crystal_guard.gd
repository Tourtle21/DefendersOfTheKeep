extends Enemy
## Crystal guard (caverns): armored and brittle against earth. A crystal shield soaks
## the first few points of damage and regrows after a pause; piercing damage ignores
## both the shield and the armor.

const SHIELD_MAX := 4.0
var _regrow := 0.0

func _ready() -> void:
	max_health = 22.0
	speed = 16
	keep_dps = 4.0
	armor = 2.5
	resist = {"earth": 1.8, "ice": 0.7}
	shield = SHIELD_MAX
	super()
	scale = Vector2(1.3, 1.3)

func _physics_process(delta: float) -> void:
	if shield <= 0.0:
		_regrow += delta
		if _regrow >= 8.0:
			_regrow = 0.0
			shield = SHIELD_MAX
			queue_redraw()
	super(delta)

## Shield bash: a slow wind-up, then a short charge that hits hard and knocks you back.
var _bash_hit := false

func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		if _winding(delta, Color(0.85, 0.7, 1.0)):
			return true
		_dash_left = 0.25
		_bash_hit = false
	if _dashing(delta):
		if !_bash_hit and _valid_target(t) and t.global_position.distance_to(global_position) <= 20.0:
			_bash_hit = true
			t.take_damage(global_position, 22.0)
			t.global_position += (t.global_position - global_position).normalized() * 14.0
		return true
	if ability_cd <= 0.0 and dist > 24.0 and dist < 70.0:
		_wind = 0.6
		ability_cd = 6.0
		_dash_dir = (t.global_position - global_position).normalized()
		_dash_speed = 220.0
		WeaponFx.spawn(Game.world, "line", global_position, Color(0.85, 0.7, 1.0, 0.7), {"dir": _dash_dir, "length": 55.0, "width": 8.0, "life": 0.6})
		return true
	return false

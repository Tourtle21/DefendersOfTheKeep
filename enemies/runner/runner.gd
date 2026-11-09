extends Enemy
## Runner: fragile but fast. Arrives before you are ready and goes for the crystal.

func _ready() -> void:
	max_health = 3.0
	contact_damage = 6.0
	speed = 72
	slowed_bonus = 1.6        # fast and fragile: slows and traps make it easy prey
	can_aggro = false
	super()

## Runners never fight you: they sprint for the crystal, in bursts.
var _sprint_in := randf_range(1.0, 3.0)
var _sprint_left := 0.0

func _physics_process(delta: float) -> void:
	_sprint_in -= delta
	if _sprint_left > 0.0:
		_sprint_left -= delta
		haste = 2.0
		if _sprint_left <= 0.0:
			haste = 1.0
			_sprint_in = randf_range(3.0, 5.0)
	elif _sprint_in <= 0.0:
		_sprint_left = 1.2
		WeaponFx.spawn(Game.world, "burst", global_position, Color(1.0, 0.9, 0.5, 0.8), {"radius": 9.0, "life": 0.2})
	super(delta)

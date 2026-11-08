extends Enemy
## Sand golem (desert): slow and heavily armored. Weak hits barely scratch it; heavy
## hits, crushing weapons and piercing damage are the answer. It stomps anyone
## standing next to it every few seconds: watch the ring and step out.

var _stomp := 4.0
var _stomp_wind := 0.0

func _ready() -> void:
	max_health = 30.0
	speed = 12
	keep_dps = 4.0
	knockback_strength = 100.0
	armor = 3.0
	resist = {"earth": 0.3}
	super()
	scale = Vector2(1.4, 1.4)
	$Sprite2D.modulate = Color(0.95, 0.8, 0.45)

func _physics_process(delta: float) -> void:
	if charm_time <= 0.0:
		var p = _target_player()
		_stomp -= delta
		if _stomp_wind > 0.0:
			_stomp_wind -= delta
			if _stomp_wind <= 0.0:
				WeaponFx.spawn(Game.world, "ring", global_position, Color(0.9, 0.75, 0.4), {"radius": 38.0, "life": 0.3})
				if p != null and p.global_position.distance_to(global_position) <= 38.0:
					p.take_damage(global_position)
		elif _stomp <= 0.0 and p != null and p.global_position.distance_to(global_position) <= 50.0:
			_stomp = 5.0
			_stomp_wind = 0.7
			WeaponFx.spawn(Game.world, "ring", global_position, Color(1.0, 0.4, 0.3), {"radius": 38.0, "life": 0.7})
	super(delta)

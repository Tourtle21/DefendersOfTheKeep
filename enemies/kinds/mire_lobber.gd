extends Enemy
## Mire Lobber (swamp): keeps its distance and lobs bombs of bog water. A ring shows where each one lands; it bursts a second later and
## leaves a poisonous puddle. Keep moving and stay out of the puddles.

const ART := "res://enemies/kinds/mire_lobber.png"
var _lob_cd := 2.0
var _windup := 0.0
var _aim_at := Vector2.ZERO

func _ready() -> void:
	max_health = 4.0
	contact_damage = 6.0
	speed = 26
	keep_dps = 0.8
	can_aggro = false                                # like the Spitter it stays back and shoots
	super()

func _physics_process(delta: float) -> void:
	if charm_time > 0.0:
		super(delta)
		return
	_lob_cd -= delta
	var target = _nearest_player(190.0)
	if _windup > 0.0:
		_windup -= delta
		velocity = Vector2.ZERO
		modulate = Color(0.6, 1.0, 0.5) if int(_windup * 12.0) % 2 == 0 else Color.WHITE
		if _windup <= 0.0:
			modulate = Color.WHITE
			_land(_aim_at)
		return
	if target != null and _lob_cd <= 0.0:
		_lob_cd = 3.2
		_windup = 0.45
		_aim_at = target.global_position + target.velocity * 0.4           # leads you a little
		WeaponFx.spawn(Game.world, "ring", _aim_at, Color(0.5, 0.9, 0.3, 0.8), {"radius": 26.0, "life": 1.3})
		return
	super(delta)

func _land(at: Vector2) -> void:
	await get_tree().create_timer(0.85).timeout
	WeaponFx.spawn(Game.world, "burst", at, Color(0.5, 0.9, 0.3), {"radius": 26.0, "life": 0.3})
	for p in get_tree().get_nodes_in_group("player"):
		if _valid_target(p) and p.global_position.distance_to(at) <= 26.0:
			p.take_damage(at, 18.0 * power)
	var h := Hazard.new()                            # the puddle that stays and poisons
	h.kind = "burn"
	h.radius = 24.0
	h.color = Color(0.4, 0.7, 0.2, 0.5)
	h.lifetime = 4.5
	h.hurts_enemies = false
	h.player_damage = 6.0 * power
	h.position = at
	Game.world.add_child.call_deferred(h)

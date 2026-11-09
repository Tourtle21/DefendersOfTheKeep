extends Enemy
## Spitter: fragile, but stops at range and lobs slow globs at the player.

var _shoot_cd := 2.0
var _windup := 0.0

func _ready() -> void:
	max_health = 4.0
	contact_damage = 6.0
	speed = 28
	keep_dps = 0.8
	can_aggro = false         # it keeps its distance and shoots
	super()

func _physics_process(delta: float) -> void:
	if charm_time > 0.0:
		super(delta)
		return
	_shoot_cd -= delta
	var player = null
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl) and !pl.get("downed") and !pl.get("is_in_tower") and (player == null or pl.global_position.distance_to(global_position) < player.global_position.distance_to(global_position)):
			player = pl
	if _windup > 0.0:
		_windup -= delta
		velocity = Vector2.ZERO
		modulate = Color(1.0, 0.6, 0.6) if int(_windup * 12.0) % 2 == 0 else Color.WHITE
		if _windup <= 0.0:
			modulate = Color.WHITE
			if player != null:
				EnemyProjectile.fire(get_parent().get_parent(), global_position, player.global_position - global_position)
		return
	if player != null and _shoot_cd <= 0.0 and global_position.distance_to(player.global_position) < 150.0:
		_shoot_cd = 2.4
		_windup = 0.4
		return
	super(delta)

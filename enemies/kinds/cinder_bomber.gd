extends Enemy
## Cinder Bomber (volcano): a goblin packed with embers. When it gets close it lights a fuse (a red ring shows the blast) and keeps
## creeping at you, then goes off. Counter: kill it before the fuse runs out and it fizzles; or just get out of the ring.

const BLAST := 46.0
var _fuse := 0.0

func _ready() -> void:
	max_health = 3.0
	contact_damage = 10.0
	speed = 60
	keep_dps = 1.5
	resist = {"fire": 0.2}
	super()

func _ability(delta: float, t, dist: float) -> bool:
	if _fuse > 0.0:
		aggro_left = maxf(aggro_left, 0.5)            # a move in progress is not interrupted when the fight times out
	if _fuse > 0.0:
		_fuse -= delta
		modulate = Color(1.0, 0.35, 0.2) if int(_fuse * 14.0) % 2 == 0 else Color.WHITE
		Game.move_on_map(self, (t.global_position - global_position).normalized() * speed * 0.55, delta)         # it keeps creeping at you
		if _fuse <= 0.0:
			_explode()
		return true
	if ability_cd <= 0.0 and dist < 52.0:
		_fuse = 1.25
		ability_cd = 99.0
		WeaponFx.spawn(Game.world, "ring", global_position, Color(1.0, 0.3, 0.15, 0.85), {"radius": BLAST, "life": 1.25})
		return true
	return false

func _explode() -> void:
	WeaponFx.spawn(Game.world, "burst", global_position, Color(1.0, 0.55, 0.2), {"radius": BLAST, "life": 0.35})
	for p in get_tree().get_nodes_in_group("player"):
		if _valid_target(p) and p.global_position.distance_to(global_position) <= BLAST:
			p.take_damage(global_position, 26.0 * power)
	WeaponUtil.patch(Game.world, global_position, "burn", 24.0, Color(1.0, 0.4, 0.1, 0.5), 3.0)
	_fuse = 0.0
	die()

func die() -> void:
	_fuse = 0.0                  # killed in time: the fuse is out
	super()

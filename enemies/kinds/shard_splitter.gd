extends Enemy
## Shard Splitter (caverns): a crystal slime that shatters when it dies, throwing shards in every direction. Kill it at range, or
## from the far side of cover, and the shards fall short.
const ART := "res://enemies/kinds/shard_splitter.png"

func _ready() -> void:
	max_health = 7.0
	contact_damage = 8.0
	speed = 30
	keep_dps = 1.4
	resist = {"earth": 1.5}
	super()

func die() -> void:
	var was_dead: bool = dead
	var pos := global_position
	super()
	if !was_dead:
		var off := randf() * TAU
		for i in 7:
			EnemyProjectile.fire(Game.world, pos, Vector2.from_angle(off + i * TAU / 7.0), 115.0, 14.0 * power, Color(0.8, 0.6, 1.0), 6.0, 0.8)
		WeaponFx.spawn(Game.world, "burst", pos, Color(0.8, 0.6, 1.0), {"radius": 22.0, "life": 0.3})

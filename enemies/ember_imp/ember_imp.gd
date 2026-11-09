extends Enemy
## Ember imp (volcano): fast and fiery. Fire does almost nothing; ice shatters it.
## When it dies it leaves a patch of embers that burns whoever stands in it.

func _ready() -> void:
	max_health = 6.0
	speed = 56
	resist = {"fire": 0.2, "ice": 1.8}
	super()

func die() -> void:
	var was_dead: bool = dead
	var pos := global_position
	super()
	if !was_dead:
		WeaponUtil.patch(Game.world, pos, "burn", 22.0, Color(1.0, 0.4, 0.1, 0.5), 3.0)

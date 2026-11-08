extends Enemy
## Frost imp (tundra): fast, fragile, immune-ish to ice but burns easily. Fire it down.
## When it dies it leaves a patch of freezing ground: kill it at range.

func _ready() -> void:
	max_health = 6.0
	speed = 60
	resist = {"ice": 0.2, "fire": 1.8}
	super()
	$Sprite2D.modulate = Color(0.6, 0.85, 1.3)

func die() -> void:
	var was_dead: bool = dead
	var pos := global_position
	super()
	if !was_dead:
		WeaponUtil.patch(Game.world, pos, "slow", 26.0, Color(0.7, 0.9, 1.0, 0.5), 4.0, 0.45)

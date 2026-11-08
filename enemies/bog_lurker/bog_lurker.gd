extends Enemy
## Bog lurker (swamp): regenerates and is immune to poison, but dry fire cooks it.
## Burst it down before it heals.

var regen := 1.2

func _ready() -> void:
	max_health = 20.0
	speed = 16
	keep_dps = 3.0
	resist = {"poison": 0.1, "fire": 1.6}
	super()
	scale = Vector2(1.3, 1.3)
	$Sprite2D.modulate = Color(0.55, 0.85, 0.4)

func _physics_process(delta: float) -> void:
	if health < max_health and !dead:
		health = minf(max_health, health + regen * delta)
		$ColorRect/Health.size.x = ($ColorRect.size.x - 2) * clampf(health / max_health, 0.0, 1.0)
	super(delta)

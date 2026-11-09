extends Enemy
## Runner: fragile but fast. Arrives before you are ready and goes for the crystal.

func _ready() -> void:
	max_health = 3.0
	speed = 72
	slowed_bonus = 1.6        # fast and fragile: slows and traps make it easy prey
	super()

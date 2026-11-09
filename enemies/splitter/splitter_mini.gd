extends Enemy
## Fragments of a splitter: tiny and quick.

func _ready() -> void:
	max_health = 1.0
	speed = 46
	keep_dps = 0.6
	swarm = true
	super()
	scale = Vector2(0.6, 0.6)

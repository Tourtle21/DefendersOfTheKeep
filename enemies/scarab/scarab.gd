extends Enemy
## Sector native enemy: a tougher, faster blobbert with a tint set by its sector.

var tint := Color(1.0, 0.75, 0.35)

func _ready() -> void:
	max_health = 8.0
	speed = 34
	keep_dps = 1.6
	swarm = true
	super()
	$Sprite2D.modulate = tint

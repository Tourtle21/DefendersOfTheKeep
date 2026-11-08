extends Enemy
## Splitter: a blob that bursts into two fast minis when it dies.

func _ready() -> void:
	max_health = 9.0
	speed = 24
	swarm = true
	super()
	$Sprite2D.modulate = Color(0.5, 0.8, 1.0)

func die() -> void:
	if dead:
		return
	var parent := get_parent()
	var pos := global_position
	var lvl: int = level
	super()
	var scene: PackedScene = load("res://enemies/splitter/splitter_mini.tscn")
	for i in 2:
		var m = scene.instantiate()
		m.level = lvl
		m.position = pos + Vector2(-8.0 + 16.0 * i, 0.0)
		parent.add_child.call_deferred(m)

extends Node
## Drops a chest on the southern path every so often (max 2 at a time).

var timer: Timer

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_timeout)
	timer.start(8.0)

func _on_timeout() -> void:
	if get_tree().get_nodes_in_group("chest").size() < 2:
		place_chest()
	timer.start(randf_range(25.0, 40.0) * maxf(0.4, 1.0 - Game.bonus("chest_rate")))

func place_chest() -> Chest:
	var world := get_parent()
	var breakables: Array = world.get_node("Breakables").get_children()
	var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
	for attempt in 40:
		var y := randf_range(190.0, 560.0)
		# the real path half-width grows roughly 0.7 per unit south of the neck
		var half := 0.8 * (60.0 + 0.7 * (y - 130.0))
		var p := Vector2(randf_range(-half, half), y)
		var ok := true
		for b in breakables:
			if b is Node2D and b.global_position.distance_to(p) < 26.0:
				ok = false
				break
		if ok:
			# also stay off solid tiles (ponds etc.)
			var q := PhysicsPointQueryParameters2D.new()
			q.position = p
			q.collision_mask = 4
			q.collide_with_bodies = true
			ok = space.intersect_point(q, 1).is_empty()
		if ok:
			var chest := Chest.new()
			chest.position = p
			chest.kind = "weapon" if randf() < 0.4 else "card"
			world.add_child(chest)
			return chest
	return null

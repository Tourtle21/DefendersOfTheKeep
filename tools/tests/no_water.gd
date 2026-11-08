extends SceneTree
# The yard lake is gone: every tile is grass, enemies path straight across the old lake.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var layer: TileMapLayer = world.get_node("GrassTilemap")
	var bad := 0
	for c in layer.get_used_cells():
		if !(layer.get_cell_atlas_coords(c) in world.GRASS_TILES): bad += 1
	print("non-grass tiles left: ", bad, " of ", layer.get_used_cells().size())
	# an enemy walking across the old lake area reaches the other side
	var player = world.get_node("Player")
	player.global_position = Vector2(0, 100)
	var e = load("res://enemies/goblin/goblin.tscn").instantiate()
	e.position = Vector2(0, 300)
	world.get_node("Enemies").add_child(e)
	var start: Vector2 = e.global_position
	var best := 9999.0
	for i in 40:
		await wait(0.25)
		if !is_instance_valid(e):
			best = 0.0
			break
		best = minf(best, e.global_position.distance_to(Vector2(0, 50)))
	print("goblin started at y=300 near the old lake, closest it got to the keep: ", snapped(best, 1.0), " (0 = it arrived and was shot down; path is open)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

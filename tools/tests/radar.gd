extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	sm.unlock("se")
	sm.unlock("ne")
	world.spawn_enemies([{"name": "blobbert", "amount": 8, "level": 1}, {"name": "goblin", "amount": 5, "level": 1}])
	world.get_node("SpawnTimer").stop()
	var spawner = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('chest_spawner.gd'): spawner = c
	spawner.place_chest(); spawner.place_chest()
	game.enter_base(player)
	player.base_zoom = 2.0
	await wait(1.0)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://radar.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

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
	game.meta.recipes_seen = ["hammer+spear"]
	var ui = load("res://ui/base/codex_ui.gd").new()
	world.add_child(ui)
	print("weapons listed: ", ui._weapon_ids().size())
	for id in ["spear", "lance", "hammer", "frostglaive", "worldbreaker"]:
		ui.selected = id
		ui.open()
		print(id, " known: ", ui._known(id), " | ", ui.detail.text.replace("\n", " / ").substr(0, 200))
	if DisplayServer.get_name() != "headless":
		ui.selected = "lance"
		ui.open()
		await wait(0.5)
		root.get_viewport().get_texture().get_image().save_png("user://codex.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

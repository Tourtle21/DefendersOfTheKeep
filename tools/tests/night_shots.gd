extends SceneTree
# Window test: screenshots of dusk, night with a torch and the Torch weapon.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.5)
	root.get_viewport().get_texture().get_image().save_png("user://night_%s.png" % name)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	var player = world.get_node("Player")
	player.equip_item(game.weapon_info("sword"))
	player.global_position = Vector2(0, 120)
	world.clock = 177.0
	await shot("1_dusk")
	world.clock = 230.0
	for i in 5:
		var e = load("res://enemies/%s/%s.tscn" % [["blobbert", "goblin", "brute", "scarab", "blobbert"][i], ["blobbert", "goblin", "brute", "scarab", "blobbert"][i]]).instantiate()
		e.position = Vector2(-90 + i * 45, 175 + (i % 2) * 25)
		world.get_node("Enemies").add_child(e)
		e.set_physics_process(false)
		e.get_node("NavigationTimer").stop()
	await shot("2_night_unlit")
	var torch = load("res://cards/structure.gd").new()
	torch.setup(game.stats_of("torch"), Vector2(-40, 175))
	world.add_child(torch)
	await shot("3_night_torch")
	player.equip_item(game.weapon_info("torch"))
	player.global_position = Vector2(60, 150)
	await shot("4_night_torch_weapon")
	game.enter_base(player)
	player.is_in_tower = true
	game.mana = 100
	game.hand = ["flare", "fireball", "torch"]
	game.hand_changed.emit()
	game.cast("fireball", Vector2(40, 190), player)
	await wait(2.2)
	await shot("5_night_fireball_cards")
	quit()

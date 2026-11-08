extends SceneTree
# Window test: weapon pickups on the ground with their rarity rings (Common to Legendary).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
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
	player.global_position = Vector2(0, 110)
	var ids := ["sword", "spear", "scimitar", "emberflail", "crystalwand", "lance", "juggernaut", "worldbreaker", "dawnbringer"]
	var x := -120.0
	for id in ids:
		var c = load("res://collectables/collectable.tscn").instantiate()
		c.item_type = id
		c.fixed = true
		c.position = Vector2(x, 140)
		world.add_child(c)
		x += 30.0
	await wait(0.8)
	print("rarities: ", ids.map(func(i): return "%s=%s" % [i, game.rarity_name(game.weapon_rarity(i))]))
	var cam = player.get_node("Camera2D")
	cam.zoom = Vector2(3.2, 3.2)
	cam.global_position = Vector2(0, 140)
	await wait(0.5)
	root.get_viewport().get_texture().get_image().save_png("user://pickup_rarity.png")
	quit()

extends SceneTree
# Window test: the ability HUD with a tier 1 Sword (padlocks) and a tier 3 Pickaxe, and the chest draft with tiered cards.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	game.meta.card_tiers = {"fireball": 4, "frost_ring": 4, "barricade": 4, "spike_trap": 4}
	for c in world.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("help_ui.gd"):
			c.panel.visible = false
	var player = world.get_node("Player")
	player.equip_item(game.weapon_info("sword"))
	await wait(0.6)
	root.get_viewport().get_texture().get_image().save_png("user://tool_sword_t1.png")
	player.equip_item(game.weapon_info("pickaxe:2"))
	await wait(0.6)
	player.item._ability_cd = 2.0
	await wait(0.3)
	root.get_viewport().get_texture().get_image().save_png("user://tool_pickaxe_t3.png")
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	game.start_draft(1)
	await wait(1.2)
	root.get_viewport().get_texture().get_image().save_png("user://chest_draft.png")
	print("draft options: ", game.draft_options)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

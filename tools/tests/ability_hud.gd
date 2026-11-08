extends SceneTree
# Screenshot of the bottom-right ability HUD with moves on cooldown, then ready pop.
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
	var info = world.get_node("Collectable").item_info
	player.equip_item(info.items["spear"])
	await wait(0.4)
	var w = player.item
	w._attack_cd = 0.2
	w._ability_cd = 3.0
	w._dash_cd = 1.5
	w._ult_cd = 40.0
	await wait(0.3)
	root.get_viewport().get_texture().get_image().save_png("user://ability_hud_cd.png")
	await wait(1.4)          # dash comes back ready -> pop
	root.get_viewport().get_texture().get_image().save_png("user://ability_hud_pop.png")
	print("ability hud screenshots written; cd_info ability: ", w.cd_info("ability"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

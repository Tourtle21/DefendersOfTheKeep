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
	var info = load("res://world/item_info.tres")
	player.equip_item(info.items["spear"])
	await wait(0.3)
	var P := Vector2(-40, 260)
	player.position = P
	player.shield_time = 999.0
	var ds := []
	for off in [Vector2(30, 0), Vector2(34, 14), Vector2(36, -14)]:
		var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
		e.position = P + off
		world.get_node("Enemies").add_child(e)
		e.set_physics_process(false)
		e.get_node("NavigationTimer").stop()
		ds.append(e)
	ds[2].health = 2.0
	root.warp_mouse(root.get_canvas_transform() * (P + Vector2(120, 0)))
	await wait(0.2)
	player.item.use_item()                      # spear tip hit = 5 dmg -> hit-stop
	await wait(0.05)
	print("time scale during hit-stop: ", Engine.time_scale)
	await wait(0.25)
	print("time scale restored: ", Engine.time_scale)
	player.item.use_ability()                   # javelin hits several
	await wait(0.35)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://feedback.png")
	var nums := 0
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("damage_number.gd"): nums += 1
	print("damage numbers alive: ", nums)
	player.shield_time = 0.0
	player.is_taking_damage = false
	var flashed := false
	game.player_hurt.connect(func(): flashed = true)
	player.take_damage(P + Vector2(30, 0))
	await wait(0.1)
	print("hurt signal fired: ", flashed)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

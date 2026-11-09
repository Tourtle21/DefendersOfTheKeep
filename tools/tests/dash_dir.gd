extends SceneTree
## A dash goes the way the left stick / movement keys point, not toward the cursor; a co-op avatar's too.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://dd_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var pl = world.get_node("Player")
	for id in ["sword", "bow", "daggers", "spear", "shield"]:
		pass
	for id in ["sword", "bow", "daggers", "spear", "shield"]:
		pl.weapon_slots.clear()
		net.give_weapon(pl, id)
		await wait(0.2)
		pl.global_position = Vector2(0, 200)
		if "_dash_cd" in pl.item: pl.item._dash_cd = 0.0
		Input.action_press("move_up")
		pl.process_movement(0.016)
		pl.global_position = Vector2(0, 200)
		pl.dash_time = 0.0
		pl.item.use_dash()
		var v: Vector2 = pl.dash_velocity
		print("  %s dash velocity %s" % [id, v])
		ok("%s dashes up with the stick, not right at the cursor" % id, v.y < -1.0 and absf(v.x) < absf(v.y) * 0.2)
		Input.action_release("move_up")
		pl.dash_time = 0.0
		await wait(0.3)
	quit()

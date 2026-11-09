extends SceneTree
## Base upgrades with a controller: D-pad up/down pick Repair / an upgrade, Y buys it, X reloads the tower (players 1 and 2).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func tap(dev: int, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = true
	Input.parse_input_event(e)
	await wait(0.13)
	e = InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = false
	Input.parse_input_event(e)
	await wait(0.15)
func _initialize() -> void:
	var game = root.get_node("Game")
	var pad = root.get_node("Pad")
	game.save_path = "user://kc_test_save.json"
	game._menu_done = true
	game._local_devices = [1, 2]               # player 1 on controller 1, player 2 on controller 2
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	for t in game.all_towers():
		t.visible = true
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	var towers: Array = game.all_towers()
	game.resources = {"stone": 40, "stick": 40, "gold": 40}
	# ---------------- player 2
	p2.global_position = towers[2].global_position + Vector2(0, 14)
	await wait(0.4)
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	ok("player 2 is in a tower", p2.is_in_tower)
	await tap(2, JOY_BUTTON_DPAD_DOWN)
	await tap(2, JOY_BUTTON_Y)
	ok("player 2: D-pad down picks the first upgrade (%s), Y buys it" % game.keep_menu_name(lp.keep_uis[1].upg), game.upgrade_levels.get("max_mana", 0) == 1)
	await tap(2, JOY_BUTTON_DPAD_UP)
	game.keep_hp = 10.0
	await tap(2, JOY_BUTTON_Y)
	ok("player 2: D-pad up picks Repair, Y mends the keep (%.0f)" % game.keep_hp, game.keep_hp > 30.0)
	var turret = null
	for c in game.current_tower(p2).get_children():
		if c.has_method("reload"): turret = c
	turret.ammo = 0
	var sticks_before: int = game.resources.stick
	await tap(2, JOY_BUTTON_X)
	ok("player 2: X reloads the tower (ammo %d, sticks %d -> %d)" % [turret.ammo, sticks_before, game.resources.stick], turret.ammo == turret.max_ammo() and game.resources.stick == sticks_before - 2)
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	# ---------------- player 1 (the Pad's keep mode)
	p1.global_position = towers[1].global_position + Vector2(0, 14)
	towers[1].get_node("EnterArea").open = true
	await wait(0.4)
	await tap(1, JOY_BUTTON_A)
	await wait(0.3)
	pad._scan_clock = 0.0
	await wait(0.3)
	ok("player 1 is in a tower and the pad is in keep mode", p1.is_in_tower and pad.mode == "keep")
	game._keep_sel = 0
	await tap(1, JOY_BUTTON_DPAD_DOWN)
	await tap(1, JOY_BUTTON_DPAD_DOWN)
	var lvl_before: int = game.upgrade_levels.get("regen", 0)
	await tap(1, JOY_BUTTON_Y)
	ok("player 1: D-pad down twice picks %s, Y buys it" % game.keep_menu_name(game._keep_sel), game._keep_sel == 2 and game.upgrade_levels.get("regen", 0) == lvl_before + 1)
	turret = null
	for c in game.current_tower(p1).get_children():
		if c.has_method("reload"): turret = c
	turret.ammo = 0
	await tap(1, JOY_BUTTON_X)
	ok("player 1: X reloads the tower", turret.ammo == turret.max_ammo())
	quit()

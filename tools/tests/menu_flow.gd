extends SceneTree
## The real menu flow: main menu (with the four starting-card dropdowns) -> local co-op lobby (keyboard + controller join) -> Start.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code; e.physical_keycode = code; e.pressed = pressed
		Input.parse_input_event(e)
		await wait(0.08)
func pad(dev: int, b: int) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = dev; e.button_index = b; e.pressed = pressed
		Input.parse_input_event(e)
		await wait(0.12)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://mf_test_save.json"
	game.meta["unlocked"] = ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "rejuvenation", "mender"]
	game._menu_done = false
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	var mm = load("res://ui/base/main_menu.gd").new()          # (headless worlds do not build the menu themselves)
	world.add_child(mm)
	await wait(0.5)
	ok("the menu pauses the game", paused)
	ok("four card dropdowns: 2 spells and 2 buildings, listing only what you own", mm._pickers.size() == 4 and mm._pickers[0].item_count == 3 and mm._pickers[2].item_count == 4)
	mm._pickers[0].selected = 2                                  # a different first spell
	mm._pickers[0].item_selected.emit(2)
	var picked: Array = game.start_cards()
	print("  chosen: ", picked)
	ok("choosing a card is saved and applied (%s)" % str(picked), picked[0] == "rejuvenation" and picked[0] != picked[1])
	mm.lobby.open()
	await wait(0.3)
	await key(KEY_ENTER)
	ok("Enter joins the keyboard", -1 in mm.lobby._members)
	mm.lobby.fake_connected = [1]
	await pad(1, JOY_BUTTON_A)
	ok("A on controller 2 joins a second player (%s)" % str(mm.lobby.devices()), mm.lobby.devices() == [-1, 1])
	mm.lobby._begin()
	await wait(1.0)
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))
	ok("Start builds the split screen for 2 players", split.size() == 1 and split[0].viewports.size() == 2 and game.player_count() == 2)
	ok("the game is unpaused and the menu is gone", !paused and !is_instance_valid(mm) or mm.is_queued_for_deletion())
	game.start_run()
	ok("a run starts with the chosen cards (deck %s)" % str(game.deck.keys()), game.deck.size() == 4 and game.deck.has("rejuvenation"))
	quit()

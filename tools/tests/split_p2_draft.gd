extends SceneTree
## A chest opened by player 2 (controller) shows its card choice in player 2's view; A takes a card.
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
	game.save_path = "user://dr_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	p2.global_position = Vector2(150, 150)
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(155, 150)
	world.add_child(chest)
	await wait(0.4)
	var p1ui = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("draft_ui.gd"))[0]
	await tap(1, JOY_BUTTON_A)
	await wait(0.3)
	var dui = lp.draft_uis[1]
	ok("player 2 opened a chest: the draft is theirs (slot %d), shown in their view, not player 1's" % game.draft_owner_slot, game.draft_active and game.draft_owner_slot == 1 and dui.is_open and !p1ui.root_ctl.visible)
	var before: int = game.deck.size()
	await tap(1, JOY_BUTTON_A)
	await wait(0.3)
	ok("A takes a card and the choice closes", !game.draft_active and !dui.is_open)
	quit()

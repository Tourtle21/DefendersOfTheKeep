extends SceneTree
# Controller: left stick walks, right stick aims, RT attacks, LT is the ability, buttons map to actions,
# the mouse takes over again, and the pad is off while a menu / the keep is up.
var fails := 0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if !ok: fails += 1
func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)
func button(i: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = i
	e.pressed = down
	Input.parse_input_event(e)
func _initialize() -> void:
	var game = root.get_node("Game")
	var pad = root.get_node("Pad")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	check(!pad.using_pad, "starts on the mouse")
	# walk right with the left stick
	var x0: float = player.global_position.x
	axis(JOY_AXIS_LEFT_X, 1.0)
	await wait(0.6)
	check(pad.using_pad, "stick switches to the pad")
	check(player.global_position.x > x0 + 10.0, "left stick walks right (%.1f -> %.1f)" % [x0, player.global_position.x])
	axis(JOY_AXIS_LEFT_X, 0.0)
	# small drift stays ignored
	axis(JOY_AXIS_LEFT_Y, 0.1)
	await wait(0.2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").length() < 0.01, "stick drift is ignored")
	axis(JOY_AXIS_LEFT_Y, 0.0)
	# right stick aims
	for d in [[Vector2.UP, "up"], [Vector2.DOWN, "down"], [Vector2.LEFT, "left"], [Vector2.RIGHT, "right"]]:
		axis(JOY_AXIS_RIGHT_X, d[0].x)
		axis(JOY_AXIS_RIGHT_Y, d[0].y)
		await wait(0.2)
		var to: Vector2 = player.aim_point() - player.global_position
		check(to.normalized().dot(d[0]) > 0.95 and to.length() > 30.0, "right stick aims %s (offset %s)" % [d[1], to.round()])
	# RT attacks with the aimed weapon, LT is the right click
	var rt_seen := false
	axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.1)
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "RT holds the attack button")
	check(player.is_using_item or player.item == null, "RT starts using the weapon")
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await wait(0.1)
	check(!Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "releasing RT releases it")
	axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await wait(0.1)
	check(Input.is_action_pressed("dash") and !Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "LT is the dash action (not the ability click)")
	axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await wait(0.1)
	check(!Input.is_action_pressed("dash"), "releasing LT releases dash")
	button(JOY_BUTTON_X, true)
	await wait(0.1)
	check(Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "X holds the ability button")
	button(JOY_BUTTON_X, false)
	await wait(0.1)
	check(!Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "releasing X releases it")
	# buttons are the same actions as the keys
	for pair in [[JOY_BUTTON_A, "interact"], [JOY_BUTTON_LEFT_SHOULDER, "switch_items"], [JOY_BUTTON_RIGHT_SHOULDER, "switch_items"], [JOY_BUTTON_Y, "ultimate"]]:
		button(pair[0], true)
		await wait(0.05)
		check(Input.is_action_pressed(pair[1]), "pad button -> %s" % pair[1])
		button(pair[0], false)
		await wait(0.05)
	# the mouse takes over again
	var m := InputEventMouseMotion.new()
	m.relative = Vector2(20, 5)
	m.position = Vector2(300, 300)
	Input.parse_input_event(m)
	await wait(0.1)
	check(!pad.using_pad, "moving the mouse hands control back")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the mouse cursor is shown again")
	# a menu (or the keep) switches the pad's gameplay buttons off
	axis(JOY_AXIS_LEFT_X, 0.8)
	await wait(0.2)
	check(pad.using_pad, "stick takes over again")
	game.draft_active = true
	await wait(0.3)
	check(pad.blocked and !pad.using_pad, "a menu blocks the pad and gives back the mouse")
	var has_pad := false
	for e in InputMap.action_get_events("interact"):
		if e is InputEventJoypadButton: has_pad = true
	check(!has_pad, "pad buttons unbound while a menu is up")
	game.draft_active = false
	axis(JOY_AXIS_LEFT_X, 0.0)
	await wait(0.3)
	has_pad = false
	for e in InputMap.action_get_events("interact"):
		if e is InputEventJoypadButton: has_pad = true
	check(!pad.blocked and has_pad, "pad buttons come back after the menu")
	print("controller test: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	quit(fails)

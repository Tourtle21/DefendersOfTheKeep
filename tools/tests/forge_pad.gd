extends SceneTree
## Player 1's Forge with a controller only: open it at the anvil with A, move with the d-pad, pick two weapons with A, close with B.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func btn(b: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 1; e.button_index = b; e.pressed = pressed
	Input.parse_input_event(e)
func tap(b: int) -> void:
	btn(b, true)
	await wait(0.12)
	btn(b, false)
	await wait(0.2)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	var pad = root.get_node("Pad")
	game.save_path = "user://fp_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	var hud = world.get_node("Hud")
	game.resources = {"stone": 30, "stick": 20, "gold": 50}
	game.note_weapon_tier("hammer", 1)
	for id in ["spear", "hammer"]:
		var info = game.weapon_info(id)
		if hud.equip_item(info):
			p.equip_item(info)
	var forge = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("forge_ui.gd"): forge = c
	p.global_position = net.FORGE_POS + Vector2(8, 0)
	await wait(0.6)
	await tap(JOY_BUTTON_A)
	await wait(0.6)
	ok("A at the anvil opens the Forge", forge.root_ctl.visible)
	var owner = forge.root_ctl.get_viewport().gui_get_focus_owner()
	print("  focus owner after opening: %s" % [owner])
	ok("a weapon card has the controller focus", owner != null and forge.root_ctl.is_ancestor_of(owner))
	await tap(JOY_BUTTON_A)
	print("  selected after A: %s, pad mode %s" % [forge.selected, pad.mode])
	ok("A picks the focused weapon", forge.selected.size() == 1)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	await tap(JOY_BUTTON_A)
	print("  selected after d-pad right + A: %s" % [forge.selected])
	ok("d-pad right then A picks a second weapon", forge.selected.size() == 2)
	await tap(JOY_BUTTON_B)
	await wait(0.3)
	ok("B closes the Forge", !forge.root_ctl.visible)
	quit()

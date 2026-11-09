extends SceneTree
# Split screen with two (simulated) controllers, headless: walking, pickup, fighting, towers + casting cards, one person per tower,
# the forge, pause from any controller, damage. Uses controllers 1 and 2 (a fake controller 0 crashes some Godot builds).
#   Godot --headless --path . --quit-after 20000 --script res://tools/tests/split_two_pads.gd
var results := []
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	results.append(c)
	print(("PASS " if c else "FAIL ") + n)
func btn(dev: int, b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)
func axis(dev: int, a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)
func tap(dev: int, b: int) -> void:
	btn(dev, b, true)
	await wait(0.13)
	btn(dev, b, false)
	await wait(0.15)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	var pad = root.get_node("Pad")
	game.save_path = "user://twopads_test_save.json"
	game._menu_done = true
	game._local_devices = [1, 2]            # player 1 on controller 1, player 2 on controller 2
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	for t in game.all_towers():
		t.visible = true
	var lp = null
	var split = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"): lp = c
		if c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"): split = c
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	print("--- setup")
	ok("two views, two players, team scale 1.45 (%.2f)" % game.team_scale(game.WAVE_TEAM_SCALE), split.viewports.size() == 2 and game.player_count() == 2 and is_equal_approx(game.team_scale(game.WAVE_TEAM_SCALE), 1.45))
	ok("pad is split with player 1 on controller 1 (dev %d)" % pad._dev, pad._dev == 1)
	# ---------------- walking
	print("--- walking")
	var a1: Vector2 = p1.global_position
	var a2: Vector2 = p2.global_position
	axis(1, JOY_AXIS_LEFT_X, 1.0)
	await wait(0.7)
	axis(1, JOY_AXIS_LEFT_X, 0.0)
	var m1: float = p1.global_position.x - a1.x
	ok("controller 1 walks player 1 right (%.1f) and not player 2 (%.1f)" % [m1, p2.global_position.x - a2.x], m1 > 15.0 and absf(p2.global_position.x - a2.x) < 2.0)
	a1 = p1.global_position
	a2 = p2.global_position
	axis(2, JOY_AXIS_LEFT_Y, 1.0)
	await wait(0.7)
	axis(2, JOY_AXIS_LEFT_Y, 0.0)
	var m2: float = p2.global_position.y - a2.y
	ok("controller 2 walks player 2 down (%.1f) and not player 1 (%.1f)" % [m2, p1.global_position.y - a1.y], m2 > 15.0 and absf(p1.global_position.y - a1.y) < 2.0)
	# ---------------- pickup
	print("--- pickup")
	var sword = null
	for c in world.get_children():
		if c.name == "Collectable": sword = c
	p1.global_position = sword.global_position
	await wait(0.4)
	await tap(1, JOY_BUTTON_A)
	ok("A on controller 1 picks up the sword for player 1", p1.item != null)
	var drop = load("res://collectables/collectable.tscn").instantiate()
	drop.item_type = "sword"
	drop.fixed = true
	drop.position = p2.global_position + Vector2(6, 0)
	world.add_child(drop)
	await wait(0.4)
	var before_w: int = p2.weapon_slots.size()
	await tap(2, JOY_BUTTON_A)
	await wait(0.2)
	ok("A on controller 2 picks up a weapon for player 2 (%d -> %d)" % [before_w, p2.weapon_slots.size()], p2.weapon_slots.size() == before_w + 1)
	# ---------------- fighting
	print("--- fighting")
	var dummy1 = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	dummy1.position = p1.global_position + Vector2(25, 0)
	world.get_node("Enemies").add_child(dummy1)
	dummy1.set_physics_process(false)
	dummy1.get_node("NavigationTimer").stop()
	dummy1.max_health = 40.0; dummy1.health = 40.0
	var dummy2 = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	dummy2.position = p2.global_position + Vector2(-25, 0)
	world.get_node("Enemies").add_child(dummy2)
	dummy2.set_physics_process(false)
	dummy2.get_node("NavigationTimer").stop()
	dummy2.max_health = 40.0; dummy2.health = 40.0
	# player 1 aims right and attacks with RT; player 2 aims left and attacks with RT
	axis(1, JOY_AXIS_RIGHT_X, 1.0)
	axis(2, JOY_AXIS_RIGHT_X, -1.0)
	await wait(0.3)
	for k in 4:
		axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		axis(2, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		await wait(0.2)
		axis(1, JOY_AXIS_TRIGGER_RIGHT, -1.0)
		axis(2, JOY_AXIS_TRIGGER_RIGHT, -1.0)
		await wait(0.5)
	axis(1, JOY_AXIS_RIGHT_X, 0.0)
	axis(2, JOY_AXIS_RIGHT_X, 0.0)
	print("  dummy hp: p1's %.1f  p2's %.1f (of 40)" % [dummy1.health, dummy2.health])
	ok("player 1 hit the enemy on their right with controller 1", dummy1.health < 40.0)
	ok("player 2 hit the enemy on their left with controller 2", dummy2.health < 40.0)
	# ---------------- towers, cards
	print("--- towers and cards")
	var t1 = game.all_towers()[1]
	var t2 = game.all_towers()[2]
	p1.global_position = t1.global_position + Vector2(0, 14)
	t1.get_node("EnterArea").open = true
	p2.global_position = t2.global_position + Vector2(0, 14)
	await wait(0.4)
	await tap(1, JOY_BUTTON_A)
	await wait(0.3)
	pad._scan_clock = 0.0
	await wait(0.2)
	ok("A enters a tower for player 1 (pad mode %s)" % pad.mode, p1.is_in_tower and pad.mode == "keep")
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	ok("A enters a different tower for player 2", p2.is_in_tower and game.current_tower(p2) == t2 and game.current_tower(p1) == t1)
	p1.global_position = t1.global_position - Vector2(0, 10)
	game.hand = ["fireball", "frost_ring", "barricade"]
	game.mana = 100.0
	game.hand_changed.emit()
	await wait(0.3)
	var kui = lp.keep_uis[1]
	await tap(2, JOY_BUTTON_RIGHT_SHOULDER)
	ok("player 2: RB picks a card (sel %d)" % kui.sel, kui.sel == 0)
	var hand_n: int = game.hand.size()
	axis(2, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.25)
	axis(2, JOY_AXIS_TRIGGER_RIGHT, -1.0)
	await wait(0.2)
	ok("player 2: RT casts it from the shared hand (%d -> %d)" % [hand_n, game.hand.size()], game.hand.size() == hand_n - 1)
	await tap(1, JOY_BUTTON_RIGHT_SHOULDER)
	await wait(0.2)
	hand_n = game.hand.size()
	axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.25)
	axis(1, JOY_AXIS_TRIGGER_RIGHT, -1.0)
	await wait(0.2)
	print("  hand now ", game.hand)
	ok("player 1: RB then RT casts a card too (%d -> %d)" % [hand_n, game.hand.size()], game.hand.size() == hand_n - 1)
	# only one person per tower
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	ok("A leaves the tower for player 2", !p2.is_in_tower)
	p2.global_position = t1.global_position + Vector2(0, 28)
	await wait(0.3)
	await tap(2, JOY_BUTTON_A)
	ok("two steps away from the tower, A does not enter it", !p2.is_in_tower)
	p2.global_position = t1.global_position + Vector2(0, 14)
	await wait(0.3)
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	ok("player 2 cannot enter player 1's tower", !p2.is_in_tower)
	await tap(1, JOY_BUTTON_A)
	await wait(0.3)
	pad._scan_clock = 0.0
	await wait(0.2)
	ok("A leaves the tower for player 1 (pad mode %s)" % pad.mode, !p1.is_in_tower and pad.mode == "all")
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	ok("the freed tower accepts player 2", p2.is_in_tower and game.current_tower(p2) == t1)
	await tap(2, JOY_BUTTON_A)
	await wait(0.3)
	# ---------------- forge
	print("--- forge")
	game.resources.gold = 99; game.resources.stone = 99; game.resources.stick = 99
	game.note_weapon_tier("hammer", 2)
	p2.weapon_slots.clear()
	net.give_weapon(p2, "hammer")
	net.give_weapon(p2, "hammer")
	p2.global_position = net.FORGE_POS + Vector2(8, 0)
	await wait(0.3)
	var fui = lp.forge_uis[1]
	await tap(2, JOY_BUTTON_DPAD_UP)
	ok("d-pad up at the anvil opens player 2's forge", fui.is_open)
	var cur0: int = fui.cur
	await tap(2, JOY_BUTTON_RIGHT_SHOULDER)
	ok("RB does not move the Forge cursor (it is for the hand's cards)", fui.cur == cur0)
	axis(2, JOY_AXIS_LEFT_X, 1.0)
	await wait(0.2)
	axis(2, JOY_AXIS_LEFT_X, 0.0)
	await wait(0.1)
	ok("the left stick does (cursor %d -> %d)" % [cur0, fui.cur], fui.cur != cur0)
	axis(2, JOY_AXIS_LEFT_X, -1.0)
	await wait(0.2)
	axis(2, JOY_AXIS_LEFT_X, 0.0)
	await wait(0.1)
	await tap(2, JOY_BUTTON_A)
	await tap(2, JOY_BUTTON_DPAD_RIGHT)
	await tap(2, JOY_BUTTON_A)
	await tap(2, JOY_BUTTON_X)
	await wait(0.3)
	ok("two hammers fused into one tier 2 hammer", p2.weapon_slots.size() == 1 and game.weapon_tier_of(p2.weapon_slots[0]) == 2)
	await tap(2, JOY_BUTTON_B)
	# ---------------- card fuser
	print("--- card fuser")
	game.hand = ["torch", "sentry", "fireball"]
	p2.global_position = net.CARD_FUSER_POS + Vector2(8, 0)
	await wait(0.3)
	var zui = lp.fuser_uis[1]
	await tap(2, JOY_BUTTON_DPAD_UP)
	ok("d-pad up at the Card Fuser opens player 2's screen", zui.is_open)
	await tap(2, JOY_BUTTON_A)
	await tap(2, JOY_BUTTON_DPAD_RIGHT)
	await tap(2, JOY_BUTTON_A)
	await tap(2, JOY_BUTTON_X)
	await wait(0.3)
	ok("torch + sentry fused into a Beacon Turret by player 2 (%s)" % str(game.hand), game.hand.size() == 2 and game.hand.any(func(h): return game.entry_id(h) == "beacon_turret"))
	await tap(2, JOY_BUTTON_B)
	ok("B closes it", !zui.is_open)
	# ---------------- pause
	print("--- pause")
	await tap(1, JOY_BUTTON_START)
	await wait(0.3)
	ok("Start on controller 1 pauses", paused)
	await tap(2, JOY_BUTTON_START)
	await wait(0.3)
	ok("Start on controller 2 resumes", !paused)
	# ---------------- damage
	print("--- damage")
	p2.shield_time = 0.0
	var hp_before: float = p2.remote_hp
	p2.take_damage(p2.global_position + Vector2(10, 0))
	await wait(0.2)
	ok("player 2 takes damage like a co-op player (%.0f -> %.0f)" % [hp_before, p2.remote_hp], p2.remote_hp < hp_before)
	var fails := 0
	for r in results:
		if !r: fails += 1
	print("RESULT: %d checks, %d failed" % [results.size(), fails])
	quit()

extends SceneTree
# A narrated, slow playtest you can WATCH in a window:
#   Godot --path . --script res://tools/tests/watch_playtest.gd
# PLAYTEST_SPEED=0.1 (environment) runs it fast, e.g. headless as a smoke test.
var world
var player
var game
var cap: Label
var speed := 1.0
func wait(sec: float) -> void:
	await create_timer(sec * speed, true, false, true).timeout
func say(text: String, secs := 2.5) -> void:
	cap.text = text
	print("PLAYTEST: ", text)
	await wait(secs)
func help_panel(on: bool) -> void:
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = on
func walk_to(target: Vector2, aim_at := Vector2.INF, max_secs := 8.0) -> void:
	var t := 0.0
	player.remote_controlled = true
	while t < max_secs * speed and player.global_position.distance_to(target) > 6.0:
		var d: Vector2 = target - player.global_position
		player.remote_input = {"move": d.normalized(), "aim": (aim_at if aim_at != Vector2.INF else player.global_position + d), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await create_timer(0.05, true, false, true).timeout
		t += 0.05
	player.remote_input = {"move": Vector2.ZERO, "aim": (aim_at if aim_at != Vector2.INF else player.global_position + Vector2(40, 0)), "attack": false, "ability": false, "dash": false, "ultimate": false}
func face(p: Vector2) -> void:
	player.remote_controlled = true
	player.remote_input = {"move": Vector2.ZERO, "aim": p, "attack": false, "ability": false, "dash": false, "ultimate": false}
func swing(at: Vector2) -> void:
	face(at)
	if player.item != null:
		player.item.use_item()
		player.is_using_item = true
func nearest(group: String, from: Vector2, skip_boss := true):
	var best = null
	for e in get_nodes_in_group(group):
		if !is_instance_valid(e) or e.is_queued_for_deletion() or (skip_boss and e.is_in_group("boss")) or !e.visible: continue
		if best == null or e.global_position.distance_to(from) < best.global_position.distance_to(from): best = e
	return best
## Chase the nearest enemy and attack, for a number of (game) seconds.
func fight(secs: float, use_moves := true) -> void:
	var t := 0.0
	var n := 0
	while t < secs * speed:
		var e = nearest("enemy", player.global_position)
		if e == null: break
		var d: Vector2 = e.global_position - player.global_position
		face(e.global_position)
		if d.length() > 22.0:
			player.remote_input.move = d.normalized()
		else:
			swing(e.global_position)
			n += 1
			if use_moves and n % 6 == 0: player.item.use_ability()
			if use_moves and n % 14 == 0: player.item.use_dash()
		await create_timer(0.15, true, false, true).timeout
		t += 0.15
	face(player.global_position + Vector2(40, 0))
func _initialize() -> void:
	game = root.get_node("Game")
	speed = float(OS.get_environment("PLAYTEST_SPEED")) if OS.get_environment("PLAYTEST_SPEED") != "" else 1.0
	game.save_path = "user://watch_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://watch_save.json"))
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await create_timer(1.2, true, false, true).timeout
	world.get_node("SpawnTimer").start(9999.0)
	player = world.get_node("Player")
	game.meta.hints_enabled = false
	game.meta.card_tiers = {"fireball": 4, "frost_ring": 4, "barricade": 4, "spike_trap": 4, "sentry": 4}
	if !("sentry" in game.unlocked_cards): game.unlocked_cards.append("sentry")
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	cap = Label.new()
	cap.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cap.offset_top = 70
	cap.offset_left = -500
	cap.offset_right = 500
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 28)
	cap.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", 8)
	layer.add_child(cap)
	var info = world.get_node("Collectable").item_info
	# ---- 1. a new player
	player.equip_item(game.weapon_info("sword"))
	await say("A new run: you start with only the free Sword. The controls panel explains the keys.", 4.0)
	help_panel(false)
	player.global_position = Vector2(0, 90)
	await say("Gather stone and sticks from rocks and trees with your weapon (the Pickaxe breaks areas).", 2.5)
	var rock = nearest("breakable", player.global_position)
	if rock != null:
		await walk_to(rock.global_position + Vector2(0, 14), rock.global_position, 12.0)
		for i in 8:
			swing(rock.global_position)
			await wait(0.5)
	# ---- 2. weapon tiers
	await say("Tier 1 Sword: Slash and Slash Dash. Right-click and Space are locked (padlocks, bottom right).", 3.5)
	player.item.use_ability()
	await say("Locked moves tell you which tier they need.", 2.5)
	player.equip_item(game.weapon_info("sword:1"))
	await say("Tier 2 Sword (two copies combined at the Forge): Whirlwind is unlocked.", 2.0)
	world.spawn_enemies([{"name": "blobbert", "amount": 4, "level": 1}, {"name": "goblin", "amount": 3, "level": 1}])
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.global_position = player.global_position + Vector2(randf_range(-110, 110), randf_range(110, 170))
	await say("A wave arrives. Fighting with Slash, Slash Dash and Whirlwind.", 1.0)
	await fight(14.0)
	# ---- 3. pickaxe mining
	player.equip_item(game.weapon_info("pickaxe:2"))
	await say("Tier 3 Pickaxe: Seismic Strike mines a whole area of rocks and trees.", 2.0)
	var r2 = nearest("breakable", player.global_position)
	if r2 != null:
		await walk_to(r2.global_position + Vector2(0, 40), r2.global_position, 10.0)
		player.item.use_ability()
		await wait(3.0)
		await say("Earthquake (Space) shakes everything nearby.", 1.5)
		player.item.use_ultimate()
		await wait(3.5)
	# ---- 4. the keep: cards
	player.equip_item(game.weapon_info("sword"))
	await say("Into the keep: cards are drawn from two decks, spells and buildings.", 1.0)
	await walk_to(Vector2(0, 40), Vector2.INF, 10.0)
	player.remote_controlled = false
	game.enter_base(player)
	player.is_in_tower = true
	game.mana = 100
	game.resources = {"stone": 30, "stick": 30, "gold": 30}
	game.hand = []
	game.add_to_hand("fireball:2:twin")
	game.add_to_hand("frost_ring")
	game.add_to_hand("barricade")
	game.add_to_hand("sentry")
	game.hand_changed.emit()
	await say("Your hand: a tier 2 Fireball with the Twin twist, a Frost Ring, a Barricade and a Sentry.", 4.0)
	world.spawn_enemies([{"name": "brute", "amount": 2, "level": 1}, {"name": "scarab", "amount": 5, "level": 1}])
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.global_position = Vector2(randf_range(-90, 90), randf_range(200, 260))
	await say("Building cards cost materials and stay on the map.", 1.0)
	game.hand = ["barricade"]
	game.cast("barricade", Vector2(-30, 150), player)
	await wait(1.5)
	game.hand = ["sentry"]
	game.cast("sentry", Vector2(30, 150), player)
	await wait(1.5)
	await say("Two of the same card merge: here two Barricades side by side become tier 2.", 1.0)
	game.hand = ["barricade"]
	game.cast("barricade", Vector2(-30, 150), player)
	await wait(3.0)
	await say("Spells cost mana. Fireball (tier 2, Twin) casts twice at the brutes.", 1.0)
	var tgt = nearest("enemy", Vector2(0, 220))
	if tgt != null:
		game.hand = ["fireball:2:twin"]
		game.cast("fireball:2:twin", tgt.global_position, player)
	await wait(3.5)
	game.hand = ["frost_ring"]
	var tgt2 = nearest("enemy", Vector2(0, 220))
	if tgt2 != null: game.cast("frost_ring", tgt2.global_position, player)
	await say("Frost Ring slows what walks into it. Fast enemies take extra damage while slowed.", 5.0)
	# ---- 4b. night
	await say("Night comes slowly (a full day is 5 minutes) with one wave by day and one by night, well apart.", 3.5)
	world.clock = 205.0
	await say("At night, enemies in the dark are shrouded: they take less damage and your towers cannot see them.", 4.0)
	game.resources = {"stone": 30, "stick": 30, "gold": 30}
	game.hand = ["torch"]
	game.cast("torch", Vector2(0, 150), player)
	await say("A Torch (a free starter card) lights the ground around it and lets sentries see.", 4.0)
	world.clock = 205.0
	game.mana = 100
	var dark_enemy = nearest("enemy", Vector2(0, 220))
	if dark_enemy != null:
		game.hand = ["flare"]
		game.cast("flare", dark_enemy.global_position, player)
	await say("A Flare floods an area with light, and the fireball glows too. Night cards are drawn more often at night.", 6.0)
	world.clock = 20.0
	# ---- 5. chest
	await say("Chests pay out better the deeper you are. Choose a card (tier and twist shown).", 1.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for id in ["se", "ne", "n"]: sm.unlock(id)          # open realms the way the game does, so chests and sheep match a real run
	game.start_draft(0)
	await wait(7.0)
	if game.draft_active and game.draft_options.size() > 0:
		game.take_draft_card(game.draft_options[0])
	await wait(1.5)
	# ---- 6. rainbow sheep
	player.is_in_tower = false
	game.exit_base(player)
	player.remote_controlled = true
	player.global_position = Vector2(0, 90)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	var well = world.get_node("Well")
	if well.get_node("Crystal").state != "home": well.return_crystal()
	await say("A rainbow sheep! Kill it before it escapes: it drops a weapon and often a better chest.", 2.0)
	var spawner = null
	for c in world.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("critter_spawner.gd"): spawner = c
	var sheep = spawner.spawn_sheep()          # the game's own spawn: an open spot somewhere in an unlocked sector
	player.global_position = sheep.global_position + Vector2(-50, 10)
	await wait(1.5)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("user://watch_sheep.png")
	await wait(1.0)
	var guard := 0
	while is_instance_valid(sheep) and !sheep.dead and guard < 120:
		guard += 1
		var d: Vector2 = sheep.global_position - player.global_position
		face(sheep.global_position)
		if d.length() > 22.0:
			player.remote_input.move = d.normalized()
		else:
			swing(sheep.global_position)
			if guard % 4 == 0: player.item.use_ability()
		await create_timer(0.15, true, false, true).timeout
	if is_instance_valid(sheep) and !sheep.dead: sheep._hurt(999.0)
	await say("Loot: gold, resources, a weapon and sometimes a card chest.", 4.0)
	# ---- 7. end of run
	await say("The run ends when the keep falls. Here is the Shard payout and reward screen.", 2.5)
	game.run_stats = {"kills": 25, "gold": 50, "waves": 3, "bosses": 0}
	game.end_run("Playtest ended")
	await wait(14.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://watch_save.json"))
	print("PLAYTEST: done")
	quit()

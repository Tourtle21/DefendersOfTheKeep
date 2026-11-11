extends SceneTree
## A slow, watchable run of the keep's cards for 2 players in a real window: the starting hand, each player casting from the
## shared hand, each player's chest (a pause before choosing), copies in the deck row, and a merge. Each step is held HOLD
## seconds (hold=<s>, default 5); the window stays open at the end until you close it.
var HOLD := 5.0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func scripted(world, f: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(f): return c
	return null
func step(label: String) -> void:
	print("=== ", label)
	await wait(HOLD)
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hold="): HOLD = float(a.substr(5))
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://cardtour_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	game.fix_meta()
	for id in ["aegis", "spike_trap", "flare", "sentry"]:
		if !(id in game.meta.unlocked):
			game.meta.unlocked.append(id)
	game.meta.card_tiers["fireball"] = 2                  # so a pair of Fireballs can combine
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(2.0)
	world.get_node("SpawnTimer").start(9999.0)
	game.start_run()
	var lp = scripted(world, "local_players.gd")
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	var towers: Array = game.all_towers()
	for t in towers:
		t.visible = true
	p1.global_position = towers[0].global_position + Vector2(0, 14)
	p2.global_position = towers[mini(1, towers.size() - 1)].global_position + Vector2(0, 14)
	await wait(0.5)
	net._set_base(p1, true)
	net._set_base(p2, true)
	game.resources = {"stone": 40, "stick": 40, "gold": 40}
	game.hand = [game.make_entry("frost_ring", 1, ""), game.make_entry("frost_ring", 1, ""), game.make_entry("fireball", 1, ""), game.make_entry("torch", 1, "")]
	game.hand_changed.emit()
	await step("0. MANA: the run starts with %.0f mana (cap %.0f), regenerating %.1f per second" % [game.mana, game.max_mana(), game.mana_regen()])
	await step("1. START: both players are in the keep and share one hand of cards (%s)" % str(game.hand))
	for who in [[p1, "PLAYER 1", Vector2(220, 120)], [p2, "PLAYER 2", Vector2(-220, 120)]]:
		var spell: String = ""
		for e in game.hand:
			if !game.is_build(game.entry_id(e)):
				spell = e
				break
		while !game.can_cast(spell):
			print("   waiting for mana: %.0f / %.0f needed" % [game.mana, game.CARDS[game.entry_id(spell)].mana])
			await wait(3.0)
		await step("%s is about to cast %s (mana %.0f)" % [who[1], spell, game.mana])
		game.cast(spell, who[2], who[0])
		await step("%s cast it: the card left the shared hand, the deck still holds it (mana now %.0f)" % [who[1], game.mana])
	game._draw_time = 99.0
	await step("the keep draws a replacement card while they are inside")
	# chests: a pair of Fireballs in the hand so the x2 and Combine show
	game.hand = [game.make_entry("fireball", 1, ""), game.make_entry("fireball", 1, ""), game.make_entry("flare", 1, ""), game.make_entry("sentry", 1, "")]
	game.deck["fireball"] = 2
	game.hand_changed.emit()
	game.deck_changed.emit()
	net._set_base(p1, false)
	net._set_base(p2, false)
	for s in 2:
		game.draft_owner_slot = s
		game.draft_active = false
		game.start_draft()
		await step("CHEST for player %d: 3 cards to choose from and your whole deck with copies held (a Combine button when a pair can go up)" % (s + 1))
		if s == 0:
			game.merge_hand(0, 1)
			await step("PLAYER 1 combined the pair of Fireballs into one Tier 2 card")
		var pick: String = game.draft_options[0]
		await step("player %d is about to take %s" % [s + 1, game.entry_id(pick)])
		game.take_draft_card(pick)
		await step("player %d took it: it is in the deck now (copy count went up)" % (s + 1))
	game.draft_owner_slot = 0
	print("=== finished; close the window when done")
	await wait(600.0)
	quit()

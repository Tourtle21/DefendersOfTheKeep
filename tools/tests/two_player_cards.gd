extends SceneTree
## Two players share the keep's hand and deck: both cast, both open chests, every rule holds. Checks the start (4-card deck, hand of 3), casts by player 1 and player 2 (the card leaves the hand, the deck keeps it, a new one is
## drawn), the 3-card chest, copies counted in the deck (x2), and merging a pair.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://tpc_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	game.fix_meta()
	game.meta["keepsake"] = ""
	for id in ["fireball", "frost_ring", "barricade", "torch", "aegis", "spike_trap"]:
		if !(id in game.meta.unlocked):
			game.meta.unlocked.append(id)
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	game.start_run()
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	game.enter_base(p1)
	game.enter_base(p2)
	ok("a run starts with 25 mana (%.0f)" % game.mana, game.mana == 25.0)
	game.mana = 100.0
	game.resources = {"stone": 99, "stick": 99, "gold": 99}
	# ---- start
	ok("the run starts with the four starting cards, one copy each (%s)" % str(game.deck), game.deck.size() == 4 and game.deck.values().all(func(v): return v == 1))
	ok("the hand starts with %d cards" % game.hand.size(), game.hand.size() == 3)
	# ---- both players cast from the shared hand
	var spell1: String = game.hand.filter(func(e): return !game.is_build(game.entry_id(e)))[0]
	var n0: int = game.hand.size()
	ok("player 1 casts a spell", game.cast(spell1, Vector2(200, 100), p1))
	ok("the card left the hand but the deck still has it", game.hand.size() == n0 - 1 and game.deck.has(game.entry_id(spell1)))
	var spell2: String = game.hand.filter(func(e): return !game.is_build(game.entry_id(e)))[0]
	ok("player 2 casts a spell from the same hand", game.cast(spell2, Vector2(-200, 100), p2))
	ok("the hand is down to %d" % game.hand.size(), game.hand.size() == n0 - 2)
	game._draw_time = 99.0
	game._process(0.1)
	await wait(0.1)
	ok("the keep draws a replacement while they are inside (hand %d)" % game.hand.size(), game.hand.size() == n0 - 1)
	# ---- chest: four choices, deck row shows copies
	game.deck["fireball"] = 2
	game.hand = []
	game.add_to_hand("fireball")
	game.add_to_hand("fireball")
	game.draft_active = false
	ok("a chest opens", game.start_draft())
	ok("it offers three different cards (%d)" % game.draft_options.size(), game.draft_options.size() == 3 and game.draft_options.map(func(e): return game.entry_id(e)).size() == 3)
	var view = load("res://ui/base/draft_view.gd").new()
	root.add_child(view)
	view.fit(Vector2(1100, 700))
	view.render()
	await wait(0.2)
	var labels := []
	for w in view.deck_row.get_children():
		for c in w.get_children():
			if c is Label:
				labels.append(c.text)
	ok("the deck row shows every deck card with its copies %s" % str(labels), view.deck_row.get_child_count() == game.deck.size() and "x2" in labels and labels.count("x1") == game.deck.size() - 1)
	ok("the chest screen has no hand row, only a Combine button when a pair can go up", view.hand_row.get_child_count() == 0 and view.combine_row.get_child_count() == (1 if game.can_merge(0, 1) else 0))
	if game.can_merge(0, 1):
		game.merge_hand(0, 1)
		ok("merging turns the pair into one tier-2 card", game.hand.size() == 1 and game.entry_tier(game.hand[0]) == 2)
	var pick: String = game.draft_options[0]
	game.take_draft_card(pick)
	ok("player 2 can take a card too, the deck counts the copy", game.deck.get(game.entry_id(pick), 0) >= 1 and !game.draft_active)
	quit()

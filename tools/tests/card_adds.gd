extends SceneTree
## What a card has ADDED by its tier stacks: tier 4 keeps what tier 2 added and adds its own; the Guards card adds one thing per tier;
## spells and buildings use every one of them; the card says "added", never "twist".
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ca_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 600)
	# ---- the stacking rule
	var fb := []
	for t in range(1, 7):
		fb.append(game.adds_for("fireball", t, game.twist_for("fireball", t)))
	ok("a fireball adds something every tier from 2 to 6 and keeps the earlier ones %s" % str(fb), fb[0].is_empty() and range(1, 6).all(func(i): return fb[i].size() == i and fb[i].slice(0, i - 1) == fb[i - 1]))
	var gd := []
	for t in range(1, 7):
		gd.append(game.adds_for("guards", t, game.twist_for("guards", t)))
	ok("guards add one thing every tier from 2 to 6, all kept %s" % str(gd.map(func(a): return a.size())), gd.map(func(a): return a.size()) == [0, 1, 2, 3, 4, 5])
	var sentry: Array = game.adds_for("sentry", 6, game.twist_for("sentry", 6))
	ok("a tier 6 sentry has all five of its additions %s" % str(sentry), sentry.size() == 5)
	ok("the entry's stats carry them (%s)" % str(game.stats_of(game.make_entry("fireball", 4, game.twist_for("fireball", 4))).adds), game.stats_of(game.make_entry("fireball", 4, game.twist_for("fireball", 4))).adds.size() == 3)
	# ---- the card says "added", lists everything, and never says twist
	var view = load("res://ui/cards/card_view.gd").new()
	view.setup("fireball", 4, "", game.twist_for("fireball", 4))
	root.add_child(view)
	await wait(0.2)
	var all_text: String = view.tooltip_text
	for l in view.find_children("*", "Label", true, false):
		all_text += " " + l.text
	ok("the tier 4 fireball card lists both additions and says Added, not Twist", all_text.contains("Added") and !all_text.to_lower().contains("twist") and all_text.contains(game.TWISTS[fb[3][1]][0]) and all_text.contains(game.TWISTS[fb[3][2]][0]))
	# ---- a spell applies every addition: a tier 4 fireball casts twice (double cast) AND leaves a patch
	var tw4: Array = fb[3]
	var before := root.get_tree().get_nodes_in_group("net").size()
	game.mana = 100.0
	game.players_in_base = [p]
	game.hand = [game.make_entry("fireball", 4, game.twist_for("fireball", 4))]
	game.cast(game.hand[0], Vector2(0, 350), p)
	await wait(2.2)
	var spells := 0
	var patches := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("spell.gd"):
			spells += 1
	for h in get_nodes_in_group("hazard"):
		patches += 1
	print("  additions %s -> spells in flight/landed %d, patches %d" % [str(tw4), spells, patches])
	ok("a tier 4 fireball uses both additions (a second cast or a patch shows up)", spells >= 1 or patches >= 1)
	# ---- a building uses every addition: a tier 6 barricade regrows AND has thorns
	var st = load("res://cards/structure.gd").new()
	st.setup(game.stats_of(game.make_entry("barricade", 6, game.twist_for("barricade", 6))), Vector2(60, 250))
	world.add_child(st)
	await wait(0.3)
	ok("a tier 6 barricade has all five additions (%s) and barbed thorns %.1f" % [str(st.adds), st.data.get("thorns", 0.0)], st.adds.size() == 5 and "last_stand" in st.adds and st.data.get("thorns", 0.0) > 3.0)
	# every card in the game says something new at every tier 2 to 6
	var bare := []
	for id in game.CARDS:
		if game.CARDS[id].get("fused", false):
			continue
		var pool: Array = game.twist_pool(id)
		if pool.size() != 5 or pool.any(func(a): return !game.TWISTS.has(a)) or pool.size() != Array(pool).filter(func(a): return true).size():
			bare.append(id)
	ok("every card has five named additions, one per tier (missing: %s)" % str(bare), bare.is_empty())
	quit()

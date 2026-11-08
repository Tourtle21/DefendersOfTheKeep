extends SceneTree
# The unlocked tier is the ceiling: cards start at tier 1, drafts and merging cannot pass it, awakening is capped by fusion tiers.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.card_tiers = {}
	game.meta.fusion_tiers = []
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "sentry"]
	game.meta.card_tiers = {"fireball": 3, "sentry": 2}
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	game.start_run()
	print("new run: deck levels ", game.deck, " (unlocked tiers: fireball 3, sentry 2, others 1)")
	game.unlocked_cards = game.meta.unlocked.duplicate()
	# chest drafts: only cards that can still grow
	for i in 6:
		game.draft_active = false
		var ok: bool = game.start_draft()
		var opts: Array = game.draft_options.duplicate()
		if ok:
			game.take_draft_card("fireball" if "fireball" in opts else opts[0])
	print("after 6 drafts: ", game.deck, " | fireball stops at its unlocked tier 3: ", game.deck.get("fireball") == 3)
	var offered_capped := false
	game.draft_active = false
	if game.start_draft():
		offered_capped = "fireball" in game.draft_options or "frost_ring" in game.draft_options
	print("draft still offers capped cards (should be false): ", offered_capped)
	game.draft_active = false
	# merging buildings
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.resources = {"stone": 50, "stick": 50, "gold": 50}
	var tiers := []
	for i in 6:
		game.hand = ["sentry"]
		game.cast("sentry", Vector2(0, 330), player)
		await wait(1.0)
		var best := 0
		for st in get_nodes_in_group("structure"):
			if st.global_position.distance_to(Vector2(0, 330)) < 30.0: best = maxi(best, st.tier)
		tiers.append("[%d casts: highest tier %d, %d structures]" % [i + 1, best, get_nodes_in_group("structure").size()])
	print("sentry (unlocked to tier 2) cast 6 times on one spot: ", " ".join(tiers), " -> tier 1+1 = 2, then a pair of tier 1s is needed again; tier 2+2 would make 3 but the unlocked tier is the ceiling")
	# weapon copies are capped by the fusion tiers you own
	game.meta.fusion_tiers = []
	var cur := "spear"
	var steps := 0
	while game.combine_weapons(cur, cur) != "":
		cur = game.combine_weapons(cur, cur)
		steps += 1
	print("spear combined ", steps, " times, tier ", game.weapon_tier_of(cur), " (cap ", game.weapon_tier_cap(), " with no fusion tiers bought)")
	game.meta.shards = 500
	game.buy_fusion_tier(3)
	print("after buying Tier 3 fusions the cap is ", game.weapon_tier_cap(), "; combine once more: ", game.combine_weapons(cur, cur) != "")
	game.buy_fusion_tier(4)
	print("after Tier 4 fusions: cap ", game.weapon_tier_cap())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

extends SceneTree
# Pacing check: a brand-new player takes many runs and spends Shards greedily (cheapest useful thing first).
# Shows how fast cards, tiers and weapons actually open up. Two player profiles: casual and strong.
func fresh(game) -> void:
	game.meta = {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 0,
		"unlocked": ["fireball", "frost_ring", "barricade", "spike_trap"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
func spend(game, log: Array) -> void:
	for guard in 60:
		var best := {}
		var best_cost := 1 << 30
		for e in game.meta.pending:
			if e.result == "offer" and e.cost < best_cost and e.cost <= game.meta.shards:
				best = {"kind": "offer", "e": e}
				best_cost = e.cost
		for id in game.meta.unlocked:
			var c: int = game.card_upgrade_cost(id)
			if game.card_tier(id) < 6 and c < best_cost and c <= game.meta.shards:
				best = {"kind": "up", "id": id}
				best_cost = c
		for w in game.WEAPON_UNLOCK_COSTS:
			if !(w in game.meta.weapons) and game.WEAPON_LEVEL[w] <= int(game.meta.get("best_level", 1)) and game.WEAPON_UNLOCK_COSTS[w] < best_cost and game.WEAPON_UNLOCK_COSTS[w] <= game.meta.shards:
				best = {"kind": "wep", "id": w}
				best_cost = game.WEAPON_UNLOCK_COSTS[w]
		if best.is_empty():
			return
		match best.kind:
			"offer":
				var e: Dictionary = best.e
				if game.unlock_offer(e): log.append("%s %s" % [e.kind, e.id])
			"up":
				game.upgrade_card(best.id)
				log.append("%s T%d" % [best.id, game.card_tier(best.id)])
			"wep":
				game.buy_weapon(best.id)
				log.append("weapon " + best.id)
func play(game, name: String, level_for_run: Callable, runs: int) -> void:
	fresh(game)
	print("=== ", name)
	var first := {}
	var total_upgrades := 0
	var chain = ["s", "se", "ne", "n", "nw", "sw"]
	for r in range(1, runs + 1):
		var lvl: int = level_for_run.call(r)
		game.sectors_unlocked = chain.slice(0, lvl)
		game.run_stats = {"kills": 25 * lvl, "gold": 50 * lvl, "waves": 3 * lvl, "bosses": lvl - 1}
		game.meta["best_level"] = maxi(int(game.meta.get("best_level", 1)), lvl)
		var earned: int = game.shards_for_run()
		game.meta.shards += earned
		var rewards: Array = game.make_rewards()
		var gained := 0
		for e in rewards: gained += int(e.get("shards", 0))
		var log := []
		spend(game, log)
		var tiers := 0
		for id in game.meta.unlocked: tiers += game.card_tier(id) - 1
		print("run %2d lvl %d | +%3d shards (+%d from converts) | bank %3d | cards %2d (tier ups %2d) weapons %d pending %d | bought: %s" % [r, lvl, earned, gained, game.meta.shards, game.meta.unlocked.size(), tiers, game.meta.weapons.size(), game.meta.pending.size(), ", ".join(log)])
		if !first.has("weapon") and game.meta.weapons.size() > 0: first.weapon = r
		if !first.has("tier2") and tiers > 0: first.tier2 = r
		if !first.has("newcard") and game.meta.unlocked.size() > 4: first.newcard = r
		if !first.has("tier3") and game.meta.card_tiers.values().any(func(t): return t >= 3): first.tier3 = r
		if !first.has("tier4") and game.meta.card_tiers.values().any(func(t): return t >= 4): first.tier4 = r
	print("first weapon: run ", first.get("weapon", "never"), " | first new card: run ", first.get("newcard", "never"), " | first tier 2: run ", first.get("tier2", "never"), " | first tier 3: run ", first.get("tier3", "never"), " | first tier 4: run ", first.get("tier4", "never"))
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	await process_frame
	play(game, "casual: dies around level 1-2, slowly gets deeper", func(r): return clampi(1 + r / 6, 1, 6), 24)
	play(game, "strong: opens a new realm every ~2 runs", func(r): return clampi(1 + r / 2, 1, 6), 24)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

extends SceneTree
# Duplicates of cards you own become spare copies: merge (same tier -> next tier), combine a pair, or sell.
func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var chain = ["s", "se", "ne", "n", "nw", "sw"]
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {"fireball": 1}
	game.meta.pending = []
	game.meta.shards = 0
	game.meta["best_level"] = 3
	var spare := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending.append(spare)
	print("sell value of a tier 1 / tier 3 copy: ", game.spare_sell_value(spare), " / ", game.spare_sell_value({"tier": 3, "realm": 1}))
	print("merge a tier 1 copy into a tier 1 card: ", game.spare_merge(spare), " -> card tier ", game.card_tier("fireball"), " | vault ", game.meta.pending.size())
	var s2 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending.append(s2)
	print("a tier 1 copy no longer fits a tier 2 card: can merge ", game.spare_can_merge(s2))
	var s3 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending.append(s3)
	print("two tier 1 spares: pair found ", !game.spare_pair(s2).is_empty(), " | combine ", game.spare_combine(s2), " -> spare tier ", s2.tier, " | vault ", game.meta.pending.size())
	print("the combined tier 2 copy merges into the tier 2 card: ", game.spare_merge(s2), " -> card tier ", game.card_tier("fireball"))
	var s4 := {"kind": "card", "id": "fireball", "tier": 3, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending.append(s4)
	print("at the level cap (deepest level 3): can merge a tier 3 copy ", game.spare_can_merge(s4), " (a tier 3 card needs a deeper run to go higher)")
	game.meta["best_level"] = 6
	print("after reaching level 6: can merge ", game.spare_can_merge(s4))
	var before: int = game.meta.shards
	var s5 := {"kind": "card", "id": "barricade", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending.append(s5)
	print("sell: +", game.spare_sell(s5), " Shards | total ", game.meta.shards - before, " | vault ", game.meta.pending.size())
	# rewards: a fully upgraded collection makes spares, not Shards
	game.meta.card_tiers = {}
	for id in game.CARDS:
		if !game.is_legendary_card(id):
			if !(id in game.meta.unlocked): game.meta.unlocked.append(id)
			game.meta.card_tiers[id] = 6
	game.meta.pending = []
	game.sectors_unlocked = chain.slice(0, 6)
	game.run_stats = {"kills": 0, "gold": 0, "waves": 5, "bosses": 0}
	var r: Array = game.make_rewards()
	var kinds := {}
	for e in r: kinds[e.result] = kinds.get(e.result, 0) + 1
	print("rewards for a fully upgraded collection: ", kinds, " | vault now ", game.meta.pending.size())
	# survives the vault and a save
	game.save_meta()
	game.meta.pending = game.meta.pending.duplicate(true)
	print("spares survive in the vault: ", game.meta.pending.filter(func(e): return e.result == "spare").size())
	# a full vault sells instead
	game.meta.pending = []
	for i in game.MAX_PENDING:
		game.meta.pending.append({"kind": "card", "id": "fireball", "tier": 6, "realm": 1, "result": "spare", "shards": 0})
	var r2: Array = game.make_rewards()
	print("vault full: ", r2.map(func(e): return e.result).filter(func(x): return x == "converted").size(), " of ", r2.size(), " rewards were sold straight away")
	quit()

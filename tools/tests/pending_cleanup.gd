extends SceneTree
## Unlocking or selling a reward takes it off the waiting list; stale "unlocked"/"converted" leftovers in a save are purged.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://pc_test_save.json"
	game.meta = {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 500, "unlocked": ["fireball", "frost_ring", "barricade", "spike_trap", "torch"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
	game.unlocked_cards = game.meta.unlocked.duplicate()
	game.sectors_unlocked = ["s", "se", "ne"]
	game.run_stats.waves = 5
	var rewards: Array = game.make_rewards()
	var offers: Array = rewards.filter(func(r): return r.result == "offer")
	print("  %d rewards, %d offers, pending %d, waiting %d" % [rewards.size(), offers.size(), game.meta.pending.size(), game.waiting_draws().size()])
	game.unlock_offer(offers[0])
	game.convert_offer(offers[1])
	game.fix_meta()
	var stale: Array = game.meta.pending.filter(func(p): return !(p.result in ["offer", "spare"]))
	ok("after unlocking one and selling one, only the others wait (%d left)" % game.meta.pending.size(), game.meta.pending.size() == offers.size() - 2 and stale.is_empty() and game.waiting_draws().filter(func(g): return g.result == "offer").size() == offers.size() - 2)
	# a save from the old bug
	game.meta.pending = [{"kind": "card", "id": "mender", "result": "unlocked", "tier": 1}, {"kind": "card", "id": "gold_magnet", "result": "converted", "tier": 1}, {"kind": "card", "id": "aegis", "result": "offer", "tier": 1, "realm": 1, "cost": 16}]
	game.fix_meta()
	ok("stale leftovers are purged from an old save, real offers kept", game.meta.pending.size() == 1 and game.meta.pending[0].id == "aegis")
	quit()

extends SceneTree
# Offers are kept between runs until unlocked or converted; recipes appear only when both ingredients are unlocked.
func _initialize() -> void:
	var game = root.get_node("Game")
	await process_frame
	game.save_path = "user://test_save.json"
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap"]
	game.meta.card_tiers = {}
	game.meta.weapons = []
	game.meta.pending = []
	game.meta.shards = 0
	var chain = ["s", "se", "ne", "n"]
	game.sectors_unlocked = chain
	var r1: Array = game.make_rewards()
	var offers1 := r1.filter(func(e): return e.result == "offer")
	print("run 1: ", r1.size(), " rewards, ", offers1.size(), " offers, pending kept: ", game.meta.pending.size())
	# save to disk and load back, like quitting the game
	game.save_meta()
	var kept_ids: Array = game.meta.pending.map(func(p): return p.kind + ":" + p.id)
	game.load_meta()
	print("after a restart the pending offers are still there: ", game.meta.pending.map(func(p): return p.kind + ":" + p.id) == kept_ids, " (", game.meta.pending.size(), ")")
	# run 2 does not offer the same things twice
	var r2: Array = game.make_rewards()
	var dup := 0
	for e in r2:
		for p in offers1:
			if e.kind == p.kind and e.id == p.id and e.result == "offer": dup += 1
	print("run 2 offered something already pending: ", dup, " | pending now ", game.meta.pending.size())
	# act on one: unlock it
	var target = game.meta.pending[0]
	game.meta.shards = 200
	var n0: int = game.meta.pending.size()
	print("unlock '", target.id, "' -> ", game.unlock_offer(target), " | pending ", n0, " -> ", game.meta.pending.size())
	var tgt2 = game.meta.pending[0]
	print("convert '", tgt2.id, "' -> +", game.convert_offer(tgt2), " | pending ", game.meta.pending.size())
	# the vault has a limit
	for i in 20:
		game.make_rewards()
	print("pending never exceeds the cap (", game.MAX_PENDING, "): ", game.meta.pending.size())
	# recipes: both ingredients unlocked
	game.meta.weapons = []
	game.recipe_log = []
	game.meta.shards = 500
	print("rapier known before: ", game.weapon_known("rapier"))
	game.buy_weapon("daggers")
	print("after unlocking daggers (spear is a starter): rapier known ", game.weapon_known("rapier"), " | log: ", game.recipe_log)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

extends SceneTree
## A weapon's next tier is DRAWN at the end of a run (not applied) and then bought with Shards, like a card's: no automatic upgrades,
## no buying a tier you have not drawn. Price on the card curve, up to the run's tier cap.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://wts_test_save.json"
	game.fix_meta()
	game.meta.weapon_tiers = {}
	game.meta.tier_drawn = {}
	game.meta.fusion_tiers = []
	game.meta.shards = 100
	ok("an undrawn tier cannot be bought, even for the sword", !game.can_buy_weapon_tier("sword") and !game.buy_weapon_tier("sword"))
	# rewards draw weapon tiers but never apply them
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	game.run_stats.waves = 10
	var drawn := 0
	for i in 80:
		for r in game.make_rewards():
			if r.kind == "weapon" and r.result == "upgrade":
				drawn += 1
				ok_once(game, r)
	ok("tier draws happened (%d) and no weapon tier was applied by drawing" % drawn, drawn > 0 and game.weapon_tier_unlocked("sword") == 1 and game.weapon_tier_unlocked("pickaxe") == 1)
	game.meta.tier_drawn["w:sword"] = 2
	ok("once drawn the sword's tier 2 can be bought", game.can_buy_weapon_tier("sword"))
	ok("tier 2 costs 8 Shards (the card curve)", game.weapon_tier_price("sword") == 8)
	ok("buying it takes the Shards and unlocks tier 2", game.buy_weapon_tier("sword") and game.meta.shards == 92 and game.weapon_tier_unlocked("sword") == 2)
	ok("the next tier needs its own draw", !game.can_buy_weapon_tier("sword"))
	game.meta.tier_drawn["w:sword"] = 3
	game.meta.shards = 5
	ok("too few Shards: refused, nothing taken", !game.buy_weapon_tier("sword") and game.meta.shards == 5 and game.weapon_tier_unlocked("sword") == 2)
	game.meta.shards = 100
	ok("with enough it unlocks tier 3 (23)", game.buy_weapon_tier("sword") and game.meta.shards == 77 and game.weapon_tier_unlocked("sword") == 3)
	game.meta.tier_drawn["w:sword"] = 4
	ok("waiting_draws lists the sword's tier 4", game.waiting_draws().any(func(g): return g.kind == "weapon" and g.id == "sword" and g.result == "upgrade" and int(g.tier) == 4))
	quit()

func ok_once(_game, _r) -> void:
	pass

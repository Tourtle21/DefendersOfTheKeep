extends SceneTree
## Weapon tiers can be bought with Shards (same curve as card tiers), up to this run's tier cap; drawing them is still free.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://wts_test_save.json"
	game.fix_meta()
	game.meta.weapon_tiers = {}
	game.meta.fusion_tiers = []
	game.meta.shards = 100
	ok("the sword (a starter) can have its next tier bought", game.can_buy_weapon_tier("sword") and game.weapon_tier_unlocked("sword") == 1)
	ok("tier 2 costs 8 Shards (the card curve)", game.weapon_tier_price("sword") == 8)
	ok("buying it takes the Shards and unlocks tier 2", game.buy_weapon_tier("sword") and game.meta.shards == 92 and game.weapon_tier_unlocked("sword") == 2)
	ok("tier 3 costs 23", game.weapon_tier_price("sword") == 23)
	game.meta.shards = 5
	ok("too few Shards: refused, nothing taken", !game.buy_weapon_tier("sword") and game.meta.shards == 5 and game.weapon_tier_unlocked("sword") == 2)
	game.meta.shards = 500
	game.buy_weapon_tier("sword")
	game.buy_weapon_tier("sword")
	ok("it stops at this run's tier cap (%d)" % game.weapon_tier_cap(), game.weapon_tier_unlocked("sword") == game.weapon_tier_cap() and !game.can_buy_weapon_tier("sword"))
	ok("a weapon you do not own cannot be bought", !game.can_buy_weapon_tier("hammer"))
	quit()

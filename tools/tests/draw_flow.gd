extends SceneTree
## The drawn-card flow: a spare copy merges into a DRAWN next tier (not an instant upgrade); paying Shards applies it and it leaves
## the Drawn pile and shows in the collection; selling a spare takes it out of the pile and pays; offers can be unlocked or converted
## from the pile; weapon tier draws work the same way.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://df_test_save.json"
	game.fix_meta()
	game.meta.shards = 100
	game.meta.best_level = 4
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {"fireball": 1}
	game.meta.tier_drawn = {}
	game.meta.pending = []
	var s1 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	var s2 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	var s3 := {"kind": "card", "id": "frost_ring", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	game.meta.pending = [s1, s2, s3]
	var has := func(kind: String, id: String, res: String) -> bool:
		return game.waiting_draws().any(func(g): return g.kind == kind and g.id == id and g.result == res)
	ok("two spares wait in the Drawn pile", has.call("card", "fireball", "spare"))
	ok("every waiting group carries the entry its buttons act on", game.waiting_draws().all(func(g): return g.has("entry")))
	# merge: draws the next tier, does NOT apply it
	ok("merging a spare succeeds", game.spare_merge(s1))
	ok("the card is still tier 1 (the merge only DREW tier 2)", game.card_tier("fireball") == 1)
	ok("one spare left the pile; the tier 2 upgrade is waiting", game.meta.pending.size() == 2 and has.call("card", "fireball", "upgrade"))
	ok("a second merge of the same tier is refused (tier 2 is already drawn)", !game.spare_can_merge(s2))
	# upgrade: pays, applies, leaves the pile
	var before: int = game.meta.shards
	ok("upgrading pays Shards and applies tier 2", game.upgrade_card("fireball") and game.card_tier("fireball") == 2 and game.meta.shards < before)
	ok("the upgrade left the Drawn pile", !has.call("card", "fireball", "upgrade"))
	ok("the collection shows the tier unlocked", game.card_tier("fireball") == 2 and game.meta.card_tiers["fireball"] == 2)
	# sell
	var c0: int = game.meta.shards
	ok("selling a spare pays Shards", game.spare_sell(s3) > 0 and game.meta.shards > c0)
	ok("the sold spare left the pile", !has.call("card", "frost_ring", "spare"))
	# offers: unlock and convert from the pile
	var o1 := {"kind": "card", "id": "mender", "tier": 1, "realm": 1, "result": "offer", "shards": 0}
	var o2 := {"kind": "card", "id": "sentry", "tier": 1, "realm": 1, "result": "offer", "shards": 0}
	for o in [o1, o2]:
		o["cost"] = game.unlock_cost(o)
	game.meta.pending.append(o1)
	game.meta.pending.append(o2)
	game.meta.shards = 200
	ok("an offer waits in the pile", has.call("card", "mender", "offer"))
	ok("unlocking from the pile owns the card and removes it", game.unlock_offer(o1) and game.owns_card("mender") and !has.call("card", "mender", "offer"))
	var c1: int = game.meta.shards
	ok("converting from the pile pays Shards and removes it", game.convert_offer(o2) > 0 and game.meta.shards > c1 and !has.call("card", "sentry", "offer"))
	# weapons: a drawn tier waits, buying applies it and it leaves
	game.meta.tier_drawn["w:sword"] = 2
	ok("a drawn weapon tier waits in the pile", has.call("weapon", "sword", "upgrade"))
	ok("buying it applies the tier and it leaves the pile", game.buy_weapon_tier("sword") and game.weapon_tier_unlocked("sword") == 2 and !has.call("weapon", "sword", "upgrade"))
	quit()

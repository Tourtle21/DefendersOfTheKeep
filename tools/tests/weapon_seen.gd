extends SceneTree
## Owning the Torch CARD must not make the Torch WEAPON look known; offering or holding the weapon does.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ws_test_save.json"
	game.meta = {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 100, "unlocked": ["fireball", "frost_ring", "barricade", "spike_trap", "torch"], "seen": ["torch", "fireball"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
	ok("the Torch card is owned and seen", game.owns_card("torch") and game.is_seen("torch"))
	ok("but the Torch weapon is still unknown", !game.weapon_seen("torch"))
	ok("and cannot be bought before it has been met", !game.buy_weapon("torch"))
	ok("a spear that was never met is unknown too", !game.weapon_seen("spear"))
	game.mark_seen("torch", "weapon")
	ok("holding or being offered the weapon makes it known", game.weapon_seen("torch"))
	ok("and then it can be bought", game.buy_weapon("torch") and game.weapon_unlocked("torch"))
	game.meta.seen.append("spear")
	ok("an older save that listed a weapon id in `seen` still counts for weapons without a card of the same name", game.weapon_seen("spear"))
	quit()

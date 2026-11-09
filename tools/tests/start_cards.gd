extends SceneTree
## A run starts with exactly the two spells and two buildings you chose; the rest of your cards come from chests.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://sc_test_save.json"
	game.meta = {"pending": [], "skills": {}, "card_tiers": {}, "weapons": [], "fusion_tiers": [], "start_weapon": "sword", "shards": 0, "unlocked": ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "rejuvenation", "mender", "aegis"], "best_wave": 0, "recipes_seen": [], "hints_seen": [], "hints_enabled": true}
	print("  spell options: ", game.start_card_options(false), " building options: ", game.start_card_options(true))
	ok("by default: fireball, frost ring, barricade, torch", game.start_cards() == ["fireball", "frost_ring", "barricade", "torch"])
	game.set_start_cards(["rejuvenation", "fireball"], ["mender", "spike_trap"])
	game.start_run()
	print("  deck: ", game.deck.keys())
	ok("the deck is exactly the four chosen cards", game.deck.keys().size() == 4 and "rejuvenation" in game.deck and "fireball" in game.deck and "mender" in game.deck and "spike_trap" in game.deck)
	ok("the other owned cards are not in the deck yet", !("frost_ring" in game.deck) and !("aegis" in game.deck) and !("barricade" in game.deck))
	ok("the first hand comes only from those cards", game.hand.all(func(h): return game.entry_id(h) in game.deck))
	ok("chests can still offer every owned card", "aegis" in game.unlocked_cards and "frost_ring" in game.unlocked_cards)
	game.meta.start_cards = ["aegis", "aegis", "mender", "mender"]
	ok("a duplicate is replaced so you still start with two of each kind", game.start_cards().size() == 4 and game.start_cards()[0] != game.start_cards()[1] and game.start_cards()[2] != game.start_cards()[3])
	game.meta.start_cards = ["hellfire", "x", "y", "z"]
	ok("ids you do not own fall back to the defaults", game.start_cards() == ["fireball", "frost_ring", "barricade", "torch"])
	quit()

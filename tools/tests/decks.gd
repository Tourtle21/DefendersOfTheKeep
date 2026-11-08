extends SceneTree
# Two decks: the hand is drawn from spells and buildings separately (3 + 2 slots).
func _initialize() -> void:
	var game = root.get_node("Game")
	await process_frame
	game.save_path = "user://test_save.json"
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "sentry", "aegis", "rejuvenation"]
	game.start_run()
	game.deck = {"fireball": 1, "frost_ring": 1, "aegis": 1, "barricade": 1, "spike_trap": 1, "sentry": 1}
	var worst_spell := 99
	var worst_build := 99
	var viol := 0
	for trial in 200:
		game.hand = []
		game.resources = {"stone": 0, "stick": 0, "gold": 0}      # builds unaffordable: used to clog the hand
		for i in 5:
			game.add_to_hand(game.draw_card())
		var sp: int = game.hand_count(false)
		var bd: int = game.hand_count(true)
		if sp != 3 or bd != 2: viol += 1
		worst_spell = mini(worst_spell, sp)
		worst_build = mini(worst_build, bd)
	print("200 full hands with no materials: hands not 3 spells + 2 builds: ", viol, " (min spells ", worst_spell, ", min builds ", worst_build, ")")
	# spell-only deck fills the hand with spells; build-only with builds
	game.deck = {"fireball": 1, "frost_ring": 1}
	game.hand = []
	for i in 5: game.add_to_hand(game.draw_card())
	print("spell-only deck: hand ", game.hand)
	game.deck = {"barricade": 1}
	game.hand = []
	for i in 5: game.add_to_hand(game.draw_card())
	print("build-only deck: hand ", game.hand)
	# ordering: spells first
	game.deck = {"fireball": 1, "barricade": 1}
	game.hand = ["barricade"]
	game.add_to_hand("fireball")
	print("order after adding a spell to [barricade]: ", game.hand)
	quit()

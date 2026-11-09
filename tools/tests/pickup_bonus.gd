extends SceneTree
## Skill-tree pickup bonuses go to whoever picked the resource up, including players 2-4.
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://pb_test_save.json"
	game.meta["skills"] = {"gold_find": 5, "prospector": 5}      # +50% bonus gold, +50% extra stone / sticks
	var avatar = load("res://player/player.tscn").instantiate()
	avatar.remote_controlled = true
	game.carried = {}
	for i in 400:
		game.pick_up_resource("stone", avatar)
		game.pick_up_resource("gold", avatar)
	print("  avatar carries %s, player 1 carries %s" % [avatar.carried, game.carried])
	ok("player 2's stone got the Prospector bonus (about 600 of 400)", avatar.carried.get("stone", 0) > 480)
	ok("player 2's gold got the Lucky Coins bonus and none went to player 1", avatar.carried.get("gold", 0) > 480 and game.carried.get("gold", 0) == 0)
	quit()

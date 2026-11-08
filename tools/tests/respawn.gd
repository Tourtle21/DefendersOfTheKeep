extends SceneTree
# Falling in battle: out for 30 seconds, enemies ignore you, then back at the keep with full health. The run does not end.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var player = world.get_node("Player")
	player.global_position = Vector2(0, 150)
	var hp: Control = world.get_node("Hud/Control2/ColorRect/Health")
	print("start: hp bar ", hp.size.x, " | run_over ", game.run_over)
	for i in 9:
		player.take_damage(Vector2(0, 200))
		await wait(0.55)
		if player.downed:
			break
	print("after enough hits: downed ", player.downed, " | run over ", game.run_over, " | respawn_left ", snappedf(player.respawn_left, 0.1), " | visible ", player.visible, " | at ", player.global_position)
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = Vector2(0, 300)
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	print("enemy targets the fallen player: ", e._target_player() == player)
	player.take_damage(Vector2(0, 200))
	print("damage while fallen is ignored: bar ", hp.size.x)
	await wait(5.0)
	print("5 s later: respawn_left ", snappedf(player.respawn_left, 0.1))
	player.respawn_left = 0.2                       # skip ahead
	await wait(0.6)
	print("respawned: downed ", player.downed, " | visible ", player.visible, " | hp bar ", hp.size.x, " | at ", player.global_position, " | shielded ", player.shield_time > 0.0, " | run over ", game.run_over)
	# a co-op avatar falls too
	var av = load("res://player/player.tscn").instantiate()
	av.remote_controlled = true
	world.add_child(av)
	await wait(0.3)
	av.remote_hp = 20.0
	av.take_damage(Vector2.ZERO)
	await wait(0.3)
	print("co-op avatar: downed ", av.downed, " | hp ", av.remote_hp)
	av.respawn_left = 0.1
	await wait(0.5)
	print("co-op avatar back: downed ", av.downed, " | hp ", av.remote_hp, " | at ", av.global_position)
	quit()

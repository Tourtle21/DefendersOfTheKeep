extends SceneTree
# Co-op polish host: roster, scaling, disconnect handling. Run with net_client_polish.gd.
# Add `-- short` to quit after ~8 seconds (used to test the client noticing a vanished host).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var picked = [{"name": "blobbert", "amount": 2, "level": 1}]
	game.run_stats.waves = 6
	var solo := 0
	for e in world.wave_plan(picked):
		solo += e.amount
	print("HOST: wave 6 with one player: ", solo, " enemies")
	print("HOST: listening -> ", net.host_game())
	world.get_node("Player").position = Vector2(-100, -60)
	world.spawn_enemies(picked)       # moving enemies for the client's smoothing check
	world.get_node("SpawnTimer").stop()
	var short := OS.get_cmdline_args().has("short") or OS.get_cmdline_user_args().has("short")
	if short:
		await wait(8.0)
		print("HOST: quitting now")
		quit()
		return
	var duo := 0
	var boss_hp := 0.0
	var inside := false
	for i in 24:
		await wait(1.0)
		if net.remote_players.size() > 0 and duo == 0:
			await wait(1.0)
			game.run_stats.waves = 6      # same wave number as the solo plan, so only the player count differs
			for e in world.wave_plan(picked):
				duo += e.amount
			var pl = net.remote_players.values()[0]
			var b = load("res://enemies/boss/boss.gd").new()
			b.setup({"boss_name": "Test Boss", "max_health": 40.0, "color": Color.RED, "body_radius": 20.0})
			b.position = pl.global_position + Vector2(30, 0)
			world.add_child(b)
			b._physics_process(0.1)
			boss_hp = b.max_health
			print("HOST: roster ", net.names, " | wave 6 with two players: ", duo, " enemies (solo was ", solo, ") | boss health 40 -> ", boss_hp)
		if net.remote_players.size() > 0 and net.remote_players.values()[0].is_in_tower:
			inside = true
	print("HOST: client was inside the keep: ", inside, " | after it dropped: remote avatars ", net.remote_players.size(), ", keep occupied: ", game.in_base)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

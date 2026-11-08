extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var music = root.get_node("Music")
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	# synthesis cost and level check per theme
	for name in music.THEMES:
		var t0 := Time.get_ticks_msec()
		var w = music._build(music.THEMES[name], name)
		var ms := Time.get_ticks_msec() - t0
		var peak := 0
		var sum := 0.0
		var d: PackedByteArray = w.data
		var n := d.size() / 2
		for i in range(0, n, 7):
			var v := absi(d.decode_s16(i * 2))
			peak = max(peak, v)
			sum += float(v) * v
		print("%-8s %5.1fs loop, built in %4d ms, peak %5.2f of full scale, rms %.2f" % [name, n / 22050.0, ms, peak / 32767.0, sqrt(sum / (n / 7.0)) / 32767.0])
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(0.8)
	world.get_node("SpawnTimer").start(600.0)
	print("theme at start: ", music.current_theme(), " playing: ", music._a.playing or music._b.playing)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	sm.unlock("se")
	await wait(0.3)
	print("after unlocking desert: ", music.current_theme())
	sm.unlock("ne"); sm.unlock("n")
	await wait(0.3)
	print("after tundra + volcano: ", music.current_theme())
	game.boss_fight.emit(true)
	await wait(0.3)
	print("boss awake: ", music.current_theme())
	game.boss_fight.emit(false)
	await wait(0.3)
	print("boss gone: ", music.current_theme())
	await wait(2.0)
	var vols := [music._a.volume_db, music._b.volume_db]
	print("crossfade settled, player volumes (db): ", vols)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

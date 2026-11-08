extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
var _ui = null
func key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	_ui._input(ev)          # key events are not delivered in this test harness, so call the handler
	await wait(0.1)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var ui = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("pause_ui.gd"): ui = c
	_ui = ui
	await key(KEY_P)
	print("P opens: visible ", ui.root_ctl.visible, " tree paused ", paused)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://pause.png")
	await key(KEY_P)
	print("P closes: visible ", ui.root_ctl.visible, " tree paused ", paused)
	# opened while the game was already paused (e.g. wave screen): stays paused after closing
	paused = true
	await key(KEY_P)
	await key(KEY_P)
	print("closing restores the earlier paused state: ", paused)
	paused = false
	# volume
	game.meta["music_vol"] = 0.25
	root.get_node("Music").apply_volume()
	var m = root.get_node("Music")
	var active = m._b if m._use_a else m._a
	print("music volume at 25% slider: ", snapped(active.volume_db, 0.1), " dB (full would be -16)")
	game.meta["sfx_vol"] = 0.5
	root.get_node("Sfx").play("coin", 0.0)
	var sp = null
	for p in root.get_node("Sfx")._players:
		if p.playing: sp = p
	print("sfx volume at 50% slider: ", snapped(sp.volume_db, 0.1) if sp else "n/a", " dB (full would be -8)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

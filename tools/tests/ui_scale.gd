extends SceneTree
# UI scale: bigger UI on tall windows, same world framing, nothing pushed off screen.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"):
			c.panel.visible = false
	var cam = player.get_node("Camera2D")
	print("window ", root.size, " ui_scale ", game.ui_scale)
	await wait(1.0)      # let the window finish maximizing
	print("window px ", root.size)
	for h in [720, 1000, 1080, 1440, 2102, 3000]:
		game.forced_height = h
		game._update_ui_scale()
		print("  height %4d px -> ui scale %.2f" % [h, game.ui_scale])
	var widths := []
	for h in [1000, 2000]:
		game.forced_height = h
		game._update_ui_scale()
		await wait(0.5)
		var rect = root.get_visible_rect().size
		widths.append(rect.x / cam.zoom.x)
		print("  scale %.2f: logical viewport %s, camera zoom %.2f, world width seen %.1f units" % [game.ui_scale, rect, cam.zoom.x, rect.x / cam.zoom.x])
	print("world framing unchanged by UI scale: ", absf(widths[0] - widths[1]) < 1.0)
	var rect2 = root.get_visible_rect().size
	# UI stays inside the logical viewport
	player.base_zoom = 2.0
	game.enter_base(player)
	await wait(0.6)
	var bad := []
	var vis = Rect2(Vector2.ZERO, rect2)
	for ctl in world.find_children("*", "Control", true, false):
		if ctl.is_visible_in_tree() and ctl.get_global_rect().size.x > 1 and (ctl is Label or ctl is Button or ctl is ProgressBar):
			var r: Rect2 = ctl.get_global_rect()
			if r.end.x > vis.end.x + 2 or r.end.y > vis.end.y + 2 or r.position.x < -2 or r.position.y < -2:
				bad.append("%s %s" % [ctl.name, r])
	print("controls outside the viewport at scale 2: ", bad.size(), " ", bad.slice(0, 3))
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://ui_scale2.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

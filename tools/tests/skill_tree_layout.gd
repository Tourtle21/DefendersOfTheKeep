extends SceneTree
## The skill tree: no two cards overlap and every card sits inside the panel, at several window sizes.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://stl_test_save.json"
	var ui = load("res://ui/base/skill_tree_ui.gd").new()
	root.add_child(ui)
	await wait(0.3)
	for size in [Vector2(1680, 900), Vector2(1200, 640), Vector2(900, 500)]:
		ui.open()
		await wait(0.2)
		ui.tree.custom_minimum_size = size
		ui.tree.size = size
		await wait(0.2)
		ui._layout()
		ui._refresh()
		var rects := {}
		for id in ui._buttons:
			var b: Control = ui._buttons[id]
			rects[id] = Rect2(b.position, b.size)
		var overlaps := []
		var ids: Array = rects.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				if rects[ids[i]].grow(-1.0).intersects(rects[ids[j]].grow(-1.0)):
					overlaps.append("%s / %s" % [ids[i], ids[j]])
		var outside := []
		for id in rects:
			if rects[id].end.x > size.x + 1.0:
				outside.append(id)
		ok("%s: no overlapping cards %s" % [size, str(overlaps)], overlaps.is_empty())
		ok("%s: every card inside the panel width %s" % [size, str(outside)], outside.is_empty())
	ok("Vitality is in the tree", ui._buttons.has("vitality"))
	quit()

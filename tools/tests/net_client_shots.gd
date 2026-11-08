extends SceneTree
# Window client: joins net_host_shots and saves a screenshot of what a co-op player sees.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	print("CLIENT: connecting -> ", net.join_game("127.0.0.1"))
	var t := 0.0
	while !state.ok and t < 8.0:
		await wait(0.1)
		t += 0.1
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	await wait(5.0)
	for c in view.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	await wait(0.5)
	root.get_viewport().get_texture().get_image().save_png("user://client_structures.png")
	var n := 0
	for s in root.get_tree().get_nodes_in_group("structure"): n += 1
	print("CLIENT: structure puppets: ", n)
	quit()

extends SceneTree
# Window client for audit_lan_host.gd: screenshots of what a LAN player sees at the Card Fuser, the Forge and in a tower.
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	await process_frame
	var net = root.get_node("Net")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	print("CLIENT: connecting -> ", net.join_game("127.0.0.1"))
	var t := 0.0
	while !state.ok and t < 10.0:
		await wait(0.1)
		t += 0.1
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	await wait(1.0)
	for c in view.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	await wait(10.0)
	await shot("l1_client_fuser")
	await wait(7.0)
	await shot("l2_client_forge")
	await wait(7.0)
	await shot("l3_client_tower")
	quit()

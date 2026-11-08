extends SceneTree
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	net.my_name = "LanTestHost"
	print("HOST addresses: ", net.lan_addresses(), " hosting -> ", net.host_game())
	await create_timer(8.0, true, false, true).timeout
	quit()

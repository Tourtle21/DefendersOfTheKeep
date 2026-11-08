extends SceneTree
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	net.start_lan_scan()
	await create_timer(4.0, true, false, true).timeout
	print("SCAN found: ", net.lan_hosts)
	print("SCAN RESULT: ", "PASS" if net.lan_hosts.size() > 0 else "FAIL")
	net.stop_lan_scan()
	quit()

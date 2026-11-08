extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var rep = root.get_node("Rep")
	var state := {"ok": false, "ended": false, "restart": false}
	net.joined.connect(func(): state.ok = true)
	net.join_game("127.0.0.1")
	var t := 0.0
	while !state.ok and t < 8.0:
		await wait(0.1)
		t += 0.1
	var me: int = net.multiplayer.get_unique_id()
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	root.get_node("Game").announce.connect(func(text): if text == "RUN_START": state.restart = true)
	# keep pressing interact (the host reacts when the avatar is next to the generator), for 22 s
	for i in 22:
		net.net_command.rpc_id(1, {"cmd": "interact"})
		await wait(1.0)
	print("CLIENT: puppets before the host restarts: ", rep.puppet_count())
	await wait(5.0)
	var has_me := false
	for p in net.last_snapshot.get("players", []):
		if p.id == me: has_me = true
	print("CLIENT: players in the last snapshot: ", net.last_snapshot.get("players", []).map(func(p): return p.id), " me ", me, " snapshot age ms ", Time.get_ticks_msec() - int(net.last_snapshot.get("t", 0)))
	print("CLIENT: after the restart: puppets ", rep.puppet_count(), " | my avatar in the snapshot: ", has_me, " | got the RUN_START notice: ", state.restart)
	quit()

extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var stay := OS.get_cmdline_args().has("stay") or OS.get_cmdline_user_args().has("stay")
	var state := {"ok": false, "lost": false}
	net.joined.connect(func(): state.ok = true)
	net.server_lost.connect(func(): state.lost = true)
	net.my_name = "Alex"
	net.join_game("127.0.0.1")
	var t := 0.0
	while !state.ok and t < 6.0:
		await wait(0.1)
		t += 0.1
	if !state.ok:
		print("CLIENT: could not connect")
		quit()
		return
	if stay:
		t = 0.0
		while !state.lost and t < 14.0:
			await wait(0.2)
			t += 0.2
		print("CLIENT: noticed the host disappearing: ", state.lost, " (after ~", snapped(t, 0.1), "s)")
		quit()
		return
	# smoothing check through the real client view node
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	await wait(2.0)
	var snap: Dictionary = net.last_snapshot
	var rep = root.get_node("Rep")
	var enemy_puppets: Array = rep.puppets_of_group("enemy")
	print("CLIENT: roster from the host: ", snap.roster, " | enemy puppets ", enemy_puppets.size())
	var lag := 0.0
	for id in rep._puppets:
		var n = rep._puppets[id]
		if is_instance_valid(n) and n.is_in_group("enemy"):
			lag = max(lag, n.global_position.distance_to(rep._targets[id].pos))
	print("CLIENT: drawn enemies trail their latest snapshot by at most ", snapped(lag, 0.1), " units (smoothing on, not teleporting)")
	# walk to a tower, step inside, then drop off without leaving
	for i in 36:
		net.local_input = {"move": Vector2(0, 1), "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	net.local_input = {"move": Vector2.ZERO, "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.3)
	net.net_command.rpc_id(1, {"cmd": "base", "on": true})
	await wait(3.0)      # stay inside long enough for the host to notice
	print("CLIENT: inside the keep, now dropping the connection abruptly")
	net.leave()
	await wait(0.5)
	quit()

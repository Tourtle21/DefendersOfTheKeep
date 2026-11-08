extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var rep = root.get_node("Rep")
	var game = root.get_node("Game")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	net.join_game("127.0.0.1")
	var t := 0.0
	while !state.ok and t < 8.0:
		await wait(0.1)
		t += 0.1
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	await wait(4.0)
	var structs := get_nodes_in_group("structure").filter(func(n): return n.has_meta("net_puppet")).map(func(n): return n.kind)
	structs.sort()
	print("CLIENT: late join -> puppets ", rep.puppet_count(), " | structures ", structs, " | enemies ", rep.puppets_of_group("enemy").size(), " | keep ", game.keep_hp, " | waves ", game.run_stats.waves, " | sectors open ", game.sectors_unlocked.size())
	quit()

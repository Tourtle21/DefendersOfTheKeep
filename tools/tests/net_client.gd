extends SceneTree
# Co-op client side of the two-process test (run after net_host.gd is listening).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame      # let the autoloads enter the tree first
	var net = root.get_node("Net")
	var state := {"ok": false}      # a dictionary: lambdas capture plain locals by value
	net.joined.connect(func(): state.ok = true)
	print("CLIENT: connecting -> ", net.join_game("127.0.0.1"))
	var t := 0.0
	while !state.ok and t < 6.0:
		await wait(0.1)
		t += 0.1
	print("CLIENT: connected: ", state.ok)
	if !state.ok:
		quit()
		return
	await wait(1.0)
	var snap: Dictionary = net.last_snapshot
	var me = root.get_node("Net").multiplayer.get_unique_id()
	print("CLIENT: first snapshot -> players ", snap.get("players", []).size(), " keep ", snap.get("keep"), " wave ", snap.get("wave"), " my peer id ", me)
	var before = null
	for p in snap.players:
		if p.id == me: before = p.pos
	# hold "move right" for 2 seconds, aiming at +x
	for i in 40:
		net.local_input = {"move": Vector2(1, 0), "aim": Vector2(300, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	var after = null
	for p in net.last_snapshot.players:
		if p.id == me: after = p.pos
	print("CLIENT: my avatar moved from ", before, " to ", after, " (driven by my input, simulated by the host)")
	# click the attack button a few times in front of the dummy
	for k in 5:
		net.local_input = {"move": Vector2.ZERO, "aim": Vector2(300, 0), "attack": true, "ability": false, "dash": false, "ultimate": false}
		await wait(0.15)
		net.local_input = {"move": Vector2.ZERO, "aim": Vector2(300, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.55)
	var s2: Dictionary = net.last_snapshot
	print("CLIENT: latest snapshot -> players ", s2.players.size(), " keep ", s2.keep)
	quit()

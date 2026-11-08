extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func mine(snap: Dictionary, me: int) -> Dictionary:
	for p in snap.get("players", []):
		if p.id == me:
			return p
	return {}
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	net.join_game("127.0.0.1")
	var t := 0.0
	while !state.ok and t < 6.0:
		await wait(0.1)
		t += 0.1
	if !state.ok:
		print("CLIENT: could not connect")
		quit()
		return
	var me: int = net.multiplayer.get_unique_id()
	var view = load("res://net/client_view.tscn").instantiate()
	root.add_child(view)
	await wait(1.5)
	var rep = root.get_node("Rep")
	var s: Dictionary = net.last_snapshot
	print("CLIENT: sees ", rep.puppets_of_group("pickup").size(), " pickups and ", rep.puppets_of_group("chest").size(), " chest(s); my weapons ", mine(s, me).slots)
	net.net_command.rpc_id(1, {"cmd": "interact"})          # nearest thing first: the chest
	await wait(0.5)
	s = net.last_snapshot
	print("CLIENT: chest opened, draft offered: ", s.draft)
	if s.draft.size() > 0:
		net.net_command.rpc_id(1, {"cmd": "draft", "id": s.draft[0]})
	await wait(0.5)
	print("CLIENT: draft closed: ", net.last_snapshot.draft.is_empty(), " | deck ", net.last_snapshot.deck)
	net.net_command.rpc_id(1, {"cmd": "interact"})
	await wait(0.4)
	net.net_command.rpc_id(1, {"cmd": "interact"})
	await wait(0.5)
	s = net.last_snapshot
	print("CLIENT: after picking up: weapons ", mine(s, me).slots, " active ", mine(s, me).active, " | pickups left ", rep.puppets_of_group("pickup").size())
	net.net_command.rpc_id(1, {"cmd": "switch"})
	await wait(0.4)
	print("CLIENT: after switching: active ", mine(net.last_snapshot, me).active)
	for i in 8:                                               # step south, around the well...
		net.local_input = {"move": Vector2(0, 1), "aim": Vector2(-300, 20), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	for i in 22:                                              # ...then west to the forge
		net.local_input = {"move": Vector2(-1, 0), "aim": Vector2(-300, 20), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	net.local_input = {"move": Vector2.ZERO, "aim": Vector2(-300, 20), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.4)
	var m = mine(net.last_snapshot, me)
	print("CLIENT: at ", m.pos, " near the forge: ", m.near_forge)
	var slots: Array = m.slots
	net.net_command.rpc_id(1, {"cmd": "fuse", "a": slots.find("sword"), "b": slots.find("shield")})
	await wait(0.6)
	m = mine(net.last_snapshot, me)
	print("CLIENT: after fusing sword + shield: weapons ", m.slots)
	quit()

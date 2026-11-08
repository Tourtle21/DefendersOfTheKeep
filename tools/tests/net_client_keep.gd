extends SceneTree
# Co-op client for the keep test: walk to a tower, enter, cast, repair, upgrade, leave.
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
	await wait(1.0)
	print("CLIENT: connected, avatar at ", mine(net.last_snapshot, me).get("pos"))
	for i in 36:   # walk south to the tower
		net.local_input = {"move": Vector2(0, 1), "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	net.local_input = {"move": Vector2.ZERO, "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.3)
	print("CLIENT: avatar now at ", mine(net.last_snapshot, me).get("pos"))
	net.net_command.rpc_id(1, {"cmd": "base", "on": true})
	await wait(0.6)
	var s: Dictionary = net.last_snapshot
	print("CLIENT: inside the keep: ", mine(s, me).get("base"), " | hand ", s.hand, " | mana ", int(s.mana), "/", int(s.max_mana), " | resources ", s.resources)
	net.net_command.rpc_id(1, {"cmd": "cast", "card": "fireball", "pos": Vector2(0, 230)})
	await wait(0.4)
	net.net_command.rpc_id(1, {"cmd": "repair"})
	await wait(0.3)
	net.net_command.rpc_id(1, {"cmd": "upgrade", "id": "max_mana"})
	await wait(2.6)    # let the fireball fly and land
	s = net.last_snapshot
	print("CLIENT: after casting, repairing and upgrading -> mana ", int(s.mana), "/", int(s.max_mana), " keep ", int(s.keep), " hand ", s.hand)
	net.net_command.rpc_id(1, {"cmd": "base", "on": false})
	await wait(0.6)
	print("CLIENT: left the keep: ", not mine(net.last_snapshot, me).get("base", true))
	quit()

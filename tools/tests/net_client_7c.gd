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
	net.my_name = "Sam"
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
	view.scripted_input = true      # this script drives the input, not the keyboard
	root.add_child(view)
	await wait(1.5)
	var s: Dictionary = net.last_snapshot
	var m = mine(s, me)
	print("CLIENT: lobby flag from the host: ", s.lobby, " | roster ", s.roster, " | my hp ", m.hp, " | I carry ", m.carried)
	print("CLIENT: view label: ", view.info.text.substr(0, 60), " | hp bar ", view.hp_bar.value)
	net.net_command.rpc_id(1, {"cmd": "interact"})      # pick up the stone
	await wait(0.8)
	m = mine(net.last_snapshot, me)
	print("CLIENT: after picking up: I carry ", m.carried, " | carry label: ", view.carry_label.text.substr(0, 50))
	for i in 36:
		net.local_input = {"move": Vector2(0, 1), "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
		await wait(0.05)
	net.local_input = {"move": Vector2.ZERO, "aim": Vector2(0, 400), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.3)
	print("CLIENT: avatar at ", mine(net.last_snapshot, me).pos, " before asking to enter")
	net.net_command.rpc_id(1, {"cmd": "base", "on": true})
	await wait(1.2)
	s = net.last_snapshot
	m = mine(s, me)
	print("CLIENT: base flag ", m.base)
	print("CLIENT: inside the keep -> I carry ", m.carried, " | keep pool ", s.resources, " | minimap visible ", view.radar.visible)
	await wait(0.6)       # let the minimap draw a few frames
	var waited := 0.0
	while net.last_snapshot.lobby and waited < 12.0:
		await wait(0.5)
		waited += 0.5
	print("CLIENT: lobby ended after the host pressed Start: ", !net.last_snapshot.lobby)
	quit()

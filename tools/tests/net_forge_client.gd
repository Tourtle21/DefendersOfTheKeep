extends SceneTree
# Co-op client side of the forge-storage test (run after net_forge_host.gd is listening).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	await process_frame
	var net = root.get_node("Net")
	var state := {"ok": false}
	net.joined.connect(func(): state.ok = true)
	net.join_game("127.0.0.1")
	var t := 0.0
	while !state.ok and t < 8.0:
		await wait(0.1)
		t += 0.1
	print("CLIENT: connected: ", state.ok)
	if !state.ok:
		quit()
		return
	await wait(4.0)                  # the host moves our avatar to the forge and sets up the weapons
	var me: int = net.multiplayer.get_unique_id()
	var near := false
	var slots := []
	for p in net.last_snapshot.get("players", []):
		if p.id == me:
			near = p.near_forge
			slots = p.slots
	print("CLIENT: near the forge: ", near, "  holding ", slots, "  stored (from the snapshot): ", net.last_snapshot.get("store", []))
	# 1. drop the spear into the forge
	var spear_idx := -1
	for i in slots.size():
		if str(slots[i]).begins_with("spear"): spear_idx = i
	net.net_command.rpc_id(1, {"cmd": "forge_store", "src": "held", "idx": spear_idx})
	await wait(1.5)
	print("CLIENT: stored after dropping the spear: ", net.last_snapshot.get("store", []))
	# 2. combine the held hammer with the stored hammer
	var held_hammer := -1
	for p in net.last_snapshot.get("players", []):
		if p.id == me:
			for i in p.slots.size():
				if str(p.slots[i]).begins_with("hammer"): held_hammer = i
	var store: Array = net.last_snapshot.get("store", [])
	var stored_hammer := -1
	for j in store.size():
		if str(store[j]).begins_with("hammer"): stored_hammer = j
	net.net_command.rpc_id(1, {"cmd": "forge_craft", "a_src": "held", "a_idx": held_hammer, "b_src": "store", "b_idx": stored_hammer})
	await wait(1.5)
	for p in net.last_snapshot.get("players", []):
		if p.id == me:
			print("CLIENT: now holding ", p.slots, "  stored ", net.last_snapshot.get("store", []))
	await wait(3.0)                  # stay connected while the host checks
	quit()

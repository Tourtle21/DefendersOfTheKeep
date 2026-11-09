extends Node
## Autoload "Net": co-op groundwork (ENet). The HOST runs the whole game and is the only
## authority. Each CLIENT sends its input (move, aim, buttons) 20 times a second; the
## host moves a remote-controlled player for it, and broadcasts a snapshot of the
## world (players, enemies, bosses, keep, mana, wave) 10 times a second. The client
## view (net/client_view.gd) draws those snapshots.
## Inert unless host_game() / join_game() is called.

const PORT := 24680
signal snapshot_received(data: Dictionary)
signal joined
signal join_failed
signal client_connected(id: int)
signal server_lost

var active := false
var is_host := false
var remote_players := {}           # peer id -> Player (host side)
var last_snapshot := {}            # client side
var local_input := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "attack": false, "ability": false, "dash": false, "ultimate": false}
var names := {}                    # peer id -> display name (host keeps the roster)
var my_name := "Player"
var lobby := false                 # host: waiting for players; waves do not start until start_game()
var cmd_join := ""                 # set from the command line: -- join=ADDRESS
const LAN_PORT := 24681           # UDP: hosts announce themselves, clients scan
var lan_hosts := {}               # address -> {"name", "port", "players", "seen_ms"}
var _beacons: Array = []          # host: UDP senders (broadcast, each subnet, loopback) for "DOTK1|name|port|players" once a second
var _scanner: PacketPeerUDP       # client: listens for those broadcasts
var _beacon_t := 0.0
var _snap_t := 0.0
var _input_t := 0.0
var _prev := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # the join menu pauses the game; LAN scanning must keep running
	for a in OS.get_cmdline_user_args():
		if a.begins_with("join="):
			cmd_join = a.substr(5)
		if a.begins_with("name="):
			my_name = a.substr(5)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func():
		net_hello.rpc_id(1, my_name)
		joined.emit())
	multiplayer.server_disconnected.connect(func():
		active = false
		server_lost.emit())
	multiplayer.connection_failed.connect(func(): join_failed.emit())

func start_game() -> void:
	lobby = false
	if Game.world != null:
		Game.world.get_node("SpawnTimer").paused = false

func wants_host() -> bool:
	return OS.get_cmdline_user_args().has("host")

func host_game(port := PORT) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(port, 3)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	active = true
	is_host = true
	_start_beacon()
	return OK

func join_game(address := "127.0.0.1", port := PORT) -> int:
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = p
	active = true
	is_host = false
	return OK

func leave() -> void:
	_stop_beacon()
	multiplayer.multiplayer_peer = null
	active = false
	is_host = false
	remote_players.clear()

# ---------- LAN discovery ----------

## IPv4 addresses other computers on the same network can use to reach this one.
func lan_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			out.append(a)
	return out

func _start_beacon() -> void:
	_stop_beacon()
	var dests := ["255.255.255.255", "127.0.0.1"]
	for a in lan_addresses():
		var p: PackedStringArray = a.split(".")
		dests.append("%s.%s.%s.255" % [p[0], p[1], p[2]])         # this subnet's directed broadcast
	for d in dests:
		var u := PacketPeerUDP.new()
		u.set_broadcast_enabled(true)
		u.set_dest_address(d, LAN_PORT)
		_beacons.append(u)

func _stop_beacon() -> void:
	for u in _beacons:
		u.close()
	_beacons.clear()

## Start listening for hosts on the local network (the join screen calls this).
func start_lan_scan() -> void:
	if _scanner != null:
		return
	_scanner = PacketPeerUDP.new()
	_scanner.set_broadcast_enabled(true)
	var err := _scanner.bind(LAN_PORT, "*")
	if err != OK:
		_scanner = null

func stop_lan_scan() -> void:
	if _scanner != null:
		_scanner.close()
		_scanner = null
	lan_hosts.clear()

func _lan_tick(delta: float) -> void:
	if !_beacons.is_empty() and is_host:
		_beacon_t += delta
		if _beacon_t >= 1.0:
			_beacon_t = 0.0
			var msg := ("DOTK1|%s|%d|%d" % [my_name, PORT, 1 + remote_players.size()]).to_utf8_buffer()
			for u in _beacons:
				u.put_packet(msg)
	if _scanner != null:
		while _scanner.get_available_packet_count() > 0:
			var text := _scanner.get_packet().get_string_from_utf8()
			var ip := _scanner.get_packet_ip()
			var parts := text.split("|")
			if parts.size() >= 4 and parts[0] == "DOTK1":
				lan_hosts[ip] = {"name": parts[1], "port": int(parts[2]), "players": int(parts[3]), "seen_ms": Time.get_ticks_msec()}
		for ip in lan_hosts.keys():
			if Time.get_ticks_msec() - lan_hosts[ip].seen_ms > 4000:
				lan_hosts.erase(ip)

# ---------- host side ----------

func _on_peer_connected(id: int) -> void:
	if !is_host:
		return
	spawn_avatar(id)

## A new world (after "Restart run" reloads the scene) needs an avatar for everyone still connected.
func respawn_avatars() -> void:
	remote_players.clear()
	_prev.clear()
	for id in multiplayer.get_peers():
		spawn_avatar(id)
	Rep.event("announce", ["RUN_START"], true)

func spawn_avatar(id: int) -> void:
	if Game.world == null:
		return
	var pl = preload("res://player/player.tscn").instantiate()
	pl.remote_controlled = true
	pl.set_meta("peer_id", id)
	pl.name = "RemotePlayer%d" % id
	pl.position = Vector2(20, 0)
	pl.get_node("Camera2D").enabled = false          # the host keeps its own camera
	Game.world.add_child(pl)
	give_weapon(pl, Game.start_weapon_id() if Game.start_weapon_id() in Game.start_weapon_options() else "sword")      # a joining player starts with the host's chosen starting weapon (the free sword by default)
	remote_players[id] = pl
	_prev[id] = {}
	if !_last_slow.is_empty():
		net_snapshot_slow.rpc_id(id, _last_slow)          # a joiner needs the slow part right away
	client_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	names.erase(id)
	if remote_players.has(id):
		var pl = remote_players[id]
		if is_instance_valid(pl):
			if pl.is_in_tower:
				Game.exit_base(pl)          # leaving mid-keep must not leave the keep marked occupied
			Game.announce.emit("%s left the co-op game" % names.get(id, "A player"))
			pl.queue_free()
		remote_players.erase(id)
		_prev.erase(id)

@rpc("any_peer", "call_remote", "reliable")
func net_hello(player_name: String) -> void:
	if !is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	names[id] = player_name.substr(0, 16)
	Game.announce.emit("%s joined the co-op game" % names[id])

@rpc("any_peer", "call_remote", "unreliable")
func net_input(state: Dictionary) -> void:
	if !is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	apply_input_state(id, remote_players.get(id), state)

## Drive an avatar from one input state: {move, aim (a world point), attack, ability, dash, ultimate}.
## Used for network clients and for local split-screen players alike.
func apply_input_state(id: int, pl, state: Dictionary) -> void:
	if pl == null or !is_instance_valid(pl):
		return
	pl.remote_input = {"move": state.move, "aim": state.aim}
	var prev: Dictionary = _prev.get(id, {})
	var item = pl.item
	if item != null and !pl.has_crystal:            # whoever carries the crystal cannot fight
		if state.attack and !prev.get("attack", false) and item.has_method("use_item"):
			item.use_item()
		elif !state.attack and prev.get("attack", false) and item.has_method("release_item"):
			item.release_item()
		if state.ability and !prev.get("ability", false) and item.has_method("use_ability"):
			item.use_ability()
		elif !state.ability and prev.get("ability", false) and item.has_method("release_ability"):
			item.release_ability()
		if state.dash and !prev.get("dash", false) and item.has_method("use_dash"):
			item.use_dash()
		if state.ultimate and !prev.get("ultimate", false) and item.has_method("use_ultimate"):
			item.use_ultimate()
	_prev[id] = state

## Next weapon slot for an avatar.
func switch_weapon(pl) -> void:
	if pl.weapon_slots.size() > 1:
		pl.active_slot = (pl.active_slot + 1) % pl.weapon_slots.size()
		pl.equip_item(Game.weapon_info(pl.weapon_slots[pl.active_slot]))

const FORGE_POS := Vector2(-62, 22)

## Give a co-op avatar a weapon: a free slot if there is one, otherwise swap with the
## active weapon (the old one is dropped as a pickup).
func give_weapon(pl, entry: String) -> void:
	var slots: Array = pl.weapon_slots
	if slots.size() < 3:
		slots.append(entry)
		pl.active_slot = slots.size() - 1
	else:
		var old: String = slots[pl.active_slot]
		slots[pl.active_slot] = entry
		var pick = load("res://collectables/collectable.tscn").instantiate()
		pick.item_type = Game.entry_id(old)
		pick.bonus = Game.weapon_bonus(old)
		pick.twist = Game.entry_twist(old)
		pick.fixed = true
		pick.position = pl.global_position + Vector2(0, 18)
		Game.world.add_child.call_deferred(pick)
	pl.equip_item(Game.weapon_info(entry))

func _interact(pl) -> void:
	if pl.downed:
		return
	if pl.is_in_tower:
		_set_base(pl, false)
		return
	if _nearest_tower(pl.global_position, 60.0) != null:
		_set_base(pl, true)
		return
	for c in get_tree().get_nodes_in_group("chest"):
		if is_instance_valid(c) and !c.opened and c.global_position.distance_to(pl.global_position) <= 30.0:
			c.open_now()
			return
	for g in get_tree().get_nodes_in_group("generator"):
		if is_instance_valid(g) and !Rep.is_puppet(g) and g.is_visible_in_tree() and g.global_position.distance_to(pl.global_position) <= 28.0:
			g.use(pl)
			return
	for p in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(p) and p.global_position.distance_to(pl.global_position) <= 28.0:
			p.pickup_by(pl)
			return

func _fuse(pl, a: int, b: int) -> void:
	if pl.global_position.distance_to(FORGE_POS) > 50.0:
		return
	var slots: Array = pl.weapon_slots
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return
	var ida := Game.entry_id(slots[a])
	var idb := Game.entry_id(slots[b])
	var r: Dictionary = Fusion.recipe(ida, idb)
	if r.is_empty():
		return
	var cost: Dictionary = Fusion.cost(r.tier)
	if !Game.fusion_tier_unlocked(r.tier) or !Game.can_afford(cost):
		return
	Game.pay(cost)
	Game.note_recipe(Fusion.key(ida, idb))
	var hi: int = max(a, b)
	var lo: int = min(a, b)
	slots.remove_at(hi)
	slots.remove_at(lo)
	give_weapon(pl, Game.make_weapon_entry(r.id, 0, Game.weapon_twist(r.id, r.tier)))

## Two identical copies (same weapon and tier) combine into one a tier higher.
func _combine(pl, a: int, b: int) -> void:
	if pl.global_position.distance_to(FORGE_POS) > 50.0:
		return
	var slots: Array = pl.weapon_slots
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return
	var result := Game.combine_weapons(slots[a], slots[b])
	if result == "":
		return
	var cost: Dictionary = Game.combine_cost(slots[a])
	if !Game.can_afford(cost):
		return
	Game.pay(cost)
	slots.remove_at(max(a, b))
	slots.remove_at(min(a, b))
	give_weapon(pl, result)

## Commands that are not continuous input: enter/leave the keep, cast, repair, upgrade.
@rpc("any_peer", "call_remote", "reliable")
func net_command(cmd: Dictionary) -> void:
	if !is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	var pl = remote_players.get(id)
	if pl == null or !is_instance_valid(pl):
		return
	match cmd.get("cmd", ""):
		"base":
			_set_base(pl, cmd.get("on", false))
		"interact":
			_interact(pl)
		"switch":
			switch_weapon(pl)
		"draft":
			if Game.draft_active and cmd.id in Game.draft_options:
				Game.take_draft_card(cmd.id)
		"combine":
			_combine(pl, int(cmd.a), int(cmd.b))
		"merge":
			if pl.is_in_tower:
				Game.merge_hand(int(cmd.a), int(cmd.b))
		"fuse":
			_fuse(pl, int(cmd.a), int(cmd.b))
		"cast":
			if pl.is_in_tower:
				Game.cast(cmd.card, cmd.pos, pl)
		"tower_tp":
			if pl.is_in_tower:
				Game.teleport_to_tower(pl, Game.tower_at(cmd.pos, 34.0, Game.current_tower(pl)), false)
		"repair":
			if pl.is_in_tower:
				Game.repair_keep()
		"upgrade":
			if pl.is_in_tower:
				Game.buy_upgrade(cmd.id)

func _nearest_tower(pos: Vector2, max_dist: float):
	var best = null
	for c in Game.world.get_children():
		if c is StaticBody2D and c.name.begins_with("Tower"):
			var d: float = c.global_position.distance_to(pos)
			if d <= max_dist and (best == null or d < best.global_position.distance_to(pos)):
				best = c
	return best

func _set_base(pl, on: bool) -> void:
	if on and !pl.is_in_tower:
		var tower = _nearest_tower(pl.global_position, 60.0)
		if tower == null:
			return
		pl.is_in_tower = true
		pl.global_position = tower.global_position - Vector2(0, 10)
		Game.enter_base(pl)
	elif !on and pl.is_in_tower:
		pl.is_in_tower = false
		Game.exit_base(pl)
		pl.global_position += Vector2(0, 40)

func roster() -> Dictionary:
	var r := {1: "Host"}
	for id in names:
		r[id] = names[id]
	return r

func _pickups() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(p) and out.size() < 60:
			out.append({"pos": p.global_position, "type": p.item_type})
	return out

func _chests() -> Array:
	var out := []
	for c in get_tree().get_nodes_in_group("chest"):
		if is_instance_valid(c):
			out.append({"pos": c.global_position, "kind": c.kind, "t": c.time_left})
	return out

## Cooldowns of the weapon in a player's hand, for the client's ability HUD.
func _cooldowns(p) -> Dictionary:
	var out := {}
	var item = p.item
	if item != null and item.has_method("cd_info"):
		for slot in ["attack", "ability", "dash", "ultimate"]:
			out[slot] = item.cd_info(slot)
	return out

func build_snapshot() -> Dictionary:
	var players := []
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			players.append({"id": p.get_meta("peer_id", 1), "pos": p.global_position, "hp": (p.remote_hp if p.remote_controlled else 228.0) / 228.0, "base": p.is_in_tower, "slots": p.weapon_slots, "active": p.active_slot, "near_forge": p.global_position.distance_to(FORGE_POS) <= 50.0, "down": (ceili(p.respawn_left) if p.downed else 0), "carried": (p.carried if p.remote_controlled else Game.carried)})
	return {
		"players": players,
		"keep": Game.keep_hp, "mana": Game.mana, "wave": Game.run_stats.waves,
		"max_mana": Game.max_mana(), "hand": Game.hand, "resources": Game.resources, "deck": Game.deck,
		"upgrades": Game.upgrade_levels, "keep_max": Game.keep_max(),
		"roster": roster(), "lobby": lobby, "draft": Game.draft_options, "forge": FORGE_POS,
		"sectors": Game.sectors_unlocked, "t": Time.get_ticks_msec(),
	}

var my_cd := {}                    # client: this player's weapon cooldowns (sent apart so snapshots stay under the packet size)

@rpc("authority", "call_remote", "unreliable")
func net_cooldowns(cd: Dictionary) -> void:
	my_cd = cd

const SLOW_SNAPSHOT_KEYS := ["hand", "resources", "deck", "upgrades", "roster", "lobby", "draft", "forge", "sectors", "max_mana", "keep_max"]
var _last_slow := {}
var _slow_cache := {}              # client: the latest slow part, merged into every snapshot

@rpc("authority", "call_remote", "reliable")
func net_snapshot_slow(slow: Dictionary) -> void:
	_slow_cache = slow
	for k in slow:
		last_snapshot[k] = slow[k]
	snapshot_received.emit(last_snapshot)

@rpc("authority", "call_remote", "unreliable")
func net_snapshot(data: Dictionary) -> void:
	for k in _slow_cache:
		data[k] = _slow_cache[k]
	last_snapshot = data
	snapshot_received.emit(data)

func _process(delta: float) -> void:
	_lan_tick(delta)
	if !active or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if is_host:
		_snap_t += delta
		if _snap_t >= 0.1 and !multiplayer.get_peers().is_empty():
			_snap_t = 0.0
			var snap := build_snapshot()
			# the slow parts (hand, resources, deck, draft, roster...) go as a small RELIABLE message, only when they change:
			# one unreliable snapshot near the packet size limit can be dropped, and a dropped draft or hand would not come back
			var slow := {}
			for k in SLOW_SNAPSHOT_KEYS:
				if snap.has(k):
					slow[k] = snap[k]
					snap.erase(k)
			if slow != _last_slow:
				_last_slow = slow
				net_snapshot_slow.rpc(slow)
			net_snapshot.rpc(snap)
			for id in remote_players:
				if is_instance_valid(remote_players[id]):
					net_cooldowns.rpc_id(id, _cooldowns(remote_players[id]))
	else:
		_input_t += delta
		if _input_t >= 0.05:
			_input_t = 0.0
			net_input.rpc_id(1, local_input)

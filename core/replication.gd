extends Node
## Automatic multiplayer replication. Autoload "Rep".
##
## THE RULE FOR NEW CONTENT: a gameplay node (enemy, structure, projectile, pickup...)
## joins the group "net" in its _ready (add_to_group("net")) and it is replicated to every
## client with no further work:
##   * the host spawns it on each client as a PUPPET of the same scene/script (logic off,
##     collisions off, visuals and animations on),
##   * every PUBLIC script variable (no leading underscore) is synced, only when it changes.
##     Keep a variable local by naming it _like_this, or list it in `const NET_SKIP := [...]`.
##   * position, rotation, scale, modulate and visibility are synced and smoothed,
##   * when the host frees the node, the puppet is freed.
## Visual-only timers: a puppet's `age` / `_age` variable is advanced locally each frame, or
## define `func net_tick(delta)` for custom visuals. A puppet can test `Rep.is_puppet(self)`
## in _ready to skip host-only setup.
## One-shot effects go through WeaponFx.spawn / DamageNumber.spawn / Sfx.play / Game.announce,
## which are mirrored to clients automatically (Rep.event).
## Game state: every public variable of the Game autoload is synced the same way
## (exclusions in Game.NET_SKIP).
## tools/tests/net_coverage.gd fails if a gameplay node is neither replicated nor listed
## as local-only, so forgetting the group is caught.

const TICK := 0.1                    # every node is sent at 10 Hz...
const SLICES := 5                    # ...but the work is spread over 5 slices so no single frame pays for all of it
const BUILTINS := ["modulate", "scale", "z_index"]
const MAX_DEPTH := 4

var client_root: Node:                # client: where puppets live (the client view)
	set(v):
		client_root = v
		if v != null:
			for rec in _pending:
				_client_spawn(rec)
			_pending.clear()
var _pending: Array = []              # spawn records that arrived before the client view existed
var _next_id := 1
var _host_ids := {}                   # instance id -> net id
var _host_nodes := {}                 # net id -> node
var _last := {}                       # net id -> last sent state
var _game_last := {}
var _prop_cache := {}                 # script path -> property names
var _skip_cache := {}
var _puppets := {}                    # client: net id -> node
var _targets := {}                    # client: net id -> {pos, rot}
var _timer := 0.0
var _slice := 0
var spawned_count := 0                # stats for tests
var updates_sent := 0

func _ready() -> void:
	Net.client_connected.connect(_on_client_connected)
	Game.announce.connect(func(text: String): if hosting(): event("announce", [text]))
	Game.run_ended.connect(func(info: Dictionary): event("announce", ["RUN_END|" + String(info.reason)], true))

func hosting() -> bool:
	return Net.active and Net.is_host and multiplayer.multiplayer_peer != null and !multiplayer.get_peers().is_empty()

func is_puppet(n: Node) -> bool:
	return n != null and n.has_meta("net_puppet")

# ---------------------------------------------------------------- state extraction

func _script_chain(n: Object) -> Array:
	var out := []
	var s = n.get_script()
	while s != null:
		out.append(s)
		s = s.get_base_script()
	return out

func _prop_names(n: Node) -> Array:
	var s = n.get_script()
	if s == null:
		return []
	var key: String = s.resource_path
	if _prop_cache.has(key):
		return _prop_cache[key]
	var skip := []
	for sc in _script_chain(n):
		var consts: Dictionary = sc.get_script_constant_map()
		if consts.has("NET_SKIP"):
			skip.append_array(consts["NET_SKIP"])
	var names := []
	for sc in _script_chain(n):
		for p in sc.get_script_property_list():
			if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var pname: String = p.name
			if pname.begins_with("_") or pname in skip or pname in names:
				continue
			if p.type == TYPE_OBJECT or p.type == TYPE_CALLABLE or p.type == TYPE_SIGNAL or p.type == TYPE_RID:
				continue
			names.append(pname)
	_prop_cache[key] = names
	return names

## True if a value can cross the network (no Objects anywhere inside).
func ser_ok(v: Variant, depth := 0) -> bool:
	match typeof(v):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return false
		TYPE_ARRAY:
			if depth > MAX_DEPTH or v.size() > 400:
				return false
			for x in v:
				if !ser_ok(x, depth + 1):
					return false
		TYPE_DICTIONARY:
			if depth > MAX_DEPTH or v.size() > 400:
				return false
			for k in v:
				if !ser_ok(k, depth + 1) or !ser_ok(v[k], depth + 1):
					return false
	return true

func _copy(v: Variant) -> Variant:
	if typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY:
		return v.duplicate(true)
	return v

func state_of(n: Node) -> Dictionary:
	var st := {}
	for k in _prop_names(n):
		var v = n.get(k)
		if ser_ok(v):
			st[k] = _copy(v)
	if n is Node2D:
		st["pos"] = n.global_position
		st["rot"] = n.rotation
	if n is CanvasItem:
		st["vis"] = n.is_visible_in_tree()
		for b in BUILTINS:
			st[b] = n.get(b)
	return st

func _delta(id: int, n: Node) -> Dictionary:
	var cur := state_of(n)
	var last: Dictionary = _last[id]
	var d := {}
	for k in cur:
		if !last.has(k) or typeof(cur[k]) != typeof(last[k]) or cur[k] != last[k]:
			d[k] = cur[k]
	_last[id] = cur
	return d

# ---------------------------------------------------------------- host

func _process(delta: float) -> void:
	if !Net.active or multiplayer.multiplayer_peer == null:
		return
	if Net.is_host:
		_timer += delta
		if _timer >= TICK / SLICES:
			_timer = 0.0
			if !multiplayer.get_peers().is_empty():
				_slice = (_slice + 1) % SLICES
				_host_tick(_slice)
	else:
		_client_frame(delta)

## A node that is part of a replicated scene's own file (like the crystal inside the Well)
## comes along with it. Children added at run time (a turret on a tower) replicate on their own.
func _has_net_ancestor(n: Node) -> bool:
	if n.has_meta("net_own"):
		return false
	var o := n.owner
	while o != null:
		if o != n and o.is_in_group("net"):
			return true
		o = o.owner
	return false

func _spawn_record(id: int, n: Node, state: Dictionary) -> Dictionary:
	var rec := {"id": id, "state": state, "parent": "."}
	if n.scene_file_path != "":
		rec["scene"] = n.scene_file_path
	else:
		rec["script"] = n.get_script().resource_path
	var par := n.get_parent()
	if par != null and Game.world != null and Game.world.is_ancestor_of(n):
		rec["parent"] = str(Game.world.get_path_to(par))
	return rec

func _host_tick(slice := 0) -> void:
	var spawns := []
	var updates := {}
	var seen := {}
	for n in get_tree().get_nodes_in_group("net"):
		if !is_instance_valid(n) or n.is_queued_for_deletion() or is_puppet(n):
			continue
		if n.get_script() == null and n.scene_file_path == "":
			continue
		if n.get_instance_id() % SLICES != slice:
			continue                # another slice sends this one
		if _has_net_ancestor(n):
			continue                # part of a replicated scene (e.g. the crystal inside the Well)
		var iid := n.get_instance_id()
		var id: int = _host_ids.get(iid, 0)
		if id == 0:
			id = _next_id
			_next_id += 1
			_host_ids[iid] = id
			_host_nodes[id] = n
			var st := state_of(n)
			_last[id] = st
			spawns.append(_spawn_record(id, n, st))
		else:
			var d := _delta(id, n)
			if !d.is_empty():
				updates[id] = d
		seen[id] = true
	var gone := []
	for id in _host_nodes.keys():
		if !seen.has(id) and (!is_instance_valid(_host_nodes[id]) or _host_nodes[id].get_instance_id() % SLICES == slice or _host_nodes[id].is_queued_for_deletion()):
			gone.append(id)
			_host_ids.erase(_host_nodes[id].get_instance_id() if is_instance_valid(_host_nodes[id]) else -1)
			_host_nodes.erase(id)
			_last.erase(id)
	var game_d := _game_delta() if slice == 0 else {}
	if !spawns.is_empty() or !gone.is_empty():
		_send_spawns(spawns, gone)
	_send_updates(updates, game_d)

const FAST_GAME_KEYS := ["mana", "keep_hp", "crystal_eta", "night_level", "run_stats"]
const MAX_PACKET := 1100            # keep unreliable packets under the ~1400 byte MTU

## Updates go out in packets small enough not to fragment; the Game state rides in the first.
func _send_updates(updates: Dictionary, game_d: Dictionary) -> void:
	if updates.is_empty() and game_d.is_empty():
		return
	# Game state: the rarely-changing parts (sectors, hand, deck, resources...) go in a small RELIABLE message, because a
	# change is only sent once and a lost packet would leave a client stale for good. Numbers that change all the time
	# (mana, keep hp, stats) ride in the unreliable updates: the next change repairs a lost one.
	if !game_d.is_empty():
		var slow := {}
		for k in game_d.keys():
			if !(k in FAST_GAME_KEYS):
				slow[k] = game_d[k]
				game_d.erase(k)
		if !slow.is_empty():
			rep_game.rpc(slow)
		if updates.is_empty() and game_d.is_empty():
			return
	var chunk := {}
	var size := var_to_bytes(game_d).size() if !game_d.is_empty() else 0
	var first := true
	for id in updates:
		var sz := var_to_bytes(updates[id]).size() + 8
		if !chunk.is_empty() and size + sz > MAX_PACKET:
			rep_update.rpc(chunk, game_d if first else {})
			updates_sent += 1
			first = false
			chunk = {}
			size = 0
		chunk[id] = updates[id]
		size += sz
	if !chunk.is_empty() or (first and !game_d.is_empty()):
		rep_update.rpc(chunk, game_d if first else {})
		updates_sent += 1

## Spawn lists can be long (a whole map at join), so they are sent in reliable batches.
func _send_spawns(spawns: Array, gone: Array, peer := 0) -> void:
	var batch := []
	var size := 0
	for rec in spawns:
		var sz := var_to_bytes(rec).size()
		if !batch.is_empty() and size + sz > 3000:
			_rpc_spawn(batch, [], peer)
			batch = []
			size = 0
		batch.append(rec)
		size += sz
	_rpc_spawn(batch, gone, peer)

func _rpc_spawn(batch: Array, gone: Array, peer: int) -> void:
	if batch.is_empty() and gone.is_empty():
		return
	if peer == 0:
		rep_spawn.rpc(batch, gone)
	else:
		rep_spawn.rpc_id(peer, batch, gone)

func _on_client_connected(peer: int) -> void:
	if !Net.is_host:
		return
	# a late joiner gets every live node and the full game state
	var spawns := []
	for id in _host_nodes:
		var n = _host_nodes[id]
		if is_instance_valid(n):
			spawns.append(_spawn_record(id, n, state_of(n)))
	_send_spawns(spawns, [], peer)
	rep_game.rpc_id(peer, _game_state())             # reliable: a joiner must get the whole state

# ---------------------------------------------------------------- Game state

func _game_state() -> Dictionary:
	var out := {}
	var skip: Array = Game.NET_SKIP
	for p in Game.get_script().get_script_property_list():
		if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var pname: String = p.name
		if pname.begins_with("_") or pname in skip or p.type == TYPE_OBJECT:
			continue
		var v = Game.get(pname)
		if ser_ok(v):
			out[pname] = _copy(v)
	return out

func _game_delta() -> Dictionary:
	var cur := _game_state()
	var d := {}
	for k in cur:
		if !_game_last.has(k) or cur[k] != _game_last[k]:
			d[k] = cur[k]
	_game_last = cur
	return d

# ---------------------------------------------------------------- events (host -> clients)

## A one-shot happening (effect, sound, damage number, message) replayed on every client.
func event(kind: String, args: Array, reliable := false) -> void:
	if hosting():
		if reliable:
			rep_event_reliable.rpc(kind, args)
		else:
			rep_event.rpc(kind, args)

@rpc("authority", "call_remote", "unreliable")
func rep_event(kind: String, args: Array) -> void:
	_handle_event(kind, args)

@rpc("authority", "call_remote", "reliable")
func rep_event_reliable(kind: String, args: Array) -> void:
	_handle_event(kind, args)

func _handle_event(kind: String, args: Array) -> void:
	var world: Node = client_root
	match kind:
		"fx":      # loaded at run time: these scripts call Rep too, so no compile-time reference
			load("res://items/weapons/fx.gd").spawn(world, args[0], args[1], args[2], args[3])
		"dmg":
			load("res://ui/fx/damage_number.gd").spawn(world, args[0], args[1], args[2], args[3])
		"sfx":
			Sfx.play(args[0], args[1], args[2])
		"announce":
			Game.announce.emit(args[0])
		_:
			pass

# ---------------------------------------------------------------- client

@rpc("authority", "call_remote", "reliable")
func rep_spawn(spawns: Array, gone: Array) -> void:
	for rec in spawns:
		if client_root == null:
			_pending.append(rec)
		else:
			_client_spawn(rec)
	for id in gone:
		var n = _puppets.get(id)
		if is_instance_valid(n):
			n.queue_free()
		_puppets.erase(id)
		_targets.erase(id)

@rpc("authority", "call_remote", "reliable")
func rep_game(state: Dictionary) -> void:
	for k in state:
		Game.set(k, state[k])
	Game.net_synced.emit()

@rpc("authority", "call_remote", "unreliable")
func rep_update(updates: Dictionary, game_state: Dictionary) -> void:
	for id in updates:
		var n = _puppets.get(id)
		if !is_instance_valid(n):
			continue
		_apply_state(n, updates[id], false)
		if updates[id].has("pos"):
			_targets[id]["pos"] = updates[id].pos
	if !game_state.is_empty():
		for k in game_state:
			Game.set(k, game_state[k])
		Game.net_synced.emit()

func _apply_state(n: Node, st: Dictionary, pre_tree: bool) -> void:
	for k in st:
		match k:
			"pos":
				if pre_tree:
					n.position = st[k]
				elif !_targets.has(_id_of(n)):
					n.global_position = st[k]
			"rot":
				n.rotation = st[k]
			"vis":
				n.visible = st[k]
			_:
				n.set(k, st[k])

func _id_of(n: Node) -> int:
	return int(n.get_meta("net_id", 0))

func _ensure_parent(path: String) -> Node:
	if client_root == null:
		return null
	if path == "." or path == "":
		return client_root
	var cur: Node = client_root
	for part in path.split("/", false):
		if part == "..":
			continue
		var nxt := cur.get_node_or_null(part)
		if nxt == null:
			nxt = Node2D.new()
			nxt.name = part
			cur.add_child(nxt)
		cur = nxt
	return cur

func _client_spawn(rec: Dictionary) -> void:
	if _puppets.has(rec.id):
		return
	var n: Node
	if rec.has("scene"):
		n = (load(rec.scene) as PackedScene).instantiate()
	else:
		n = (load(rec.script) as GDScript).new()
	n.set_meta("net_puppet", true)
	n.set_meta("net_id", rec.id)
	_apply_state(n, rec.state, true)
	var parent := _ensure_parent(rec.parent)
	if parent == null:
		n.queue_free()
		return
	parent.add_child(n)
	_apply_state(n, rec.state, false)       # _ready may have changed things: the host's values win
	if n is Node2D and rec.state.has("pos"):
		n.global_position = rec.state.pos
	_make_puppet(n)
	_puppets[rec.id] = n
	_targets[rec.id] = {"pos": rec.state.get("pos", Vector2.ZERO)}
	spawned_count += 1

## Switch a replicated node's own behaviour off; it only shows what the host sends.
func _make_puppet(n: Node) -> void:
	for c in n.find_children("*", "", true, true):
		if c != n and c.has_meta("net_own") and c.owner == n:
			c.queue_free()              # the real one replicates separately
	n.add_to_group("puppet")
	n.set_process(false)
	n.set_physics_process(false)
	n.set_process_input(false)
	n.set_process_unhandled_input(false)
	n.set_process_unhandled_key_input(false)
	var kids := n.find_children("*", "", true, false)
	kids.append(n)
	for c in kids:
		if c is Timer:
			c.stop()
		if c is CollisionObject2D:
			c.collision_layer = 0
			c.collision_mask = 0
		if c is Area2D:
			c.set_deferred("monitoring", false)
			c.set_deferred("monitorable", false)
		if c is NavigationAgent2D:
			c.avoidance_enabled = false

func _client_frame(delta: float) -> void:
	var k: float = 1.0 - exp(-14.0 * delta)
	for id in _puppets.keys():
		var n = _puppets[id]
		if !is_instance_valid(n):
			_puppets.erase(id)
			_targets.erase(id)
			continue
		if n is Node2D:
			var tgt: Vector2 = _targets[id].pos
			var prev: Vector2 = n.global_position
			n.global_position = prev.lerp(tgt, k)
			var dx: float = tgt.x - prev.x
			if absf(dx) > 0.3:
				var sp = n.get_node_or_null("Sprite2D")
				if sp is Sprite2D:
					sp.scale.x = absf(sp.scale.x) * (-1.0 if dx < 0.0 else 1.0)
		# visual timers
		if "age" in n and typeof(n.get("age")) == TYPE_FLOAT:
			n.age += delta
		if "_age" in n and typeof(n.get("_age")) == TYPE_FLOAT:
			n._age += delta
		if n.has_method("net_tick"):
			n.net_tick(delta)
		if n is CanvasItem and n.has_method("_draw"):
			n.queue_redraw()

func puppet_count() -> int:
	var c := 0
	for id in _puppets:
		if is_instance_valid(_puppets[id]):
			c += 1
	return c

func puppets_of_group(group: String) -> Array:
	var out := []
	for id in _puppets:
		var n = _puppets[id]
		if is_instance_valid(n) and n.is_in_group(group):
			out.append(n)
	return out

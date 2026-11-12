extends SceneTree
## Shared helpers of the building tier tests (structure_tiers_*.gd): each of those extends this and lists its card sections.
var game
var world
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
## A still target (damage dealt = 99999 - health).
func dummy(pos: Vector2, hp := 99999.0):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.health = hp
	e.set_physics_process(false)
	return e
func dealt(e) -> float:
	return 99999.0 - e.health
## Place a building of a card at a tier (its own stacked additions included, like a real one).
func build(id: String, tier: int, pos: Vector2, tough := true):
	game.meta.card_tiers[id] = 6
	var st = load("res://cards/structure.gd").new()
	st.setup(game.stats_of(game.make_entry(id, tier, game.twist_for(id, tier))), pos)
	world.add_child(st)
	if tough:
		st.max_hp = 99999.0
		st.hp = 99999.0
	return st
func clear() -> void:
	for n in world.get_children():
		if n.get_script() != null and (str(n.get_script().resource_path).ends_with("structure.gd") or str(n.get_script().resource_path).ends_with("projectile.gd") or str(n.get_script().resource_path).ends_with("hazard.gd") or str(n.get_script().resource_path).ends_with("spell.gd")):
			n.queue_free()
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.2)
func fx_seen(secs: float) -> Dictionary:
	var seen := {}
	var out := {}
	var t := 0.0
	while t < secs:
		await wait(0.05)
		t += 0.05
		for n in world.get_children():
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("fx.gd") and !seen.has(n.get_instance_id()):
				seen[n.get_instance_id()] = true
				out[n.kind] = int(out.get(n.kind, 0)) + 1
	return out
func exposed(e) -> bool:
	return load("res://items/weapons/weapon_util.gd").is_exposed(e)
func count_nodes(file: String) -> int:
	var n := 0
	for c in world.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with(file):
			n += 1
	return n
## Sections to run, in order: each is the name of a method (the card id). `-- only=<id>` runs one.
func sections() -> Array:
	return []
func player():
	return world.get_node("Player")
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://tier_structs_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	world.set_process(false)                 # (the day clock stands still: it is day, so defences see everything)
	game.night_level = 0.0
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 700)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for id in sections():
		if only == "" or only == id:
			await call(id)
			await clear()
	quit()

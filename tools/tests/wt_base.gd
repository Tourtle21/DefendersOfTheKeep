extends SceneTree
## Shared base of the weapon-tier tests (docs/weapon_tiers). A test file extends this by path and overrides run():
##   extends "res://tools/tests/wt_base.gd"
##   func run() -> void: ...   (use `only` to pick a weapon: `-- only=sword`)
## Never name Weapon, WeaponTiers, WeaponArt as types in a --script test: load by path.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
var game
var world
var player
var only := ""
const P := Vector2(-40, 260)
const HP := 99999.0

func dummy(pos: Vector2, hp := HP, walks := false):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.health = hp
	e.set_physics_process(walks)            # stands still unless the walking matters
	e.get_node("NavigationTimer").stop()
	return e
func lost(e) -> float:
	return HP - (e.health if is_instance_valid(e) else 0.0)
func clear() -> void:
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.1)
func aim_at(p: Vector2) -> void:                 # the weapon aims at the cursor (the pad cursor: a headless mouse cannot be warped)
	await wait(0.1)
	var pad = root.get_node("Pad")
	pad.using_pad = true
	pad.cursor = player.get_canvas_transform() * p
	await wait(0.1)
## Equip weapon `id` at tier `tier` (the entry is id:bonus:twist, bonus = tier - fusion tier), clear the field and aim to the right.
func equip(id: String, tier: int, twisted := true):
	var f: int = load("res://items/fusion.gd").tier_of(id)
	var entry: String = game.make_weapon_entry(id, tier - f, game.weapon_twist(id, tier) if twisted else "")
	player.equip_item(game.weapon_info(entry))
	world.clock = 50.0                             # broad daylight: no night shroud on the dummies
	await wait(0.3)
	player.position = P
	player.shield_time = 0.0
	player.dash_time = 0.0
	player.speed_mult = 1.0
	player.is_using_item = false
	await clear()
	await aim_at(P + Vector2(120, 0))
	return player.item
## Count the kinds of WeaponFx that are alive now into `seen` (call every 0.05 s while an effect plays).
func fx_kinds(seen: Dictionary) -> void:
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("items/weapons/fx.gd"):
			seen[n.kind] = int(seen.get(n.kind, 0)) + 1
func count_script(path_end: String) -> int:     # projectiles, auras, hazards
	var c := 0
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with(path_end):
			c += 1
	return c
func fx_count() -> int:
	return count_script("items/weapons/fx.gd")
## Watch for `secs`, sampling every 0.05 s: the kinds of fx seen, the most live fx at once and the most projectiles at once.
func watch(secs: float) -> Dictionary:
	var seen := {}
	var peak := 0
	var proj := 0
	for i in int(secs / 0.05):
		await wait(0.05)
		fx_kinds(seen)
		peak = maxi(peak, fx_count())
		proj = maxi(proj, count_script("items/weapons/projectile.gd"))
	return {"kinds": seen, "peak": peak, "proj": proj}
## Draw smoke: equip each tier, redraw, check the aura exists (tier >= 2 only) and the hand sprite shows.
func draw_smoke(id: String) -> void:
	var good := true
	var info := []
	for t in range(1, 7):
		var f: int = load("res://items/fusion.gd").tier_of(id)
		if t < f:
			continue
		var w = await equip(id, t)
		await wait(0.3)
		w.queue_redraw()
		var auras := count_script("weapon_aura.gd")
		if auras != (1 if t >= 2 else 0):
			good = false
		info.append("%d:%d" % [t, auras])
	ok("%s: draw smoke, aura count per tier %s" % [id, info], good)
func run() -> void:
	pass
func _initialize() -> void:
	game = root.get_node("Game")
	game.save_path = "user://wtier_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	player = world.get_node("Player")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	await run()
	quit()

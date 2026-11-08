extends SceneTree
# Swarm enemies (scarab, splitter, minis) take +50% from area attacks; others are unaffected.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func make(world, type: String, pos: Vector2):
	var e = load("res://enemies/%s/%s.tscn" % [type, type]).instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.health = 1000.0
	e.max_health = 1000.0
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	for t in ["scarab", "splitter", "splitter_mini", "blobbert", "brute", "runner"]:
		var path := "res://enemies/%s/%s.tscn" % [t, t] if t != "splitter_mini" else "res://enemies/splitter/splitter_mini.tscn"
		var e = (load(path) as PackedScene).instantiate()
		e.position = Vector2(-40, 250)
		world.get_node("Enemies").add_child(e)
		e.set_physics_process(false)
		e.get_node("NavigationTimer").stop()
		e.health = 1000.0
		e.max_health = 1000.0
		e.spell_damage(4.0, "", false)
		var single: float = 1000.0 - e.health
		e.health = 1000.0
		e.spell_damage(4.0, "", true)
		var area: float = 1000.0 - e.health
		print("%-14s swarm=%s  single hit 4 -> %.1f   area hit 4 -> %.1f" % [t, e.swarm, single, area])
		e.queue_free()
	# a weapon hit on three scarabs in one frame is an area attack for the 2nd and 3rd
	var a = make(world, "scarab", Vector2(-20, 250))
	var b = make(world, "scarab", Vector2(0, 250))
	var c = make(world, "scarab", Vector2(20, 250))
	var util = load("res://items/weapons/weapon_util.gd")
	util.hit(a, 4.0, Vector2.ZERO)
	util.hit(b, 4.0, Vector2.ZERO)
	util.hit(c, 4.0, Vector2.ZERO)
	print("one swing across 3 scarabs: first ", 1000.0 - a.health, ", second ", 1000.0 - b.health, ", third ", 1000.0 - c.health)
	await wait(0.1)
	a.health = 1000.0
	util.hit(a, 4.0, Vector2.ZERO)
	print("a lone follow-up hit next frame: ", 1000.0 - a.health)
	# a fireball on a pack of 4 scarabs
	var pack := []
	for i in 4:
		pack.append(make(world, "scarab", Vector2(-30 + i * 12, 250)))
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.hand = ["fireball"]
	game.cast("fireball", Vector2(-12, 250), player)
	await wait(2.0)
	var dmg := []
	for e in pack: dmg.append(snapped(1000.0 - e.health, 0.1))
	print("fireball (5 dmg, fire) on 4 scarabs: ", dmg, " (5 x 1.5 = 7.5 each)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

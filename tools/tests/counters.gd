extends SceneTree
# Enemy counters: armor, element resist/weakness, slow weakness; spells and weapons carry elements.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func make(world, type: String):
	var e = load("res://enemies/%s/%s.tscn" % [type, type]).instantiate()
	e.position = Vector2(-40, 250)
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	return e
func dmg(world, type: String, amount: float, element: String, slow := false) -> float:
	var e = make(world, type)
	e.health = 1000.0
	e.max_health = 1000.0
	if slow:
		e.slow_mult = 0.5
	e.spell_damage(amount, element)
	var d: float = 1000.0 - e.health
	e.queue_free()
	return snapped(d, 0.01)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var types := ["blobbert", "brute", "runner", "golem", "frost_imp", "ember_imp", "bog_lurker", "crystal_guard"]
	var probes := [["small 1.5 phys", 1.5, "", false], ["heavy 6 phys", 6.0, "", false], ["pierce 2", 2.0, "pierce", false], ["fire 4", 4.0, "fire", false],
		["ice 4", 4.0, "ice", false], ["poison 4", 4.0, "poison", false], ["earth 4", 4.0, "earth", false], ["slowed 4 phys", 4.0, "", true]]
	var header := "%-14s" % "damage taken"
	for p in probes: header += " | %-14s" % p[0]
	print(header)
	for t in types:
		var row := "%-14s" % t
		for p in probes:
			row += " | %-14s" % str(dmg(world, t, p[1], p[2], p[3]))
		print(row)
	# elements carried by cards and weapons
	var els := []
	for id in game.CARDS:
		if game.CARDS[id].get("element", "") != "": els.append("%s=%s" % [id, game.CARDS[id].element])
	print("card elements: ", ", ".join(els))
	var info = world.get_node("Collectable").item_info
	var player = world.get_node("Player")
	for w in ["spear", "frostglaive", "emberflail", "bogstaff", "crystalwand", "scimitar", "rimelance"]:
		player.equip_item(info.items[w])
		await wait(0.2)
		print("weapon ", w, " element '", player.item.element, "' -> WeaponUtil.element '", load("res://items/weapons/weapon_util.gd").element, "'")
	# a fireball (fire) on a frost imp vs ember imp
	var a = make(world, "frost_imp")
	var b = make(world, "ember_imp")
	a.global_position = Vector2(-60, 250)
	b.global_position = Vector2(60, 250)
	a.health = 100.0; b.health = 100.0
	game.enter_base(player)
	game.mana = 100
	game.hand = ["fireball", "fireball"]
	game.cast("fireball", a.global_position, player)
	game.cast("fireball", b.global_position, player)
	await wait(2.0)
	print("two fireballs (5 dmg, fire): frost imp took ", snapped(100.0 - a.health, 0.1), ", ember imp took ", snapped(100.0 - b.health, 0.1))
	# boss weaknesses
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for id in ["s", "se", "ne", "n", "nw", "sw"]:
		var bs = sm._bosses[id]
		var row := "boss %-14s" % bs.boss_name
		for el in ["", "fire", "ice", "poison", "earth", "pierce"]:
			bs.health = 1000.0
			bs.max_health = 1000.0
			bs.spell_damage(4.0, el)
			row += " | %s %.1f" % [el if el != "" else "phys", 1000.0 - bs.health]
		print(row)
	# pips screenshot (needs a window)
	if DisplayServer.get_name() != "headless":
		for e in world.get_node("Enemies").get_children(): e.queue_free()
		var player2 = world.get_node("Player")
		player2.global_position = Vector2(-40, 330)
		var x := -100.0
		for t in types:
			var e = make(world, t)
			e.global_position = Vector2(x, 290)
			x += 26.0
		for c2 in world.get_children():
			if c2.get_script() and str(c2.get_script().resource_path).ends_with("help_ui.gd"): c2.panel.visible = false
		await wait(0.5)
		root.get_viewport().get_texture().get_image().save_png("user://counters.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

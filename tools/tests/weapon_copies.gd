extends SceneTree
# Weapon copies: per-copy tier and twist, rare drops, twists on hits, combining in the Forge.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = 5000.0
	e.health = 5000.0
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.fusion_tiers = [3, 4]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	for lvl in [0, 3, 5]:
		game.meta.skills = {"rare_draw": lvl} if lvl > 0 else {}
		var counts := {0: 0, 1: 0, 2: 0, 3: 0}
		var twists := 0
		for i in 3000:
			var e: String = game.roll_weapon_entry("spear")
			counts[game.weapon_bonus(e)] += 1
			if game.entry_twist(e) != "": twists += 1
		print("Rare Draws ", lvl, ": dropped spears with +1 tier %.1f%%, +2 %.1f%%, +3 %.1f%%; with a twist %.1f%%" % [counts[1] / 30.0, counts[2] / 30.0, counts[3] / 30.0, twists / 30.0])
	game.meta.skills = {}
	print("entries: ", game.weapon_info("spear:2:chill").entry, " bonus ", game.weapon_info("spear:2:chill").bonus, " twist ", game.weapon_info("spear:2:chill").twist, " tier ", game.weapon_tier_of("spear:2:chill"))
	# a pickup rolls its own copy
	game.meta.skills = {"rare_draw": 5}
	var rolled := []
	for i in 12:
		var pk = load("res://collectables/collectable.tscn").instantiate()
		pk.item_type = "hammer"
		pk.position = Vector2(0, 600)
		world.add_child(pk)
		rolled.append(pk.entry())
		pk.queue_free()
	print("12 hammer pickups at Rare Draws 5: ", rolled)
	game.meta.skills = {}
	# twists on hits
	var util = load("res://items/weapons/weapon_util.gd")
	var a = dummy(world, Vector2(0, 700))
	var b = dummy(world, Vector2(30, 700))
	for tw in ["bleed", "chill", "chain", "lifesteal", "thunder"]:
		a.health = 5000.0; b.health = 5000.0
		a.slow_mult = 1.0; a.slow_time = 0.0
		util.twist = tw
		util._twist_hits = 0
		var hr = world.get_node("Hud/Control2/ColorRect/Health")
		hr.size.x = 100.0
		for i in 4:
			util.hit(a, 4.0, Vector2(0, 650))
			await wait(0.05)
		await wait(1.8)
		print("twist ", tw, ": target took ", snapped(5000.0 - a.health, 0.1), " | neighbour took ", snapped(5000.0 - b.health, 0.1), " | target slow ", snapped(a.slow_mult, 0.01), " | player hp bar ", snapped(hr.size.x, 0.1))
	util.twist = ""
	# a copy equipped carries its twist into the weapon
	player.equip_item(game.weapon_info("spear:1:chain"))
	await wait(0.4)
	print("equipped spear:1:chain -> tier ", player.item.tier, " twist ", player.item.twist, " WeaponUtil.twist ", util.twist)
	# the Forge: combine two identical copies, fuse different ones
	var hud = world.get_node("Hud")
	for i in 3:
		hud.remove_slot(i)
	hud.equip_item(game.weapon_info("bow:1"))
	hud.equip_item(game.weapon_info("bow:1"))
	hud.equip_item(game.weapon_info("hammer"))
	game.resources = {"stone": 20, "stick": 20, "gold": 50, "iron": 20, "frost": 20, "ember": 20, "moss": 20, "gem": 20}
	var fui = null
	for c in world.get_children():
		if c.is_in_group("forge_ui"): fui = c
	fui.open()
	fui._toggle(0)
	fui._toggle(1)
	print("forge, two bow:1 selected: ", fui.info_label.text.replace("\n", " / "), " | button visible ", fui.awaken_button.visible, " enabled ", !fui.awaken_button.disabled)
	var gold0: int = game.resources.gold
	fui.awaken()
	print("combined: slots ", hud.item_slots.get_children().filter(func(sl): return sl.has_item).map(func(sl): return sl.current_item.entry), " | gold spent ", gold0 - game.resources.gold)
	fui.open()
	var filled := []
	var all_slots = hud.item_slots.get_children()
	for i in all_slots.size():
		if all_slots[i].has_item: filled.append(i)
	fui._toggle(filled[0])
	fui._toggle(filled[1])
	print("forge, a bow:2 and a hammer selected: ", fui.info_label.text.replace("\n", " / ").substr(0, 120))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

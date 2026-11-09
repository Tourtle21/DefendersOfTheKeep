extends SceneTree
## The Damage skill (weapon_dmg) must make the sword's basic swing hit harder too, not just the fancy weapons.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func dummy(world, pos: Vector2):
	var d = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	d.position = pos
	world.get_node("Enemies").add_child(d)
	d.set_physics_process(false)
	d.get_node("NavigationTimer").stop()
	d.max_health = 400.0; d.health = 400.0
	return d
func swing(world, p, d) -> float:
	d.health = 400.0
	d.is_taking_damage = false
	p.global_position = d.global_position + Vector2(-14, 0)
	p.item._on_animation_player_animation_finished("use_item")
	p.is_using_item = true
	await wait(0.9)
	return 400.0 - d.health
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://sd_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	for c in world.get_children():
		if c.name == "Collectable": c.queue_free()
	var d = dummy(world, Vector2(120, 120))
	var base := 0.0
	var boosted := 0.0
	game.meta.skills["weapon_dmg"] = 0
	p.equip_item(game.weapon_info("sword"))
	await wait(0.3)
	base = await swing(world, p, d)
	game.meta.skills["weapon_dmg"] = 5
	p.equip_item(game.weapon_info("sword"))
	await wait(0.3)
	boosted = await swing(world, p, d)
	print("  one sword hit: %.2f damage without the skill, %.2f with Sharpened Steel x5 (bonus %.2f)" % [base, boosted, game.bonus("weapon_dmg")])
	ok("the sword's basic attack hits harder with the Damage skill", base > 0.0 and boosted > base * 1.2)
	# every other weapon: the damage multiplier it sets for all its hits
	var WU = load("res://items/weapons/weapon_util.gd")
	var ratios := []
	for id in ["spear", "bow", "hammer", "daggers", "staff", "whip", "shield"]:
		game.meta.skills["weapon_dmg"] = 0
		p.equip_item(game.weapon_info(id))
		await wait(0.2)
		var a: float = WU.power
		game.meta.skills["weapon_dmg"] = 5
		p.equip_item(game.weapon_info(id))
		await wait(0.2)
		ratios.append(snappedf(WU.power / a, 0.01))
	print("  power ratio with the skill per weapon: ", ratios)
	ok("the skill raises the damage multiplier of every weapon by 30%", ratios.all(func(r): return is_equal_approx(r, 1.3)))
	quit()

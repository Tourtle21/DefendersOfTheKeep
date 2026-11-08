extends SceneTree
# Sword and Pickaxe have the same tier ladder as every weapon: tier 2 ability, tier 3 ultimate,
# bigger areas, copies that combine, always in the weapon chests, and they still fuse with other weapons.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.weapons = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var info = world.get_node("Collectable").item_info
	player.position = Vector2(-40, 260)
	print("chest pool with nothing bought: ", game.weapon_pool())
	var seen := {}
	for i in 200:
		seen[game.weapon_pool().pick_random()] = true
	print("200 chest picks cover: ", seen.keys())
	for entry in ["sword", "sword:1", "sword:2", "pickaxe", "pickaxe:1", "pickaxe:2"]:
		player.equip_item(game.weapon_info(entry))
		await wait(0.2)
		var w = player.item
		print(entry, " -> tier ", w.tier, ", ability ", w.ability_unlocked(), ", ultimate ", w.ultimate_unlocked(), ", area x", snapped(w.area(), 0.01), ", HUD slots ", [w.cd_info("ability")[3], w.cd_info("ultimate")[3]], " (locked flags)")
	# locked moves do nothing
	player.equip_item(game.weapon_info("sword"))
	await wait(0.2)
	player.item.use_ability()
	player.item.use_ultimate()
	print("tier 1 sword: ability cd ", player.item.ability_cd_left(), " ultimate cd ", player.item.ult_cd_left(), " (0 = nothing happened)")
	player.equip_item(game.weapon_info("sword:1"))
	await wait(0.2)
	player.item.use_ability()
	print("tier 2 sword: tier ", player.item.tier, " ability cd ", snapped(player.item.ability_cd_left(), 0.1))
	player.item.use_ultimate()
	print("tier 2 sword ultimate still locked: cd ", player.item.ult_cd_left())
	# pickaxe mines an area; bigger at higher tiers
	var results := {}
	for entry in ["pickaxe:1", "pickaxe:3"]:
		player.equip_item(game.weapon_info(entry))
		await wait(0.2)
		var rocks := []
		var centre: Vector2 = player.global_position + (player.aim_point() - player.global_position).limit_length(80.0)
		for i in 12:
			var b = load("res://collectables/rock/medium_rock.tscn").instantiate()
			b.position = centre + Vector2(1, 0).rotated(i * TAU / 12.0) * (14.0 + i * 3.0)
			world.add_child(b)
			rocks.append(b)
		await wait(0.1)
		player.item.use_ability()
		await wait(1.6)
		var mined := 0
		var broken := 0
		for b in rocks:
			if !is_instance_valid(b) or b.is_queued_for_deletion():
				broken += 1
				mined += 16
			else:
				mined += 16 - int(b.health)
		results[entry] = "%d of 12 rocks broken, %d health mined" % [broken, mined]
		for b in rocks:
			if is_instance_valid(b): b.queue_free()
		await wait(0.2)
	print("Seismic Strike on 12 medium rocks (16 health each): ", results)
	# copies combine; rare drops can be tools
	var walk := []
	var cur := "pickaxe"
	for i in 6:
		var nxt: String = game.combine_weapons(cur, cur)
		if nxt == "": break
		walk.append(nxt)
		cur = nxt
	print("pickaxe copies combine: ", walk, " (cap ", game.weapon_tier_cap(), ")")
	game.meta.skills = {"rare_draw": 5}
	var tiers := {}
	for i in 600:
		var e: String = game.roll_weapon_entry("sword")
		tiers[game.weapon_tier_of(e)] = tiers.get(game.weapon_tier_of(e), 0) + 1
	print("600 dropped swords at Rare Draws 5, by tier: ", tiers)
	game.meta.skills = {}
	print("still fuses: shield+sword ", game.Fusion.recipe("shield", "sword") if game.get("Fusion") else "", " | ", load("res://items/fusion.gd").recipe("shield", "sword"), " | hammer+pickaxe ", load("res://items/fusion.gd").recipe("hammer", "pickaxe"))
	quit()

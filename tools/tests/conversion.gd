extends SceneTree
## Mass Conversion (legendary card) and the Mindbender (legendary weapon): enemies in the area change sides for a long while,
## fight the rest, and the rest turn on them. Bosses cannot be converted.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func mk(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.max_health = 99999.0
	e.health = 99999.0
	e.set_physics_process(true)
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://cv_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 600)
	ok("the card is legendary and not a normal reward (rarity %d)" % game.card_rarity("mass_conversion"), game.is_legendary_card("mass_conversion") and game.card_rarity("mass_conversion") == 6 and "mass_conversion" in game.LEGENDARY_CARDS)
	ok("the weapon is legendary (rarity %d)" % game.weapon_rarity("mindbender"), "mindbender" in game.LEGENDARY_WEAPONS and game.weapon_rarity("mindbender") == 6 and game.weapon_info("mindbender").has("path"))
	var a = mk(world, Vector2(60, 140))
	var b = mk(world, Vector2(80, 140))
	var far = mk(world, Vector2(70, 270))                       # outside the radius
	for e in [a, b]:
		e.apply_slow(0.0, 2.0)                                  # (held still until the spell lands)
	far.apply_slow(0.0, 60.0)                                   # (and the far one stays put, out of the radius)
	game.hand = ["mass_conversion"]
	game.mana = 100.0
	game.resources = {"stone": 0, "stick": 0, "gold": 20, "gem": 5}
	game.in_base = true if false else game.in_base
	game.players_in_base = [p]
	ok("it costs crystal gems, the caverns' resource (%s)" % str(game.CARDS["mass_conversion"].res), game.CARDS["mass_conversion"].res.has("gem") and game.card_sector("mass_conversion") == "sw")
	ok("it casts", game.cast("mass_conversion", Vector2(70, 140), p))
	await wait(2.2)
	ok("both enemies in the area are converted (%.0f s, %.0f s)" % [a.charm_time, b.charm_time], a.charm_time > 15.0 and b.charm_time > 15.0 and a.is_in_group("ally") and b.is_in_group("ally"))
	ok("the one outside is not", far.charm_time <= 0.0 and !far.is_in_group("ally"))
	var hp0: float = far.health
	var turned := false
	for i in 200:
		await wait(0.1)
		if is_instance_valid(far) and far.aggro_target != null and far.aggro_target.is_in_group("ally"):
			turned = true
	ok("the allies fight the other enemy (%.0f damage taken)" % (hp0 - far.health), hp0 - far.health > 1.0)
	ok("and the other enemy turns on them", turned)
	# the weapon
	var c1 = mk(world, Vector2(-200, 250))
	var c2 = mk(world, Vector2(-190, 250))
	p.equip_item(game.weapon_info("mindbender"))
	await wait(0.3)
	var w = p.item
	ok("the Mindbender is in hand (%s)" % str(w.weapon_name), w != null and str(w.weapon_name) == "Mindbender")
	var n: int = w._convert(Vector2(-195, 250), 60.0, 12.0)
	ok("Turncoat converts what is in its circle (%d)" % n, n == 2 and c1.charm_time > 10.0 and c2.is_in_group("ally"))
	quit()

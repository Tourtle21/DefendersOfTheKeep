extends SceneTree
## The weapon rules: every fusion is rarer than both of its parts; every fused weapon out-damages both parts (damage per second at
## tier 1 of that weapon); damage per second rises with rarity across the base weapons; every weapon is in the basic-attack table
## (the stat screens and the weapon scripts both read it).
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var fusion = load("res://items/fusion.gd")
	var bad_rarity := []
	var bad_dps := []
	var recipes: Dictionary = fusion.RECIPES
	for key in recipes:
		var parts: PackedStringArray = key.split("+")
		var id: String = recipes[key].id
		var r: int = game.weapon_rarity(id)
		if r <= game.weapon_rarity(parts[0]) or r <= game.weapon_rarity(parts[1]):
			bad_rarity.append(id)
		if !game.WEAPON_BASIC.has(id):
			bad_dps.append(id + " (no table entry)")
			continue
		var mine: float = game.basic_numbers(id, 0).dps
		for p in parts:
			if game.WEAPON_BASIC.has(p) and mine <= game.basic_numbers(p, 0).dps:
				bad_dps.append("%s %.1f <= %s %.1f" % [id, mine, p, game.basic_numbers(p, 0).dps])
	ok("every fusion is rarer than both parts %s" % [bad_rarity], bad_rarity.is_empty())
	ok("every fused weapon out-damages both parts %s" % [bad_dps], bad_dps.is_empty())
	# base weapons: the average damage per second of each rarity is higher than the one below
	var by_r := {}
	for id in game.WEAPON_BASIC:
		if fusion.tier_of(id) != 1:
			continue
		var r: int = game.weapon_rarity(id)
		if !by_r.has(r):
			by_r[r] = []
		by_r[r].append(game.basic_numbers(id, 0).dps)
	var prev := 0.0
	var rising := true
	var report := []
	var keys := by_r.keys()
	keys.sort()
	for r in keys:
		var total := 0.0
		for d in by_r[r]:
			total += d
		var avg: float = total / by_r[r].size()
		report.append("%s %.1f" % [game.rarity_name(r), avg])
		if avg <= prev:
			rising = false
		prev = avg
	ok("base weapons: damage per second rises with rarity (%s)" % ", ".join(report), rising)
	var items: Dictionary = load("res://world/item_info.tres").items
	var missing := []
	for id in items:
		if items[id].type == "item" and !(id in ["sword", "pickaxe"]) and !game.WEAPON_BASIC.has(id):
			missing.append(id)
	ok("every weapon has a basic-attack entry %s" % [missing], missing.is_empty())
	quit()

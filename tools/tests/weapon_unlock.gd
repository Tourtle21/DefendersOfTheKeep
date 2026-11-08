extends SceneTree
# Weapons must be unlocked before they appear; recipes show once their ingredients are unlocked.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func pickups_of(item: String) -> int:
	return get_nodes_in_group("pickup").filter(func(p): return p.item_type == item).size()
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.weapons = []
	game.meta.fusion_tiers = []
	game.meta.recipes_seen = []
	game.meta.shards = 0
	print("known at the start (starters + sword/pickaxe): spear ", game.weapon_known("spear"), ", hammer ", game.weapon_known("hammer"), ", daggers ", game.weapon_known("daggers"))
	print("recipe known? lance (hammer+spear) ", game.weapon_known("lance"), " | rapier (daggers+spear) ", game.weapon_known("rapier"), " | rimelance (frostglaive+spear) ", game.weapon_known("rimelance"), " | knightblade (shield+sword) ", game.weapon_known("knightblade"))
	game.meta.shards = 200
	print("unlock daggers: ", game.buy_weapon("daggers"), " -> rapier known now ", game.weapon_known("rapier"), ", chains: dragoonpike (lance+rapier) known ", game.weapon_known("dragoonpike"))
	print("tier 3 fusion unlocked? ", game.fusion_tier_unlocked(3), " (the recipe is visible but needs the tier)")
	# sector weapons only appear once unlocked
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	sm.unlock("se")
	await wait(0.3)
	print("desert opened while scimitar is LOCKED: scimitar pickups in the world = ", pickups_of("scimitar"))
	print("chest pool never holds sector weapons: ", game.weapon_pool())
	game.meta.shards = 200
	var price_ok := true
	for w in game.WEAPON_UNLOCK_COSTS:
		if game.WEAPON_UNLOCK_COSTS[w] != int(round(16.0 * pow(game.WEAPON_LEVEL[w], 1.5))): price_ok = false
	print("weapon prices follow the card rule (16 x realm^1.5): ", price_ok)
	print("unlock scimitar: ", game.buy_weapon("scimitar"), " (cost ", game.WEAPON_UNLOCK_COSTS["scimitar"], ")")
	sm.unlock("ne")
	sm.unlock("n")
	await wait(0.3)
	print("tundra opened (frostglaive still locked) frostglaive pickups: ", pickups_of("frostglaive"), " | ember opened, emberflail locked: ", pickups_of("emberflail"))
	# a re-run of the desert with the scimitar unlocked
	sm._spawn_weapon_pickup("se")
	await wait(0.3)
	print("scimitar pickups after unlocking it: ", pickups_of("scimitar"))
	# codex + forge journal
	var ui = load("res://ui/base/codex_ui.gd").new()
	world.add_child(ui)
	ui.open()
	for id in ["rapier", "rimelance", "frostglaive"]:
		ui.selected = id
		ui._refresh()
		print("codex ", id, ": known ", ui._known(id), " | ", ui.detail.text.replace("\n", " / ").substr(0, 150), " | button: ", ui.action_row.get_child(0).text if ui.action_row.get_child_count() > 0 else "-")
	print("rewards can offer sector weapons by level: ", range(1, 7).map(func(l): return game.WEAPON_UNLOCK_COSTS.keys().filter(func(w): return game.WEAPON_LEVEL[w] <= l).size()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

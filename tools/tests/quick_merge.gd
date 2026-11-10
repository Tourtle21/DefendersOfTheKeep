extends SceneTree
## Merge on the spot: weapons in your hands that fuse or combine can be merged anywhere (player 1 with F / d-pad down,
## players 2+ with d-pad down), with a hint on the weapon slots; the forge screen lists hands and storage in separate areas;
## cards that fuse can be fused in the keep without the Card Fuser.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
func tap(dev: int, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = true
	Input.parse_input_event(e)
	await wait(0.2)
	e = InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = false
	Input.parse_input_event(e)
	await wait(0.2)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://qm_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var split = scripted(world, "split_screen.gd")
	var lp = scripted(world, "local_players.gd")
	var rects: Array = split.layout(2, Vector2(1280, 720))
	for i in 2:
		split.containers[i].position = rects[i].position + Vector2(1, 1)
		split.containers[i].size = rects[i].size - Vector2(2, 2)
	await wait(0.3)
	split._pin_all()
	await wait(0.4)
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	var hud = world.get_node("Hud")
	var forge = scripted(world, "forge_ui.gd")
	game.note_weapon_tier("hammer", 1)
	game.note_weapon_tier("spear", 1)
	# ---- player 1: hammer + spear in hand fuse into a lance anywhere (far from the forge)
	game.resources = {"stone": 40, "stick": 40, "gold": 99}
	for id in ["hammer", "spear"]:
		var info = game.weapon_info(id)
		if hud.equip_item(info):
			p1.equip_item(info)
	p1.global_position = Vector2(300, 300)
	await wait(0.5)
	ok("player 1 is far from the forge", p1.global_position.distance_to(net.FORGE_POS) > 100.0)
	ok("the merge hint shows for player 1 (on the compact weapon slots)", hud.slots_widget.hint.find("merge") >= 0 and !hud.item_slots.visible)
	print("  hint: ", hud.slots_widget.hint)
	var gold_before: int = game.resources.gold
	var did: bool = forge.quick_merge()
	await wait(0.2)
	var held: Array = forge._held_entries()
	ok("player 1 merged hammer + spear in the field", did and held.size() == 1 and game.entry_id(held[0].entry) == "lance")
	ok("it cost something from the keep's stores", game.resources.gold < gold_before or game.resources.stone < 40 or game.resources.stick < 40)
	await wait(0.4)
	ok("with nothing left to merge the hint hides", hud.slots_widget.hint == "")
	# ---- not enough in the keep: refused
	for id in ["hammer", "spear"]:
		var info = game.weapon_info(id)
		if hud.equip_item(info):
			p1.equip_item(info)
	var saved: Dictionary = game.resources.duplicate()
	game.resources = {"stone": 0, "stick": 0, "gold": 0}
	var refused: bool = !forge.quick_merge()
	ok("too poor: the merge is refused and nothing is lost", refused and forge._held_entries().size() == 3)
	game.resources = saved
	# ---- player 2 (an avatar): d-pad down
	p2.weapon_slots = ["hammer", "spear"]
	p2.global_position = Vector2(-300, 300)
	await wait(0.3)
	ok("player 2's slot widget carries the hint", split._corner[1].slots.hint.find("merge") >= 0)
	await tap(1, JOY_BUTTON_DPAD_DOWN)
	ok("player 2: d-pad down merged their two weapons", p2.weapon_slots.size() == 1 and game.entry_id(p2.weapon_slots[0]) == "lance")
	# ---- the forge lists hands and storage in separate areas
	game._forge_store = ["spear", "hammer"]
	var layout = load("res://ui/forge/forge_layout.gd")
	var items: Array = layout.items(["lance"], game._forge_store)
	ok("forge list: hands first, then the forge's storage", items[0].src == "held" and items[1].src == "store" and items[2].src == "store")
	var fv = load("res://ui/forge/forge_view.gd").new({"forge": "X"})
	root.add_child(fv)
	fv.fit(Vector2(640, 360))
	fv.render({"list": items, "picks": [], "cur": 0})
	ok("player 2+ forge: two separate areas", fv.held_box.get_child_count() == 1 and fv.store_box.get_child_count() == 2)
	fv.queue_free()
	forge.open()
	await wait(0.4)
	ok("player 1 forge: separate areas for hands and storage", forge.held_title.text.begins_with("IN YOUR HANDS") and forge.store_title.text.begins_with("IN THE FORGE"))
	ok("player 1 forge: stored cards sit in the storage area", forge.store_box.get_child_count() > 0 and forge.list_box.get_child_count() > 0)
	forge.root_ctl.visible = false
	game._forge_store = []
	# ---- the forge lists only recipes you can make: no "Tier 2 locked" cards
	var two_hammers: Array = layout.items(["hammer", "hammer"], [])
	game.meta.weapon_tiers["hammer"] = 1
	var shown_locked: Array = layout.recipes(two_hammers).filter(func(r): return r.a[0] == "hammer" and r.b[0] == "hammer")
	ok("recipes: hammer + hammer is left out while tier 2 is not unlocked", shown_locked.is_empty())
	game.meta.weapon_tiers["hammer"] = 2
	shown_locked = layout.recipes(two_hammers).filter(func(r): return r.a[0] == "hammer" and r.b[0] == "hammer")
	ok("recipes: it appears once tier 2 is unlocked", shown_locked.size() == 1)
	var any_locked: bool = layout.recipes(two_hammers).any(func(r): return str(r.c[1]).find("locked") >= 0)
	ok("recipes: nothing says locked", !any_locked)
	# ---- cards: two different cards with a recipe fuse in the keep
	game.hand = [game.make_entry("fireball", 1, ""), game.make_entry("flare", 1, "")]
	game.resources.gold = 20
	ok("fireball + flare can fuse in hand", game.can_fuse_pair(0, 1))
	ok("fuse_hand makes one fused card and charges gold", game.fuse_hand(0, 1) and game.hand.size() == 1 and game.entry_id(game.hand[0]) == "solar_burst" and game.resources.gold < 20)
	game.hand = [game.make_entry("fireball", 1, ""), game.make_entry("sentry", 1, "")]
	ok("cards without a recipe do not fuse", !game.can_fuse_pair(0, 1))
	quit()

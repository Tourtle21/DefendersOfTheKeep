extends SceneTree
const OUT := "user://"
var world
var player
var info
var hud
const P := Vector2(-40, 260)

func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + name + ".png")

func aim_at(p: Vector2) -> void:
	root.warp_mouse(root.get_canvas_transform() * p)
	await wait(0.1)

func dummy(pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	return e

func clear() -> void:
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	await wait(0.1)

func mouse(button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = root.get_mouse_position()
	Input.parse_input_event(ev)

func act(name: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	Input.parse_input_event(ev)

func setup(id: String) -> void:
	player.equip_item(info.items[id])
	await wait(0.3)
	player.position = P
	player.shield_time = 0.0
	player.dash_time = 0.0
	player.speed_mult = 1.0
	player.parry_time = 0.0
	await clear()
	await aim_at(P + Vector2(120, 0))

func _initialize() -> void:
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	player = world.get_node("Player")
	hud = world.get_node("Hud")
	info = load("res://world/item_info.tres")
	world.get_node("SpawnTimer").start(600.0)
	var game = root.get_node("Game")

	# ---- aim rule: tap casts on release; hold shows the preview after 1s
	await setup("spear")
	var d1 = dummy(P + Vector2(60, 0))
	mouse(MOUSE_BUTTON_RIGHT, true)
	await wait(0.15)
	print("RMB held 0.15s: aim_time ", snapped(player.aim_time("ability"), 0.01), " cd (should be 0, not cast yet): ", player.item.ability_cd_left())
	mouse(MOUSE_BUTTON_RIGHT, false)
	await wait(0.6)
	print("RMB tap released -> javelin cast: cd ", snapped(player.item.ability_cd_left(), 0.1), " target dmg ", 10.0 - d1.health)
	await clear()
	mouse(MOUSE_BUTTON_RIGHT, true)
	player.item._ability_cd = 0.0
	await wait(1.2)
	print("RMB held 1.2s: aim_time ", snapped(player.aim_time("ability"), 0.1), " (>=1 shows preview)")
	await shot("t_aim_preview")
	mouse(MOUSE_BUTTON_RIGHT, false)
	await wait(0.3)
	var x0 = player.position.x
	act("dash", true); await wait(0.1); act("dash", false)
	await wait(0.4)
	print("Shift tap -> lunge on release: moved ", snapped(player.position.x - x0, 0.1))
	act("ultimate", true)
	await wait(0.2)
	act("ultimate", false)
	await wait(0.3)
	print("Space tap -> ultimate on release: ult cd ", snapped(player.item.ult_cd_left(), 1.0), " (~60)")

	# ---- Forge flow
	await clear()
	game.resources.gold = 30
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	hud.active_item_slot = -1
	hud.equip_item(info.items["spear"])
	hud.equip_item(info.items["hammer"])
	var forge = get_first_node_in_group("forge_ui")
	forge.open()
	forge._toggle(0)
	forge._toggle(1)
	print("forge preview: ", forge.info_label.text.replace("\n", " | "), " fuse enabled: ", !forge.fuse_button.disabled)
	await shot("t_forge_ui")
	forge.fuse()
	await wait(0.5)
	print("after fuse: gold ", game.resources.gold, " (20), slots filled: ", hud.equipped_items_count, " equipped weapon: ", player.item.weapon_name if player.item.get("weapon_name") != null else player.item.name)
	forge._toggle(0) if false else null
	# bad pairing is refused
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	hud.equip_item(info.items["sword"])
	hud.equip_item(info.items["bow"])
	forge.open(); forge._toggle(0); forge._toggle(1)
	print("sword+bow: ", forge.info_label.text, " fuse enabled: ", !forge.fuse_button.disabled)
	forge.root_ctl.visible = false

	# ---- every T2 / T3 weapon through all four actions
	for id in ["lance", "warpbow", "chainfangs", "bulwark", "knightblade", "quakepick", "tempest", "rapier", "spellblade", "stormbow", "juggernaut"]:
		await setup(id)
		var w = player.item
		var ds = [dummy(P + Vector2(28, 0)), dummy(P + Vector2(58, 5)), dummy(P + Vector2(90, -5))]
		w.player = player
		w.use_item()
		await wait(0.5)
		if w.has_method("release_item"): w.release_item()
		await wait(0.3)
		w._ability_cd = 0.0
		w.use_ability()
		if w.hold_ability:
			await wait(0.5)
			w.release_ability()
		elif id in ["warpbow", "stormbow"]:
			await wait(0.4)
			w.use_ability()
		elif id == "rapier":
			await wait(0.2)
			w.use_ability()
		await wait(0.8)
		w.use_dash()
		await wait(0.5)
		w.use_ultimate()
		await wait(2.0)
		var total := 0.0
		for e in ds:
			total += 10.0 - (e.health if is_instance_valid(e) else 0.0)
		print("%-12s tier-kit ran: dmg total %.1f | ult cd %.0f | %s / %s / %s / %s" % [id, total, w.ult_cd_left(), w.attack_name, w.ability_name, w.dash_name, w.ultimate_name])
	await shot("t_t3_done")
	quit()

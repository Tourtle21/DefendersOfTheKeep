extends SceneTree
const OUT := "user://"
var world
var player
var info
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

func setup(id: String) -> void:
	player.equip_item(info.items[id])
	await wait(0.3)
	player.position = P
	player.shield_time = 0.0
	player.dash_time = 0.0
	player.speed_mult = 1.0
	await clear()
	await aim_at(P + Vector2(120, 0))

func lost(e) -> float:
	return 10.0 - (e.health if is_instance_valid(e) else 0.0)

func _initialize() -> void:
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	player = world.get_node("Player")
	info = load("res://world/item_info.tres")
	world.get_node("SpawnTimer").start(600.0)
	var x0 := 0.0

	await setup("spear")
	var a = dummy(P + Vector2(60, 0)); var b = dummy(P + Vector2(95, 0))
	player.item.use_ability()
	await wait(0.8)
	print("spear JAVELIN: first ", lost(a), " second (pierce) ", lost(b), " (4 each)")
	await shot("k_spear_ready")
	await setup("spear")
	var c = dummy(P + Vector2(50, 0))
	x0 = player.position.x
	var ev := InputEventAction.new(); ev.action = "dash"; ev.pressed = true
	Input.parse_input_event(ev)    # the real Shift key path
	await wait(0.5)
	print("spear LUNGE via real dash key: moved ", player.position.x - x0, " dmg ", lost(c), " dash cd left ", player.item.dash_cd_left(), " (refund ~1.75)")

	await setup("daggers")
	var d1 = dummy(P + Vector2(50, 0))
	player.item.use_ability()
	await wait(0.7)
	print("daggers KNIVES: dmg ", lost(d1), " exposed ", load("res://items/weapons/weapon_util.gd").is_exposed(d1))
	await setup("daggers")
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.4)
	print("daggers STEP: moved ", player.position.x - x0)

	await setup("staff")
	var s1 = dummy(P + Vector2(80, 0))
	player.item.use_ability()
	await wait(0.9)
	print("staff BURST at cursor: dmg ", lost(s1), " stun ", s1.slow_time)
	await setup("staff")
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.3)
	print("staff BLINK: moved ", player.position.x - x0)

	await setup("hammer")
	var h1 = dummy(P + Vector2(60, 0))
	await aim_at(P + Vector2(60, 0))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.6)
	print("hammer LEAP: moved ", player.position.x - x0, " landing dmg ", lost(h1), " stun ", h1.slow_time)

	await setup("bow")
	var b1 = dummy(P + Vector2(100, 0))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.9)
	print("bow BACKFLIP: moved ", player.position.x - x0, " arrow dmg ", lost(b1))

	await setup("whip")
	var w1 = dummy(P + Vector2(30, 0))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.4)
	print("whip SWING: moved ", player.position.x - x0, " dmg ", lost(w1))

	await setup("shield")
	var sh = dummy(P + Vector2(30, 0))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.4)
	print("shield CHARGE: moved ", player.position.x - x0, " dmg ", lost(sh), " stun ", sh.slow_time)

	await setup("sword")
	var sw = dummy(P + Vector2(65, 0))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.5)
	print("sword SLASH DASH: moved ", player.position.x - x0, " dmg ", lost(sw), " | label: ", player.item.attack_name, " / ", player.item.ability_name, " / ", player.item.dash_name)

	await setup("pickaxe")
	var pk = dummy(P + Vector2(60, 0))
	await aim_at(P + Vector2(60, 0))
	player.item.use_ability()
	await wait(0.8)
	print("pickaxe SEISMIC at cursor: dmg ", lost(pk))
	x0 = player.position.x
	player.item.use_dash()
	await wait(0.4)
	print("pickaxe DASH-MINE: moved ", player.position.x - x0)
	quit()

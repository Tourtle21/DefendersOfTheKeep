extends SceneTree
## Keyboard player 1 + controller player 2 (the real lobby setup): player 2 holds RT and swings; does the swing hit an enemy
## on the side the right stick points to, and what does it do with a live (walking) enemy?
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func axis(dev: int, a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev; e.axis = a; e.axis_value = v
	Input.parse_input_event(e)
func dummy(world, pos: Vector2):
	var d = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	d.position = pos
	world.get_node("Enemies").add_child(d)
	d.set_physics_process(false)
	d.get_node("NavigationTimer").stop()
	d.max_health = 40.0; d.health = 40.0
	return d
func swing(dev: int) -> void:
	for k in 4:
		axis(dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		await wait(0.2)
		axis(dev, JOY_AXIS_TRIGGER_RIGHT, -1.0)
		await wait(0.5)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://p2h_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	p2.global_position = Vector2(150, 150)          # open ground, away from the keep's walls
	await wait(0.3)
	print("  p2 at %s, in tower %s, has_crystal %s, weapon %s, slots %s, downed %s" % [p2.global_position, p2.is_in_tower, p2.has_crystal, p2.item, p2.weapon_slots, p2.downed])
	var right = dummy(world, p2.global_position + Vector2(25, 0))
	axis(1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await wait(0.15)
	print("  using %s anim %s player %s hitbox? %s" % [p2.is_using_item, p2.item_animation_player.current_animation if p2.item_animation_player else "none", p2.item_animation_player, p2.item.get_children().map(func(c): return c.name)])
	print("  RT axis read %.2f; net prev %s; item cd? %s; rot %.2f" % [Input.get_joy_axis(1, JOY_AXIS_TRIGGER_RIGHT), root.get_node("Net")._prev.get(101, {}), p2.item.get("_attack_cd"), p2.item.rotation])
	axis(1, JOY_AXIS_TRIGGER_RIGHT, -1.0)
	await wait(0.5)
	await swing(1)
	print("  scale.x %s item rot %.2f" % [p2.scale.x, p2.item.rotation])
	axis(1, JOY_AXIS_RIGHT_X, 1.0)
	await wait(0.3)
	await swing(1)
	axis(1, JOY_AXIS_RIGHT_X, 0.0)
	print("  right dummy at %s (p2 %s) taking_damage %s layer %s mask %s process %s" % [right.global_position, p2.global_position, right.is_taking_damage, right.collision_layer, right.collision_mask, right.is_physics_processing()])
	var hb = p2.item.get_node("Hitbox2")
	print("  sword Hitbox2 at %s mask %s monitoring %s shape %s disabled %s" % [hb.global_position, hb.collision_mask, hb.monitoring, hb.get_child(0).shape if hb.get_child_count() > 0 else null, hb.get_child(0).disabled if hb.get_child_count() > 0 else null])
	print("  enemy on the right (default aim): hp %.1f/40" % right.health)
	ok("P2 hits the enemy in front of the default aim", right.health < 40.0)
	var left = dummy(world, p2.global_position + Vector2(-25, 0))
	axis(1, JOY_AXIS_RIGHT_X, -1.0)
	await wait(0.3)
	await swing(1)
	axis(1, JOY_AXIS_RIGHT_X, 0.0)
	print("  enemy on the left after aiming left with the right stick: hp %.1f/40" % left.health)
	ok("P2 hits the enemy on the left after aiming left", left.health < 40.0)
	quit()

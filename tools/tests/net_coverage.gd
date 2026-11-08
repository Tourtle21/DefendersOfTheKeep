extends SceneTree
# Multiplayer coverage: every gameplay node in a fully populated world must either be
# replicated (group "net") or be explicitly local (group "net_local", or a UI/camera/etc
# node type listed in ALLOW). A new node type that forgets to opt in fails this test.
const ALLOW := ["CanvasLayer", "Control", "Camera2D", "Timer", "AudioStreamPlayer", "AudioStreamPlayer2D", "PointLight2D", "CanvasModulate"]
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for id in ["se", "ne", "n", "nw", "sw"]: sm.unlock(id)
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.resources = {"stone": 99, "stick": 99, "gold": 99, "iron": 20, "frost": 20, "ember": 20, "moss": 20, "gem": 20}
	for card in game.CARDS:
		game.hand = [card]
		game.cast(card, Vector2(randf_range(-100, 100), 330), player)
		await wait(0.9)
	world.spawn_enemies([{"name": "blobbert", "amount": 2, "level": 1}])
	load("res://collectables/gold/gold_coin.gd").spawn(world, Vector2(0, 280), 2)
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(-80, 260)
	world.add_child(chest)
	# weapon effects and projectiles
	var info = world.get_node("Collectable").item_info
	for w in ["bow", "staff", "frostglaive", "crystalwand", "bogstaff"]:
		player.equip_item(info.items[w])
		await wait(0.2)
		player.item.tier = 6
		player.item.use_item()
		player.item.use_ability()
		await wait(0.2)
	game.end_run  # (not called: just keeping the symbol referenced)
	var uncovered := {}
	var covered := {}
	var stack := [world]
	while !stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == world or n.get_script() == null:
			continue
		if n.is_in_group("net"):
			covered[n.get_script().resource_path] = true
			continue
		if n.is_in_group("net_local") or n.is_in_group("player"):
			continue
		var cls := n.get_class()
		var allowed := false
		for a in ALLOW:
			if n.is_class(a): allowed = true
		if allowed:
			continue
		var s: Script = n.get_script()
		var active: bool = n.has_method("_process") or n.has_method("_physics_process") or n.has_method("_draw") or n.has_method("_input")
		if !active:
			continue
		# a child of a replicated or local node is part of it
		var p := n.get_parent()
		var inherited := false
		while p != null and p != world:
			if p.is_in_group("net") or p.is_in_group("net_local") or p.is_in_group("player"):
				inherited = true
			p = p.get_parent()
		if inherited:
			continue
		uncovered[s.resource_path] = uncovered.get(s.resource_path, 0) + 1
	print("replicated script types: ", covered.size())
	for k in covered: print("   net  ", k)
	print("NOT replicated and not marked local (%d types):" % uncovered.size())
	for k in uncovered: print("   ?? ", k, " x", uncovered[k])
	print("RESULT: ", "PASS" if uncovered.is_empty() else "FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()

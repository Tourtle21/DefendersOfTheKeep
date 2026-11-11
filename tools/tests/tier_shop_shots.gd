extends SceneTree
## Window screenshots of a drawn weapon tier waiting to be bought: the end-of-run card with its Upgrade button, the Weapons tab
## button and the Drawn tab. Pass out=<dir>.
var OUT := "user://"
var HOLD := 8.0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
func scripted(world, f: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(f): return c
	return null
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
		if a.begins_with("hold="): HOLD = float(a.substr(5))
	var game = root.get_node("Game")
	game.save_path = "user://tss_save.json"
	game.fix_meta()
	game.meta.shards = 60
	game.meta.weapons = ["spear"]
	game.meta.tier_drawn = {"w:sword": 2}
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	game.run_stats = {"kills": 40, "gold": 60, "waves": 6, "bosses": 1}
	game.sectors_unlocked = ["s", "se", "ne"]
	game.run_ended.emit({"reason": "The keep has fallen", "shards": 20, "stats": game.run_stats.duplicate(),
		"rewards": [{"kind": "weapon", "id": "sword", "tier": 2, "realm": 1, "result": "upgrade", "shards": 0}]})
	var re = scripted(world, "run_end_ui.gd")
	await wait(0.5)
	re._flip_all()
	await wait(1.0)
	print("=== 1. END OF RUN: a drawn weapon tier shows TIER 2 DRAWN and an Upgrade (8 Shards) button")
	await shot("t1_run_end_weapon_tier")
	await wait(HOLD)
	game.buy_weapon_tier("sword")                       # what pressing Upgrade does
	re._refresh()
	print("=== 2. after pressing Upgrade: it is bought (Shards go down, the button says Upgraded)")
	await shot("t2_after_upgrade")
	await wait(HOLD)
	re.root_ctl.visible = false
	game.meta.tier_drawn["w:sword"] = 3
	var cx = load("res://ui/base/codex_ui.gd").new()
	world.add_child(cx)
	cx.open()
	cx.selected = "sword"
	cx._refresh()
	print("=== 3. WEAPONS TAB: the sword's tier 3 was drawn, so 'Unlock tier 3 for 23 Shards' shows")
	await shot("t3_weapons_tab")
	await wait(HOLD)
	print("=== done")
	quit()

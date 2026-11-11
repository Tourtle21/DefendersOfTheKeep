extends SceneTree
## Every button on the end-of-run reward cards at once, in a real window: Unlock + Convert on a new card and a new weapon,
## Upgrade on a drawn card tier and a drawn weapon tier, Merge / Combine pair / Sell on spare copies. hold=<seconds> (default 15);
## out=<dir> saves a PNG.
var OUT := ""
var HOLD := 15.0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
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
	game.save_path = "user://rbs_save.json"
	game.fix_meta()
	game.meta.shards = 120
	game.meta.best_level = 4
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {"fireball": 1}
	game.meta.weapons = []
	game.meta.weapon_tiers = {}                   # (a fresh demo every time: nothing bought yet)
	game.meta.pending = []
	game.meta.tier_drawn = {"w:sword": 2, "frost_ring": 2}
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	game.run_stats = {"kills": 80, "gold": 120, "waves": 10, "bosses": 2}
	game.sectors_unlocked = ["s", "se", "ne", "n"]
	var spare1 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	var spare2 := {"kind": "card", "id": "fireball", "tier": 1, "realm": 1, "result": "spare", "shards": 0}
	var new_card := {"kind": "card", "id": "mender", "tier": 1, "realm": 1, "result": "offer", "shards": 0}
	var new_weapon := {"kind": "weapon", "id": "bow", "tier": 1, "realm": 1, "result": "offer", "shards": 0}
	for e in [new_card, new_weapon]:
		e["cost"] = game.unlock_cost(e)
	game.meta.pending = [spare1, spare2, new_card, new_weapon]
	game.run_ended.emit({"reason": "The keep has fallen", "shards": 40, "stats": game.run_stats.duplicate(), "rewards": [
		new_card, new_weapon,
		{"kind": "card", "id": "frost_ring", "tier": 2, "realm": 1, "result": "upgrade", "shards": 0},
		{"kind": "weapon", "id": "sword", "tier": 2, "realm": 1, "result": "upgrade", "shards": 0},
		spare1, spare2]})
	var re = scripted(world, "run_end_ui.gd")
	await wait(0.5)
	if OUT != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/reward_before_flip.png" % OUT)
	re._flip_all()
	await wait(7.0)
	var widths := []
	for c in re.shop_row.get_children():
		widths.append("%d" % c.size.x)
	print("column widths: ", widths, "  (all the same: ", widths.all(func(w): return w == widths[0]), ")")
	print("=== every reward button: Unlock + Convert (new card, new weapon), Upgrade (card tier, weapon tier), Merge + Combine pair + Sell (spare copies)")
	if OUT != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/reward_buttons.png" % OUT)
	await wait(HOLD)
	quit()

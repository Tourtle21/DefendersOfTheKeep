extends SceneTree
## A window with all seven rarities side by side for each card design: spell, building and weapon. hold=<seconds> (default 60); out=<dir> saves a PNG.
var OUT := ""
var HOLD := 60.0
func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
		if a.begins_with("hold="): HOLD = float(a.substr(5))
	var game = root.get_node("Game")
	game.save_path = "user://rs_save.json"
	var CV = load("res://ui/cards/card_view.gd")
	var WC = load("res://ui/cards/weapon_card.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# one card of each rarity (0 Common .. 6 Legendary) per design
	# one of each rarity (0 Common .. 6 Legendary) per design, picked by the real rarity
	var spells := []
	var builds := []
	var weapons := []
	for r in 7:
		var sp := ""
		var bd := ""
		for id in game.CARDS:
			if game.CARDS[id].get("fused", false) or game.card_rarity(id) != r:
				continue
			if game.CARDS[id].kind == "build":
				if bd == "": bd = id
			elif sp == "": sp = id
		spells.append(sp)
		builds.append(bd)
		var wp := ""
		for id in load("res://world/item_info.tres").items:
			if load("res://world/item_info.tres").items[id].type == "item" and game.weapon_rarity(id) == r and wp == "":
				wp = id
		weapons.append(wp)
	var rows := [["SPELLS", spells, "card"], ["BUILDINGS", builds, "card"], ["WEAPONS", weapons, "weapon"]]
	var y := 8
	for row in rows:
		var title := Label.new()
		title.text = row[0]
		title.position = Vector2(12, y)
		title.add_theme_font_size_override("font_size", 18)
		bg.add_child(title)
		var x := 10
		for i in 7:
			var id: String = row[1][i]
			if id == "":
				x += 155
				continue
			var c = CV.new()
			if row[2] == "card":
				c.setup(id, 1)
				c.scale = Vector2(1.5, 1.5)
				c.position = Vector2(x, y + 30)
			else:
				c.setup_weapon(id, 2, {"icon": WC.icon(id), "title": id.capitalize()}, Vector2(144, 240))
				c.position = Vector2(x, y + 30)
			bg.add_child(c)
			var rl := Label.new()
			rl.text = game.rarity_name(i)
			rl.position = Vector2(x + 30, y + 274)
			rl.add_theme_color_override("font_color", game.rarity_color(i))
			bg.add_child(rl)
			x += 155
		y += 300
	await wait(1.0)
	if OUT != "":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/rarity_showcase.png" % OUT)
	await wait(HOLD)
	quit()

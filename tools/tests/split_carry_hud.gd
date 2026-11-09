extends SceneTree
## Player 2's corner shows what they carry; the codex badge shows the unlocked tier; the reward panel crops the pickaxe sheet.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ch_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	await wait(0.3)
	var label: Label = split._local_huds[0].info
	ok("with nothing collected it says so (%s)" % label.text, label.text.begins_with("Carrying: 0 stone, 0 stick, 0 gold"))
	game.pick_up_resource("stone", p2)
	game.pick_up_resource("stone", p2)
	game.pick_up_resource("stick", p2)
	await wait(0.3)
	print("  ", label.text)
	ok("after two stone and a stick it lists them", label.text.begins_with("Carrying: 2 stone, 1 stick"))
	var UiKit = load("res://ui/cards/ui_kit.gd")
	var tex = UiKit.weapon_icon("res://items/tools/pickaxe/pickaxe.png")
	ok("the pickaxe icon is one frame of the sheet, not the whole sheet (%s)" % str(tex.get_size()), tex is AtlasTexture and tex.get_size().x < 64)
	game.note_weapon_tier("pickaxe", 2)
	ok("a tier 2 pickaxe counts as unlocked tier 2 (what the codex badge and gems now show)", game.weapon_tier_unlocked("pickaxe") == 2)
	quit()

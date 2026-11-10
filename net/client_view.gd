extends Node2D
## Co-op CLIENT view (groundwork). Draws the host's latest snapshot (the six sectors,
## players, enemies, bosses) and sends this player's input to the host. It does not
## simulate anything itself.

const SM := preload("res://world/sector_manager.gd")
var cam: Camera2D
var _down_label: Label
var _daylight: PointLight2D
var info: Label
var hp_bar: ProgressBar
var carry_label: Label
var radar: Control
var base_box: VBoxContainer
var hand_row: HBoxContainer
var mana_bar: ProgressBar
var res_label: Label
var extras: HBoxContainer
var selected := -1
var draft_view: Control           # the shared chest choice (ui/base/draft_view.gd)
var forge_view: Control           # the shared Forge screen (ui/forge/forge_view.gd), opened with E at the anvil
var weapons_label: Label
var ability_hud: AbilityHud
var _ended_label: Label
var _forge_sel: Array = []        # positions in the forge list (ForgeLayout.items) the player picked
var _me := {}                     # this player's entry in the latest snapshot
var fuser_view: Control           # the shared Card Fuser (ui/forge/fuser_view.gd), opened with E at the table
var wave_label: Label
var keep_bar: ProgressBar
var keep_lbl: Label
var hp_fill: ColorRect
var slots_ctl: Control
var _extras_key := ""
const TierCard = preload("res://ui/cards/tier_card.gd")
var _fuse_sel: Array = []        # hand positions picked at the Card Fuser
const ForgeLayout = preload("res://ui/forge/forge_layout.gd")
var _hand_key := ""
var _in_base := false
var _player_tgt := {}
var _player_disp := {}
var _last_snap_t := -1
var _host_lost := false
var scripted_input := false      # tests: keep whatever is in Net.local_input instead of reading the keyboard

func _ready() -> void:
	# This view acts as the "world" for replicated puppets (see core/replication.gd): it has the
	# same landmark nodes real enemies look for, and Game.world points here for effects.
	Game.world = self
	Game.set_process(false)             # the host simulates mana, card draws and so on
	var enemies_root := Node2D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	var well := Node2D.new()
	well.name = "Well"
	var crystal := Node2D.new()
	crystal.name = "Crystal"
	well.add_child(crystal)
	add_child(well)
	Rep.client_root = self              # only now: spawns that arrived early are created here and look for the Enemies and Well nodes above
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * 2.0 / Game.ui_scale
	add_child(cam)
	# night: the same dark overlay as the host's world (night_level is synced), and a light on your own player
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.00554017])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 3000
	tex.height = 3000
	tex.fill_from = Vector2(1, 0)
	tex.fill_to = Vector2(0, 1)
	_daylight = PointLight2D.new()
	_daylight.texture = tex
	_daylight.blend_mode = Light2D.BLEND_MODE_SUB
	_daylight.energy = 0.0
	_daylight.color = Color(1.0, 0.95, 0.75)
	add_child(_daylight)
	GlowLight.attach(cam, 46.0, Color(1.0, 1.0, 1.0), 0.55)
	var layer := CanvasLayer.new()
	add_child(layer)
	_down_label = Label.new()
	_down_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_down_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_down_label.position.y = 120
	_down_label.add_theme_font_size_override("font_size", 34)
	_down_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_down_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_down_label.add_theme_constant_override("outline_size", 8)
	_down_label.visible = false
	layer.add_child(_down_label)
	info = Label.new()                        # connection / lobby status and a few numbers: small, under the resource line
	info.position = Vector2(12, 40)
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.8))
	layer.add_child(info)
	DisplayServer.window_set_title("Defenders of the Keep (co-op client)")
	_ended_label = Label.new()
	_ended_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ended_label.add_theme_font_size_override("font_size", 34)
	_ended_label.visible = false
	layer.add_child(_ended_label)
	Game.announce.connect(func(text: String):
		if text.begins_with("RUN_END|"):
			_ended_label.text = text.substr(8) + "\nThe host decides what happens next."
			_ended_label.visible = true
		elif text.begins_with("Wave ") or text.begins_with("RUN_START"):
			_ended_label.visible = false)
	Net.server_lost.connect(func():
		_host_lost = true
		info.text = "The host closed the game. Returning to a solo game..."
		await get_tree().create_timer(2.5).timeout
		Net.leave()
		get_tree().change_scene_to_file("res://world/world.tscn"))
	# keep UI, shown only while this player is inside a tower
	base_box = VBoxContainer.new()
	base_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	base_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	base_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	base_box.offset_bottom = -10
	base_box.visible = false
	layer.add_child(base_box)
	res_label = Label.new()
	res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	base_box.add_child(res_label)
	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(420, 22)
	mana_bar.show_percentage = false
	mana_bar.modulate = Color(0.5, 0.7, 1.4)
	base_box.add_child(mana_bar)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", 8)
	base_box.add_child(hand_row)
	hp_bar = ProgressBar.new()                # (kept for tests that read it; the visible bar is the frame below)
	hp_bar.max_value = 1.0
	hp_bar.visible = false
	layer.add_child(hp_bar)
	# the same HUD layout as player 1's and the split-screen players' (ui/base/local_hud.gd): resources top-left, the keep bar
	# top-centre, the health bar top-right, the weapon slots bottom-left
	carry_label = Label.new()
	carry_label.position = Vector2(12, 10)
	carry_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(carry_label)
	keep_bar = ProgressBar.new()
	keep_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	keep_bar.offset_left = -170
	keep_bar.offset_right = 170
	keep_bar.offset_top = 38
	keep_bar.offset_bottom = 58
	keep_bar.show_percentage = false
	keep_bar.modulate = Color(1.0, 0.55, 0.45)
	keep_lbl = Label.new()
	keep_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep_lbl.add_theme_font_size_override("font_size", 13)
	keep_bar.add_child(keep_lbl)
	layer.add_child(keep_bar)
	wave_label = Label.new()
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_label.position.y = 62
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(wave_label)
	var hp_frame := ColorRect.new()
	hp_frame.color = Color.BLACK
	hp_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hp_frame.offset_left = -250
	hp_frame.offset_right = -16
	hp_frame.offset_top = 16
	hp_frame.offset_bottom = 43
	hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hp_frame)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(1, 0.14902, 0, 1)
	hp_fill.position = Vector2(3, 3)
	hp_fill.size = Vector2(228, 21)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_frame.add_child(hp_fill)
	slots_ctl = Control.new()
	slots_ctl.set_script(preload("res://ui/hud/weapon_slots.gd"))
	layer.add_child(slots_ctl)
	radar = Control.new()
	radar.set_script(preload("res://net/client_minimap.gd"))
	radar.view = self
	layer.add_child(radar)
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -236
	radar.offset_right = -16
	radar.offset_top = 70
	radar.offset_bottom = 290
	weapons_label = Label.new()               # (kept for tests; the weapon slots on the left show it)
	weapons_label.visible = false
	layer.add_child(weapons_label)
	draft_view = preload("res://ui/base/draft_view.gd").new()
	draft_view.visible = false
	layer.add_child(draft_view)
	draft_view.take.connect(func(entry): Net.net_command.rpc_id(1, {"cmd": "draft", "id": entry}))
	draft_view.combine.connect(func(i, j): Net.net_command.rpc_id(1, {"cmd": "draft_merge", "a": i, "b": j}))
	forge_view = preload("res://ui/forge/forge_view.gd").new()
	forge_view.visible = false
	layer.add_child(forge_view)
	forge_view.card_pressed.connect(func(pos: int):
		if pos in _forge_sel:
			_forge_sel.erase(pos)
		elif _forge_sel.size() < 2:
			_forge_sel.append(pos)
		else:
			_forge_sel = [_forge_sel[1], pos])
	forge_view.recipe_pressed.connect(func(a: int, b: int): _forge_sel = [a, b])
	forge_view.forge_pressed.connect(func():
		var list := _forge_list()
		if _forge_sel.size() == 2 and _forge_sel.max() < list.size():
			Net.net_command.rpc_id(1, {"cmd": "forge_craft", "a_src": list[_forge_sel[0]].src, "a_idx": list[_forge_sel[0]].idx, "b_src": list[_forge_sel[1]].src, "b_idx": list[_forge_sel[1]].idx})
		_forge_sel = [])
	forge_view.store_pressed.connect(func():
		var t: int = forge_view.store_target()
		var list := _forge_list()
		if t >= 0 and t < list.size():
			Net.net_command.rpc_id(1, {"cmd": "forge_store", "src": list[t].src, "idx": list[t].idx})
		_forge_sel = [])
	forge_view.back_pressed.connect(func(): forge_view.visible = false)
	fuser_view = preload("res://ui/forge/fuser_view.gd").new()
	fuser_view.visible = false
	layer.add_child(fuser_view)
	fuser_view.card_pressed.connect(func(i): _fuse_sel = fuser_view.toggle(_fuse_sel, i))
	fuser_view.fuse_pressed.connect(func():
		if _fuse_sel.size() == 2:
			Net.net_command.rpc_id(1, {"cmd": "card_fuse", "a": _fuse_sel[0], "b": _fuse_sel[1]})
		_fuse_sel = [])
	fuser_view.back_pressed.connect(func(): fuser_view.visible = false)
	ability_hud = AbilityHud.new()
	add_child(ability_hud)
	add_child(CrystalAlert.new())
	extras = HBoxContainer.new()               # Repair and the upgrades as the same small cards player 1 has
	extras.position = Vector2(12, 74)
	extras.add_theme_constant_override("separation", 8)
	layer.add_child(extras)

## Take a new snapshot into the target tables.
func _ingest(snap: Dictionary) -> void:
	if snap.get("t", -1) == _last_snap_t or !snap.has("players"):
		return
	_last_snap_t = snap.t
	_player_tgt.clear()
	for p in snap.players:
		_player_tgt[p.id] = p.pos
	for id in _player_disp.keys():
		if !_player_tgt.has(id):
			_player_disp.erase(id)

## Ease what is drawn toward the latest positions so 10 snapshots/second look smooth.
func smooth(delta: float) -> void:
	var k: float = 1.0 - exp(-14.0 * delta)
	for id in _player_tgt:
		_player_disp[id] = _player_disp.get(id, _player_tgt[id]).lerp(_player_tgt[id], k)

func _process(delta: float) -> void:
	if _host_lost:
		return
	_daylight.energy = Game.night_level * 1.0          # same strength as the host's NIGHT_DARKNESS
	_ingest(Net.last_snapshot)
	smooth(delta)
	# gather input for the host
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if !scripted_input:
		Net.local_input = {
		"move": move, "aim": Pad.world_mouse(self),
		"attack": Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"ability": Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
		"dash": Input.is_action_pressed("dash"), "ultimate": Input.is_action_pressed("ultimate"),
	}
	var snap: Dictionary = Net.last_snapshot
	if snap.has("players"):
		for p in snap.players:
			if p.id == multiplayer.get_unique_id():
				cam.position = cam.position.lerp(_player_disp.get(p.id, p.pos), 0.2)
				_in_base = p.base
				_down_label.visible = p.get("down", 0) > 0
				_down_label.text = "You fell!  Back in %d" % p.get("down", 0)
		cam.zoom = Vector2.ONE * (1.2 if _in_base else 2.0) / Game.ui_scale
		Net.local_input["attack"] = Net.local_input.attack and !_in_base      # clicks are for casting while in the keep
		_update_keep_ui(snap)
		_update_loot_ui(snap)
		info.text = ("LOBBY - waiting for the host to start...   " if snap.get("lobby", false) else "") + "Co-op client   keep %d   mana %d   wave %d   players: %s   enemies %d   things %d" % [snap.keep, snap.mana, snap.wave, ", ".join(snap.roster.values()), get_tree().get_nodes_in_group("enemy").size(), Rep.puppet_count()]
	else:
		info.text = "Connecting... waiting for the host's first snapshot"
	queue_redraw()

func _draw() -> void:
	var snap: Dictionary = Net.last_snapshot
	var sectors: Array = snap.get("sectors", ["s"])
	# sector wedges (locked ones grey)
	for id in Game.SECTOR_ANGLES:
		var c: float = Game.SECTOR_ANGLES[id]
		var col := Color(0.35, 0.8, 0.3)
		if id != "s":
			col = SM.SECTORS[id].ground
		if !(id in sectors):
			col = Color(0.45, 0.45, 0.45)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.from_angle(deg_to_rad(c - 30.0 + 60.0 * i / 12.0)) * 1300.0)
		draw_colored_polygon(pts, col.darkened(0.1))
	draw_circle(Vector2.ZERO, 120.0, Color(0.35, 0.8, 0.3))
	draw_circle(Vector2(0, 4), 10.0, Color(0.6, 0.3, 0.8))                 # the well / crystal
	if !snap.has("players"):
		return
	draw_rect(Rect2(snap.forge - Vector2(8, 4), Vector2(16, 8)), Color(0.6, 0.65, 0.7))
	draw_string(ThemeDB.fallback_font, snap.forge + Vector2(-10, 14), "forge", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	if snap.has("fuser"):
		draw_rect(Rect2(snap.fuser - Vector2(8, 4), Vector2(16, 8)), Color(0.6, 0.55, 0.72))
		draw_string(ThemeDB.fallback_font, snap.fuser + Vector2(-14, 14), "fuser", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
	# enemies, bosses, chests, pickups, structures... are replicated puppets (Rep), drawn by themselves
	for p in snap.players:
		var mine: bool = p.id == multiplayer.get_unique_id()
		var dp: Vector2 = _player_disp.get(p.id, p.pos)
		draw_circle(dp, 6.0, Color.BLACK)
		draw_circle(dp, 5.0, Color(1, 1, 0.5) if mine else Color(0.5, 0.8, 1.0))
		draw_string(ThemeDB.fallback_font, dp + Vector2(-12, -10), snap.roster.get(p.id, "?"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
		if p.slots.size() > 0 and p.active < p.slots.size():
			draw_string(ThemeDB.fallback_font, dp + Vector2(-12, 17), Fusion.display_name(p.slots[p.active]), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 0.8))
		draw_rect(Rect2(dp + Vector2(-8, 8), Vector2(16.0 * p.hp, 2)), Color(0.9, 0.25, 0.2))

var _info_res: Resource
func _item_info() -> Resource:
	if _info_res == null:
		_info_res = load("res://world/item_info.tres")
	return _info_res

func _weapon_label(entry: String) -> String:
	var tw := Game.entry_twist(entry)
	return "%s T%d%s" % [Fusion.display_name(Game.entry_id(entry)), Game.weapon_tier_of(entry), (" *" + Game.TWISTS[tw][0]) if tw != "" and Game.TWISTS.has(tw) else ""]

func _update_keep_ui(snap: Dictionary) -> void:
	base_box.visible = _in_base
	extras.visible = _in_base
	if !_in_base:
		selected = -1
		return
	mana_bar.max_value = snap.max_mana
	mana_bar.value = snap.mana
	var parts := []
	for k in snap.resources:
		if snap.resources[k] > 0 or k in ["stone", "stick", "gold"]:
			parts.append("%d %s" % [snap.resources[k], k])
	res_label.text = "Keep: " + ", ".join(parts) + "    Mana %d/%d" % [snap.mana, snap.max_mana]
	var key := str(snap.hand) + str(snap.deck)
	if key != _hand_key:
		_hand_key = key
		for c in hand_row.get_children():
			hand_row.remove_child(c)
			c.queue_free()
		for i in snap.hand.size():
			var view := CardView.new()
			view.setup(Game.entry_id(snap.hand[i]), Game.entry_tier(snap.hand[i]), "", Game.entry_twist(snap.hand[i]))
			view.pressed_down.connect(func(_v):
				if selected >= 0 and selected != i and (Game.can_merge(selected, i) or Game.can_fuse_pair(selected, i)):
					Net.net_command.rpc_id(1, {"cmd": "merge", "a": selected, "b": i})      # same card, same tier: combine
					selected = -1
				else:
					selected = i)
			hand_row.add_child(view)
	for i in hand_row.get_child_count():
		hand_row.get_child(i).set_state(i == selected, true)
	# repair / upgrades, as player 1's small cards (a green frame means you can buy it now)
	var ekey := str(Game.upgrade_levels) + str(snap.resources) + str(snap.get("keep", 0))
	if ekey != _extras_key:
		_extras_key = ekey
		for c in extras.get_children():
			extras.remove_child(c)
			c.queue_free()
		var can_repair: bool = snap.get("keep", 0) < snap.get("keep_max", 1) and snap.resources.get("stone", 0) >= 3
		var rc := TierCard.new()
		rc.setup({"size": Vector2(92, 128), "title": "Repair", "glyph": "+", "lines": ["+30 keep"], "footer": "3 stone", "accent": Color(0.9, 0.5, 0.4), "locked": !can_repair})
		rc.set_selected(can_repair)
		rc.pressed.connect(func(_c): Net.net_command.rpc_id(1, {"cmd": "repair"}))
		extras.add_child(rc)
		var glyphs := {"max_mana": "M", "regen": "R", "draw": "D"}
		for id in Game.UPGRADES:
			var u: Dictionary = Game.UPGRADES[id]
			var cost := Game.upgrade_cost(id)
			var lvl: int = Game.upgrade_levels.get(id, 0)
			var cost_parts := []
			var can := true
			for t in cost:
				cost_parts.append("%d %s" % [cost[t], t])
				if snap.resources.get(t, 0) < cost[t]:
					can = false
			var c := TierCard.new()
			c.setup({"size": Vector2(92, 128), "title": u.name, "glyph": glyphs.get(id, "+"), "tier": mini(lvl, 6), "max_tier": 6, "badge": "Lv %d" % lvl,
				"lines": [u.desc], "footer": " ".join(cost_parts), "accent": Color(0.5, 0.75, 1.0), "locked": !can})
			c.set_selected(can)
			c.pressed.connect(func(_c): Net.net_command.rpc_id(1, {"cmd": "upgrade", "id": id}))
			extras.add_child(c)

## Weapons carried, the chest draft, and the Forge (when standing next to it).
func _update_loot_ui(snap: Dictionary) -> void:
	var me := {}
	for p in snap.players:
		if p.id == multiplayer.get_unique_id():
			me = p
	if me.is_empty():
		return
	var names := []
	for i in me.slots.size():
		names.append(("[%s]" if i == me.active else "%s") % _weapon_label(me.slots[i]))
	weapons_label.text = "Weapons (Q switches): " + "  ".join(names)               # (hidden; the slots on the left show it)
	hp_bar.value = me.hp
	hp_fill.size.x = clampf(me.hp * 228.0, 0.0, 228.0)
	slots_ctl.slots = me.slots
	slots_ctl.active = me.active
	var mg: Dictionary = Game.held_merge(me.slots) if !_in_base else {}
	slots_ctl.set_merge(mg, "D-pad down" if Pad.using_pad else "F")
	var keep_pool := []
	for k in snap.resources:
		if snap.resources[k] > 0 or k in ["stone", "stick", "gold"]:
			keep_pool.append("%d %s" % [snap.resources[k], k])
	keep_bar.max_value = snap.get("keep_max", 150.0)
	keep_bar.value = snap.get("keep", 0.0)
	keep_lbl.text = "Keep %d / %d" % [snap.get("keep", 0), snap.get("keep_max", 0)]
	wave_label.text = Game.wave_timer_text()
	ability_hud.remote_cd = Net.my_cd
	var load_parts := []
	for k in me.carried:
		if me.carried[k] > 0:
			load_parts.append("%d %s" % [me.carried[k], k])
	carry_label.text = "Carrying: " + (", ".join(load_parts) if load_parts.size() > 0 else "nothing") + "     Keep: " + ", ".join(keep_pool)
	# chest draft: the same screen as everyone's
	draft_view.visible = snap.draft.size() > 0
	if draft_view.visible:
		_fit(draft_view)
		draft_view.render()
	_me = me
	_update_forge(snap)
	# Card Fuser: the same screen as everyone's; the host fuses
	if !me.get("near_fuser", false):
		fuser_view.visible = false
	if fuser_view.visible:
		_fit(fuser_view)
		fuser_view.render({"hand": snap.get("hand", []), "picks": _fuse_sel, "cur": -1, "gold": int(snap.get("resources", {}).get("gold", 0))})
	else:
		_fuse_sel = []

## Size a shared screen to the window (it scales itself like player 1's).
func _fit(v: Control) -> void:
	var area := get_viewport().get_visible_rect().size
	if !v.size.is_equal_approx(area / v.scale.x):
		v.fit(area)

func _forge_list() -> Array:
	return ForgeLayout.items(_me.get("slots", []), Net.last_snapshot.get("store", []))

## The Forge: the same screen as everyone's (ui/forge/forge_view.gd); the host does the work (forge_store / forge_craft).
func _update_forge(snap: Dictionary) -> void:
	if !_me.get("near_forge", false):
		forge_view.visible = false
	if !forge_view.visible:
		_forge_sel = []
		return
	_fit(forge_view)
	forge_view.render({"list": _forge_list(), "picks": _forge_sel, "cur": -1, "store_full": snap.get("store", []).size() >= Game.FORGE_STORE_MAX, "hands_full": _me.slots.size() >= 3})

func open_forge() -> void:
	if _me.get("near_forge", false):
		_forge_sel = []
		forge_view.visible = true
		_update_forge(Net.last_snapshot)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and !event.echo and event.keycode == KEY_Q) or event.is_action_pressed("switch_items"):
		Net.net_command.rpc_id(1, {"cmd": "switch"})
	if event.is_action_pressed("merge_weapons") and !_in_base:
		Net.net_command.rpc_id(1, {"cmd": "merge_held"})
	if event.is_action_pressed("interact") and _me.get("near_forge", false) and !forge_view.visible:
		open_forge()                                         # E at the anvil opens the Forge, like player 1's
	elif event.is_action_pressed("interact") and _me.get("near_fuser", false) and !fuser_view.visible:
		_fuse_sel = []
		fuser_view.visible = true                            # E at the table opens the Card Fuser
	elif event.is_action_pressed("interact"):
		Net.net_command.rpc_id(1, {"cmd": "interact"})      # tower, chest or pickup: the host decides what is in reach
	elif _in_base and event is InputEventKey and event.pressed and !event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		selected = event.keycode - KEY_1
	elif _in_base and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected < 0:
		Net.net_command.rpc_id(1, {"cmd": "tower_tp", "pos": Pad.world_mouse(self)})      # the host checks there is a lit tower there
	elif _in_base and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and selected >= 0:
		var hand: Array = Net.last_snapshot.get("hand", [])
		if selected < hand.size():
			Net.net_command.rpc_id(1, {"cmd": "cast", "card": hand[selected], "pos": Pad.world_mouse(self)})
			selected = -1

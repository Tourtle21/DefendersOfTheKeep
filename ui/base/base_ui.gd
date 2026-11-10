extends CanvasLayer
## HUD for the keep: carried/pooled resources are always visible; the mana bar,
## card hand and upgrades only appear while a player is inside the keep.

var selected := -1          # index into Game.hand (click-to-aim fallback)
var dragging := -1          # index being dragged from the hand
var ghost: CardView
var info_label: Label
var hint_label: Label
var wave_label: Label
var mana_bar: ProgressBar
var mana_label: Label
var draw_bar: ProgressBar
var hand_box: HBoxContainer
var base_panel: Control      # everything that is base-only
var upgrade_box: HBoxContainer
var reticle: Control
var deck_label: Label
var ability_label: Label
var banner: Label
var keep_bar: ProgressBar
var hurt_flash: ColorRect

func _ready() -> void:
	layer = 5
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	# always visible: resources
	info_label = Label.new()
	info_label.position = Vector2(12, 10)
	info_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(info_label)

	ability_label = Label.new()
	ability_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ability_label.offset_left = -420
	ability_label.offset_right = -12
	ability_label.offset_top = 36
	ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ability_label.add_theme_font_size_override("font_size", 16)
	ability_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ability_label.add_theme_constant_override("outline_size", 4)
	ui.add_child(ability_label)

	hurt_flash = ColorRect.new()
	hurt_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hurt_flash)
	Game.player_hurt.connect(func():
		Sfx.play("hurt")
		hurt_flash.color.a = 0.35
		create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.4))

	keep_bar = ProgressBar.new()
	keep_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	keep_bar.offset_left = -170
	keep_bar.offset_right = 170
	keep_bar.offset_top = 38
	keep_bar.offset_bottom = 58
	keep_bar.max_value = Game.keep_max()
	keep_bar.show_percentage = false
	keep_bar.modulate = Color(1.0, 0.55, 0.45)
	var keep_lbl := Label.new()
	keep_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep_lbl.add_theme_font_size_override("font_size", 13)
	keep_bar.add_child(keep_lbl)
	ui.add_child(keep_bar)
	Game.keep_sel_changed.connect(func(): _rebuild_upgrades())
	Pad.device_changed.connect(func(_on): _refresh_all())          # the hint names the buttons of whichever device you are using
	Game.keep_changed.connect(func():
		keep_bar.value = Game.keep_hp
		keep_lbl.text = "Keep %d / %d" % [Game.keep_hp, Game.keep_max()]
		_rebuild_upgrades())
	keep_bar.value = Game.keep_hp
	keep_lbl.text = "Keep %d / %d" % [Game.keep_hp, Game.keep_max()]

	banner = Label.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 70
	banner.offset_left = -400
	banner.offset_right = 400
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.modulate.a = 0.0
	ui.add_child(banner)
	Game.announce.connect(func(text):
		banner.text = text
		var tw := create_tween()
		tw.tween_property(banner, "modulate:a", 1.0, 0.2)
		tw.tween_interval(3.0)
		tw.tween_property(banner, "modulate:a", 0.0, 0.8))

	base_panel = Control.new()
	base_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(base_panel)

	# aiming reticle drawn under the other widgets
	reticle = Control.new()
	reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.draw.connect(_draw_reticle)
	base_panel.add_child(reticle)

	wave_label = Label.new()                       # the countdown to the next wave, so there is time to prepare
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave_label.position.y = 62
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.add_theme_constant_override("outline_size", 5)
	ui.add_child(wave_label)
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.position.y = 88      # under the keep integrity bar and the wave timer
	hint_label.add_theme_font_size_override("font_size", 15)
	base_panel.add_child(hint_label)

	# bottom centre: mana bar + draw bar + hand
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12
	bottom.alignment = BoxContainer.ALIGNMENT_END
	base_panel.add_child(bottom)

	mana_bar = ProgressBar.new()
	mana_bar.custom_minimum_size = Vector2(420, 22)
	mana_bar.show_percentage = false
	mana_bar.modulate = Color(0.5, 0.7, 1.4)
	bottom.add_child(mana_bar)
	mana_label = Label.new()
	mana_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_bar.add_child(mana_label)

	draw_bar = ProgressBar.new()
	draw_bar.custom_minimum_size = Vector2(420, 6)
	draw_bar.show_percentage = false
	draw_bar.max_value = 1.0
	bottom.add_child(draw_bar)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 8)
	bottom.add_child(hand_box)

	# radar for scouting (top-right, under the weapon readout)
	var radar := Control.new()
	radar.set_script(preload("res://ui/base/minimap.gd"))
	base_panel.add_child(radar)
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -236
	radar.offset_right = -16
	radar.offset_top = 150
	radar.offset_bottom = 370

	# top-left under the resources: upgrades
	upgrade_box = HBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 8)
	upgrade_box.position = Vector2(12, 44)
	base_panel.add_child(upgrade_box)
	deck_label = Label.new()
	deck_label.position = Vector2(12, 176)
	deck_label.add_theme_font_size_override("font_size", 14)
	base_panel.add_child(deck_label)

	Game.mana_changed.connect(_refresh_mana)
	Game.resources_changed.connect(_refresh_all)
	Game.hand_changed.connect(_refresh_hand)
	Game.base_players_changed.connect(func(): _on_base_mode(Game.local_in_base()))
	Game.deck_changed.connect(_refresh_deck)
	_on_base_mode(false)
	_refresh_all()
	_refresh_hand()
	_refresh_mana()
	_refresh_deck()

	# the old two-slot resource display is replaced by the labels here
	var hud = get_parent().get_node_or_null("Hud")
	if hud and hud.has_node("Control3"):
		hud.get_node("Control3").visible = false

func _process(_delta: float) -> void:
	wave_label.text = Game.wave_timer_text()
	_update_ability_label()
	if base_panel.visible:
		draw_bar.value = Game.draw_progress()
		reticle.queue_redraw()
		if ghost:
			ghost.position = Pad.screen_mouse(get_viewport()) - CardView.SIZE * 0.275

func _on_base_mode(active: bool) -> void:
	base_panel.visible = active
	selected = -1
	_refresh_hand(active)
	_refresh_all()

func _refresh_mana() -> void:
	mana_bar.max_value = Game.max_mana()
	mana_bar.value = Game.mana
	mana_label.text = "Mana %d / %d" % [Game.mana, Game.max_mana()]
	_refresh_hand_enabled()

func _refresh_all() -> void:
	var carry := []
	var keep := []
	for k in Game.resources:
		if Game.resources[k] > 0 or k in ["stone", "stick", "gold"]:
			keep.append("%d %s" % [Game.resources[k], k])
	for k in Game.carried:
		if Game.carried[k] > 0 or k in ["stone", "stick", "gold"]:
			carry.append("%d %s" % [Game.carried[k], k])
	info_label.text = "Carrying: %s     Keep: %s" % [", ".join(carry), ", ".join(keep)]
	if Game.local_in_base():
		hint_label.text = "LB / RB pick a card   RT place it (or jump to a lit tower)   D-pad up/down pick Repair / an upgrade, Y buy   X reload the tower   A leave" if Pad.using_pad else "Drag a card onto the map.  Click a lit tower to jump to it."
	_rebuild_upgrades()
	_refresh_hand_enabled()

const TierCard = preload("res://ui/cards/tier_card.gd")
const COST_SHORT := {"stone": "stone", "stick": "stick", "gold": "gold"}

func _cost_short(cost: Dictionary) -> String:
	var parts := []
	for t in cost:
		parts.append("%d %s" % [cost[t], COST_SHORT.get(t, t)])
	return "  ".join(parts)

## Keep upgrades as small cards: green frame = you can buy it now. The gems are the level.
func _rebuild_upgrades() -> void:
	for c in upgrade_box.get_children():
		c.queue_free()
	var rcost := {"stone": 3}
	var can_repair: bool = Game.keep_hp < Game.keep_max() and Game.can_afford(rcost)
	var rc := TierCard.new()
	rc.setup({"size": Vector2(92, 128), "title": "Repair", "glyph": "+", "lines": ["+30 keep"], "footer": "3 stone",
		"accent": Color(0.9, 0.5, 0.4), "locked": !can_repair, "tooltip": "Repair the keep +30 (3 stone)"})
	rc.set_selected(can_repair)
	if Pad.using_pad and Game._keep_sel == 0:
		rc.data["blink"] = true                       # the controller's highlight (D-pad up/down, Y buys)
	rc.pressed.connect(func(_c): Game.repair_keep())
	upgrade_box.add_child(rc)
	var glyphs := {"max_mana": "M", "regen": "R", "draw": "D"}
	var pick_n := 0
	for id in Game.UPGRADES:
		pick_n += 1
		var u: Dictionary = Game.UPGRADES[id]
		var cost := Game.upgrade_cost(id)
		var lvl: int = Game.upgrade_levels.get(id, 0)
		var can := Game.can_afford(cost)
		var c := TierCard.new()
		c.setup({"size": Vector2(92, 128), "title": u.name, "glyph": glyphs.get(id, "+"), "tier": mini(lvl, 6), "max_tier": 6,
			"badge": "Lv %d" % lvl, "lines": [u.desc], "footer": _cost_short(cost), "accent": Color(0.5, 0.75, 1.0),
			"locked": !can, "tooltip": "%s: %s" % [u.name, u.desc]})
		c.set_selected(can)
		if Pad.using_pad and Game._keep_sel == pick_n:
			c.data["blink"] = true
		c.pressed.connect(func(_c): Game.buy_upgrade(id))
		upgrade_box.add_child(c)

func _refresh_hand(flip_all := false) -> void:
	var prev := hand_box.get_child_count()
	for c in hand_box.get_children():
		hand_box.remove_child(c)
		c.queue_free()
	if selected >= Game.hand.size():
		selected = -1
	for i in Game.hand.size():
		var view := CardView.new()
		view.setup(Game.entry_id(Game.hand[i]), Game.entry_tier(Game.hand[i]), "", Game.entry_twist(Game.hand[i]))
		view.pressed_down.connect(_on_card_down)
		hand_box.add_child(view)
		# new cards (or the whole hand when entering the keep) spin in like tokens
		if flip_all:
			view.flip_in(i * 0.08)
		elif i >= prev:
			view.flip_in()
	_refresh_hand_enabled()

func _refresh_hand_enabled() -> void:
	Game.card_aim_active = selected >= 0 or dragging >= 0
	if hand_box == null:
		return
	var kids := hand_box.get_children()
	for i in kids.size():
		if i >= Game.hand.size():
			break
		kids[i].set_state(i == selected or i == dragging, Game.can_cast(Game.hand[i]))
		# a card that can merge with the one you picked up glows green
		var pick := dragging if dragging >= 0 else selected
		if pick >= 0 and i != pick and Game.can_merge(pick, i):
			kids[i].modulate = Color(0.7, 1.4, 0.8)
		elif pick >= 0 and i != pick and Game.can_fuse_pair(pick, i):
			kids[i].modulate = Color(0.7, 1.2, 1.5)          # a different card it fuses with (drop or click it: no trip to the Card Fuser)

func select(i: int) -> void:
	if i < 0 or i >= Game.hand.size():
		return
	selected = -1 if selected == i else i
	_refresh_hand_enabled()

func _world_mouse() -> Vector2:
	return Pad.view_transform(get_viewport()).affine_inverse() * Pad.screen_mouse(get_viewport())

func cast_selected_at(world_pos: Vector2) -> void:
	if selected < 0 or selected >= Game.hand.size():
		return
	var id: String = Game.hand[selected]
	var players := get_tree().get_nodes_in_group("player")
	if Game.cast(id, world_pos, players[0] if players.size() > 0 else null):
		selected = -1

func _on_card_down(view: CardView) -> void:
	start_drag(view.get_index())

func start_drag(i: int) -> void:
	if i < 0 or i >= Game.hand.size() or !Game.local_in_base() or Game.draft_active:
		return
	dragging = i
	selected = -1
	ghost = CardView.new()
	ghost.setup(Game.entry_id(Game.hand[i]), Game.entry_tier(Game.hand[i]), "", Game.entry_twist(Game.hand[i]))
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.scale = Vector2(0.55, 0.55)
	ghost.modulate = Color(1, 1, 1, 0.85)
	base_panel.add_child(ghost)
	_refresh_hand_enabled()

func _hand_slot_at_mouse() -> int:
	var m := Pad.screen_mouse(get_viewport())
	var kids := hand_box.get_children()
	for i in kids.size():
		if kids[i].get_global_rect().has_point(m):
			return i
	return -1

func _over_hand() -> bool:
	return hand_box.get_global_rect().grow(8).has_point(Pad.screen_mouse(get_viewport()))

## Drop the dragged card: onto the map casts it (shot from the crystal), back
## onto the hand just selects it so you can still click-to-aim.
func end_drag() -> void:
	if dragging < 0:
		return
	var i := dragging
	dragging = -1
	if ghost:
		ghost.queue_free()
		ghost = null
	if _over_hand():
		var k := _hand_slot_at_mouse()
		if k >= 0 and k != i and Game.can_merge(i, k):
			Game.merge_hand(i, k)             # dropped onto an identical card: they combine into the next tier
			selected = -1
		elif selected >= 0 and selected != i and Game.can_merge(selected, i):
			Game.merge_hand(selected, i)
			selected = -1
		elif k >= 0 and k != i and Game.can_fuse_pair(i, k):
			_fuse_cards(i, k)
		elif selected >= 0 and selected != i and Game.can_fuse_pair(selected, i):
			_fuse_cards(selected, i)
		else:
			selected = i
	else:
		var id: String = Game.hand[i]
		var players := get_tree().get_nodes_in_group("player")
		Game.cast(id, _world_mouse(), players[0] if players.size() > 0 else null)
		selected = -1
	_refresh_hand_enabled()

## Fuse two different hand cards right here (the Card Fuser's recipes and cost, paid from the keep's gold).
func _fuse_cards(i: int, j: int) -> void:
	var pv := Game.fuse_preview(i, j)
	if pv.ok:
		Game.fuse_hand(i, j)
	else:
		Game.announce.emit(pv.reason)
	selected = -1

func _input(event: InputEvent) -> void:
	if dragging >= 0 and event is InputEventMouseButton and !event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		end_drag()

func _unhandled_input(event: InputEvent) -> void:
	if !Game.local_in_base():
		return
	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			select(event.keycode - KEY_1)
		elif event.keycode == KEY_ESCAPE:
			selected = -1
			_refresh_hand_enabled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if selected < 0 and dragging < 0 and _try_tower_jump(_world_mouse()):
				return
			cast_selected_at(_world_mouse())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected = -1
			_refresh_hand_enabled()

## With no card picked up, clicking another lit tower jumps you there.
func _try_tower_jump(world_pos: Vector2) -> bool:
	var player = null
	for p in Game.players_in_base:
		if is_instance_valid(p) and !p.remote_controlled:
			player = p
	if player == null:
		return false
	var target = Game.tower_at(world_pos, 34.0, Game.current_tower(player))
	if target == null:
		return false
	return Game.teleport_to_tower(player, target)

## Rings on the other lit towers while you are inside one.
func _draw_tower_markers() -> void:
	if selected >= 0 or dragging >= 0:
		return
	var player = null
	for p in Game.players_in_base:
		if is_instance_valid(p) and !p.remote_controlled:
			player = p
	if player == null:
		return
	var here = Game.current_tower(player)
	var xf := Pad.view_transform(get_viewport())
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var zoom: float = xf.get_scale().x
	for t in Game.all_towers():
		if t == here or !Game.tower_online(t):
			continue
		var sp: Vector2 = xf * (t.global_position + Vector2(0, -6))
		reticle.draw_arc(sp, (20.0 + 3.0 * pulse) * zoom, 0, TAU, 32, Color(0.7, 0.9, 1.0, 0.8), 2.0)
		reticle.draw_string(ThemeDB.fallback_font, sp + Vector2(-30, -26 * zoom), "click to go", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.95, 1.0))

func _draw_reticle() -> void:
	_draw_chest_markers()
	_draw_tower_markers()
	var idx := dragging if dragging >= 0 else selected
	if idx < 0 or idx >= Game.hand.size():
		return
	var id: String = Game.hand[idx]
	var card: Dictionary = Game.stats_of(id)
	var zoom: float = Pad.view_transform(get_viewport()).get_scale().x
	var mouse := Pad.screen_mouse(get_viewport())
	var cancel := dragging >= 0 and _over_hand()
	var col := Color(1, 0.35, 0.35, 0.8) if cancel else Color(1, 1, 0.4, 0.95)
	# where it will land
	reticle.draw_arc(mouse, card.radius * zoom, 0, TAU, 48, col, 2.0)
	if cancel:
		return
	# the shot leaves the crystal, so show the path and how long it takes
	var crystal_screen: Vector2 = Pad.view_transform(get_viewport()) * Game.crystal_position()
	reticle.draw_dashed_line(crystal_screen, mouse, Color(col, 0.6), 2.0, 8.0)
	reticle.draw_circle(crystal_screen, 4.0, col)
	var secs := Game.flight_time(id, _world_mouse())
	reticle.draw_string(ThemeDB.fallback_font, mouse + Vector2(card.radius * zoom + 8, 4),
		"%.1fs" % secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

func _refresh_deck() -> void:
	if deck_label == null:
		return
	var parts := []
	for id in Game.deck:
		parts.append("%s x%d" % [Game.CARDS[id].name, Game.deck[id]])
	deck_label.text = "Deck: " + ", ".join(parts)

## Edge markers for chests: lets whoever is in the keep spot and call out loot.
func _draw_chest_markers() -> void:
	var xf := Pad.view_transform(get_viewport())
	var rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(-48)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var font := ThemeDB.fallback_font
	for c in get_tree().get_nodes_in_group("chest"):
		var sp: Vector2 = xf * c.global_position
		var inside := rect.has_point(sp)
		var p := sp if inside else sp.clamp(rect.position, rect.end)
		var col := Color(1, 0.85, 0.3, 0.95)
		if !inside:
			var d := (sp - p).normalized()
			var side := d.orthogonal()
			reticle.draw_colored_polygon(PackedVector2Array([p + d * 14, p - d * 4 + side * 9, p - d * 4 - side * 9]), col)
		reticle.draw_string(font, p + Vector2(12, -8), "%s %ds" % [c.label(), int(c.time_left)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

func _update_ability_label() -> void:
	ability_label.text = ""          # replaced by the bottom-right ability HUD (ui/hud/ability_hud.gd)
	return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.item == null or p.item.get("ability_name") == null:
		ability_label.text = ""
		return
	var it = p.item
	var lines := []
	if it.get("attack_name") != null and it.attack_name != "":
		lines.append("Left click: %s" % it.attack_name)
	if it.ability_name != "":
		var cd: float = it.ability_cd_left()
		lines.append("Right click: %s  %s" % [it.ability_name, "ready" if cd <= 0.0 else "%.1fs" % cd])
	if it.get("dash_name") != null and it.dash_name != "":
		var dcd: float = it.dash_cd_left()
		lines.append("Shift: %s  %s" % [it.dash_name, "ready" if dcd <= 0.0 else "%.1fs" % dcd])
	if it.get("ultimate_name") != null and it.ultimate_name != "":
		var ucd: float = it.ult_cd_left()
		lines.append("Space: %s  %s" % [it.ultimate_name, "READY" if ucd <= 0.0 else "%.0fs" % ucd])
	lines.append("(tap = cast at cursor, hold 1s = aim, release = cast)")
	ability_label.text = "\n".join(lines)

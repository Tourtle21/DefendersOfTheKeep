extends CanvasLayer
## HUD for the keep: carried/pooled resources are always visible; the mana bar,
## card hand and upgrades only appear while a player is inside the keep.
const UiKit = preload("res://ui/cards/ui_kit.gd")

var selected := -1          # index into Game.hand (click-to-aim fallback)
var dragging := -1          # index being dragged from the hand
var ghost: CardView
var top: Dictionary         # the shared HUD top (ui/hud/hud_kit.gd): resource line, keep bar, wave countdown, banner
var info_label: Label:
	get: return top.info
var wave_label: Label:
	get: return top.wave
var keep_bar: ProgressBar:
	get: return top.keep_bar
var hint_label: Label
var mana: Dictionary        # the shared mana and card-draw bars
var hand_box: HBoxContainer
var hand_views: Array = []
var base_panel: Control      # everything that is base-only
var upgrade_box: HBoxContainer
var reticle: Control
var radar: Control
var deck_label: Label
var hurt_flash: ColorRect

const HudKit = preload("res://ui/hud/hud_kit.gd")

func _ready() -> void:
	layer = 5
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiKit.make_theme(true)           # the one look; text over the world is outlined
	add_child(ui)
	hurt_flash = HudKit.hurt_flash(ui)
	Game.player_hurt.connect(func():
		Sfx.play("hurt")
		HudKit.flash(hurt_flash))
	top = HudKit.top(ui)
	Game.announce.connect(func(text): HudKit.announce(top.banner, text))
	Game.keep_sel_changed.connect(func(): _rebuild_upgrades())
	Pad.device_changed.connect(func(_on): _refresh_all())          # the hint names the buttons of whichever device you are using
	Game.keep_changed.connect(_rebuild_upgrades)

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

	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.position.y = 88      # under the keep integrity bar and the wave timer
	hint_label.add_theme_font_size_override("font_size", UiKit.FONT_BODY)
	base_panel.add_child(hint_label)

	# bottom centre: mana bar + draw bar + hand
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -12
	bottom.alignment = BoxContainer.ALIGNMENT_END
	base_panel.add_child(bottom)
	mana = HudKit.mana_block(bottom)
	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 8)
	bottom.add_child(hand_box)

	# radar for scouting (top-right, under the weapon readout)
	radar = Control.new()
	radar.set_script(preload("res://ui/base/minimap.gd"))
	base_panel.add_child(radar)

	# top-left under the resources: upgrades
	upgrade_box = HBoxContainer.new()
	upgrade_box.add_theme_constant_override("separation", 8)
	upgrade_box.position = Vector2(12, 44)
	base_panel.add_child(upgrade_box)
	deck_label = Label.new()
	deck_label.position = Vector2(12, 176)
	deck_label.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
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

var _fitted := Vector2.ZERO

func _view_size() -> Vector2:
	return Vector2(custom_viewport.size) if custom_viewport is SubViewport else get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	var view := _view_size()
	if view != _fitted:
		_fitted = view
		HudKit.fit_top(top, view)
		HudKit.fit_keep(view, mana, radar, upgrade_box, hint_label)       # the same keep layout as every other player's
		_rebuild_upgrades()
		_refresh_hand()
	HudKit.set_top(top, Game.carried, Game.resources, Game.keep_hp, Game.keep_max())
	if base_panel.visible:
		# in a split-screen half the upgrade cards would sit on top of the keep bar and the wave timer: drop them below the hint
		deck_label.position.y = upgrade_box.position.y + HudKit.upgrade_size(view.x).y + 4.0
		mana.draw.value = Game.draw_progress()
		reticle.queue_redraw()
		if ghost:
			ghost.position = Pad.screen_mouse(get_viewport()) - CardView.SIZE * 0.275

func _on_base_mode(active: bool) -> void:
	base_panel.visible = active
	selected = -1
	_refresh_hand(active)
	_refresh_all()

func _refresh_mana() -> void:
	HudKit.set_mana(mana, Game.mana, Game.max_mana(), Game.draw_progress())
	_refresh_hand_enabled()

func _refresh_all() -> void:
	if Game.local_in_base():
		hint_label.text = "LB / RB pick a card   RT place it (or jump to a lit tower)   D-pad up/down pick Repair / an upgrade, Y buy   X reload the tower   A leave" if Pad.using_pad else "Drag a card onto the map.  Click a lit tower to jump to it."
	_rebuild_upgrades()
	_refresh_hand_enabled()

## Keep upgrades as small cards (shared with every player: ui/hud/hud_kit.gd); the controller's pick blinks.
func _rebuild_upgrades() -> void:
	HudKit.upgrade_cards(upgrade_box, HudKit.upgrade_size(_view_size().x), Game._keep_sel if Pad.using_pad else -1, Game.resources, Game.keep_hp, Game.keep_max(),
		func(): Game.repair_keep(), func(id): Game.buy_upgrade(id))

func _refresh_hand(flip_all := false) -> void:
	var prev := hand_views.size()
	if selected >= Game.hand.size():
		selected = -1
	hand_views = HudKit.hand_cards(hand_box, Game.hand, HudKit.hand_scale(Game.hand.size(), _view_size().x), selected, start_drag)
	for i in hand_views.size():
		# new cards (or the whole hand when entering the keep) spin in like tokens
		if flip_all:
			hand_views[i].flip_in(i * 0.08)
		elif i >= prev:
			hand_views[i].flip_in()
	_refresh_hand_enabled()

func _refresh_hand_enabled() -> void:
	Game.card_aim_active = selected >= 0 or dragging >= 0
	if hand_box == null:
		return
	var kids := hand_views
	for i in kids.size():
		if i >= Game.hand.size() or !is_instance_valid(kids[i]):
			break
		kids[i].set_state(i == selected or i == dragging, Game.can_cast(Game.hand[i]))
		# a card that can merge with the one you picked up glows green
		var pick := dragging if dragging >= 0 else selected
		if pick >= 0 and i != pick and Game.can_merge(pick, i):
			kids[i].modulate = UiKit.GLOW_MERGE
		elif pick >= 0 and i != pick and Game.can_fuse_pair(pick, i):
			kids[i].modulate = UiKit.GLOW_FUSE          # a different card it fuses with (drop or click it: no trip to the Card Fuser)

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

func start_drag(i: int) -> void:
	if i < 0 or i >= Game.hand.size() or !Game.local_in_base() or Game.draft_active:
		return
	dragging = i
	selected = -1
	ghost = CardView.new()
	ghost.setup(Game.entry_id(Game.hand[i]), Game.entry_tier(Game.hand[i]), "", Game.entry_twist(Game.hand[i]))
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.scale = Vector2(0.55, 0.55)
	ghost.modulate = Color(UiKit.WHITE, 0.85)
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
		reticle.draw_arc(sp, (20.0 + 3.0 * pulse) * zoom, 0, TAU, 32, Color(UiKit.TEXT_HINT, 0.8), 2.0)
		reticle.draw_string(ThemeDB.fallback_font, sp + Vector2(-30, -26 * zoom), "click to go", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TEXT_HINT)

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
	var col := Color(UiKit.BAD, 0.8) if cancel else Color(UiKit.CURSOR, 0.95)
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
		var col := Color(UiKit.GOLD, 0.95)
		if !inside:
			var d := (sp - p).normalized()
			var side := d.orthogonal()
			reticle.draw_colored_polygon(PackedVector2Array([p + d * 14, p - d * 4 + side * 9, p - d * 4 - side * 9]), col)
		reticle.draw_string(font, p + Vector2(12, -8), "%s %ds" % [c.label(), int(c.time_left)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

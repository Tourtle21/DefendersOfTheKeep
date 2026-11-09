extends CanvasLayer
## The keep screen for a local split-screen player (players 2 to 4): their hand, mana, a cursor over their view of the
## map, and what their controller does inside a tower. It shows only while that player is inside a tower.
##   A leave   B / LT put the card back   LB / RB pick a card   RT place it (or jump to a lit tower)
##   X merge the picked card   d-pad up repair the keep   d-pad left / right choose an upgrade   d-pad down buy it
## During a chest draft the same player can pick a card with LB / RB and A.

const CURSOR_SPEED := 560.0

var pl: Node
var vp: SubViewport
var slot := 0
var cursor := Vector2.ZERO
var sel := -1
var upg := 0
var draft_sel := 0
var _prev := {}
var _root: Control
var _hand_row: HBoxContainer
var _mana: ProgressBar
var _info: Label
var _hint: Label
var _draft_row: HBoxContainer
var _canvas: Control
var _hand_key := ""
var _was_inside := false

func setup(player: Node, viewport: SubViewport, player_slot: int) -> void:
	pl = player
	vp = viewport
	slot = player_slot
	layer = 6
	custom_viewport = viewport
	cursor = Vector2(viewport.size) / 2.0
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(viewport.size)
	_root.visible = false
	add_child(_root)
	_canvas = Control.new()                                # the cursor and the landing ring
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	_root.add_child(_canvas)
	_info = Label.new()
	_info.position = Vector2(10, 76)
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	_root.add_child(_info)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_bottom = -4
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	bottom.add_child(_hint)
	_mana = ProgressBar.new()
	_mana.custom_minimum_size = Vector2(240, 14)
	_mana.show_percentage = false
	_mana.modulate = Color(0.5, 0.7, 1.4)
	bottom.add_child(_mana)
	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 3)
	_hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_hand_row)
	_draft_row = HBoxContainer.new()
	_draft_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_draft_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_draft_row.grow_vertical = Control.GROW_DIRECTION_BOTH
	_draft_row.add_theme_constant_override("separation", 8)
	_draft_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_row.visible = false
	_root.add_child(_draft_row)

## Re-fit to the view's size (the window can be resized).
func fit(area: Vector2) -> void:
	_root.size = area
	cursor = cursor.clamp(Vector2.ZERO, area)

func _world_pos() -> Vector2:
	return vp.get_canvas_transform().affine_inverse() * cursor

func _edge(key: String, down: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = down
	return down and !was

## Called every physics frame by LocalPlayers with this player's controller.
func poll(dev: int, delta: float) -> void:
	var inside: bool = is_instance_valid(pl) and pl.is_in_tower and !pl.downed
	_root.visible = inside
	if !inside:
		_prev.clear()
		sel = -1
		_was_inside = false
		return
	if !_was_inside:
		# just stepped in: whatever is held right now (the A that opened the door) must not also act on this screen
		_was_inside = true
		for k in ["lb", "rb", "a", "b", "x", "up", "down", "rt", "lt"]:
			_prev[k] = true
		_prev["lb"] = false
		_prev["rb"] = false
		_prev["a"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_A)
		_prev["b"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_B)
		_prev["x"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_X)
		_prev["y"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)
		_prev["up"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP)
		_prev["down"] = Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN)
		_prev["rt"] = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		_prev["lt"] = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5
		_refresh_ui()
		return
	var v := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)) + Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
	if v.length() > 0.25:
		cursor = (cursor + v.limit_length(1.0) * CURSOR_SPEED * delta).clamp(Vector2.ZERO, Vector2(vp.size))
	var lb := _edge("lb", Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	var b := _edge("b", Input.is_joy_button_pressed(dev, JOY_BUTTON_B))
	var x := _edge("x", Input.is_joy_button_pressed(dev, JOY_BUTTON_X))
	var up := _edge("up", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP))
	var down := _edge("down", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN))
	var rt := _edge("rt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5)
	var lt := _edge("lt", Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5)
	var y := _edge("y", Input.is_joy_button_pressed(dev, JOY_BUTTON_Y))
	if Game.draft_active and !Game.draft_options.is_empty():
		var n := Game.draft_options.size()
		if lb: draft_sel = wrapi(draft_sel - 1, 0, n)
		if rb: draft_sel = wrapi(draft_sel + 1, 0, n)
		if a:
			Game.take_draft_card(Game.draft_options[draft_sel])
			draft_sel = 0
		_refresh_ui()
		return
	var hand_n: int = Game.hand.size()
	if lb and hand_n > 0:
		sel = wrapi(sel - 1, 0, hand_n)
	if rb and hand_n > 0:
		sel = wrapi(sel + 1, 0, hand_n)
	if b or lt:
		sel = -1
	if a:
		Net._interact(pl)                                  # leave the tower
		return
	if rt:
		if sel >= 0 and sel < hand_n:
			if Game.cast(Game.hand[sel], _world_pos(), pl):
				sel = -1
		else:
			Game.teleport_to_tower(pl, Game.tower_at(_world_pos(), 34.0, Game.current_tower(pl)), false)
	if x and sel >= 0 and sel < hand_n:
		for j in hand_n:
			if j != sel and Game.can_merge(sel, j):
				Game.merge_hand(sel, j)
				sel = -1
				break
	elif x:
		Game.reload_tower_of(pl)                           # X with no card in hand reloads the tower you are in
	var n_items: int = Game.keep_menu_items().size()
	if up:
		upg = wrapi(upg - 1, 0, n_items)                   # D-pad up/down move over Repair and the upgrades, Y buys
	if down:
		upg = wrapi(upg + 1, 0, n_items)
	if y:
		Game.keep_menu_buy(upg)
	_refresh_ui()

func _refresh_ui() -> void:
	_mana.max_value = Game.max_mana()
	_mana.value = Game.mana
	var item_id: String = Game.keep_menu_items()[upg % Game.keep_menu_items().size()]
	var what: String
	if item_id == "repair":
		what = "Repair (3 stone)"
	else:
		var uc: Dictionary = Game.upgrade_cost(item_id)
		what = "%s lv%d  (%s)" % [Game.UPGRADES[item_id].name, Game.upgrade_levels.get(item_id, 0), ", ".join(uc.keys().map(func(k): return "%d %s" % [uc[k], k]))]
	_info.text = "Keep %d/%d   %s   > %s" % [Game.keep_hp, Game.keep_max(), _res_text(), what]
	_hint.text = "LB/RB card  RT place  A leave  X merge / reload tower  D-pad up/down pick  Y buy" if !Game.draft_active else "Chest draft!  LB/RB choose   A take it"
	var key := str(Game.hand) + "|" + str(sel) + "|" + str(Game.draft_options) + str(draft_sel) + str(Game.draft_active)
	if key != _hand_key:
		_hand_key = key
		for c in _hand_row.get_children():
			_hand_row.remove_child(c)
			c.queue_free()
		for i in Game.hand.size():
			var holder := Control.new()
			holder.custom_minimum_size = CardView.SIZE * 0.5
			var view := CardView.new()
			view.setup(Game.entry_id(Game.hand[i]), Game.entry_tier(Game.hand[i]), "", Game.entry_twist(Game.hand[i]))
			view.scale = Vector2(0.5, 0.5)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(view)
			_hand_row.add_child(holder)
			view.set_state(i == sel, Game.can_cast(Game.hand[i]))
		for c in _draft_row.get_children():
			_draft_row.remove_child(c)
			c.queue_free()
		_draft_row.visible = Game.draft_active
		if Game.draft_active:
			for i in Game.draft_options.size():
				var holder2 := Control.new()
				holder2.custom_minimum_size = CardView.SIZE * 0.8
				var view2 := CardView.new()
				view2.setup(Game.entry_id(Game.draft_options[i]), Game.entry_tier(Game.draft_options[i]), "NEW", Game.entry_twist(Game.draft_options[i]))
				view2.scale = Vector2(0.8, 0.8)
				view2.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder2.add_child(view2)
				_draft_row.add_child(holder2)
				view2.set_state(i == draft_sel, true)
	_canvas.queue_redraw()

func _res_text() -> String:
	var parts := []
	for k in Game.resources:
		if Game.resources[k] > 0 or k in ["stone", "stick", "gold"]:
			parts.append("%d %s" % [Game.resources[k], k])
	return ", ".join(parts)

func _draw_canvas() -> void:
	var col := Color(1.0, 0.92, 0.45)
	if sel >= 0 and sel < Game.hand.size():
		var card: Dictionary = Game.stats_of(Game.hand[sel])
		var zoom: float = vp.get_canvas_transform().get_scale().x
		_canvas.draw_arc(cursor, card.radius * zoom, 0, TAU, 40, Color(col, 0.9), 2.0)
	_canvas.draw_arc(cursor, 10.0, 0, TAU, 24, Color(0, 0, 0, 0.85), 4.0)
	_canvas.draw_arc(cursor, 10.0, 0, TAU, 24, col, 2.0)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_canvas.draw_line(cursor + d * 13.0, cursor + d * 18.0, col, 2.0)

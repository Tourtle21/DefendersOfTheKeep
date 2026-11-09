extends CanvasLayer
## The forge for a local split-screen player (players 2 to 4). Stand at the anvil and press d-pad up. It shows the
## weapons you hold and the ones stored in the forge, grouped by type. LB / RB move, A picks a weapon (two of them),
## X forges (two different weapons fuse, two copies of the same one combine into the next tier), Y drops the weapon
## under the cursor into the forge or takes it out, B closes. Costs and unlocked tiers are the normal forge's.

const ForgeLayout = preload("res://ui/forge/forge_layout.gd")

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var _prev := {}
var _root: Control
var _row: HBoxContainer
var _info: Label
var _hint: Label
var _key := ""

func setup(player: Node, viewport: SubViewport) -> void:
	pl = player
	vp = viewport
	layer = 8
	custom_viewport = viewport
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(viewport.size)
	_root.visible = false
	add_child(_root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.94)
	sb.border_color = Color(0.55, 0.45, 0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := Label.new()
	t.text = "FORGE"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	v.add_child(t)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	v.add_child(_row)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(300, 40)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 13)
	v.add_child(_info)
	_hint = Label.new()
	_hint.text = "LB/RB move  A pick  X forge  Y drop in / take out  B close"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	v.add_child(_hint)

func fit(area: Vector2) -> void:
	_root.size = area

func _edge(key: String, down: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = down
	return down and !was

func _near_forge() -> bool:
	return pl.global_position.distance_to(Net.FORGE_POS) <= 50.0

func _slots() -> Array:
	return pl.weapon_slots

## Everything the forge can use, in display order (shared with the LAN client's forge screen).
func _items() -> Array:
	return ForgeLayout.items(_slots(), Game._forge_store)

func preview() -> Dictionary:
	return ForgeLayout.preview(_items(), picks)

## Drop the weapon under the cursor into the forge, or take it out (when a hand slot is free).
func _toggle_store() -> void:
	var items := _items()
	if cur >= items.size():
		return
	Net.forge_toggle_store(pl, items[cur].src, items[cur].idx)
	picks.clear()
	cur = clampi(cur, 0, maxi(0, _items().size() - 1))

func _forge_picked() -> void:
	var items := _items()
	if picks.size() != 2 or !preview().ok:
		return
	Net.forge_craft(pl, items[picks[0]].src, items[picks[0]].idx, items[picks[1]].src, items[picks[1]].idx)
	picks.clear()
	cur = 0

func close() -> void:
	is_open = false
	_root.visible = false
	picks.clear()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var up := _edge("up", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP))
	var lb := _edge("lb", Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	var b := _edge("b", Input.is_joy_button_pressed(dev, JOY_BUTTON_B))
	var x := _edge("x", Input.is_joy_button_pressed(dev, JOY_BUTTON_X))
	var y := _edge("y", Input.is_joy_button_pressed(dev, JOY_BUTTON_Y))
	if !is_open:
		if up and _near_forge() and !pl.is_in_tower and !pl.downed:
			is_open = true
			cur = 0
			picks.clear()
			_root.visible = true
			_prev["a"] = true            # the press that is held now must not also pick a weapon
			_refresh()
		return
	if !_near_forge() or pl.downed or pl.is_in_tower:
		close()
		return
	var n := _items().size()
	if n > 0:
		if lb: cur = wrapi(cur - 1, 0, n)
		if rb: cur = wrapi(cur + 1, 0, n)
	if a and n > 0:
		if cur in picks:
			picks.erase(cur)
		elif picks.size() < 2:
			picks.append(cur)
	if y:
		_toggle_store()
	if x and picks.size() == 2:
		_forge_picked()
	if b:
		close()
		return
	_refresh()

func _refresh() -> void:
	var items := _items()
	var key := str(items.map(func(it): return it.entry)) + str(cur) + str(picks) + str(Game.resources)
	if key == _key:
		return
	_key = key
	ForgeLayout.build(_row, items, picks, cur, Vector2(78, 108))
	if items.is_empty():
		var l := Label.new()
		l.text = "No weapons held or stored."
		_row.add_child(l)
	var p := preview()
	_info.text = p.text
	_info.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if p.ok else Color(1, 0.8, 0.5))

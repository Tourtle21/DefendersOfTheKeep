extends CanvasLayer
## The Card Fuser for a local split-screen player (players 2 to 4). Stand at the table and press d-pad up. It shows the
## shared hand. LB / RB move, A picks a card (two of them), X fuses them, B closes. Rules are Game.fuse_preview / Net.card_fuse.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const CARD_SCALE := 0.6

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var _prev := {}
var _root: Control
var _row: HBoxContainer
var _info: Label
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
	_root.theme = UiKit.make_theme()
	add_child(_root)
	var backdrop := ColorRect.new()                 # dims the view like player 1's full-screen menus
	backdrop.color = Color(UiKit.BG, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	var panel := PanelContainer.new()
	var sb: StyleBoxFlat = UiKit.style(UiKit.PANEL, UiKit.BORDER, 12.0)       # the same panel as player 1's screens
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := UiKit.heading("Card Fuser", 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 6)
	v.add_child(_row)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(300, 40)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 13)
	v.add_child(_info)
	var hint := Label.new()
	hint.text = "LB/RB move  A pick  X fuse  B close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	v.add_child(hint)

func fit(area: Vector2) -> void:
	_root.size = area

func _edge(key: String, down: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = down
	return down and !was

func _near() -> bool:
	return pl.global_position.distance_to(Net.CARD_FUSER_POS) <= 50.0

func preview() -> Dictionary:
	if picks.size() != 2:
		return {"ok": false, "reason": "Pick two cards."}
	return Game.fuse_preview(picks[0], picks[1])

func fuse_picked() -> void:
	if picks.size() == 2 and preview().ok:
		Net.card_fuse(pl, picks[0], picks[1])
		picks.clear()
		cur = 0

func close() -> void:
	is_open = false
	_root.visible = false
	picks.clear()

func open() -> void:
	is_open = true
	cur = 0
	picks.clear()
	_root.visible = true
	_prev["a"] = true            # the press that is held now must not also pick a card
	_key = ""
	_refresh()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var up := _edge("up", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP))
	var lb := _edge("lb", Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	var b := _edge("b", Input.is_joy_button_pressed(dev, JOY_BUTTON_B))
	var x := _edge("x", Input.is_joy_button_pressed(dev, JOY_BUTTON_X))
	if !is_open:
		if up and _near() and !pl.is_in_tower and !pl.downed:
			open()
		return
	if !_near() or pl.downed or pl.is_in_tower:
		close()
		return
	var n := Game.hand.size()
	if n > 0:
		if lb: cur = wrapi(cur - 1, 0, n)
		if rb: cur = wrapi(cur + 1, 0, n)
	picks = picks.filter(func(i): return i < n)
	if a and n > 0:
		if cur in picks:
			picks.erase(cur)
		elif picks.size() < 2:
			picks.append(cur)
	if x:
		fuse_picked()
	if b:
		close()
		return
	_refresh()

func _refresh() -> void:
	var key := str(Game.hand) + str(cur) + str(picks) + str(Game.resources.get("gold", 0))
	if key == _key:
		return
	_key = key
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for i in Game.hand.size():
		var entry: String = Game.hand[i]
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * CARD_SCALE
		var v := CardView.new()
		v.setup(Game.entry_id(entry), Game.entry_tier(entry), "", Game.entry_twist(entry))
		v.scale = Vector2(CARD_SCALE, CARD_SCALE)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chosen := i in picks
		v.ready.connect(func(): v.set_state(chosen, true))
		wrap.add_child(v)
		if i == cur:
			var ring := ReferenceRect.new()
			ring.border_color = Color(1, 0.95, 0.4)
			ring.border_width = 3.0
			ring.editor_only = false
			ring.size = CardView.SIZE * CARD_SCALE
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			wrap.add_child(ring)
		_row.add_child(wrap)
	if Game.hand.is_empty():
		var l := Label.new()
		l.text = "No cards in the hand."
		_row.add_child(l)
	var p := preview()
	if p.get("ok", false):
		_info.text = "Makes %s for %d gold." % [Game.CARDS[Game.entry_id(p.result)].name, p.cost.gold]
	else:
		_info.text = p.reason
	_info.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if p.get("ok", false) else Color(1, 0.8, 0.5))

extends CanvasLayer
## The chest card choice for a local split-screen player (players 2 to 4) who opened the chest: shown in their own view.
## LB / RB move, A takes the card.

const CARD_SCALE := 0.75

var pl: Node
var slot := 1
var vp: SubViewport
var is_open := false
var cur := 0
var _prev := {}
var _root: Control
var _row: HBoxContainer
var _key := ""

func setup(player: Node, viewport: SubViewport, slot_index: int) -> void:
	pl = player
	vp = viewport
	slot = slot_index
	layer = 9
	custom_viewport = viewport
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(viewport.size)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)
	var t := Label.new()
	t.text = "Chest! Choose a card  (cards you own are upgraded)"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 4)
	box.add_child(t)
	var sub := Label.new()
	sub.text = "LB / RB move   A take it"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	box.add_child(sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	box.add_child(_row)

func fit(area: Vector2) -> void:
	_root.size = area

func _edge(key: String, down: bool) -> bool:
	var was: bool = _prev.get(key, false)
	_prev[key] = down
	return down and !was

## True while this player's chest choice is up (their controller belongs to it).
func wants() -> bool:
	return Game.draft_active and Game.draft_owner_slot == slot

func poll(dev: int) -> void:
	var lb := _edge("lb", Input.is_joy_button_pressed(dev, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	if !wants():
		if is_open:
			is_open = false
			_root.visible = false
		return
	if !is_open:
		is_open = true
		cur = 0
		_key = ""
		_root.visible = true
		_prev["a"] = true          # the press that opened the chest must not also take a card
	var n := Game.draft_options.size()
	if n > 0:
		if lb: cur = wrapi(cur - 1, 0, n)
		if rb: cur = wrapi(cur + 1, 0, n)
		if a:
			Game.take_draft_card(Game.draft_options[cur])
			return
	_refresh()

func _refresh() -> void:
	var key := str(Game.draft_options) + str(cur)
	if key == _key:
		return
	_key = key
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	for i in Game.draft_options.size():
		var entry: String = Game.draft_options[i]
		var id := Game.entry_id(entry)
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * CARD_SCALE
		var v := CardView.new()
		v.setup(id, Game.entry_tier(entry), "NEW" if Game.deck.get(id, 0) == 0 else "+1 copy", Game.entry_twist(entry))
		v.scale = Vector2(CARD_SCALE, CARD_SCALE)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.ready.connect(func(): v.set_state(false, true))
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

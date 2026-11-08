extends Control
class_name CardView
## One card in the hand: pixel-art frame + icon (see tools/make_card_art.gd),
## text on top. Flips in like the wave tokens, lifts on hover, and can be dragged
## (the drag itself is handled by ui/base/base_ui.gd).

signal pressed_down(view: CardView)

const SIZE := Vector2(96, 160)   # the 48x80 art at 2x

var card_id: String
var level := 1
var badge := ""
var twist := ""
var _body: Control
var _face: Control
var _back: TextureRect
var _selected := false
var _affordable := true
var _hover := false

func setup(id: String, lvl := 1, badge_text := "", twist_id := "") -> void:
	card_id = id
	level = lvl
	badge = badge_text
	twist = twist_id

func _tex(path: String, pos: Vector2, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.position = pos
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _label(text: String, pos: Vector2, size: Vector2, font: int, color: Color, center := true, wrap := false) -> Label:
	var l := Label.new()
	# wrapping/min size first, otherwise the label grows to the full text width
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = size
	l.clip_text = true
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var card: Dictionary = Game.CARDS[card_id]
	var kind: String = card.get("art", card.kind)

	_body = Control.new()
	_body.size = SIZE
	_body.pivot_offset = SIZE / 2.0
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_face = Control.new()
	_face.size = SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_face)
	_face.add_child(_tex("res://ui/cards/frame_%s.png" % kind, Vector2.ZERO, SIZE))
	_face.add_child(_tex("res://ui/cards/icon_%s.png" % kind, Vector2(32, 26), Vector2(32, 32)))

	# mana cost badge, top-left of the art window
	if card.mana > 0:
		_face.add_child(_label(str(card.mana), Vector2(11, 9), Vector2(24, 18), 14, Color("8fc8ff"), false))
	# level / draft badge, top-right of the art window
	# a draft badge ("NEW", "+1 copy") also shows the tier of the offered card
	var tag := ("T%d %s" % [level, badge.replace(" copy", "")] if level > 1 else badge) if badge != "" else ("T%d" % level if level > 1 else "")
	if tag != "":
		var tl := _label(tag, Vector2(48, 9), Vector2(38, 18), 11, Color("ffd23a"), false)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_face.add_child(tl)
	# resource costs under the icon
	var parts := []
	var short_parts := []
	for t in card.res:
		parts.append("%d %s" % [card.res[t], t])
		short_parts.append("%d%s" % [card.res[t], {"stone": "st", "stick": "sk", "gold": "g"}.get(t, t.substr(0, 2))])
	if parts.size() > 0:
		var cost_text := ", ".join(parts)
		if cost_text.length() > 13:
			cost_text = " ".join(short_parts)
		_face.add_child(_label(cost_text, Vector2(10, 60), Vector2(76, 14), 10, Color("ffe08a")))
	_face.add_child(_label(card.name, Vector2(10, 81), Vector2(76, 20), 11, Color.WHITE))
	var desc_text: String = card.desc
	var desc_color := Color("c9d3f2")
	if twist != "" and Game.TWISTS.has(twist):
		desc_text = "* " + Game.TWISTS[twist][0]          # the twist's name replaces the blurb; hover for what it does
		desc_color = Color("ffd23a")
		tooltip_text = "%s\nTwist: %s - %s" % [card.desc, Game.TWISTS[twist][0], Game.TWISTS[twist][1]]
	var desc := _label(desc_text, Vector2(10, 108), Vector2(76, 40), 10, desc_color, true, true)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_face.add_child(desc)

	_back = _tex("res://ui/cards/card_back.png", Vector2.ZERO, SIZE)
	_back.visible = false
	_body.add_child(_back)

	mouse_entered.connect(func(): _hover = true; _apply())
	mouse_exited.connect(func(): _hover = false; _apply())
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_down.emit(self)

func set_state(selected: bool, affordable: bool) -> void:
	_selected = selected
	_affordable = affordable
	_apply()

func _apply() -> void:
	if _body == null:
		return
	var lift := -16.0 if _selected else (-8.0 if _hover else 0.0)
	create_tween().tween_property(_body, "position:y", lift, 0.08)
	if _selected:
		modulate = Color(1.2, 1.2, 0.85)
	elif !_affordable:
		modulate = Color(0.55, 0.55, 0.62)
	else:
		modulate = Color.WHITE

## Spin in like a token: show the back, squash to a line, swap to the face.
func flip_in(delay := 0.0) -> void:
	_back.visible = true
	_face.visible = false
	_body.scale.x = 1.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(_body, "scale:x", 0.0, 0.12)
	t.tween_callback(func():
		_back.visible = false
		_face.visible = true)
	t.tween_property(_body, "scale:x", 1.0, 0.12)

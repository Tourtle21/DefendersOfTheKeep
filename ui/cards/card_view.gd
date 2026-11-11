extends Control
class_name CardView
## One card in the hand: pixel-art frame + icon (see tools/make_card_art.gd),
## text on top. Flips in like the wave tokens, lifts on hover, and can be dragged
## (the drag itself is handled by ui/base/base_ui.gd).
const ResIcons = preload("res://ui/cards/res_icons.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")

signal pressed_down(view: CardView)
signal pressed(view: CardView)           # (the same click, under the name the other card widgets use)

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
var _ring: ReferenceRect
var _scaler: Control                      # everything is drawn at SIZE inside this, scaled to fit_size
var _sel_ring: ReferenceRect              # weapon cards show selection with a gold ring (spells lift)
var fit_size := Vector2.ZERO              # draw the card to fit this box (ZERO: its natural SIZE)
var weapon := {}                          # a weapon card: {title, icon, accent, lines, footer, footer_color, locked, glyph, tooltip}

## A weapon as a card: the same layout as a spell or building card (frame, art window, name banner, text box, tier badge top-right),
## in the weapon frame. `d` may hold title, icon (Texture2D), accent (the rarity colour, drawn as a thin line inside the frame),
## lines, footer, footer_color, locked, glyph ("?" in the art window) and tooltip; fit is the box to draw it in.
func setup_weapon(id: String, tier: int, d := {}, fit := Vector2.ZERO) -> void:
	card_id = id
	level = tier
	weapon = d
	fit_size = fit
	if d.has("tooltip"):
		tooltip_text = d.tooltip

func set_selected(on: bool) -> void:
	set_state(on, true)

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
	l.add_theme_color_override("font_outline_color", UiKit.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The weapon's icon (or a glyph for one you have not met) centred in the art window, at a whole-number pixel scale.
func _weapon_art() -> void:
	var window := Rect2(16, 12, 64, 64)                  # inside the frame's art window (a 32 px weapon icon fits at 2x), clear of the name banner
	var tex = weapon.get("icon")
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var ik := minf(window.size.x / ts.x, window.size.y / ts.y)
		ik = minf(ik, 2.0)
		if ik >= 1.0:
			ik = floorf(ik)                               # whole-number pixel scale when it fits
		var dr := (ts * ik).floor()
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = dr
		r.position = (window.position + (window.size - dr) / 2.0).floor()
		_face.add_child(r)
	elif weapon.has("glyph"):
		var g := _label(str(weapon.glyph), window.position, window.size, 36, weapon.get("accent", UiKit.ACCENT), true)
		g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_face.add_child(g)

func _tex_of(t: Texture2D, pos: Vector2, size: Vector2) -> TextureRect:
	var r := _tex("res://ui/cards/card_back.png", pos, size)          # (a TextureRect set up the usual way, then given the picture)
	r.texture = t
	return r

func _ready() -> void:
	var k := 1.0 if fit_size == Vector2.ZERO else minf(fit_size.x / SIZE.x, fit_size.y / SIZE.y)
	custom_minimum_size = SIZE * k
	size = SIZE * k
	mouse_filter = Control.MOUSE_FILTER_STOP
	var card: Dictionary
	var kind: String
	if !weapon.is_empty() or !Game.CARDS.has(card_id):
		card = {"name": str(weapon.get("title", card_id)), "mana": 0, "res": {}, "desc": "", "kind": "weapon"}
		kind = "weapon"
	else:
		card = Game.CARDS[card_id]
		kind = card.get("art", card.kind)

	_scaler = Control.new()
	_scaler.size = SIZE
	_scaler.scale = Vector2(k, k)
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scaler)
	_body = Control.new()
	_body.size = SIZE
	_body.pivot_offset = SIZE / 2.0
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_body)

	_face = Control.new()
	_face.size = SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_face)
	var design := "weapon" if kind == "weapon" else ("build" if card.kind == "build" else "spell")      # the border design by kind ...
	var rarity: int = Game.weapon_rarity(card_id) if kind == "weapon" else Game.card_rarity(card_id)  # ... and its colour by rarity
	_face.add_child(_tex("res://ui/cards/frame_%s_%d.png" % [design, rarity], Vector2.ZERO, SIZE))
	if kind == "weapon":
		_weapon_art()
	else:
		_face.add_child(_tex("res://ui/cards/icon_%s.png" % kind, Vector2(32, 26), Vector2(32, 32)))

	# mana cost badge, top-left of the art window
	if card.mana > 0:
		_face.add_child(_label(str(card.mana), Vector2(11, 9), Vector2(24, 18), 14, UiKit.SKY, false))
	# level / draft badge, top-right of the art window
	# a draft badge ("NEW", "+1 copy") also shows the tier of the offered card
	var tag := ("T%d %s" % [level, badge.replace(" copy", "")]) if badge != "" else ("T%d" % level if level > 0 else "")        # every card shows its tier, tier 1 too
	if tag != "":
		var tl := _label(tag, Vector2(48, 9), Vector2(38, 18), 11, UiKit.GOLD_BRIGHT, false)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_face.add_child(tl)
	# resource costs under the icon: an icon and an amount for each
	if !card.res.is_empty():
		var cost := ResIcons.row(card.res, 12, 11, UiKit.WARM)
		cost.position = Vector2(10, 59)
		cost.size = Vector2(76, 16)
		_face.add_child(cost)
	_face.add_child(_label(card.name, Vector2(10, 81), Vector2(76, 20), 11, UiKit.WHITE))
	var desc_text: String = card.desc
	var desc_color := UiKit.TEXT_HINT
	var adds: Array = Game.adds_for(card_id, level, twist) if kind != "weapon" else []
	adds = adds.filter(func(a): return Game.TWISTS.has(a))
	if !adds.is_empty():
		desc_text = "\n".join(adds.slice(-2).map(func(a): return "+ " + Game.TWISTS[a][0]))      # what it has added (the newest two; hover for all of them)
		desc_color = UiKit.GOLD_BRIGHT
		tooltip_text = "%s\nAdded so far:\n%s" % [card.desc, "\n".join(adds.map(func(a): return "+ %s: %s" % [Game.TWISTS[a][0], Game.TWISTS[a][1]]))]
	if kind == "weapon":
		desc_text = "\n".join(weapon.get("lines", []))
		desc_color = UiKit.TEXT_HINT
	var desc := _label(desc_text, Vector2(10, 108), Vector2(76, 26 if kind == "weapon" else 40), 10, desc_color, true, true)
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_face.add_child(desc)
	if kind == "weapon" and str(weapon.get("footer", "")) != "":                     # a state ("HELD", "STORED", a price) at the bottom of the text box
		_face.add_child(_label(str(weapon.footer), Vector2(10, 136), Vector2(76, 14), 10, weapon.get("footer_color", UiKit.WARM)))
	if kind == "weapon" and weapon.get("locked", false):
		modulate = UiKit.MUTED

	_back = _tex("res://ui/cards/card_back.png", Vector2.ZERO, SIZE)
	_back.visible = false
	_body.add_child(_back)

	_ring = ReferenceRect.new()                      # shown while the card has controller focus (menus opt in with focus_mode)
	_ring.border_color = UiKit.SKY
	_ring.border_width = 3.0
	_ring.editor_only = false
	_ring.size = SIZE
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	_body.add_child(_ring)
	_sel_ring = ReferenceRect.new()                  # weapon cards: the picked one has a gold ring
	_sel_ring.border_color = UiKit.GOLD_BRIGHT
	_sel_ring.border_width = 4.0
	_sel_ring.editor_only = false
	_sel_ring.size = SIZE
	_sel_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_ring.visible = false
	_body.add_child(_sel_ring)
	focus_entered.connect(func(): _ring.visible = true)
	focus_exited.connect(func(): _ring.visible = false)
	if !weapon.is_empty():
		_apply()                                     # a weapon card that was picked / under the cursor before it entered the tree shows it now
	mouse_entered.connect(func(): _hover = true; _apply())
	mouse_exited.connect(func(): _hover = false; _apply())
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and focus_mode == Control.FOCUS_ALL:
		pressed_down.emit(self)
		pressed.emit(self)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed_down.emit(self)
		pressed.emit(self)

func set_state(selected: bool, affordable: bool) -> void:
	_selected = selected
	_affordable = affordable
	_apply()

func _apply() -> void:
	if _body == null:
		return
	if !weapon.is_empty():                           # weapon cards: a ring when picked, a small lift on hover, no glow
		_sel_ring.visible = _selected
		create_tween().tween_property(_body, "position:y", -6.0 if _hover else 0.0, 0.08)
		return
	var lift := -16.0 if _selected else (-8.0 if _hover else 0.0)
	create_tween().tween_property(_body, "position:y", lift, 0.08)
	if _selected:
		modulate = UiKit.GLOW_HOVER
	elif !_affordable:
		modulate = UiKit.MUTED
	else:
		modulate = UiKit.WHITE

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

extends Control
## The chest card choice. ONE builder for player 1 (ui/base/draft_ui.gd), split-screen players 2-4 (ui/base/local_draft_ui.gd)
## and LAN clients (net/client_view.gd): the three cards, then your hand with x2 / x3 and a Combine button for each pair.
## Reads the options and the hand from Game (synced to LAN clients). fit(area) scales it like player 1's (area.x / 1100).

const UiKit = preload("res://ui/cards/ui_kit.gd")
const MAX_SCALE := 1.5                 # the choices at full size; a small view shrinks them only as far as it must
const HAND_SCALE := 0.53               # the hand row, relative to the choices

signal take(entry: String)             # a choice card was clicked
signal combine(i: int, j: int)         # a pair in the hand was combined

var keys := {}                         # controller labels {"take": "A", "combine": "X"}; empty = mouse
var row: HBoxContainer
var hand_row: HBoxContainer
var title: Label
var hand_title: Label
var choice_views: Array = []
var _sub: Label
var _key := ""

func _init(controller_keys := {}) -> void:
	keys = controller_keys
	mouse_filter = Control.MOUSE_FILTER_STOP if keys.is_empty() else Control.MOUSE_FILTER_IGNORE     # no clicks through to the map
	theme = UiKit.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	title = UiKit.label("Chest! Choose a card  (cards you own are upgraded)", 26, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
	title.add_theme_constant_override("outline_size", 5)
	box.add_child(title)
	_sub = UiKit.label("Left stick / d-pad move   %s take it   %s combine two of the same card" % [keys.get("take", ""), keys.get("combine", "")], UiKit.FONT_SMALL, UiKit.TEXT_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.visible = !keys.is_empty()
	box.add_child(_sub)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	hand_title = UiKit.label("", 16, UiKit.TEXT_HINT)
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hand_title)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", 14)
	box.add_child(hand_row)

func fit(area: Vector2) -> void:
	var k := clampf(area.x / 1100.0, 0.5, 1.0)
	position = Vector2.ZERO
	scale = Vector2(k, k)
	size = area / k
	_key = ""

## The scale of the three choices: as big as player 1's, unless the view is too small to hold them with the hand row under.
func card_scale() -> float:
	var n := maxi(3, Game.draft_options.size())
	var by_width: float = (size.x * 0.92 - 24.0 * (n - 1)) / (n * CardView.SIZE.x)
	var by_height: float = (size.y * 0.9 - 150.0) / (CardView.SIZE.y * (1.0 + HAND_SCALE))
	return clampf(minf(by_width, by_height), 0.6, MAX_SCALE)

## Show the current choices and hand. `cur` is a controller's cursor (-1: none).
func render(cur := -1) -> void:
	var key := str(Game.draft_options) + str(cur) + str(Game.hand) + str(size)
	if key == _key:
		return
	var first := !_key.begins_with(str(Game.draft_options))
	_key = key
	UiKit.clear(row)
	choice_views.clear()
	var cs := card_scale()
	for i in Game.draft_options.size():
		var entry: String = Game.draft_options[i]
		var id := Game.entry_id(entry)
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * cs
		var v := CardView.new()
		v.setup(id, Game.entry_tier(entry), "NEW" if Game.deck.get(id, 0) == 0 else "+1 copy", Game.entry_twist(entry))
		v.scale = Vector2(cs, cs)
		if keys.is_empty():
			v.focus_mode = Control.FOCUS_ALL
			v.pressed_down.connect(func(_v): take.emit(entry))
		else:
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(v)
		if i == cur:
			wrap.add_child(UiKit.cursor_ring(CardView.SIZE * cs))
		row.add_child(wrap)
		choice_views.append(v)
		if first:
			v.flip_in(i * 0.1)
	UiKit.clear(hand_row)
	hand_title.text = "Your cards" + ("  (two of the same card combine into the next tier)" if !Game.hand.is_empty() else "")
	var hs := cs * HAND_SCALE
	for g in Game.hand_groups():
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * hs
		var hv := CardView.new()
		hv.setup(Game.entry_id(g.entry), Game.entry_tier(g.entry), ("x%d" % g.count) if g.count > 1 else "", Game.entry_twist(g.entry))
		hv.scale = Vector2(hs, hs)
		hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(hv)
		col.add_child(wrap)
		if g.count > 1:
			var can: bool = Game.can_merge(g.i, g.j)
			var b := Button.new()
			b.text = (keys.get("combine", "") + "  " if keys.has("combine") else "") + (("Combine -> T%d" % (Game.entry_tier(g.entry) + 1)) if can else "Next tier locked")
			b.disabled = !can
			b.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
			b.tooltip_text = "" if can else "Unlock this card's next tier in the Collection to combine them."
			if keys.is_empty():
				var i: int = g.i
				var j: int = g.j
				b.pressed.connect(func(): combine.emit(i, j))
			else:
				b.focus_mode = Control.FOCUS_NONE
				b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(b)
		hand_row.add_child(col)

## The first pair in the hand that can combine now: [i, j] or [].
static func first_pair() -> Array:
	for g in Game.hand_groups():
		if g.count > 1 and Game.can_merge(g.i, g.j):
			return [g.i, g.j]
	return []

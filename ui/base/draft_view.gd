extends Control
## The chest card choice. ONE builder for player 1 (ui/base/draft_ui.gd), split-screen players 2-4 (ui/base/local_draft_ui.gd)
## and LAN clients (net/client_view.gd): one panel with the three choices, your hand (every card the same size, x2 / x3 badges,
## the ones that can combine ringed in green) and, under the hand, one "Combine" button per pair, so no button ever pushes a card.
## Reads the options and the hand from Game (synced to LAN clients). fit(area) scales it like player 1's (area.x / 1100).

const UiKit = preload("res://ui/cards/ui_kit.gd")
const MAX_SCALE := 1.5                 # the choices at full size; a small view shrinks them only as far as it must
const HAND_SCALE := 0.7                # the hand row, relative to the choices

signal take(entry: String)             # a choice card was clicked
signal combine(i: int, j: int)         # a pair in the hand was combined

var keys := {}                         # controller labels {"take": "A", "combine": "X"}; empty = mouse
var row: HBoxContainer
var hand_row: HBoxContainer
var combine_row: HFlowContainer
var deck_title: Label
var deck_row: HBoxContainer
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
	dim.color = UiKit.DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := UiKit.panel(UiKit.PANEL, UiKit.BORDER, 16.0)          # one navy panel holds the whole screen, like the Forge
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	title = UiKit.label("Chest!  Pick one card", UiKit.FONT_TITLE, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_sub = UiKit.label("A card you already own gets another copy. Left stick / d-pad move, %s take it, %s combine." % [keys.get("take", ""), keys.get("combine", "")] if !keys.is_empty() else "A card you already own gets another copy.", UiKit.FONT_SMALL, UiKit.TEXT_DIM)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size.x = 560.0
	_sub.set_meta("parity_skip", true)        # (the controls wording differs between a mouse and a controller)
	box.add_child(_sub)
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	box.add_child(HSeparator.new())
	hand_title = UiKit.label("", UiKit.FONT_AREA, UiKit.TEXT_HINT)
	hand_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hand_title)
	hand_row = HBoxContainer.new()
	hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_row.add_theme_constant_override("separation", 12)
	box.add_child(hand_row)
	deck_title = UiKit.label("", UiKit.FONT_SMALL, UiKit.TEXT_HINT)
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(deck_title)
	deck_row = HBoxContainer.new()                      # the whole deck, one card each with how many copies you hold (x2, x3 ...)
	deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_row.add_theme_constant_override("separation", 6)
	box.add_child(deck_row)
	combine_row = HFlowContainer.new()                  # the Combine buttons live here, under the hand, never between cards
	combine_row.alignment = FlowContainer.ALIGNMENT_CENTER
	combine_row.add_theme_constant_override("h_separation", 10)
	combine_row.add_theme_constant_override("v_separation", 6)
	box.add_child(combine_row)

func fit(area: Vector2) -> void:
	var k := clampf(area.x / 1100.0, 0.5, 1.0)
	position = Vector2.ZERO
	scale = Vector2(k, k)
	size = area / k
	_key = ""

## A short view drops the sentence under the title and the "Your cards" label to make room.
func _tight() -> bool:
	return size.y < 520.0

## The scale of the three choices: as big as player 1's, unless the view is too small to hold them with the hand row under.
func card_scale() -> float:
	var n := maxi(3, Game.draft_options.size())
	var by_width: float = (size.x * 0.92 - 24.0 * (n - 1)) / (n * CardView.SIZE.x)
	var overhead := 200.0 if _tight() else 330.0            # title, panel edges, the Combine row
	var by_height: float = (size.y * 0.9 - overhead) / (CardView.SIZE.y * (1.0 + HAND_SCALE))
	return clampf(minf(by_width, by_height), 0.35, MAX_SCALE)

## Show the current choices and hand. `cur` is a controller's cursor (-1: none).
func render(cur := -1) -> void:
	var key := str(Game.draft_options) + str(cur) + str(Game.hand) + str(Game.deck) + str(size)
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
	UiKit.clear(combine_row)
	UiKit.clear(deck_row)
	var ds := cs * 0.5
	var ids: Array = Game.deck.keys()
	ids.sort_custom(func(a, b): return (Game.is_build(a) as int) < (Game.is_build(b) as int) if Game.is_build(a) != Game.is_build(b) else str(a) < str(b))
	deck_title.text = "Your deck (copies you hold - more copies come up more often)" if !ids.is_empty() else ""
	deck_title.visible = !_tight() and !ids.is_empty()
	for id in ids:
		var dw := Control.new()
		dw.custom_minimum_size = CardView.SIZE * ds
		var dv := CardView.new()
		dv.setup(id, 1)
		dv.scale = Vector2(ds, ds)
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dw.add_child(dv)
		var mult := UiKit.label("x%d" % int(Game.deck[id]), UiKit.FONT_SMALL, UiKit.GOLD_BRIGHT)
		mult.position = Vector2(2, CardView.SIZE.y * ds - 20.0)
		mult.add_theme_color_override("font_outline_color", UiKit.BLACK)
		mult.add_theme_constant_override("outline_size", 4)
		dw.add_child(mult)
		deck_row.add_child(dw)
	_sub.visible = !_tight()
	var groups: Array = Game.hand_groups()
	hand_title.visible = false
	var combine_first := true
	for g in groups:
		var can: bool = g.count > 1 and Game.can_merge(g.i, g.j)
		if !can:
			continue                                                    # (a pair whose next tier is locked shows no button)
		var nxt: int = Game.entry_tier(g.entry) + 1
		var b := Button.new()
		b.text = (keys.get("combine", "") + "   " if combine_first and keys.has("combine") else "") + "Combine 2 %s  ->  Tier %d" % [Game.CARDS[Game.entry_id(g.entry)].name, nxt]
		combine_first = false
		b.add_theme_font_size_override("font_size", UiKit.FONT_SMALL)
		if keys.is_empty():
			var i: int = g.i
			var j: int = g.j
			b.pressed.connect(func(): combine.emit(i, j))
		else:
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combine_row.add_child(b)

## The first pair in the hand that can combine now: [i, j] or [].
static func first_pair() -> Array:
	for g in Game.hand_groups():
		if g.count > 1 and Game.can_merge(g.i, g.j):
			return [g.i, g.j]
	return []

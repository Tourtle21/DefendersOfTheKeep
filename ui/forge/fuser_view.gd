extends Control
## The Card Fuser screen. ONE builder for player 1 (ui/forge/card_fuse_ui.gd), split-screen players 2-4
## (ui/base/local_fuser_ui.gd) and LAN clients (net/client_view.gd): your hand, the result with its cost, the Fuse button
## and the recipes. Rules: Game.fuse_preview. fit(area) scales it like player 1's (area.x / 1100) and drops pieces to fit.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const MAX_LEVEL := 3

signal card_pressed(i: int)
signal fuse_pressed
signal back_pressed

var keys := {}                    # controller labels {"pick": "A", "fuse": "X", "back": "B"}; empty = mouse
var level := 0
var hand_box: HBoxContainer
var result_box: HBoxContainer
var info: Label
var fuse_btn: Button
var back_btn: Button
var recipes_label: RichTextLabel
var _title: Label
var _hint_panel: Control
var _margin: MarginContainer
var _outer: VBoxContainer
var _top: BoxContainer
var _right: PanelContainer
var _recipes_panel: Control
var _headings: Array = []
var _state := {}
var _key := ""

func _init(controller_keys := {}) -> void:
	keys = controller_keys
	theme = UiKit.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP if keys.is_empty() else Control.MOUSE_FILTER_IGNORE
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_outer = VBoxContainer.new()
	_outer.add_theme_constant_override("separation", 10)
	_margin.add_child(_outer)
	var bar := UiKit.panel(UiKit.BAR_BG, UiKit.BORDER, 8.0)
	_outer.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	_title = UiKit.heading("Card Fuser", UiKit.FONT_TITLE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(_title)
	back_btn = _button("back", "Back", Vector2(110, 36))
	back_btn.pressed.connect(func(): back_pressed.emit())
	bar_row.add_child(back_btn)
	_hint_panel = UiKit.panel(UiKit.HINT_BG, UiKit.HINT_EDGE, 8.0)
	_outer.add_child(_hint_panel)
	var hint := UiKit.label("Pick two different cards of the same tier." + ("   Left stick move   %s pick   %s fuse   %s close" % [keys.get("pick", ""), keys.get("fuse", ""), keys.get("back", "")] if !keys.is_empty() else ""), UiKit.FONT_BODY, UiKit.TEXT_HINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(hint)
	_top = BoxContainer.new()
	_top.add_theme_constant_override("separation", 12)
	_outer.add_child(_top)
	var left := UiKit.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	lv.add_child(_heading("1. Your hand"))
	var lift_room := Control.new()                  # (a picked card is lifted: leave room so it does not cover the heading)
	lift_room.custom_minimum_size = Vector2(0, 14)
	lv.add_child(lift_room)
	hand_box = HBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 10)
	lv.add_child(hand_box)
	_right = UiKit.panel(UiKit.RESULT_BG)
	_top.add_child(_right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	_right.add_child(rv)
	rv.add_child(_heading("2. Result"))
	result_box = HBoxContainer.new()
	rv.add_child(result_box)
	info = UiKit.label("", UiKit.FONT_BODY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(info)
	rv.add_child(_heading("3. Fuse"))
	fuse_btn = _button("fuse", "Fuse", Vector2(150, 44))
	fuse_btn.pressed.connect(func(): fuse_pressed.emit())
	rv.add_child(fuse_btn)
	_recipes_panel = UiKit.panel()
	_recipes_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(_recipes_panel)
	var bv := VBoxContainer.new()
	_recipes_panel.add_child(bv)
	bv.add_child(_heading("Recipes"))
	recipes_label = RichTextLabel.new()
	recipes_label.bbcode_enabled = true
	recipes_label.fit_content = true
	recipes_label.add_theme_font_size_override("normal_font_size", UiKit.FONT_SMALL + 1)
	var lines := []
	for key in Game.FUSE_RECIPES:
		var parts: PackedStringArray = key.split("+")
		var r: Dictionary = Game.FUSE_RECIPES[key]
		lines.append("%s + %s = [b]%s[/b]  (%s)" % [Game.CARDS[parts[0]].name, Game.CARDS[parts[1]].name, Game.CARDS[r.result].name, Game.CARDS[r.result].desc.get_slice(": ", 1)])
	recipes_label.text = "\n".join(lines)
	bv.add_child(recipes_label)
	_apply_level()

func _heading(text: String) -> Label:
	var h := UiKit.heading(text, UiKit.FONT_HEAD)
	_headings.append(h)
	return h

func _button(key: String, text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = (keys[key] + "   " + text) if keys.has(key) else text
	b.custom_minimum_size = min_size
	if !keys.is_empty():
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func fit(area: Vector2) -> void:
	var k := clampf(area.x / 1100.0, 0.5, 1.0)
	position = Vector2.ZERO
	scale = Vector2(k, k)
	size = area / k
	level = 0
	_apply_level()
	_rerender()

func _apply_level() -> void:
	_top.vertical = size.x < 700.0
	_recipes_panel.visible = level < 1
	_hint_panel.visible = level < 2
	result_box.visible = level < 3
	_right.custom_minimum_size = Vector2(430, 0) if level < 2 else Vector2(260, 0)
	info.custom_minimum_size = Vector2(400, 50) if level < 2 else Vector2(240, 36)
	for h in _headings:
		h.add_theme_font_size_override("font_size", UiKit.FONT_HEAD if level < 2 else 16)
	var m := 16 if level < 2 else 8
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, m)

## Show the fuser. state: {hand (entries), picks (hand positions), cur (controller cursor, -1 none), gold}.
func render(state: Dictionary) -> void:
	_state = state
	var hand: Array = state.hand
	var picks: Array = state.picks
	var cur: int = state.get("cur", -1)
	var key := str(hand) + str(picks) + str(cur) + str(state.get("gold", 0)) + str(level) + str(size)
	if key == _key:
		return
	_key = key
	UiKit.clear(hand_box)
	var room: float = (size.x - (480.0 if !_top.vertical else 0.0) - 80.0)
	var cs := clampf(room / maxf(1.0, hand.size() * (CardView.SIZE.x + 10.0)), 0.45, 1.0)
	for i in hand.size():
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE * cs
		var v := _card(hand[i], i in picks, cs)
		if keys.is_empty():
			var idx := i
			v.pressed_down.connect(func(_v): card_pressed.emit(idx))
		else:
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(v)
		if i == cur:
			wrap.add_child(UiKit.cursor_ring(CardView.SIZE * cs))
		hand_box.add_child(wrap)
	if hand.is_empty():
		hand_box.add_child(UiKit.label("No cards in the hand.", UiKit.FONT_SMALL, UiKit.TEXT_DIM))
	UiKit.clear(result_box)
	var p := preview()
	if p.has("result"):
		var wrap := Control.new()
		wrap.custom_minimum_size = CardView.SIZE
		wrap.add_child(_card(p.result, false, 1.0))
		result_box.add_child(wrap)
	if picks.size() < 2:
		info.text = "Pick two cards from your hand."
	elif p.ok:
		info.text = "Makes %s for %d gold.  Gold in the keep: %d" % [Game.CARDS[Game.entry_id(p.result)].name, p.cost.gold, state.get("gold", 0)]
	else:
		info.text = p.reason
	info.add_theme_color_override("font_color", UiKit.GOOD if p.ok else (UiKit.WARN if picks.size() == 2 else UiKit.TEXT))
	fuse_btn.disabled = !p.ok

func preview() -> Dictionary:
	var picks: Array = _state.get("picks", [])
	if picks.size() != 2:
		return {"ok": false, "reason": "Pick two cards."}
	return Game.fuse_preview(picks[0], picks[1], _state.hand, {"gold": _state.get("gold", 0)})

func _card(entry: String, mark: bool, cs: float) -> CardView:
	var v := CardView.new()
	v.setup(Game.entry_id(entry), Game.entry_tier(entry), "", Game.entry_twist(entry))
	v.scale = Vector2(cs, cs)
	v.ready.connect(func(): v.set_state(mark, true))
	return v

func _rerender() -> void:
	_key = ""
	if !_state.is_empty():
		render(_state)

func _process(_delta: float) -> void:
	if !is_visible_in_tree() or level >= MAX_LEVEL or size.y < 10.0:
		return
	if _outer.get_combined_minimum_size().y + 2.0 * _margin.get_theme_constant("margin_top") > size.y + 0.5:
		level += 1
		_apply_level()
		_rerender()

## Pick or unpick hand card i (at most two; a third replaces the oldest). The one picking rule for every front-end.
static func toggle(picks: Array, i: int) -> Array:
	var out := picks.duplicate()
	if i in out:
		out.erase(i)
	else:
		out.append(i)
		if out.size() > 2:
			out.pop_front()
	return out

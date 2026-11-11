extends Control
## The Forge screen. ONE builder for everyone: player 1 (ui/forge/forge_ui.gd), split-screen players 2-4
## (ui/base/local_forge_ui.gd) and LAN clients (net/client_view.gd). Each front-end only supplies the data (render())
## and reacts to the signals with its own input (mouse, focus, or a controller polled by device id).
## fit(area) scales the screen like player 1's (area.x / 1100) and drops pieces one level at a time until it fits.

const ResIcons = preload("res://ui/cards/res_icons.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")
const WeaponCard = preload("res://ui/cards/weapon_card.gd")
const ForgeLayout = preload("res://ui/forge/forge_layout.gd")
const MAX_LEVEL := 7

signal card_pressed(pos: int)              # a weapon card (position in the list)
signal recipe_pressed(a: int, b: int)      # a recipe card that can be forged from the list
signal forge_pressed
signal store_pressed                       # drop into the forge / take out
signal back_pressed

var keys := {}                    # controller labels for the buttons, e.g. {"forge": "X", "store": "Y", "back": "B"}; empty = mouse
var focusable := false            # player 1: cards and buttons take Godot focus for the d-pad
var level := 0                    # 0 = everything at full size; each level drops or shrinks a piece to fit a small view
var cards := {}                   # list position -> card
var held_title: Label
var store_title: Label
var held_box: Container
var store_box: Container
var info: Label
var cost_box: HBoxContainer
var numbers: RichTextLabel
var forge_btn: Button
var store_btn: Button
var take_btn: Button
var back_btn: Button
var recipes_box: HFlowContainer
var _hint: Label
var _bar_hint: Label
var _title: Label
var _margin: MarginContainer
var _outer: VBoxContainer
var _top: BoxContainer
var _result: PanelContainer
var _legend: Label
var _headings: Array = []         # [pick, result, forge it, recipes]
var _hint_panel: Control
var _recipes_panel: Control
var _state := {}
var _key := ""

func _init(controller_keys := {}, can_focus := false) -> void:
	keys = controller_keys
	focusable = can_focus
	theme = UiKit.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE if !keys.is_empty() else Control.MOUSE_FILTER_STOP
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
	bar_row.add_theme_constant_override("separation", 16)
	bar.add_child(bar_row)
	_title = UiKit.heading("Forge", UiKit.FONT_TITLE)
	bar_row.add_child(_title)
	var controls := "%s pick   %s forge   %s drop in / take out   %s close" % [keys.get("pick", "Click"), keys.get("forge", ""), keys.get("store", ""), keys.get("back", "")]
	_bar_hint = UiKit.label(controls, UiKit.FONT_TINY, UiKit.TEXT_HINT)        # the controls, in the title bar once the hint line is dropped
	_bar_hint.set_meta("parity_skip", true)
	bar_row.add_child(_bar_hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(spacer)
	back_btn = _button("back", "Back", Vector2(110, 36))
	back_btn.pressed.connect(func(): back_pressed.emit())
	bar_row.add_child(back_btn)
	_hint_panel = UiKit.panel(UiKit.HINT_BG, UiKit.HINT_EDGE, 8.0)
	_outer.add_child(_hint_panel)
	_hint = UiKit.label("Pick two weapons, then forge them." + ("   Left stick move   " + controls if !keys.is_empty() else ""), UiKit.FONT_BODY, UiKit.TEXT_HINT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_top = BoxContainer.new()                       # weapons on the left, the result on the right (stacked in a narrow view)
	_top.add_theme_constant_override("separation", 12)
	_outer.add_child(_top)
	var weapons := UiKit.panel()
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(weapons)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 8)
	weapons.add_child(wv)
	wv.add_child(_heading("1. Pick two weapons"))
	var areas := []
	for held in [true, false]:                     # two areas: what is in your hands, what is stored in the forge
		var area := UiKit.panel(UiKit.HELD_BG if held else UiKit.STORE_BG, UiKit.HELD_EDGE if held else UiKit.STORE_EDGE, 8.0)
		wv.add_child(area)
		var av := VBoxContainer.new()
		av.add_theme_constant_override("separation", 4)
		area.add_child(av)
		var t := UiKit.label("", UiKit.FONT_AREA, UiKit.GOOD if held else UiKit.STORE_TEXT)
		av.add_child(t)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 8)
		av.add_child(flow)
		areas.append([t, flow])
	held_title = areas[0][0]
	held_box = areas[0][1]
	store_title = areas[1][0]
	store_box = areas[1][1]
	_result = UiKit.panel(UiKit.RESULT_BG)
	_top.add_child(_result)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	_result.add_child(rv)
	rv.add_child(_heading("2. Result"))
	info = UiKit.label("", UiKit.FONT_BODY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(info)
	cost_box = HBoxContainer.new()                  # "Cost" and the resource icons with their amounts (red when the keep is short)
	cost_box.add_theme_constant_override("separation", 8)
	rv.add_child(cost_box)
	numbers = RichTextLabel.new()
	numbers.bbcode_enabled = true
	numbers.fit_content = true
	numbers.scroll_active = false
	rv.add_child(numbers)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(grow)
	rv.add_child(_heading("3. Forge it"))
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 12)
	buttons.add_theme_constant_override("v_separation", 6)
	rv.add_child(buttons)
	forge_btn = _button("forge", "Fuse", Vector2(150, 44))
	forge_btn.pressed.connect(func(): forge_pressed.emit())
	buttons.add_child(forge_btn)
	store_btn = _button("store", "Drop into forge", Vector2(160, 44))
	store_btn.tooltip_text = "Leave the weapon in the forge so you do not have to carry it. Take it out or fuse it any time."
	store_btn.pressed.connect(func(): store_pressed.emit())
	buttons.add_child(store_btn)
	take_btn = _button("store", "Take out", Vector2(130, 44))
	take_btn.pressed.connect(func(): store_pressed.emit())
	buttons.add_child(take_btn)
	_recipes_panel = UiKit.panel()
	_recipes_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer.add_child(_recipes_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	_recipes_panel.add_child(cv)
	cv.add_child(_heading("Recipes you know"))
	_legend = UiKit.label("Green: ready to forge     Yellow: need more     Grey: missing weapon", UiKit.FONT_SMALL, UiKit.TEXT_HINT)
	cv.add_child(_legend)
	recipes_box = HFlowContainer.new()
	recipes_box.add_theme_constant_override("h_separation", 8)
	recipes_box.add_theme_constant_override("v_separation", 8)
	cv.add_child(recipes_box)
	_apply_level()

func _heading(text: String) -> Label:
	var h := UiKit.heading(text, UiKit.FONT_HEAD)
	_headings.append(h)
	return h

func _button(key: String, text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.set_meta("label", text)
	b.text = (keys[key] + "   " + text) if keys.has(key) else text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	if !keys.is_empty():
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _set_text(b: Button, text: String) -> void:
	var key := "forge" if b == forge_btn else ("store" if b != back_btn else "back")
	b.text = (keys[key] + "   " + text) if keys.has(key) else text

## Size this screen to `area` (the view it is drawn in): player 1's layout scaled by area.x / 1100, then drop pieces
## (recipes, full sizes, numbers, card size, the hint line, headings) one level at a time while it overflows.
func fit(area: Vector2) -> void:
	var k := clampf(area.x / 1100.0, 0.5, 1.0)
	position = Vector2.ZERO
	scale = Vector2(k, k)
	size = area / k
	level = 0
	_apply_level()
	_rerender()

func _apply_level() -> void:
	var roomy := level < 2
	_top.vertical = size.x < 700.0
	var f := func(full: int, compact: int) -> int: return full if roomy else compact
	_title.add_theme_font_size_override("font_size", f.call(UiKit.FONT_TITLE, 24))
	for h in _headings:
		h.add_theme_font_size_override("font_size", f.call(UiKit.FONT_HEAD, 16))
	_headings[0].visible = level < 7
	_headings[1].visible = level < 7
	_headings[2].visible = level < 5
	_hint.add_theme_font_size_override("font_size", f.call(UiKit.FONT_BODY, UiKit.FONT_SMALL))
	for t in [held_title, store_title]:
		t.add_theme_font_size_override("font_size", f.call(UiKit.FONT_AREA, UiKit.FONT_CHIP))
	info.add_theme_font_size_override("font_size", f.call(UiKit.FONT_BODY, UiKit.FONT_SMALL))
	info.custom_minimum_size = Vector2(400, 60) if roomy else Vector2(230, 36)
	numbers.add_theme_font_size_override("normal_font_size", f.call(14, 12))
	numbers.add_theme_font_size_override("bold_font_size", f.call(14, 12))
	_result.custom_minimum_size = Vector2(430, 0) if roomy else Vector2(250, 0)
	for b in [forge_btn, store_btn, take_btn]:
		b.custom_minimum_size.y = 44 if roomy else 34
	_recipes_panel.visible = level < 1
	numbers.visible = level < 3
	_hint_panel.visible = level < 5
	_bar_hint.visible = level >= 5 and !keys.is_empty()
	var m := 16 if roomy else (10 if level < 5 else 6)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, m)
	_outer.add_theme_constant_override("separation", 10 if roomy else 8)

func _card_size() -> Vector2:
	return [Vector2(100, 140), Vector2(100, 140), Vector2(78, 108), Vector2(62, 86), Vector2(52, 72), Vector2(52, 72), Vector2(44, 60), Vector2(38, 52)][level]

## Show the forge. state: {list (ForgeLayout.items), picks (positions), cur (controller cursor, -1 for none),
## store_full (the forge holds FORGE_STORE_MAX), hands_full (three weapons held)}.
func render(state: Dictionary) -> void:
	_state = state
	var key := str(state.list.map(func(it): return it.entry)) + str(state.picks) + str(state.get("cur", -1)) + str(Game.resources) + str(state.get("store_full", false)) + str(state.get("hands_full", false)) + str(level)
	if key == _key:
		return
	_key = key
	var list: Array = state.list
	var picks: Array = state.picks
	var cur: int = state.get("cur", -1)
	_fill_areas(list, picks, cur)
	var p := ForgeLayout.preview(list, picks)
	info.text = p.text
	info.add_theme_color_override("font_color", UiKit.GOOD if p.ok else (UiKit.WARN if picks.size() == 2 else UiKit.TEXT))
	UiKit.clear(cost_box)
	if p.has("cost"):
		cost_box.add_child(UiKit.label("Cost", UiKit.FONT_SMALL, UiKit.TEXT_DIM))
		cost_box.add_child(ResIcons.row(p.cost, 18, UiKit.FONT_BODY, UiKit.TEXT, Game.resources))
	numbers.text = ""
	var combine: bool = picks.size() == 2 and p.kind == "combine" and p.result != ""
	if combine:
		numbers.text = ForgeLayout.numbers_text(Game.weapon_info(list[picks[0]].entry), Game.weapon_bonus(list[picks[0]].entry))
	_set_text(forge_btn, ("Combine into tier %d" % (Game.weapon_tier_of(list[picks[0]].entry) + 1)) if combine else "Fuse")
	forge_btn.disabled = !(p.ok and picks.size() == 2)
	var target := store_target()
	var on_held: bool = target >= 0 and list[target].src == "held"
	store_btn.disabled = !(on_held and !state.get("store_full", false))
	take_btn.disabled = !(target >= 0 and !on_held and !state.get("hands_full", false))
	if _recipes_panel.visible:
		_fill_recipes(list)

## The weapon "Drop into forge" / "Take out" acts on: the controller's cursor, else the one picked weapon. -1 if none.
func store_target() -> int:
	var list: Array = _state.get("list", [])
	var cur: int = _state.get("cur", -1)
	if cur >= 0 and cur < list.size():
		return cur
	var picks: Array = _state.get("picks", [])
	return picks[0] if picks.size() == 1 and picks[0] < list.size() else -1

func _rerender() -> void:
	_key = ""
	if !_state.is_empty():
		render(_state)

## One area of the screen per source: its weapons grouped by type, common first, a card per copy.
func _fill_areas(list: Array, picks: Array, cur: int) -> void:
	var focused := -1                               # keep the d-pad's place when the cards rebuild
	if focusable and is_inside_tree():
		for n in cards:
			if is_instance_valid(cards[n]) and cards[n].has_focus():
				focused = n
	cards.clear()
	var held_n := 0
	for it in list:
		if it.src == "held":
			held_n += 1
	held_title.text = "IN YOUR HANDS  %d / 3" % held_n
	store_title.text = "IN THE FORGE  %d / %d  -  stays here for the whole team" % [list.size() - held_n, Game.FORGE_STORE_MAX]
	var small := level >= 2
	for held in [true, false]:
		var box: Container = held_box if held else store_box
		UiKit.clear(box)
		var group: HBoxContainer = null
		var last_id := ""
		for n in list.size():
			var it: Dictionary = list[n]
			if (it.src == "held") != held:
				continue
			if it.id != last_id:
				last_id = it.id
				var copies := 0
				for o in list:
					if o.id == it.id and o.src == it.src:
						copies += 1
				var col := VBoxContainer.new()
				col.add_theme_constant_override("separation", 4)
				col.add_child(UiKit.label("%s  x%d" % [Fusion.display_name(it.id), copies], UiKit.FONT_CHIP if small else UiKit.FONT_BODY, Game.rarity_color(Game.weapon_rarity(it.id))))
				group = HBoxContainer.new()
				group.add_theme_constant_override("separation", 4 if small else 6)
				col.add_child(group)
				box.add_child(col)
			var tw: String = Game.entry_twist(it.entry)
			var card = WeaponCard.make(it.id, Game.weapon_tier_of(it.entry), _card_size(), {"title": "T%d" % Game.weapon_tier_of(it.entry),
				"lines": ["* " + Game.TWISTS[tw][0]] if tw != "" and Game.TWISTS.has(tw) and !small else [],
				"footer": "PICKED" if n in picks else ("HELD" if held else "STORED"), "footer_color": UiKit.GOOD if held else UiKit.STORE_TEXT})
			card.set_selected(n == cur or n in picks)
			card.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
			if keys.is_empty():
				var pos := n
				card.pressed.connect(func(_c): card_pressed.emit(pos))
			else:
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cards[n] = card
			group.add_child(card)
		if box.get_child_count() == 0:
			box.add_child(UiKit.label("Nothing in your hands." if held else "Nothing stored. Pick a weapon and drop it into the forge.", UiKit.FONT_SMALL, UiKit.TEXT_DIM))
	if focused >= 0 and !cards.is_empty():
		cards[mini(focused, cards.size() - 1)].grab_focus.call_deferred()

## The recipe cards (two ingredients, an arrow, the result). Green: ready, yellow: need more, grey: missing a weapon.
func _fill_recipes(list: Array) -> void:
	UiKit.clear(recipes_box)
	for r in ForgeLayout.recipes(list):
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(330, 100)
		rb.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
		rb.modulate = UiKit.RECIPE_TINTS[r.state]
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_chip(r.a))
		h.add_child(UiKit.label("+"))
		h.add_child(_chip(r.b))
		h.add_child(UiKit.label("->"))
		h.add_child(_chip(r.c))
		rb.add_child(h)
		if r.pick.is_empty():
			rb.disabled = true
		elif keys.is_empty():
			var ab: Array = r.pick
			rb.pressed.connect(func(): recipe_pressed.emit(ab[0], ab[1]))
		recipes_box.add_child(rb)

func _chip(c: Array) -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tr := TextureRect.new()
	tr.texture = WeaponCard.icon(c[0])
	tr.custom_minimum_size = Vector2(48, 48)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tr)
	var l := UiKit.label("%s\n%s" % [Fusion.display_name(c[0]), c[1]], UiKit.FONT_CHIP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	return v

## While shown, drop a level whenever the screen is taller than its view (containers settle a frame after a rebuild).
func _process(_delta: float) -> void:
	if !is_visible_in_tree() or level >= MAX_LEVEL or size.y < 10.0:
		return
	if _outer.get_combined_minimum_size().y + 2.0 * _margin.get_theme_constant("margin_top") > size.y + 0.5:
		level += 1
		_apply_level()
		_rerender()

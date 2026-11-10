extends CanvasLayer
## The forge for a local split-screen player (players 2 to 4). Stand at the anvil and press d-pad up. It shows the
## weapons you hold and the ones stored in the forge, grouped by type. Left stick / d-pad move, A picks a weapon (two of them),
## X forges (two different weapons fuse, two copies of the same one combine into the next tier), Y drops the weapon
## under the cursor into the forge or takes it out, B closes. Away from the forge, d-pad down merges two weapons in hand. Costs and unlocked tiers are the normal forge's.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const ForgeLayout = preload("res://ui/forge/forge_layout.gd")

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var _prev := {}
var _root: Control
var _row: VBoxContainer
var _info: Label
var _numbers: RichTextLabel
var _hint: Label
var _fuse_btn: Label
var _store_btn: Label
var _recipes_panel: Control
var _hint_panel: Control
var _bar_hint: Label
var _forge_heading: Label
var _margin: MarginContainer
var _outer: Control
var _top: BoxContainer
var _take_btn: Label
var _pick_heading: Label
var _result_heading: Label
var _level := 0          # how much has been dropped to make the screen fit this view (0 = everything)
var _recipes: HFlowContainer
var _card_size := Vector2(78, 108)
var _recipe_size := Vector2(270, 84)
var _recipe_icon := 36.0
var _recipe_font := 11
var _key := ""

func _action_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_stylebox_override("normal", UiKit.style(Color(0.14, 0.14, 0.22), Color(0.4, 0.34, 0.2), 6.0))
	l.custom_minimum_size = Vector2(0, 34)
	return l

## The same screen as player 1's Forge (ui/forge/forge_ui.gd), laid out to fit this player's view: the weapons in your hands and
## in the forge, the result with its cost and numbers, the buttons, and the recipes you know.
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
	var backdrop := ColorRect.new()
	backdrop.color = UiKit.BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outer = outer
	margin.add_child(outer)
	var bar := UiKit.panel(Color(0.12, 0.10, 0.06), UiKit.BORDER, 6.0)
	outer.add_child(bar)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 14)
	bar.add_child(bar_row)
	bar_row.add_child(UiKit.heading("Forge", 24))
	_bar_hint = Label.new()                          # the controls, in the title bar when the view is too short for the hint line
	_bar_hint.text = "A pick   X forge   Y drop in / take out   B close"
	_bar_hint.add_theme_font_size_override("font_size", 11)
	_bar_hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_bar_hint.visible = false
	bar_row.add_child(_bar_hint)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(spacer)
	var back := _action_label("B   Back")
	back.add_theme_font_size_override("font_size", 13)
	bar_row.add_child(back)
	var hint_panel := UiKit.panel(Color(0.07, 0.10, 0.16), Color(0.3, 0.5, 0.7), 6.0)
	_hint_panel = hint_panel
	outer.add_child(hint_panel)
	_hint = Label.new()
	_hint.text = "Pick two weapons, then forge them.   Left stick move   A pick   X forge   Y drop in / take out   B close"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	hint_panel.add_child(_hint)
	_top = BoxContainer.new()                       # weapons on the left, the result on the right (stacked in a narrow view)
	_top.add_theme_constant_override("separation", 10)
	outer.add_child(_top)
	var weapons := UiKit.panel(UiKit.PANEL, UiKit.BORDER, 8.0)
	weapons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(weapons)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 4)
	weapons.add_child(wv)
	_pick_heading = UiKit.heading("1. Pick two weapons", 16)
	wv.add_child(_pick_heading)
	_row = VBoxContainer.new()                      # two areas stacked: what is in your hands, what is stored in the forge
	_row.add_theme_constant_override("separation", 6)
	wv.add_child(_row)
	var result := UiKit.panel(Color(0.08, 0.08, 0.14), UiKit.BORDER, 8.0)
	result.custom_minimum_size = Vector2(250, 0)
	_top.add_child(result)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	result.add_child(rv)
	_result_heading = UiKit.heading("2. Result", 16)
	rv.add_child(_result_heading)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(300, 36)
	_info.add_theme_font_size_override("font_size", 13)
	rv.add_child(_info)
	_numbers = RichTextLabel.new()
	_numbers.bbcode_enabled = true
	_numbers.fit_content = true
	_numbers.scroll_active = false
	_numbers.add_theme_font_size_override("normal_font_size", 12)
	_numbers.add_theme_font_size_override("bold_font_size", 12)
	rv.add_child(_numbers)
	_forge_heading = UiKit.heading("3. Forge it", 16)
	rv.add_child(_forge_heading)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	rv.add_child(buttons)
	_fuse_btn = _action_label("X   Fuse")
	buttons.add_child(_fuse_btn)
	_store_btn = _action_label("Y   Drop into forge")
	buttons.add_child(_store_btn)
	_take_btn = _action_label("Y   Take out")
	buttons.add_child(_take_btn)
	var rec := UiKit.panel(UiKit.PANEL, UiKit.BORDER, 8.0)
	rec.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(rec)
	_recipes_panel = rec
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	rec.add_child(cv)
	cv.add_child(UiKit.heading("Recipes you know", 16))
	var legend := Label.new()
	legend.text = "Green: ready to forge     Yellow: need more     Grey: missing weapon"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	cv.add_child(legend)
	_recipes = HFlowContainer.new()
	_recipes.add_theme_constant_override("h_separation", 6)
	_recipes.add_theme_constant_override("v_separation", 6)
	cv.add_child(_recipes)
	fit(Vector2(viewport.size))

## Fit to this player's view: start with everything, and let _check_fit drop pieces (recipes, numbers, hint line, card size)
## one step at a time until the screen no longer overflows.
func fit(area: Vector2) -> void:
	var k := clampf(area.x / 1100.0, 0.5, 1.0)        # player 1's screen is drawn at this scale in a split view; this one matches it
	_root.scale = Vector2(k, k)
	_root.size = area / k
	_level = 0
	_apply_level()

func _apply_level() -> void:
	var area := _root.size
	_top.vertical = area.x < 700.0
	var roomy: bool = _level == 0                      # level 0 is player 1's own sizes (the scale in fit() shrinks them to the view)
	_card_size = Vector2(100, 140) if roomy else Vector2(78, 108)
	if _level >= 2:
		_card_size = Vector2(62, 86)
	if _level >= 3:
		_card_size = Vector2(52, 72)
	if _level >= 5:
		_card_size = Vector2(44, 60)
	if _level >= 6:
		_card_size = Vector2(38, 52)
	_pick_heading.visible = _level < 6
	_result_heading.visible = _level < 6
	_recipe_size = Vector2(330, 100) if roomy else Vector2(270, 84)
	_recipe_icon = 48.0 if roomy else 36.0
	_recipe_font = 12 if roomy else 11
	_recipes_panel.visible = _level < 1
	_numbers.visible = _level < 2
	_hint_panel.visible = _level < 4
	_bar_hint.visible = _level >= 4
	_forge_heading.visible = _level < 4
	var m := 6 if _level >= 4 else 10
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, m)
	_key = ""

func _check_fit() -> void:
	if !is_open or _level >= 6:
		return
	if _outer.get_combined_minimum_size().y + 20.0 > _root.size.y:
		_level += 1
		_apply_level()
		_refresh()

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

func open() -> void:
	if pl.is_in_tower or pl.downed:
		return
	is_open = true
	cur = 0
	picks.clear()
	_root.visible = true
	_prev["a"] = true            # the press that is held now must not also pick a weapon
	_key = ""
	_refresh()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var up := _edge("up", Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP))
	var stick_x: float = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)             # menus move with the left stick or the d-pad (the right stick aims, LB / RB are for the hand's cards)
	var lb := _edge("lb", stick_x < -0.6 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT))
	var rb := _edge("rb", stick_x > 0.6 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT))
	var a := _edge("a", Input.is_joy_button_pressed(dev, JOY_BUTTON_A))
	var b := _edge("b", Input.is_joy_button_pressed(dev, JOY_BUTTON_B))
	var x := _edge("x", Input.is_joy_button_pressed(dev, JOY_BUTTON_X))
	var y := _edge("y", Input.is_joy_button_pressed(dev, JOY_BUTTON_Y))
	if !is_open:
		if up and _near_forge() and !pl.is_in_tower and !pl.downed:
			open()
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
	var key := str(items.map(func(it): return it.entry)) + str(cur) + str(picks) + str(Game.resources) + str(Game._forge_store.size())
	if key == _key:
		return
	_key = key
	ForgeLayout.build(_row, items, picks, cur, _card_size)
	var p := preview()
	_info.text = p.text
	_info.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if p.ok else (Color(1, 0.8, 0.5) if picks.size() == 2 else Color(0.85, 0.88, 1.0)))
	_numbers.text = ""
	if picks.size() == 2 and p.kind == "combine" and p.result != "":
		_numbers.text = ForgeLayout.numbers_text(Game.weapon_info(items[picks[0]].entry), Game.weapon_bonus(items[picks[0]].entry))
	_fuse_btn.text = ("X   Combine into tier %d" % (Game.weapon_tier_of(items[picks[0]].entry) + 1)) if p.kind == "combine" and p.result != "" and picks.size() == 2 else "X   Fuse"
	_fuse_btn.modulate = Color.WHITE if p.ok and picks.size() == 2 else Color(1, 1, 1, 0.45)
	var on_held: bool = cur < items.size() and items[cur].src == "held"
	var can_store: bool = cur < items.size() and ((on_held and Game._forge_store.size() < Game.FORGE_STORE_MAX) or (!on_held and _slots().size() < 3))
	_store_btn.modulate = Color.WHITE if can_store and on_held else Color(1, 1, 1, 0.45)
	_take_btn.modulate = Color.WHITE if can_store and !on_held else Color(1, 1, 1, 0.45)
	if _recipes_panel.visible:
		ForgeLayout.recipes(_recipes, items, _recipe_size, _recipe_icon, _recipe_font)
	_check_fit.call_deferred()

extends RefCounted
## Shared look for the menu screens: bordered panels, a title bar, section headings and a helper that sizes a
## grid of cards so they all fit on screen without scrolling.

const BG := Color(0.05, 0.05, 0.10, 0.98)
const PANEL := Color(0.09, 0.09, 0.16)
const BORDER := Color(0.55, 0.45, 0.2)
const GOLD := Color(1.0, 0.85, 0.35)

static func style(bg := PANEL, border := BORDER, margin := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(margin)
	return s

static func panel(bg := PANEL, border := BORDER, margin := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border, margin))
	return p

## One theme for every menu: dark buttons with a gold edge on hover and focus, so plain buttons match the cards.
static func make_theme() -> Theme:
	var t := Theme.new()
	var states := {"normal": [Color(0.14, 0.14, 0.22), Color(0.4, 0.34, 0.2)], "hover": [Color(0.2, 0.19, 0.3), GOLD],
		"pressed": [Color(0.3, 0.26, 0.12), GOLD], "disabled": [Color(0.1, 0.1, 0.14), Color(0.25, 0.25, 0.3)], "focus": [Color(0, 0, 0, 0), GOLD]}
	for k in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[k][0]
		sb.border_color = states[k][1]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		t.set_stylebox(k, "Button", sb)
	t.set_color("font_color", "Button", Color(0.92, 0.92, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.58))
	return t

static func heading(text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l

## A full-screen shell: dark backdrop, title bar (title, optional right-hand text, Back button) and an empty body area.
## Returns {"root": Control, "body": VBoxContainer, "right": Label}.
const TABS := [["cards", "Cards"], ["weapons", "Weapons"], ["draws", "Drawn"], ["skills", "Skills"]]

## Jump from one tab screen (Cards / Weapons / Drawn) to another without going back to the menu.
static func switch_tab(from_root: Control, to_id: String) -> void:
	for n in from_root.get_tree().get_nodes_in_group("tab_screen"):
		if n.get("tab_id") == to_id:
			from_root.visible = false
			n.open()
			return

static func screen(parent: Node, title: String, on_back: Callable, hint := "", tab_id := "") -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	root.theme = make_theme()
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	root.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	var bar := panel(Color(0.12, 0.10, 0.06), BORDER, 8.0)
	outer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var t := heading(title, 28)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var right := Label.new()
	right.add_theme_font_size_override("font_size", 20)
	right.add_theme_color_override("font_color", Color("8fd8ff"))
	row.add_child(right)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(110, 36)
	back.pressed.connect(on_back)
	row.add_child(back)
	if hint != "":                  # plain words: what this screen is for and what to do next
		var hp := panel(Color(0.07, 0.10, 0.16), Color(0.3, 0.5, 0.7), 8.0)
		outer.add_child(hp)
		var hl := Label.new()
		hl.text = hint
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.add_theme_font_size_override("font_size", 15)
		hl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		hp.add_child(hl)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	if tab_id != "":                      # tab bar along the bottom: Cards | Weapons | Drawn | Skills, the current one highlighted
		var tabs_bar := panel(Color(0.12, 0.10, 0.06), BORDER, 8.0)
		outer.add_child(tabs_bar)
		var trow := HBoxContainer.new()
		trow.alignment = BoxContainer.ALIGNMENT_CENTER
		trow.add_theme_constant_override("separation", 14)
		tabs_bar.add_child(trow)
		for tb in TABS:
			var b := Button.new()
			b.text = tb[1]
			b.custom_minimum_size = Vector2(150, 40)
			if tb[0] == tab_id:
				var cur := style(Color(0.45, 0.36, 0.12), GOLD, 6.0)
				for st in ["normal", "hover", "pressed", "disabled", "focus"]:
					b.add_theme_stylebox_override(st, cur)
				b.add_theme_color_override("font_color", Color.WHITE)
				b.add_theme_color_override("font_hover_color", Color.WHITE)
				b.add_theme_color_override("font_pressed_color", Color.WHITE)
				b.focus_mode = Control.FOCUS_NONE
			else:
				var id: String = tb[0]
				b.pressed.connect(func(): switch_tab(root, id))
			trow.add_child(b)
	return {"root": root, "body": body, "right": right}

## Biggest card size (keeping `aspect` = width / height) that fits n cards in `area`. Returns {"cols", "size"}.
static func fit_cards(n: int, area: Vector2, aspect := 0.72, gap := 8.0, max_w := 150.0) -> Dictionary:
	var best := {"cols": 1, "size": Vector2(60, 60 / aspect)}
	var best_w := 0.0
	for cols in range(1, n + 1):
		var rows := ceili(float(n) / cols)
		var w := minf((area.x - gap * (cols - 1)) / cols, ((area.y - gap * (rows - 1)) / rows) * aspect)
		w = minf(w, max_w)
		if w >= best_w:                      # on a tie (cards at their size cap) prefer more columns: fewer rows
			best_w = w
			best = {"cols": cols, "size": Vector2(w, w / aspect).floor()}
	return best

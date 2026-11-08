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

static func heading(text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l

## A full-screen shell: dark backdrop, title bar (title, optional right-hand text, Back button) and an empty body area.
## Returns {"root": Control, "body": VBoxContainer, "right": Label}.
static func screen(parent: Node, title: String, on_back: Callable, hint := "") -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
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
	return {"root": root, "body": body, "right": right}

## Biggest card size (keeping `aspect` = width / height) that fits n cards in `area`. Returns {"cols", "size"}.
static func fit_cards(n: int, area: Vector2, aspect := 0.72, gap := 8.0, max_w := 150.0) -> Dictionary:
	var best := {"cols": 1, "size": Vector2(60, 60 / aspect)}
	var best_w := 0.0
	for cols in range(1, n + 1):
		var rows := ceili(float(n) / cols)
		var w := minf((area.x - gap * (cols - 1)) / cols, ((area.y - gap * (rows - 1)) / rows) * aspect)
		w = minf(w, max_w)
		if w > best_w:
			best_w = w
			best = {"cols": cols, "size": Vector2(w, w / aspect).floor()}
	return best

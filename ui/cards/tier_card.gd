extends Control
## A drawn fantasy card for anything with tiers or levels: weapons, skills, upgrades, recipes.
## Ornate double border in an accent colour, a title banner, an art window, a few lines of text and a
## row of tier gems (filled = owned, outlined = the next one). It scales to whatever size it is given,
## so a whole screen of them fits without scrolling.
##   var c := preload("res://ui/cards/tier_card.gd").new(); c.setup({"title": "Hammer", "icon": tex, "tier": 2, "max_tier": 6,
##       "lines": ["Left click: Smash"], "footer": "16 shards", "accent": Color(...), "locked": false})
## `pressed` fires on a left click; `set_selected` draws the gold selection frame.

signal pressed(card)

var data := {}
var selected := false
var _hover := false
var _pulse := 0.0
var _pulse_tw: Tween

func setup(d: Dictionary):
	data = d
	custom_minimum_size = d.get("size", Vector2(120, 168))
	size = custom_minimum_size
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL          # controller / keyboard: move with the d-pad, confirm with A / Enter
	if d.has("tooltip"):
		tooltip_text = d.tooltip
	if d.get("blink", false):
		_start_blink()
	queue_redraw()
	return self

## A pulsing gold glow: this card can be upgraded right now.
func _start_blink() -> void:
	if _pulse_tw != null or !is_inside_tree():
		return
	_pulse_tw = create_tween().set_loops()
	_pulse_tw.tween_method(func(v): _pulse = v; queue_redraw(), 0.0, 1.0, 0.6)
	_pulse_tw.tween_method(func(v): _pulse = v; queue_redraw(), 1.0, 0.0, 0.6)

func set_selected(on: bool) -> void:
	selected = on
	queue_redraw()

func _ready() -> void:
	if data.get("blink", false):
		_start_blink()
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
		elif ev.is_action_pressed("ui_accept"):
			pressed.emit(self))

func _gem(center: Vector2, r: float, fill: Color, outline: Color, filled: bool) -> void:
	var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.8, 0), center + Vector2(0, r), center + Vector2(-r * 0.8, 0)])
	if filled:
		draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, outline, 1.5)

func _draw() -> void:
	if data.is_empty():
		return
	var w := size.x
	var h := size.y
	var accent: Color = data.get("accent", Color(0.85, 0.7, 0.3))
	var locked: bool = data.get("locked", false)
	var dim := 0.45 if locked else 1.0
	var font := ThemeDB.fallback_font
	var u := minf(w / 120.0, h / 168.0)          # everything scales with the card
	# body
	draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.07, 0.12))
	draw_rect(Rect2(2, 2, w - 4, h - 4), Color(0.12, 0.12, 0.2).darkened(0.0 if !locked else 0.3))
	var top_glow := Color(accent, 0.18 * dim)
	draw_rect(Rect2(2, 2, w - 4, h * 0.5), top_glow)
	# ornate border: outer accent, inner dark gold, corner diamonds
	var bc := Color(accent.r, accent.g, accent.b, dim)
	draw_rect(Rect2(1, 1, w - 2, h - 2), bc, false, 2.0 * maxf(u, 0.7))
	draw_rect(Rect2(5 * u, 5 * u, w - 10 * u, h - 10 * u), Color(0.75, 0.6, 0.25, 0.7 * dim), false, 1.0)
	for c in [Vector2(5, 5), Vector2(w - 5, 5), Vector2(5, h - 5), Vector2(w - 5, h - 5)]:
		_gem(c, 4.5 * u, bc, Color(1, 0.9, 0.5, dim), true)
	# title banner
	var th := 20.0 * u
	draw_rect(Rect2(8 * u, 8 * u, w - 16 * u, th), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(8 * u, 8 * u, w - 16 * u, th), Color(accent, 0.8 * dim), false, 1.0)
	var title: String = str(data.get("title", ""))
	var fs := int(clampf(12.0 * u, 8.0, 18.0))
	draw_string(font, Vector2(10 * u, 8 * u + th * 0.72), title, HORIZONTAL_ALIGNMENT_CENTER, w - 20 * u, fs, Color(1, 1, 1, dim))
	# art window
	var ay := 8 * u + th + 5 * u
	var ah := h * 0.34
	var aw := w - 24 * u
	var art := Rect2(12 * u, ay, aw, ah)
	draw_rect(art, Color(0.02, 0.02, 0.05, 0.85))
	draw_rect(art, Color(accent, 0.5 * dim), false, 1.0)
	var tex = data.get("icon")
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var k := minf((art.size.x - 6) / ts.x, (art.size.y - 6) / ts.y)
		k = maxf(1.0, floorf(k)) if k >= 1.0 else k          # whole-number pixel scale when it fits
		var dr := Vector2(ts.x * k, ts.y * k)
		draw_texture_rect(tex, Rect2(art.position + (art.size - dr) / 2.0, dr), false, Color(1, 1, 1, dim))
	elif data.has("glyph"):
		draw_string(font, art.position + Vector2(0, art.size.y * 0.68), str(data.glyph), HORIZONTAL_ALIGNMENT_CENTER, art.size.x, maxi(8, int(minf(art.size.y * 0.6, art.size.x / (maxf(1.0, float(str(data.glyph).length())) * 0.62)))), Color(accent, dim))
	# corner badge (cost, mana, "NEW")
	var badge: String = str(data.get("badge", ""))
	if badge != "":
		draw_string(font, Vector2(art.position.x + 3, art.position.y + 13 * u), badge, HORIZONTAL_ALIGNMENT_LEFT, art.size.x - 6, int(clampf(10.0 * u, 8.0, 14.0)), Color(0.55, 0.8, 1.0, dim))
	var tier: int = int(data.get("tier", 0))
	var max_tier: int = int(data.get("max_tier", 0))
	if tier > 0:
		draw_string(font, Vector2(art.position.x, art.position.y + 13 * u), "T%d" % tier, HORIZONTAL_ALIGNMENT_RIGHT, art.size.x - 4, int(clampf(11.0 * u, 8.0, 15.0)), Color(1, 0.85, 0.25, dim))
	# text lines
	var ty := ay + ah + 4 * u
	var lines: Array = data.get("lines", [])
	var lfs := int(clampf(9.5 * u, 7.0, 13.0))
	var pip_h := 16.0 * u if max_tier > 0 else 0.0
	var foot: String = str(data.get("footer", ""))
	var foot_h := 13.0 * u if foot != "" else 0.0
	var room := h - ty - pip_h - foot_h - 9 * u
	for l in lines:
		if room < lfs:
			break
		var col := Color(0.8, 0.85, 1.0, dim)
		var txt := str(l)
		if font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, w - 18 * u, lfs, 2).y > room:
			break
		if txt.begins_with("+"):
			col = Color(0.45, 0.95, 0.55, dim)
		var lw := w - 18 * u
		var sz := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2)
		draw_multiline_string(font, Vector2(9 * u, ty + lfs), txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2, col)
		ty += sz.y + 2 * u
		room -= sz.y + 2 * u
	# footer (price / state)
	if foot != "":
		var fc: Color = data.get("footer_color", Color(1, 0.88, 0.5))
		draw_string(font, Vector2(8 * u, h - 8 * u - pip_h - 2 * u), foot, HORIZONTAL_ALIGNMENT_CENTER, w - 16 * u, int(clampf(10.0 * u, 7.0, 13.0)), Color(fc, dim))
	# tier gems
	if max_tier > 0:
		var gr := minf(5.0 * u, (w - 24 * u) / (max_tier * 2.4))
		var total := max_tier * gr * 2.2
		var gx := (w - total) / 2.0 + gr * 1.1
		var gy := h - 9 * u - gr * 1.2
		for i in max_tier:
			var owned := i < tier
			var nxt := i == tier
			var gc := Color(accent.lightened(0.2), dim) if owned else Color(0.25, 0.25, 0.32)
			var oc := Color(1, 0.9, 0.4) if nxt and !locked else (Color(accent, dim) if owned else Color(0.4, 0.4, 0.5))
			_gem(Vector2(gx + i * gr * 2.2, gy), gr, gc, oc, owned)
	if locked:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.25))
	if data.get("lock", false):                        # a padlock over the art window
		var c := art.get_center() + Vector2(0, art.size.y * 0.08)
		var k := minf(art.size.x, art.size.y) * 0.22
		draw_arc(c + Vector2(0, -k * 0.55), k * 0.62, PI, TAU, 14, Color(0.85, 0.85, 0.9), maxf(2.0, k * 0.28))
		draw_rect(Rect2(c + Vector2(-k, -k * 0.55), Vector2(k * 2.0, k * 1.5)), Color(0.85, 0.7, 0.3))
		draw_rect(Rect2(c + Vector2(-k * 0.14, -k * 0.05), Vector2(k * 0.28, k * 0.5)), Color(0.15, 0.12, 0.05))
	if _hover:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.07))
	if data.get("blink", false):
		draw_rect(Rect2(0, 0, w, h), Color(1, 0.85, 0.25, 0.28 * _pulse))
		draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(1, 0.85, 0.25, 0.4 + 0.6 * _pulse), false, 3.0)
	if has_focus():
		draw_rect(Rect2(-3, -3, w + 6, h + 6), Color(0.5, 0.85, 1.0), false, 3.0)
	if selected:
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(1, 0.85, 0.25), false, 3.0)

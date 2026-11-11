extends Control
## A drawn fantasy card for anything with tiers or levels: weapons, skills, upgrades, recipes.
## Ornate double border in an accent colour, a title banner, an art window, a few lines of text and a
## row of tier gems (filled = owned, outlined = the next one). It scales to whatever size it is given,
## so a whole screen of them fits without scrolling.
##   var c := preload("res://ui/cards/tier_card.gd").new(); c.setup({"title": "Hammer", "icon": tex, "tier": 2, "max_tier": 6,
##       "lines": ["Left click: Smash"], "footer": "16 shards", "accent": Color(...), "locked": false})
## `pressed` fires on a left click; `set_selected` draws the gold selection frame.
const ResIcons = preload("res://ui/cards/res_icons.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")

signal pressed(card)

var data := {}
var selected := false
var _hover := false
var _pulse := 0.0
var _pulse_tw: Tween
var _frame_tex: Texture2D           # the card-style frame picture, loaded once in setup

func setup(d: Dictionary):
	data = d
	_frame_tex = load(str(d.frame)) if d.has("frame") else null
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
	if data.has("frame"):
		_draw_card_face()
		return
	var w := size.x
	var h := size.y
	var accent: Color = data.get("accent", UiKit.ACCENT)
	var locked: bool = data.get("locked", false)
	var dim := 0.45 if locked else 1.0
	var font := ThemeDB.fallback_font
	var u := minf(w / 120.0, h / 168.0)          # everything scales with the card
	# body
	draw_rect(Rect2(0, 0, w, h), UiKit.PANEL_DEEP)
	draw_rect(Rect2(2, 2, w - 4, h - 4), UiKit.PANEL.darkened(0.0 if !locked else 0.3))
	var top_glow := Color(accent, 0.18 * dim)
	draw_rect(Rect2(2, 2, w - 4, h * 0.5), top_glow)
	# ornate border: outer accent, inner dark gold, corner diamonds
	var bc := Color(accent.r, accent.g, accent.b, dim)
	draw_rect(Rect2(1, 1, w - 2, h - 2), bc, false, 2.0 * maxf(u, 0.7))
	draw_rect(Rect2(5 * u, 5 * u, w - 10 * u, h - 10 * u), Color(UiKit.ACCENT, 0.7 * dim), false, 1.0)
	for c in [Vector2(5, 5), Vector2(w - 5, 5), Vector2(5, h - 5), Vector2(w - 5, h - 5)]:
		_gem(c, 4.5 * u, bc, Color(UiKit.WARM, dim), true)
	# title banner
	var th := 20.0 * u
	draw_rect(Rect2(8 * u, 8 * u, w - 16 * u, th), Color(UiKit.BLACK, 0.45))
	draw_rect(Rect2(8 * u, 8 * u, w - 16 * u, th), Color(accent, 0.8 * dim), false, 1.0)
	var title: String = str(data.get("title", ""))
	var fs := int(clampf(12.0 * u, 8.0, 18.0))
	draw_string(font, Vector2(10 * u, 8 * u + th * 0.72), title, HORIZONTAL_ALIGNMENT_CENTER, w - 20 * u, fs, Color(UiKit.WHITE, dim))
	# art window
	var ay := 8 * u + th + 5 * u
	var ah := h * 0.34
	var aw := w - 24 * u
	var art := Rect2(12 * u, ay, aw, ah)
	draw_rect(art, Color(UiKit.BLACK, 0.85))
	draw_rect(art, Color(accent, 0.5 * dim), false, 1.0)
	var tex = data.get("icon")
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var k := minf((art.size.x - 6) / ts.x, (art.size.y - 6) / ts.y)
		k = maxf(1.0, floorf(k)) if k >= 1.0 else k          # whole-number pixel scale when it fits
		var dr := Vector2(ts.x * k, ts.y * k)
		draw_texture_rect(tex, Rect2(art.position + (art.size - dr) / 2.0, dr), false, Color(UiKit.WHITE, dim))
	elif data.has("glyph"):
		draw_string(font, art.position + Vector2(0, art.size.y * 0.68), str(data.glyph), HORIZONTAL_ALIGNMENT_CENTER, art.size.x, maxi(8, int(minf(art.size.y * 0.6, art.size.x / (maxf(1.0, float(str(data.glyph).length())) * 0.62)))), Color(accent, dim))
	# corner badge (cost, mana, "NEW")
	var badge: String = str(data.get("badge", ""))
	if badge != "":
		draw_string(font, Vector2(art.position.x + 3, art.position.y + 13 * u), badge, HORIZONTAL_ALIGNMENT_LEFT, art.size.x - 6, int(clampf(10.0 * u, 8.0, 14.0)), Color(UiKit.SKY, dim))
	var tier: int = int(data.get("tier", 0))
	var max_tier: int = int(data.get("max_tier", 0))
	if tier > 0:
		draw_string(font, Vector2(art.position.x, art.position.y + 13 * u), "T%d" % tier, HORIZONTAL_ALIGNMENT_RIGHT, art.size.x - 4, int(clampf(11.0 * u, 8.0, 15.0)), Color(UiKit.GOLD_BRIGHT, dim))
	# text lines
	var ty := ay + ah + 4 * u
	var lines: Array = data.get("lines", [])
	var lfs := int(clampf(9.5 * u, 7.0, 13.0))
	var pip_h := 16.0 * u if max_tier > 0 else 0.0
	var foot: String = str(data.get("footer", ""))
	var foot_cost: Dictionary = data.get("footer_cost", {})                # a price: icons and amounts, drawn instead of the footer text
	var foot_h := 13.0 * u if foot != "" or !foot_cost.is_empty() else 0.0
	var room := h - ty - pip_h - foot_h - 9 * u
	for l in lines:
		if room < lfs:
			break
		var col := Color(UiKit.TEXT_HINT, dim)
		var txt := str(l)
		if font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, w - 18 * u, lfs, 2).y > room:
			break
		if txt.begins_with("+"):
			col = Color(UiKit.GOOD, dim)
		var lw := w - 18 * u
		var sz := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2)
		draw_multiline_string(font, Vector2(9 * u, ty + lfs), txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2, col)
		ty += sz.y + 2 * u
		room -= sz.y + 2 * u
	# footer (price / state)
	if !foot_cost.is_empty():
		var isz := clampf(11.0 * u, 8.0, 14.0)
		var ffs := int(clampf(10.0 * u, 7.0, 13.0))
		var cw := ResIcons.width(foot_cost, isz, ffs)
		ResIcons.draw(self, Vector2((w - cw) / 2.0, h - 8 * u - pip_h - 2 * u), foot_cost, isz, ffs, Color(data.get("footer_color", UiKit.WARM), dim))
	elif foot != "":
		var fc: Color = data.get("footer_color", UiKit.WARM)
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
			var gc := Color(accent.lightened(0.2), dim) if owned else UiKit.PANEL.lightened(0.15)
			var oc := UiKit.CURSOR if nxt and !locked else (Color(accent, dim) if owned else UiKit.MUTED_DARK)
			_gem(Vector2(gx + i * gr * 2.2, gy), gr, gc, oc, owned)
	_draw_overlays(w, h, art, locked)

## Locked dimming, the padlock, hover, the upgrade blink, the controller focus ring and the gold selection frame: the same on every card style.
func _draw_overlays(w: float, h: float, art: Rect2, locked: bool) -> void:
	if locked:
		draw_rect(Rect2(0, 0, w, h), Color(UiKit.BLACK, 0.25))
	if data.get("lock", false):                        # a padlock over the art window
		var c := art.get_center() + Vector2(0, art.size.y * 0.08)
		var k := minf(art.size.x, art.size.y) * 0.22
		draw_arc(c + Vector2(0, -k * 0.55), k * 0.62, PI, TAU, 14, UiKit.DRAW_FILL, maxf(2.0, k * 0.28))
		draw_rect(Rect2(c + Vector2(-k, -k * 0.55), Vector2(k * 2.0, k * 1.5)), UiKit.ACCENT)
		draw_rect(Rect2(c + Vector2(-k * 0.14, -k * 0.05), Vector2(k * 0.28, k * 0.5)), UiKit.BAR_BG)
	if _hover:
		draw_rect(Rect2(0, 0, w, h), Color(UiKit.WHITE, 0.07))
	if data.get("blink", false):
		draw_rect(Rect2(0, 0, w, h), Color(UiKit.GOLD_BRIGHT, 0.28 * _pulse))
		draw_rect(Rect2(-2, -2, w + 4, h + 4), Color(UiKit.GOLD_BRIGHT, 0.4 + 0.6 * _pulse), false, 3.0)
	if has_focus():
		draw_rect(Rect2(-3, -3, w + 6, h + 6), UiKit.SKY, false, 3.0)
	if selected:
		draw_rect(Rect2(-1, -1, w + 2, h + 2), UiKit.GOLD_BRIGHT, false, 3.0)

## The card style: the same layout as a spell or building card (ui/cards/card_view.gd) - the kind's frame picture, the art window,
## the name banner, the description box, the tier badge top-right - so a weapon looks like the other cards. data.frame is the
## frame picture (weapons use frame_weapon.png: chamfered corners and a steel border); data.accent colours a thin rarity line
## just inside it. title / icon / glyph / lines / footer / footer_cost / tier work as in the other style.
func _draw_card_face() -> void:
	var accent: Color = data.get("accent", UiKit.ACCENT)
	var locked: bool = data.get("locked", false)
	var dim := 0.45 if locked else 1.0
	var font := ThemeDB.fallback_font
	var k := minf(size.x / 48.0, size.y / 80.0)                                # the frame is 48 x 80 art pixels
	var o := (size - Vector2(48.0, 80.0) * k) / 2.0
	draw_texture_rect(_frame_tex, Rect2(o, Vector2(48.0, 80.0) * k), false, Color(UiKit.WHITE, dim))
	draw_rect(Rect2(o + Vector2(3.5, 3.5) * k, Vector2(41.0, 73.0) * k), Color(accent, dim), false, maxf(1.0, 0.8 * k))
	# art window
	var art := Rect2(o + Vector2(6, 6) * k, Vector2(35, 31) * k)
	var tex = data.get("icon")
	if tex != null:
		var ts: Vector2 = tex.get_size()
		var ik := minf((art.size.x - 4) / ts.x, (art.size.y - 4) / ts.y)
		ik = maxf(1.0, floorf(ik)) if ik >= 1.0 else ik
		var dr := Vector2(ts.x * ik, ts.y * ik)
		draw_texture_rect(tex, Rect2(art.position + (art.size - dr) / 2.0, dr), false, Color(UiKit.WHITE, dim))
	elif data.has("glyph"):
		draw_string(font, art.position + Vector2(0, art.size.y * 0.72), str(data.glyph), HORIZONTAL_ALIGNMENT_CENTER, art.size.x, int(art.size.y * 0.7), Color(accent, dim))
	# tier badge, top-right of the art window
	var tier: int = int(data.get("tier", 0))
	var bfs := clampi(int(5.5 * k), 8, 16)
	if tier > 0:
		var bp := art.position + Vector2(0, bfs + 1.0)
		draw_string_outline(font, bp, "T%d" % tier, HORIZONTAL_ALIGNMENT_RIGHT, art.size.x - 2.0, bfs, 3, UiKit.BLACK)
		draw_string(font, bp, "T%d" % tier, HORIZONTAL_ALIGNMENT_RIGHT, art.size.x - 2.0, bfs, Color(UiKit.GOLD_BRIGHT, dim))
	# name banner
	var title: String = str(data.get("title", ""))
	var tfs := clampi(int(5.5 * k), 7, 16)
	while tfs > 7 and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > 41.0 * k:
		tfs -= 1
	draw_string(font, o + Vector2(0, 48.3 * k), title, HORIZONTAL_ALIGNMENT_CENTER, 48.0 * k, tfs, Color(UiKit.WHITE, dim))
	# description box: the lines, then the footer (a state or a price) at the bottom
	var lfs := clampi(int(4.6 * k), 7, 13)
	var ty := o.y + 54.5 * k + lfs
	var bottom := o.y + 73.5 * k
	var foot: String = str(data.get("footer", ""))
	var foot_cost: Dictionary = data.get("footer_cost", {})
	var has_foot := foot != "" or !foot_cost.is_empty()
	var lw := 40.0 * k
	for l in data.get("lines", []):
		var txt := str(l)
		var sz := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2)
		if ty + sz.y - lfs > bottom - (lfs + 1.0 if has_foot else 0.0):
			break
		draw_multiline_string(font, Vector2(o.x + 4.0 * k, ty), txt, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, 2, Color(UiKit.GOOD if txt.begins_with("+") else UiKit.TEXT_HINT, dim))
		ty += sz.y + 1.0
	var fc := Color(data.get("footer_color", UiKit.WARM), dim)
	if !foot_cost.is_empty():
		var isz := float(lfs)
		var cw := ResIcons.width(foot_cost, isz, lfs)
		ResIcons.draw(self, Vector2(o.x + (48.0 * k - cw) / 2.0, bottom - 1.0), foot_cost, isz, lfs, fc)
	elif foot != "":
		draw_string(font, Vector2(o.x + 4.0 * k, bottom - 1.0), foot, HORIZONTAL_ALIGNMENT_CENTER, lw, lfs, fc)
	_draw_overlays(size.x, size.y, art, locked)

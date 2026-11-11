extends RefCounted
## The little resource icons. Anywhere a cost or a stock is shown the resource is an icon followed by its amount, never an
## abbreviation: cards, the HUD line, the Forge, hints, upgrade cards. ONE place knows which icon is which (ui/cards/res_icons/<id>.png,
## made by tools/make_resource_icons.gd). Three ways to show them:
##   row(cost)            a Control with icon + amount pairs (cards, buttons, any container)
##   bb(cost)             a BBCode string for a RichTextLabel ("[img]" icons inline in a sentence)
##   draw(item, ...)      draw icon + amount pairs straight onto a CanvasItem (world hints, the weapon-slot hint)

const UiKit = preload("res://ui/cards/ui_kit.gd")
const ORDER := ["stone", "stick", "gold", "iron", "frost", "ember", "moss", "gem"]
const CORE := ["stone", "stick", "gold"]        # always shown in the HUD stock, even at 0
const DIR := "res://ui/cards/res_icons/%s.png"

static func tex(id: String) -> Texture2D:
	var path := DIR % id
	return load(path) if ResourceLoader.exists(path) else null

## The resources of a cost/stock table in a fixed order (stone, stick, gold, then the sector ones); zero amounts left out unless `all`.
static func keys(table: Dictionary, all := false) -> Array:
	var out := []
	for k in ORDER:
		if table.has(k) and (all or int(table[k]) > 0):
			out.append(k)
	for k in table:
		if !(k in ORDER) and (all or int(table[k]) > 0):
			out.append(k)
	return out

## [img] + amount for each resource, for a RichTextLabel.
static func bb(table: Dictionary, size := 14, all := false) -> String:
	var parts := []
	for k in keys(table, all):
		var t := DIR % k
		parts.append(("[img=%d]%s[/img]%d" % [size, t, int(table[k])]) if ResourceLoader.exists(t) else "%d %s" % [int(table[k]), k])
	return "  ".join(parts)

## The HUD stock: stone, stick and gold always (even at 0), the sector resources only when you have some.
static func stock_bb(table: Dictionary, size := 14) -> String:
	var shown := {}
	for k in CORE:
		shown[k] = int(table.get(k, 0))
	for k in table:
		if !(k in shown) and int(table[k]) > 0:
			shown[k] = int(table[k])
	return bb(shown, size, true)

## Width `draw` would use, to centre it.
static func width(table: Dictionary, size := 10.0, font_size := 9) -> float:
	var font := ThemeDB.fallback_font
	var x := 0.0
	for k in keys(table):
		var t := tex(k)
		if t != null:
			x += size + 1.0
		x += font.get_string_size(str(int(table[k])) if t != null else "%d %s" % [int(table[k]), k], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 5.0
	return maxf(0.0, x - 5.0)

## A Control with an icon and the amount for each resource. `have` (optional) colours an amount red when that stock is short.
static func row(table: Dictionary, size := 14, font := UiKit.FONT_SMALL, color := UiKit.TEXT, have := {}, all := false) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override("separation", 6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in keys(table, all):
		var pair := HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 2)
		var t := tex(k)
		if t != null:
			var tr := TextureRect.new()
			tr.texture = t
			tr.custom_minimum_size = Vector2(size, size)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pair.add_child(tr)
		var l := UiKit.label(str(int(table[k])) if t != null else "%d %s" % [int(table[k]), k], font, UiKit.WARN if !have.is_empty() and int(have.get(k, 0)) < int(table[k]) else color)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(l)
		r.add_child(pair)
	return r

## Draw icon + amount pairs onto `item` starting at `at` (left, baseline). Returns the x just after the last one.
static func draw(item: CanvasItem, at: Vector2, table: Dictionary, size := 10.0, font_size := 9, color := UiKit.WHITE, all := false) -> float:
	var font := ThemeDB.fallback_font
	var x := at.x
	for k in keys(table, all):
		var t := tex(k)
		if t != null:
			item.draw_texture_rect(t, Rect2(Vector2(x, at.y - size + 1.0), Vector2(size, size)), false)
			x += size + 1.0
		var s := str(int(table[k])) if t != null else "%d %s" % [int(table[k]), k]
		item.draw_string(font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		x += font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 5.0
	return x

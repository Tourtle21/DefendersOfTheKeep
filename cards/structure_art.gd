extends RefCounted
class_name StructureArt
## How each building card is drawn, per tier. `draw` returns false for an id without its own drawing, so Structure's old
## per-kind drawing runs (a card gets its art one at a time). All motion comes from the structure's own clock (`_age`, which also
## ticks on a LAN client) and from SpellArt.jit, so every machine draws the same picture. Designs: docs/card_tiers/<card id>.md

const GOLD := Color(1.0, 0.85, 0.4)

## True when the card has its own drawing (and has drawn it).
static func draw(st, col: Color) -> bool:
	match String(st.data.get("id", "")):
		_:
			return false

# ---------------------------------------------------------------- small shared shapes

## A solid rectangle with the black 1px outline every building has.
static func box(st, rect: Rect2, fill: Color) -> void:
	st.draw_rect(rect, Color.BLACK)
	st.draw_rect(rect.grow(-1.0), fill)

## A solid polygon with a black outline.
static func poly(st, pts: PackedVector2Array, fill: Color) -> void:
	st.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	st.draw_polyline(closed, Color.BLACK, 1.0)

## A rivet.
static func rivet(st, p: Vector2, col: Color, r := 1.0) -> void:
	st.draw_circle(p, r + 0.5, Color.BLACK)
	st.draw_circle(p, r, col)

## A kite-shaped shield emblem.
static func kite(st, c: Vector2, w: float, h: float, fill: Color, edge: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-w * 0.5, -h * 0.4), c + Vector2(w * 0.5, -h * 0.4), c + Vector2(w * 0.4, h * 0.1), c + Vector2(0, h * 0.5), c + Vector2(-w * 0.4, h * 0.1)])
	st.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	st.draw_polyline(closed, edge, 1.0)

## A steady bar for the hp of a building (the card art keeps the old one).
static func hp_bar(st, y: float, half_w: float, gold_ends := false) -> void:
	if st.hp >= st.max_hp:
		return
	var f: float = clampf(st.hp / st.max_hp, 0.0, 1.0)
	st.draw_rect(Rect2(-half_w, y, half_w * 2.0, 3), Color(0.2, 0, 0))
	st.draw_rect(Rect2(-half_w, y, half_w * 2.0 * f, 3), Color(0.3, 0.9, 0.3))
	if gold_ends:
		st.draw_rect(Rect2(-half_w - 1, y - 1, 2, 5), GOLD)
		st.draw_rect(Rect2(half_w - 1, y - 1, 2, 5), GOLD)

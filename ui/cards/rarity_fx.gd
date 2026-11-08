extends Control
## The glow, burst and sparkles around a revealed reward card. Rarer cards glow brighter, burst bigger and sparkle
## more; Legendary cycles through every colour. Put it over a card-sized area (mouse is ignored).

var rarity := 0
var _t := 0.0
var _burst := 0.0

func setup(r: int, card_size: Vector2) -> void:
	rarity = r
	size = card_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2

func play_burst() -> void:
	_burst = 1.0

func _colour() -> Color:
	if rarity >= 6:
		return Color.from_hsv(fposmod(_t * 0.6, 1.0), 0.55, 1.0)         # Legendary: a slow rainbow
	return Game.rarity_color(rarity)

func _process(delta: float) -> void:
	_t += delta
	_burst = maxf(0.0, _burst - delta * 1.1)
	queue_redraw()

func _draw() -> void:
	var col := _colour()
	var c := size / 2.0
	if rarity >= 1:
		for i in 3:
			draw_rect(Rect2(Vector2(-i * 2.0, -i * 2.0), size + Vector2(i * 4.0, i * 4.0)), Color(col, (0.30 + 0.06 * rarity) - i * 0.09), false, 2.0)
	if _burst > 0.0:
		var ring := (1.0 - _burst) * (70.0 + 22.0 * rarity)
		draw_arc(c, ring, 0, TAU, 56, Color(col, _burst), 2.0 + rarity * 0.6)
		if rarity >= 3:
			draw_arc(c, ring * 0.6, 0, TAU, 40, Color(col.lightened(0.4), _burst * 0.8), 2.0)
		for i in 6 + rarity * 6:                                           # sparks flying outward
			var a := float(i) * 2.399 + float(rarity)
			var d := (1.0 - _burst) * (50.0 + 12.0 * rarity) * (0.6 + 0.4 * fposmod(float(i) * 0.37, 1.0))
			draw_circle(c + Vector2.from_angle(a) * d, 1.5 + rarity * 0.25, Color(col.lightened(0.3), _burst))
	if rarity >= 2:
		for i in rarity:                                                   # a few lingering sparkles
			var a := _t * (0.8 + 0.2 * i) + i * 2.1
			var p := c + Vector2(cos(a) * (size.x * 0.52), sin(a * 1.3) * (size.y * 0.52))
			draw_circle(p, 1.4, Color(col.lightened(0.5), 0.5 + 0.4 * sin(_t * 4.0 + i)))

extends CanvasLayer
class_name CrystalAlert
## Shown while the crystal is away from the Well: a banner (what happened, what to do, the
## thief's escape countdown) and an arrow at the screen edge pointing to the crystal.
## Reads only Game.crystal_* so it works the same for a co-op client.

var canvas: Control
var view: SubViewport = null          # split screen, players 2 to 4: draw for this player's view
var _t := 0.0

func _ready() -> void:
	layer = 9
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_alert)
	add_child(canvas)

func _process(delta: float) -> void:
	_t += delta
	canvas.visible = Game.crystal_away()
	if canvas.visible:
		canvas.queue_redraw()

func _message() -> Array:
	match Game.crystal_state:
		"carried":
			return ["THE CRYSTAL WAS STOLEN", "Base offline. Kill the thief before it reaches the edge: %d s" % int(ceil(Game.crystal_eta)), Color(1.0, 0.35, 0.3)]
		"dropped":
			return ["THE CRYSTAL IS LOOSE", "Base offline. Pick it up and carry it back to the Well!", Color(0.85, 0.55, 1.0)]
	return ["YOU HAVE THE CRYSTAL", "Base offline until it is back in the Well.", Color(0.55, 1.0, 0.7)]

func _draw_alert() -> void:
	var msg := _message()
	var col: Color = msg[2]
	var font := ThemeDB.fallback_font
	var vp := canvas.size
	var pulse := 0.6 + 0.4 * sin(_t * 6.0)
	var bw := minf(520.0, vp.x - 16.0)               # (a half-width view is narrower than the banner)
	var small := bw < 500.0
	canvas.draw_rect(Rect2(vp.x / 2.0 - bw / 2.0, 150.0, bw, 52.0), Color(0, 0, 0, 0.55))
	canvas.draw_rect(Rect2(vp.x / 2.0 - bw / 2.0, 150.0, bw, 52.0), Color(col, 0.5 + 0.4 * pulse), false, 2.0)
	canvas.draw_string(font, Vector2(vp.x / 2.0 - bw / 2.0, 174.0), msg[0], HORIZONTAL_ALIGNMENT_CENTER, bw, 18 if small else 22, col)
	canvas.draw_string(font, Vector2(vp.x / 2.0 - bw / 2.0, 194.0), msg[1], HORIZONTAL_ALIGNMENT_CENTER, bw, 11 if small else 14, Color(1, 1, 1, 0.9))
	# arrow toward the crystal when it is off screen
	var xf: Transform2D = view.get_canvas_transform() if view != null else Pad.view_transform(get_viewport())
	var sp: Vector2 = xf * Game.crystal_pos
	var rect := Rect2(Vector2.ZERO, vp).grow(-40)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var inside := rect.has_point(sp)
	var p := sp if inside else sp.clamp(rect.position, rect.end)
	if inside:
		canvas.draw_arc(sp, 22.0 + 4.0 * pulse, 0, TAU, 24, Color(col, 0.9), 2.5)
	else:
		var d := (sp - p).normalized()
		var side := d.orthogonal()
		canvas.draw_colored_polygon(PackedVector2Array([p + d * 18, p - d * 6 + side * 12, p - d * 6 - side * 12]), Color(col, 0.6 + 0.4 * pulse))
		canvas.draw_string(font, p + Vector2(-20, 28), "crystal", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, col)

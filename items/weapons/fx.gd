extends Node2D
class_name WeaponFx
## Short-lived attack visuals: ring, arc and line.

var kind := "ring"
var color := Color.WHITE
var radius := 30.0
var dir := Vector2.RIGHT
var length := 40.0
var width := 3.0
var half_angle := 0.8
var life := 0.25
var age := 0.0

static func spawn(world: Node, k: String, pos: Vector2, col: Color, params := {}) -> void:
	if world == null:
		return
	if Rep.hosting() and Rep.ser_ok(params):
		Rep.event("fx", [k, pos, col, params])
	var f := WeaponFx.new()
	f.kind = k
	f.position = pos
	f.color = col
	for key in params:
		f.set(key, params[key])
	world.add_child.call_deferred(f)

func _ready() -> void:
	add_to_group("net_local")      # one-shot effect: mirrored to clients as a Rep event, not as a node
	z_as_relative = false
	z_index = 12

func _process(delta: float) -> void:
	age += delta
	if age >= life:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := age / life
	var fade := 1.0 - t
	match kind:
		"ring":
			var r := radius * (0.55 + 0.45 * t)
			draw_circle(Vector2.ZERO, r, Color(color, 0.14 * fade))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(color, 0.9 * fade), 2.0)
		"arc":
			draw_arc(Vector2.ZERO, radius, dir.angle() - half_angle, dir.angle() + half_angle, 18, Color(color, 0.9 * fade), 3.0)
		"burst":
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0 + 0.3)
				draw_line(d * radius * 0.3 * (1.0 + t), d * radius * (0.6 + t), Color(color, 0.9 * fade), 2.0)
		"line":
			draw_line(Vector2.ZERO, dir * length, Color(color, 0.9 * fade), max(1.0, width * fade))

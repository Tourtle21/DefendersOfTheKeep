extends Node2D
class_name WeaponFx
## Short-lived attack visuals: ring, arc, burst and line, plus the bigger card effects (flash, ripple, shards, pillar,
## motes, star, bolt). Everything is drawn from `age`, and the "random" parts come from the index, so every machine draws the same.

var kind := "ring"
var color := Color.WHITE
var radius := 30.0
var dir := Vector2.RIGHT
var length := 40.0
var width := 3.0
var half_angle := 0.8
var life := 0.25
var age := 0.0
var count := 8              # shards, motes, star points
var spin := 0.0             # start angle (shards) or turn (star)
var height := 40.0          # pillar
var rise := 30.0            # motes drift up by this much
var rings := 3              # ripple
var core := Color(1.0, 0.97, 0.85)   # fall: the colour of the glowing heart of the rock

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
		"flash":
			draw_circle(Vector2.ZERO, radius * (0.6 + 0.6 * t), Color(color, 0.7 * fade * fade))
			draw_circle(Vector2.ZERO, radius * 0.4 * fade, Color(1.0, 0.97, 0.85, fade))
		"ripple":
			for i in rings:
				var u := (t - float(i) * 0.5 / float(maxi(rings, 1))) / 0.5
				if u > 0.0 and u <= 1.0:
					draw_arc(Vector2.ZERO, radius * u, 0, TAU, 40, Color(color, 0.9 * (1.0 - u)), 2.0)
		"shards":
			for i in count:
				var a := spin + i * TAU / float(maxi(count, 1))
				var d := Vector2.from_angle(a)
				var tip := d * radius * (0.25 + 0.75 * t)
				var l := 6.0 + 4.0 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
				var n := d.orthogonal()
				draw_colored_polygon(PackedVector2Array([tip, tip - d * l + n * 1.8, tip - d * l - n * 1.8]), Color(color, 0.9 * fade))
		"pillar":
			var h := height * minf(1.0, t * 4.0 + 0.3)
			var w := width
			draw_colored_polygon(PackedVector2Array([Vector2(-w / 2.0, 0), Vector2(w / 2.0, 0), Vector2(w * 0.3, -h), Vector2(-w * 0.3, -h)]), Color(color, 0.5 * fade))
			draw_colored_polygon(PackedVector2Array([Vector2(-w / 4.0, 0), Vector2(w / 4.0, 0), Vector2(w * 0.15, -h), Vector2(-w * 0.15, -h)]), Color(1, 1, 1, 0.6 * fade))
			draw_circle(Vector2.ZERO, w * 0.6 * fade, Color(1, 1, 1, 0.5 * fade))
		"motes":
			for i in count:
				var j := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
				var j2 := fposmod(sin(i * 78.233 + 1.0) * 43758.5453, 1.0)
				var p := Vector2.from_angle(j * TAU) * radius * j2 + Vector2(0, -rise * t)
				draw_circle(p, 1.5, Color(color, 0.9 * fade))
		"star":
			var pts := PackedVector2Array()
			for i in count * 2 + 1:
				var r2 := radius if i % 2 == 0 else radius * 0.45
				pts.append(Vector2.from_angle(spin * t + i * PI / float(maxi(count, 1))) * r2)
			draw_polyline(pts, Color(color, 0.9 * fade), 1.5)
		"bolt":
			var pts2 := PackedVector2Array([Vector2.ZERO])
			var side := dir.orthogonal()
			for i in range(1, 8):
				var off := (fposmod(sin(i * 12.9898 + radius) * 43758.5453, 1.0) - 0.5) * 2.0 * length * 0.08
				pts2.append(dir * length * i / 7.0 + (side * off if i < 7 else Vector2.ZERO))
			draw_polyline(pts2, Color(color, 0.6 * fade), width * 2.0)
			draw_polyline(pts2, Color(1, 1, 1, fade), maxf(1.0, width * 0.6))
		"fall":
			# a rock coming down onto this point: it starts `height` above and `rise` to the side, with a tail of embers
			var start := Vector2(-rise, -height)
			var p := start.lerp(Vector2.ZERO, t)
			var back := start.normalized()
			var n := int(12 + radius * 1.5)
			for i in n:
				var q := p + back * (float(i) * (3.0 + radius * 0.15))
				draw_circle(q, maxf(0.6, radius * 0.7 - float(i) * 0.3), Color(color, maxf(0.0, 0.8 - float(i) / float(n))))
			draw_circle(p, radius * 1.8, Color(color, 0.35))
			draw_circle(p, radius, Color(0.3, 0.15, 0.1))
			draw_circle(p, radius * 0.5, core)
			if radius >= 6.0:
				for k in 3:
					var a := k * TAU / 3.0 + 0.5
					draw_line(p, p + Vector2.from_angle(a) * radius * 0.9, color, 1.0)

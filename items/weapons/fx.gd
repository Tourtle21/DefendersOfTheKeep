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
var shape := "dot"          # orbit: dot, blade, star, shard
var thick := 6.0            # slash / shock thickness
var inward := false         # vortex: contracts instead of expanding
var col2 := Color(1, 1, 1)  # second colour (edges, cores)

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
		"slash":
			# a filled crescent, tapered to points, a white edge on the outer arc; it turns a little as it fades
			if half_angle >= 2.8:          # a whole ring: no tapered ends
				var rr := radius * (0.85 + 0.15 * t)
				draw_arc(Vector2.ZERO, rr - thick * 0.5, dir.angle(), dir.angle() + TAU, 44, Color(color, 0.55 * fade), maxf(1.0, thick * fade))
				draw_arc(Vector2.ZERO, rr, dir.angle(), dir.angle() + TAU, 44, Color(col2, 0.95 * fade), 1.5)
				return
			var a0 := dir.angle() - half_angle + 0.2 * t
			var a1 := dir.angle() + half_angle + 0.2 * t
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			var steps := 14
			for i in steps + 1:
				var u := float(i) / float(steps)
				var a := lerpf(a0, a1, u)
				var taper := sin(u * PI)
				outer.append(Vector2.from_angle(a) * radius)
				inner.append(Vector2.from_angle(a) * (radius - maxf(0.5, thick * taper)))
			inner.reverse()
			outer.append_array(inner)
			draw_colored_polygon(outer, Color(color, 0.55 * fade))
			draw_polyline(_arc_pts(a0, a1, radius, steps), Color(col2, 0.95 * fade), 1.5)
		"streak":
			var side := dir.orthogonal()
			var head := dir * length
			var wd := width * 0.5 * (0.5 + 0.5 * fade)
			draw_colored_polygon(PackedVector2Array([head, side * wd, -side * wd]), Color(color, 0.5 * fade))
			draw_line(Vector2.ZERO, head, Color(col2, 0.8 * fade), 1.0)
			for i in 5:
				var u2 := (float(i) + 0.5) / 5.0
				var off := (_jit(i, 1.0) - 0.5) * wd * 1.2 * (1.0 - u2)
				draw_circle(head * u2 + side * off, 1.0, Color(col2, 0.9 * fade))
		"cone":
			var pc := PackedVector2Array([Vector2.ZERO])
			for i in 13:
				pc.append(Vector2.from_angle(dir.angle() - half_angle + 2.0 * half_angle * float(i) / 12.0) * radius * (0.7 + 0.3 * t))
			draw_colored_polygon(pc, Color(color, 0.22 * fade))
			draw_line(Vector2.ZERO, pc[1], Color(col2, 0.8 * fade), 1.0)
			draw_line(Vector2.ZERO, pc[pc.size() - 1], Color(col2, 0.8 * fade), 1.0)
			draw_polyline(pc.slice(1), Color(col2, 0.9 * fade), 1.5)
		"beam":
			var ww := width * (1.0 - t)
			var end := dir * length
			draw_line(Vector2.ZERO, end, Color(color, 0.18 * fade), maxf(1.0, ww * 3.0))
			draw_line(Vector2.ZERO, end, Color(color, 0.7 * fade), maxf(1.0, ww))
			draw_line(Vector2.ZERO, end, Color(col2, fade), maxf(1.0, ww * 0.35))
			draw_circle(end, maxf(1.0, ww * 1.2), Color(color, 0.6 * fade))
		"orbit":
			var vis := minf(1.0, minf(age / 0.15, (life - age) / 0.15))
			for i in count:
				var a2 := spin * age + float(i) * TAU / float(maxi(count, 1))
				var q := Vector2.from_angle(a2) * radius
				var c3 := Color(color, vis)
				match shape:
					"blade":
						var d3 := Vector2.from_angle(a2 + PI / 2.0)
						draw_colored_polygon(PackedVector2Array([q + d3 * 4.0, q + Vector2.from_angle(a2) * 1.6, q - d3 * 4.0]), c3)
					"star":
						draw_polyline(PackedVector2Array([q + Vector2(-2.5, 0), q + Vector2(2.5, 0)]), c3, 1.0)
						draw_polyline(PackedVector2Array([q + Vector2(0, -2.5), q + Vector2(0, 2.5)]), c3, 1.0)
					"shard":
						var d4 := Vector2.from_angle(a2)
						draw_colored_polygon(PackedVector2Array([q + d4 * 3.0, q + d4.orthogonal() * 1.6, q - d4 * 3.0, q - d4.orthogonal() * 1.6]), c3)
					_:
						draw_circle(q, 1.6, c3)
		"vortex":
			var arms := maxi(count, 1)
			var sweep := 1.0 - t if inward else t
			for k in arms:
				var pv := PackedVector2Array()
				for i in 10:
					var u3 := float(i) / 9.0
					var rr := radius * sweep * (1.0 - u3 * 0.9) if inward else radius * sweep * u3
					pv.append(Vector2.from_angle(spin * t + float(k) * TAU / float(arms) + u3 * 2.2) * rr)
				draw_polyline(pv, Color(color, 0.7 * fade), 1.5)
		"crack":
			for k in count:
				var a5 := float(k) * TAU / float(maxi(count, 1)) + _jit(k, 3.0) * 0.5
				var pk := PackedVector2Array([Vector2.ZERO])
				for i in range(1, 6):
					var along := radius * float(i) / 5.0
					pk.append(Vector2.from_angle(a5) * along + Vector2.from_angle(a5 + PI / 2.0) * (_jit(k * 7 + i, 5.0) - 0.5) * radius * 0.18)
				var al := sqrt(fade)
				draw_polyline(pk, Color(color, 0.45 * al), 3.0)
				draw_polyline(pk, Color(0.08, 0.05, 0.05, al), 1.0)
		"sigil":
			var build := minf(1.0, t / 0.6)
			var a6 := build if t < 0.6 else fade * 2.0 + 0.2
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 0.9 * a6), 1.5)
			draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 32, Color(color, 0.6 * a6), 1.0)
			for i in count:
				var a7 := spin * t + float(i) * TAU / float(maxi(count, 1))
				var q2 := Vector2.from_angle(a7) * radius
				var dd := Vector2.from_angle(a7)
				draw_colored_polygon(PackedVector2Array([q2 + dd * 3.0, q2 + dd.orthogonal() * 2.0, q2 - dd * 3.0, q2 - dd.orthogonal() * 2.0]), Color(col2, 0.9 * a6))
				draw_line(Vector2.from_angle(-a7 * 0.7) * radius * 0.7, Vector2.from_angle(-a7 * 0.7 + 0.5) * radius * 0.7, Color(col2, 0.7 * a6), 1.0)
			if t >= 0.6:
				draw_circle(Vector2.ZERO, radius * 0.7, Color(color, 0.25 * (1.0 - (t - 0.6) / 0.4)))
		"cut":
			var pop := minf(1.0, 0.7 + 0.3 * t / 0.2)
			var ll := radius * pop
			for s2 in 2:
				var dv := Vector2.from_angle(spin + float(s2) * PI / 2.0 + PI / 4.0) * ll
				draw_line(-dv, dv, Color(color, 0.8 * fade), 3.0)
				draw_line(-dv, dv, Color(col2, fade), 1.0)
		"shock":
			var rs := radius * (0.2 + 0.8 * t)
			draw_circle(Vector2.ZERO, rs, Color(color, 0.12 * fade))
			draw_arc(Vector2.ZERO, rs, 0, TAU, 44, Color(color, 0.9 * fade), maxf(1.0, thick * fade))
			draw_arc(Vector2.ZERO, rs * 0.8, 0, TAU, 36, Color(col2, 0.6 * fade), 1.0)

static func _jit(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

func _arc_pts(a0: float, a1: float, r: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		pts.append(Vector2.from_angle(lerpf(a0, a1, float(i) / float(steps))) * r)
	return pts

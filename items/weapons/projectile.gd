extends Node2D
class_name WeaponProjectile
## Arrow / bolt fired by bows and staves. Hits the first enemy it touches
## (or more with pierce). Optional upgrades (all default to the old behaviour), set through `extra` of shoot():
## style, size, glow, trail (looks), homing, chain, burst_r / burst_mult, split, wobble, on_hit_fx (what it does).

var vel := Vector2.ZERO
var damage := 2.0
var life := 1.2
var color := Color(0.9, 0.8, 0.5)
var pierce := 0
var knock := 80.0
var radius := 7.0
var expose_secs := 0.0
var bleed_ticks := 0
var bleed_dmg := 1.0
var slow_mult := 1.0        # > 0 secs: a hit chills the enemy to this fraction (Frostfire's ice bolts)
var slow_secs := 0.0
var style := "arrow"        # arrow, orb, shard, blade, crescent, glob, bolt, lance
var size := 1.0
var glow := 0.0
var trail := 0
var homing := 0.0           # rad/s toward the nearest enemy within 90 px
var chain := 0              # on a hit jump to the nearest other enemy within 55 px for 60% damage, this many times
var burst_r := 0.0          # on a hit an area hit of damage * burst_mult around the target
var burst_mult := 0.5
var split := 0              # on the first hit spawn this many children at 40% damage
var wobble := 0.0           # sideways sine drift in px
var on_hit_fx := ""         # a WeaponFx kind at the hit point (flash, shards, cut)
var _hit := []
var _age := 0.0
var _origin := Vector2.ZERO
var _first := true

static func shoot(world: Node, pos: Vector2, dir: Vector2, speed: float, dmg: float, col: Color, life_s := 1.2, pierce_n := 0, knock_s := 80.0, extra := {}) -> void:
	if world == null:
		return
	var p := WeaponProjectile.new()
	p.position = pos
	p.vel = dir.normalized() * speed
	p.rotation = dir.angle()
	p.damage = dmg
	p.color = col
	p.life = life_s
	p.pierce = pierce_n
	p.knock = knock_s
	for k in extra:
		p.set(k, extra[k])
	world.add_child.call_deferred(p)

## How many projectiles are alive (the per-weapon cap of 40 is kept by the callers that fan out).
static func alive(tree: SceneTree) -> int:
	var c := 0
	for n in tree.get_nodes_in_group("net"):
		if n is WeaponProjectile:
			c += 1
	return c

func _ready() -> void:
	add_to_group("net")
	z_as_relative = false
	z_index = 11
	_origin = position

func _physics_process(delta: float) -> void:
	_age += delta
	if homing > 0.0:
		var best = WeaponUtil.nearest(get_tree(), global_position, 90.0, _hit)
		if best != null:
			var want: float = (best.global_position - global_position).angle()
			var cur := vel.angle()
			vel = vel.rotated(clampf(angle_difference(cur, want), -homing * delta, homing * delta))
			rotation = vel.angle()
	position += vel * delta
	if wobble > 0.0:
		position += vel.normalized().orthogonal() * cos(_age * 18.0) * wobble * 18.0 * delta
	life -= delta
	for e in WeaponUtil.enemies_in_circle(get_tree(), global_position, radius * size):
		if e in _hit:
			continue
		_hit.append(e)
		var at: Vector2 = global_position
		WeaponUtil.hit(e, damage, global_position - vel.normalized() * 4.0, knock)
		if expose_secs > 0.0 and is_instance_valid(e) and !e.is_queued_for_deletion():
			WeaponUtil.expose(e, expose_secs)
		if bleed_ticks > 0 and is_instance_valid(e) and !e.is_queued_for_deletion():
			WeaponUtil.bleed(get_tree(), e, bleed_ticks, bleed_dmg)
		if slow_secs > 0.0 and is_instance_valid(e) and !e.is_queued_for_deletion() and e.has_method("apply_slow"):
			e.apply_slow(slow_mult, slow_secs)
		if on_hit_fx != "":
			WeaponFx.spawn(get_parent(), on_hit_fx, at, color, {"radius": 10.0, "life": 0.25})
		if chain > 0:
			_do_chain(e)
		if burst_r > 0.0:
			WeaponFx.spawn(get_parent(), "burst", at, color, {"radius": burst_r * 0.6, "life": 0.2})
			for o in WeaponUtil.enemies_in_circle(get_tree(), at, burst_r):
				if o != e:
					WeaponUtil.hit(o, damage * burst_mult, at, 40.0, 0.0, "", true, true)
		if split > 0 and _first:
			_do_split(at)
		_first = false
		if _hit.size() > pierce:
			queue_free()
			return
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _do_chain(from) -> void:
	var done: Array = [from]
	var cur = from
	for i in chain:
		var nxt = null
		for o in get_tree().get_nodes_in_group("enemy"):
			if WeaponUtil._alive(o) and !(o in done) and !(o in _hit) and o.global_position.distance_to(cur.global_position) <= 55.0:
				if nxt == null or o.global_position.distance_to(cur.global_position) < nxt.global_position.distance_to(cur.global_position):
					nxt = o
		if nxt == null:
			return
		WeaponFx.spawn(get_parent(), "bolt", cur.global_position, color, {"dir": (nxt.global_position - cur.global_position).normalized(), "length": cur.global_position.distance_to(nxt.global_position), "width": 1.5, "life": 0.18})
		WeaponUtil.hit(nxt, damage * 0.6, cur.global_position, 20.0, 0.0, "", true, true)
		done.append(nxt)
		cur = nxt

func _do_split(at: Vector2) -> void:
	for s in split:
		var u := 0.0 if split == 1 else (float(s) / float(split - 1) - 0.5) * 1.0
		var dir := vel.normalized().rotated(u)
		var extra := {"style": style, "size": size * 0.8, "glow": glow, "split": 0, "radius": radius, "_first": false}
		WeaponProjectile.shoot(get_parent(), at + dir * 5.0, dir, vel.length(), damage * 0.4, color, 0.35, 0, knock, extra)

static func _sc(pts: Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out

func _draw() -> void:
	var sc := size
	match style:
		"orb":
			draw_circle(Vector2.ZERO, 3.0 * sc + 2.0, Color(color, 0.25 + glow))
			draw_circle(Vector2.ZERO, 3.0 * sc, color)
			draw_circle(Vector2.ZERO, 1.4 * sc, Color(1, 1, 1, 0.9))
		"shard":
			draw_colored_polygon(_sc([Vector2(6, 0), Vector2(0, -2.5), Vector2(-5, 0), Vector2(0, 2.5)], sc), color.lightened(0.15))
			draw_line(Vector2(-4, 0) * sc, Vector2(5, 0) * sc, Color(1, 1, 1, 0.8), 1.0)
		"blade":
			var pts := PackedVector2Array()
			for i in 9:
				var u := float(i) / 8.0
				pts.append(Vector2(2.0 * sc - 4.0 * sc * (1.0 - cos(u * PI)) * 0.5, (u - 0.5) * 8.0 * sc))
			draw_polyline(pts, color, 2.0)
			draw_polyline(pts, Color(1, 1, 1, 0.8), 1.0)
		"crescent":
			var pts2 := PackedVector2Array()
			for i in 11:
				var a := -1.1 + 2.2 * float(i) / 10.0
				pts2.append(Vector2.from_angle(a) * 7.0 * sc)
			draw_polyline(pts2, Color(color, 0.5), 4.0 * sc)
			draw_polyline(pts2, color.lightened(0.4), 1.5)
		"glob":
			draw_circle(Vector2.ZERO, 3.2 * sc, color)
			draw_circle(Vector2(-4, 0) * sc, 2.0 * sc, Color(color, 0.7))
			draw_circle(Vector2(-7, 0.6) * sc, 1.2 * sc, Color(color, 0.4))
			draw_circle(Vector2(0.8, -0.8) * sc, 1.0 * sc, Color(1, 1, 1, 0.5))
		"bolt":
			var pb := _sc([Vector2(-6, 0), Vector2(-2, -2), Vector2(1, 2), Vector2(4, -1), Vector2(7, 0)], sc)
			draw_polyline(pb, Color(color, 0.6), 3.0)
			draw_polyline(pb, Color(1, 1, 1, 0.95), 1.0)
		"lance":
			draw_line(Vector2(-10, 0) * sc, Vector2(7, 0) * sc, color, 2.0)
			draw_colored_polygon(_sc([Vector2(14, 0), Vector2(6, -2), Vector2(6, 2)], sc), Color(1, 1, 1, 0.9))
		_:
			draw_line(Vector2(-7, 0), Vector2(3, 0), color, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(2, -3), Vector2(2, 3)]), color.lightened(0.3))
	if style == "arrow" and glow > 0.0:
		draw_circle(Vector2.ZERO, 5.0, Color(color, glow))
	for i in trail:
		var back := Vector2(-3.0 * float(i + 1) - 6.0, 0)
		draw_circle(back, maxf(0.5, 1.6 * sc - float(i) * 0.25), Color(color, 0.5 - 0.4 * float(i) / float(maxi(trail, 1))))

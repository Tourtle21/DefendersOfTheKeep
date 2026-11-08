extends Node2D
class_name WeaponProjectile
## Arrow / bolt fired by bows and staves. Hits the first enemy it touches
## (or more with pierce).

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
var _hit := []

static func shoot(world: Node, pos: Vector2, dir: Vector2, speed: float, dmg: float, col: Color, life_s := 1.2, pierce_n := 0, knock_s := 80.0, extra := {}) -> void:
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

func _ready() -> void:
	add_to_group("net")
	z_as_relative = false
	z_index = 11

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	for e in WeaponUtil.enemies_in_circle(get_tree(), global_position, radius):
		if e in _hit:
			continue
		_hit.append(e)
		WeaponUtil.hit(e, damage, global_position - vel.normalized() * 4.0, knock)
		if expose_secs > 0.0 and is_instance_valid(e) and !e.is_queued_for_deletion():
			WeaponUtil.expose(e, expose_secs)
		if bleed_ticks > 0 and is_instance_valid(e) and !e.is_queued_for_deletion():
			WeaponUtil.bleed(get_tree(), e, bleed_ticks, bleed_dmg)
		if _hit.size() > pierce:
			queue_free()
			return
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-7, 0), Vector2(3, 0), color, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(2, -3), Vector2(2, 3)]), color.lightened(0.3))

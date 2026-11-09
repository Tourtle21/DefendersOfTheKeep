extends Node2D
class_name EnemyProjectile
## A slow glob fired by spitters. Hurts the player on contact; dodge it.

var vel := Vector2.ZERO
var life := 3.0
var radius := 7.0
var damage := 30.0
var tint := Color(0.5, 0.95, 0.3)
var split_at := 0.0               # > 0: after this many seconds it bursts into split_n shots (Crystal Warden)
var split_n := 3
var _age := 0.0
var _split_done := false

static func fire(world: Node, from: Vector2, dir: Vector2, speed := 95.0, dmg := 30.0, col := Color(0.5, 0.95, 0.3), rad := 7.0, lifetime := 3.0, split_time := 0.0) -> void:
	var p := EnemyProjectile.new()
	p.position = from
	p.vel = dir.normalized() * speed
	p.damage = dmg
	p.tint = col
	p.radius = rad
	p.life = lifetime
	p.split_at = split_time
	world.add_child.call_deferred(p)

func _ready() -> void:
	add_to_group("net")
	z_index = 8

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	_age += delta
	if split_at > 0.0 and !_split_done and _age >= split_at:
		_split_done = true
		for i in split_n:
			var a := vel.angle() + (i - (split_n - 1) / 2.0) * 0.5
			EnemyProjectile.fire(get_parent(), position, Vector2.from_angle(a), vel.length() * 1.1, damage * 0.8, tint, maxf(4.0, radius * 0.65), 1.6)
		queue_free()
		return
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl) and !pl.get("is_in_tower") and pl.global_position.distance_to(global_position) <= radius + 4.0:
			pl.take_damage(global_position - vel.normalized() * 10.0, damage)
			queue_free()
			return
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := radius / 7.0
	draw_circle(Vector2.ZERO, 5.0 * k, tint.darkened(0.8))
	draw_circle(Vector2.ZERO, 4.0 * k, tint)
	draw_circle(Vector2(-1, -1) * k, 1.3 * k, tint.lightened(0.7))

extends Node2D
class_name EnemyProjectile
## A slow glob fired by spitters. Hurts the player on contact; dodge it.

var vel := Vector2.ZERO
var life := 3.0
var radius := 7.0

static func fire(world: Node, from: Vector2, dir: Vector2, speed := 95.0) -> void:
	var p := EnemyProjectile.new()
	p.position = from
	p.vel = dir.normalized() * speed
	world.add_child.call_deferred(p)

func _ready() -> void:
	add_to_group("net")
	z_index = 8

func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl) and pl.global_position.distance_to(global_position) <= radius + 4.0:
			pl.take_damage(global_position - vel.normalized() * 10.0)
			queue_free()
			return
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.05, 0.2, 0.05))
	draw_circle(Vector2.ZERO, 4.0, Color(0.5, 0.95, 0.3))
	draw_circle(Vector2(-1, -1), 1.3, Color(0.85, 1.0, 0.7))

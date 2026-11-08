extends Node2D
class_name Guard
## A summoned defender (Guards card). Hunts the nearest enemy for a short time,
## strikes it, then vanishes. Enemies ignore guards; they are a damage burst.

var data: Dictionary
var life := 15.0
var damage := 1.5
var speed := 80.0
var _hit := 0.0
var _age := 0.0

func setup(card: Dictionary, pos: Vector2) -> void:
	data = card
	position = pos
	life = card.duration
	damage = card.damage

func _ready() -> void:
	z_index = 5
	add_to_group("guard")
	add_to_group("net")

func _nearest():
	var best = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or (e.get("charm_time") != null and e.charm_time > 0.0):
			continue
		if best == null or e.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = e
	return best

func _physics_process(delta: float) -> void:
	_age += delta
	_hit -= delta
	life -= delta
	if life <= 0.0:
		WeaponFx.spawn(get_parent(), "burst", global_position, Color(0.7, 0.85, 1.0), {"radius": 10.0, "life": 0.2})
		queue_free()
		return
	var t = _nearest()
	if t != null:
		var to: Vector2 = t.global_position - global_position
		if to.length() > 12.0:
			global_position += to.normalized() * speed * delta
		elif _hit <= 0.0:
			_hit = 0.5
			t.spell_damage(damage)
	queue_redraw()

func _draw() -> void:
	var bob := sin(_age * 10.0) * 1.2
	draw_circle(Vector2(0, 7), 5.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-4, -4 + bob, 8, 10), Color.BLACK)
	draw_rect(Rect2(-3, -3 + bob, 6, 8), Color(0.55, 0.7, 1.0))
	draw_circle(Vector2(0, -7 + bob), 4.5, Color.BLACK)
	draw_circle(Vector2(0, -7 + bob), 3.5, Color(0.9, 0.9, 1.0))
	draw_line(Vector2(5, -2 + bob), Vector2(9, -9 + bob), Color(1, 1, 0.8), 1.5)
	if life < 3.0:
		modulate.a = 0.5 + 0.5 * sin(_age * 16.0)

extends StaticBody2D
## A pillar of ice the Frost Wyrm raises: solid cover. Its breath is stopped by the pillar and chips it away, so it protects you for
## one sweep and cracks. It melts by itself after a while.

var hp := 6.0
var life := 16.0
var _age := 0.0
var _flash := 0.0

func _ready() -> void:
	add_to_group("ice_pillar")
	add_to_group("net")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	z_index = 2

## The breath hits it: it takes the damage and cracks; false once it has shattered.
func absorb(amount: float) -> void:
	hp -= amount
	_flash = 0.12
	if hp <= 0.0:
		WeaponFx.spawn(get_parent(), "burst", global_position, Color(0.7, 0.9, 1.0), {"radius": 18.0, "life": 0.3})
		queue_free()

func _physics_process(delta: float) -> void:
	_age += delta
	_flash = maxf(0.0, _flash - delta)
	if _age >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var rise := clampf(_age / 0.5, 0.0, 1.0)                    # grows out of the ground
	var h := 26.0 * rise
	var fade := clampf((life - _age) / 1.5, 0.0, 1.0)
	var col := Color(0.62, 0.86, 1.0, fade)
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	var dark := Color(0.28, 0.5, 0.78, fade)
	draw_circle(Vector2(0, 4), 12.0, Color(0, 0, 0, 0.25 * fade))
	var pts := PackedVector2Array([Vector2(-9, 4), Vector2(-6, 4 - h * 0.7), Vector2(0, 4 - h), Vector2(7, 4 - h * 0.65), Vector2(10, 4)])
	draw_colored_polygon(pts, Color.BLACK)
	var inner := PackedVector2Array([Vector2(-7, 3), Vector2(-4.5, 4 - h * 0.66), Vector2(0, 4 - h * 0.92), Vector2(5.5, 4 - h * 0.6), Vector2(8, 3)])
	draw_colored_polygon(inner, col)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 4 - h * 0.9), Vector2(5.5, 4 - h * 0.6), Vector2(8, 3), Vector2(1, 3)]), dark)
	if hp < 3.5:                                                  # cracked
		draw_line(Vector2(-2, 2 - h * 0.2), Vector2(1, -h * 0.5), Color(1, 1, 1, 0.8 * fade), 1.0)

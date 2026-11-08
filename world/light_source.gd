extends Node2D
class_name LightSource
## A bare patch of light: a flare, the flash of a fireball, a campfire. It joins group "light"
## (see Game.lit_at), glows at night and removes itself after `life` seconds (0 = stays).
## Replicated like every other gameplay node (group "net").

var light_radius := 60.0
var life := 2.0
var color := Color(1.0, 0.8, 0.45)
var _age := 0.0

static func spawn(world: Node, pos: Vector2, radius: float, secs: float, col := Color(1.0, 0.8, 0.45)) -> LightSource:
	var l := LightSource.new()
	l.position = pos
	l.light_radius = radius
	l.life = secs
	l.color = col
	world.add_child.call_deferred(l)
	return l

func _ready() -> void:
	add_to_group("light")
	add_to_group("net")
	z_index = 9
	GlowLight.attach(self, light_radius, color, 0.6)

func _physics_process(delta: float) -> void:
	_age += delta
	if life > 0.0 and _age >= life:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 if life <= 0.0 else clampf((life - _age) / 0.6, 0.0, 1.0)
	draw_circle(Vector2.ZERO, light_radius * 0.18, Color(color, 0.5 * fade))
	draw_arc(Vector2.ZERO, light_radius, 0, TAU, 40, Color(color, 0.18 * fade), 1.0)

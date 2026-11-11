extends StaticBody2D
class_name Gong
## The gong above the well. Stand next to it and interact (E / A) to ring it: the next wave starts right away, so a strong team can
## skip the wait. It swings and rings out with a big bronze sound; a short pause stops one ring from calling two waves.
## Players 2-4 and LAN clients ring it through Net._interact like everything else.

const POS := Vector2(2, -52)           # just above the well
const PAUSE := 4.0                     # seconds before it can be rung again
const REACH := 34.0                    # how close you stand to ring it (the same for every player)

var hovering := false
var _swing := 0.0                      # how hard it is swinging now, 0 to 1
var _ring := 0.0                       # the ring of sound drawn around it
var _pause := 0.0

func _ready() -> void:
	add_to_group("gong")
	add_to_group("net")
	position = POS
	collision_layer = 4                # solid, like the well
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 20)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	var area := Area2D.new()           # where player 1 can ring it from
	area.collision_layer = 0
	area.collision_mask = 1
	var circle := CircleShape2D.new()
	circle.radius = REACH - 8.0
	var cs := CollisionShape2D.new()
	cs.shape = circle
	cs.position = Vector2(0, 8)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b): if b.is_in_group("player") and !b.get("remote_controlled"): hovering = true)
	area.body_exited.connect(func(_b): hovering = Game.has_local_player(area))
	z_index = 2

## Ring the gong: the sound, the swing, and the next wave.
func ring() -> void:
	if _pause > 0.0:
		return
	_pause = PAUSE
	_swing = 1.0
	_ring = 1.0
	Sfx.play("gong", 0.02)
	var w = Game.world
	if w != null and w.has_method("call_next_wave"):
		w.call_next_wave()

func _process(delta: float) -> void:
	_pause = maxf(0.0, _pause - delta)
	_swing = maxf(0.0, _swing - delta * 0.55)
	_ring = maxf(0.0, _ring - delta * 0.9)
	queue_redraw()

func _draw() -> void:
	var sway := sin(Time.get_ticks_msec() / 1000.0 * 9.0) * _swing * 0.25         # the disc swings and settles
	var wood := Color("6b4a2a")
	var wood_hi := Color("8f6a3e")
	# two posts and a crossbar, with a little shadow
	draw_circle(Vector2(0, 11), 14.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-14, -17, 5, 29), Color.BLACK)
	draw_rect(Rect2(14 - 4, -17, 5, 29), Color.BLACK)
	draw_rect(Rect2(-13, -16, 3, 27), wood)
	draw_rect(Rect2(10, -16, 3, 27), wood)
	draw_rect(Rect2(-15, -19, 30, 6), Color.BLACK)
	draw_rect(Rect2(-14, -18, 28, 4), wood_hi)
	# the bronze disc hangs from the bar
	var pivot := Vector2(0, -14)
	draw_set_transform(pivot, sway, Vector2.ONE)
	draw_line(Vector2(0, 0), Vector2(0, 5), Color.BLACK, 2.0)
	draw_circle(Vector2(0, 14), 11.0, Color.BLACK)
	draw_circle(Vector2(0, 14), 9.6, Color("b8862b"))
	draw_circle(Vector2(0, 14), 6.5, Color("d9a93f"))
	draw_circle(Vector2(0, 14), 2.6, Color("f4d36a"))
	draw_arc(Vector2(0, 14), 8.2, 3.6, 4.9, 8, Color(1, 1, 0.8, 0.8), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _ring > 0.0:
		draw_arc(Vector2(0, 0), 14.0 + (1.0 - _ring) * 60.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, _ring * 0.7), 2.0)
		draw_arc(Vector2(0, 0), 8.0 + (1.0 - _ring) * 40.0, 0.0, TAU, 32, Color(1.0, 0.8, 0.4, _ring * 0.5), 1.5)
	if hovering:
		draw_arc(Vector2(0, 8), 18.0, 0, TAU, 24, Color(1, 1, 0.5, 0.9), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-50, -24), "Gong (Space): next wave", HORIZONTAL_ALIGNMENT_CENTER, 100.0, 8, Color(1, 0.95, 0.6))

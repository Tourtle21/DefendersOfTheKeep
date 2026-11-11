extends StaticBody2D
class_name Gong
## The gong above the well. Hit it with anything (the sword, a weapon, a spell, an arrow) and the next wave starts right away,
## so a strong team can skip the wait. It rings and swings when struck; a short pause stops one swing from calling two waves.
## Hits arrive as take_damage (the sword's hitbox) or spell_damage (everything else), like on an enemy.

const POS := Vector2(2, -52)           # just above the well
const PAUSE := 4.0                     # seconds before it can be struck again

var is_taking_damage := false          # (the sword's hitbox asks for this; the gong never blocks a swing)
var hit_radius := 13.0                 # (weapons hit things within this reach of their centre)
var _swing := 0.0                      # how hard it is swinging now, 0 to 1
var _ring := 0.0                       # the ring of sound drawn around it
var _pause := 0.0
var _hint := 0.0

func _ready() -> void:
	add_to_group("gong")
	add_to_group("net")
	position = POS
	collision_layer = 2                # the layer enemies are on: the sword's hitbox and projectiles see it
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 20)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	z_index = 2

func take_damage(_origin: Vector2, _amount := 0.0) -> void:
	_strike()

func spell_damage(_amount: float, _element := "", _aoe := false) -> void:
	_strike()

# Weapons treat everything they hit like an enemy (knockback, slows, stuns, marks): the gong just takes them as a strike.
var hit_from := Vector2.ZERO
func push(_vel: Vector2, _time := 0.0) -> void:
	pass
func apply_slow(_mult: float, _time: float) -> void:
	pass
func stun(_secs := 0.0) -> void:
	pass

func _strike() -> void:
	if _pause > 0.0:
		return
	_pause = PAUSE
	_swing = 1.0
	_ring = 1.0
	Sfx.play("wave_horn", 0.0)
	var w = Game.world
	if w != null and w.has_method("call_next_wave"):
		w.call_next_wave()

func _process(delta: float) -> void:
	_pause = maxf(0.0, _pause - delta)
	_swing = maxf(0.0, _swing - delta * 0.7)
	_ring = maxf(0.0, _ring - delta * 1.1)
	_hint = 0.0
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.get("remote_controlled") and p.global_position.distance_to(global_position) < 70.0:
			_hint = 1.0
	queue_redraw()

func _draw() -> void:
	var sway := sin(Time.get_ticks_msec() / 1000.0 * 11.0) * _swing * 0.22         # the disc swings and settles
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
		draw_arc(Vector2(0, 0), 14.0 + (1.0 - _ring) * 44.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, _ring * 0.7), 2.0)
		draw_arc(Vector2(0, 0), 8.0 + (1.0 - _ring) * 30.0, 0.0, TAU, 32, Color(1.0, 0.8, 0.4, _ring * 0.5), 1.5)
	if _hint > 0.0 and _pause <= 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(-44, -24), "Hit the gong: next wave", HORIZONTAL_ALIGNMENT_CENTER, 88.0, 8, Color(1, 0.95, 0.6))

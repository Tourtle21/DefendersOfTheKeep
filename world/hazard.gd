extends Node2D
class_name Hazard
## A patch of ground with an effect: slow (quicksand, mud, snow drifts), burn (lava) or
## heal (crystal shrines). Affects the player and enemies standing inside it.

var kind := "slow"
var factor := 0.5
var radius := 34.0
var color := Color(0.6, 0.5, 0.3, 0.5)
var player_damage := 30.0   # what a burn tick does to a player
var hurts_enemies := true   # false: a patch an enemy made, which only hurts players
var lifetime := 0.0         # > 0: the patch fades and removes itself after this many seconds
var _tick := 0.0
var _t := 0.0

## Combined slowdown of every slow hazard covering a point.
static func slow_at(tree: SceneTree, pos: Vector2) -> float:
	var m := 1.0
	for h in tree.get_nodes_in_group("hazard"):
		if h.kind == "slow" and h.global_position.distance_to(pos) <= h.radius:
			m = min(m, h.factor)
	return m

func _ready() -> void:
	add_to_group("hazard")
	add_to_group("net")
	z_index = -1

func _physics_process(delta: float) -> void:
	_t += delta
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
	_tick += delta
	var burn_now := false
	if _tick >= 1.0:
		_tick = 0.0
		burn_now = true
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.global_position.distance_to(global_position) <= radius:
			if kind == "heal":
				p.heal(8.0 * delta)
			elif kind == "burn" and burn_now:
				p.take_damage(global_position, player_damage)
	for e in get_tree().get_nodes_in_group("enemy"):
		if !hurts_enemies and kind == "burn":
			break
		if !is_instance_valid(e) or e.is_in_group("boss") or e.global_position.distance_to(global_position) > radius:
			continue
		if kind == "slow":
			e.apply_slow(factor, 0.25)
		elif kind == "burn" and burn_now:
			e.spell_damage(1.5, "fire" if kind == "burn" else "", true)
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * (0.8 + 0.2 * pulse)))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 28, Color(color.lightened(0.3), 0.7), 1.5)
	match kind:
		"burn":
			for i in 5:
				var a := _t * 0.8 + i * 1.3
				draw_circle(Vector2.from_angle(a) * radius * 0.5 * (0.5 + 0.5 * sin(_t + i)), 2.0 + pulse, Color(1.0, 0.7, 0.2, 0.8))
		"heal":
			draw_circle(Vector2.ZERO, radius * 0.25 * (0.8 + 0.4 * pulse), Color(0.95, 0.85, 1.0, 0.9))
		_:
			for i in 4:
				var a := i * 1.7 + 0.5
				draw_circle(Vector2.from_angle(a) * radius * 0.45, 2.0, Color(color.darkened(0.3), 0.8))

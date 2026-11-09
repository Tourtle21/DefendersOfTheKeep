extends Node2D
## A patch of ground a boss leaves behind: it warms up (harmless, shown faintly), then slows and hurts whoever
## stands in it until it fades. Used by the Sand Colossus (quicksand), Frost Wyrm (blizzard), Magma Titan
## (lava) and Bog Mother (poison). Joins the "hazard" group once active so Hazard.slow_at sees it.

var radius := 36.0
var life := 6.0
var warmup := 0.8
var dps_hit := 10.0              # damage per tick
var tick_every := 0.8
var factor := 1.0                # speed multiplier while inside (1 = no slow)
var color := Color(0.6, 0.5, 0.3)
var kind := "warm"               # "warm" until active, then "slow"
var _age := 0.0
var _tick := 0.0

func _ready() -> void:
	add_to_group("net")
	z_index = -1

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= warmup + life:
		queue_free()
		return
	if _age >= warmup and kind == "warm":
		kind = "slow"
		add_to_group("hazard")
	if kind == "slow":
		_tick += delta
		if _tick >= tick_every:
			_tick = 0.0
			for pl in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(pl) and !pl.get("downed") and pl.global_position.distance_to(global_position) <= radius:
					pl.take_damage(global_position, dps_hit)
	queue_redraw()

func _draw() -> void:
	var active := _age >= warmup
	var fade := clampf((warmup + life - _age) / 1.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 5.0)
	if !active:
		draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * _age / warmup), 0, TAU, 28, Color(color.lightened(0.3), 0.8), 2.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
		return
	draw_circle(Vector2.ZERO, radius, Color(color, 0.5 * fade))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color.lightened(0.35), 0.9 * fade), 2.0)
	for i in 5:
		var a := _age * 0.7 + i * 1.26
		draw_circle(Vector2.from_angle(a) * radius * (0.35 + 0.3 * sin(_age + i)), 2.0 + pulse, Color(color.lightened(0.5), 0.8 * fade))

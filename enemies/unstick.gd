extends RefCounted
class_name Unstick
## Gets a walker out of trouble when it keeps pushing into something. After about half a
## second of pushing without moving it either chips at what is in front (trees, rocks,
## barricades) or sidesteps around it. Used by enemies and bosses.

var chip := true                # chew through trees and rocks in the way (enemies do, critters do not)
static var enabled := true       # tests switch it off to show the old behaviour
var stuck := 0.0
var side_time := 0.0
var side_dir := Vector2.ZERO
var _chip := 0.0
var _last := Vector2.INF

## The velocity to use: the wanted direction, or a sidestep while one is running.
func steer(dir: Vector2, speed: float, delta: float) -> Vector2:
	if enabled and side_time > 0.0:
		side_time -= delta
		return (dir * 0.35 + side_dir).normalized() * speed
	return dir * speed

## Call after move_and_slide(). `wanted` is the speed the walker tried to move at.
func after_move(body: CharacterBody2D, dir: Vector2, wanted: float, delta: float) -> void:
	if !enabled:
		return
	var here := body.global_position
	var moved: float = 0.0 if _last == Vector2.INF else here.distance_to(_last)
	_last = here
	if wanted < 2.0 or side_time > 0.0:
		stuck = maxf(0.0, stuck - delta)
		return
	if moved < wanted * delta * 0.25:
		stuck += delta
	else:
		stuck = maxf(0.0, stuck - delta * 2.0)
	if stuck < 0.45:
		return
	_chip -= delta
	var chipped := false
	for i in body.get_slide_collision_count():
		var c = body.get_slide_collision(i).get_collider()
		if chip and c != null and c.is_in_group("breakable") and _chip <= 0.0:
			c.take_damage(here)            # chew through a tree or rock in the way
			_chip = 0.7
			chipped = true
	if chipped:
		return
	# otherwise walk around: pick the free side (or a random one) for a short while
	var perp := Vector2(-dir.y, dir.x)
	var left_free := !body.test_move(body.global_transform, perp * 8.0)
	var right_free := !body.test_move(body.global_transform, -perp * 8.0)
	var sign := 1.0 if (left_free and !right_free) else (-1.0 if (right_free and !left_free) else (1.0 if randf() < 0.5 else -1.0))
	side_dir = perp * sign
	side_time = 0.7
	stuck = 0.0
	if body.has_method("make_path"):
		body.make_path()

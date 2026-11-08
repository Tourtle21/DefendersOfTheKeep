extends Node2D
class_name Turret
## An arrow turret on top of each tower. It fires at the nearest enemy in range but has
## limited ammo. Whoever is in the keep reloads it (click the tower in the wide view),
## paying sticks from the keep's pool, so explorers have to keep bringing sticks home.

const BASE_AMMO := 12

func max_ammo() -> int:
	return BASE_AMMO + int(Game.bonus("turret_ammo"))
const RELOAD_COST := {"stick": 2}
var ammo := BASE_AMMO
var turret_range := 135.0
var fire_delay := 1.1
var _cd := 0.5
const ARROW_SPEED := 300.0
const MUZZLE := Vector2(0, -22)       # where the arrow leaves the tower top
var _seen := {}                       # enemy instance id -> recent [time, position] samples, so shots can lead a moving target

func _ready() -> void:
	add_to_group("turret")
	add_to_group("net")
	z_index = 6

## A tower only defends once its sector is open and it is visible: the towers under the
## grey covers (or hidden ones) must not shoot from places the player cannot see.
func online() -> bool:
	var tower := get_parent()
	return tower != null and !Game.crystal_away() and tower.is_visible_in_tree() and Game.sector_at(tower.position) in Game.sectors_unlocked

func _process(delta: float) -> void:
	if Rep.is_puppet(self) or !online():
		queue_redraw()
		return
	_track(delta)
	_cd -= delta
	if _cd <= 0.0 and ammo > 0:
		var best = null
		var origin := global_position
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and !e.is_queued_for_deletion():
				var d: float = e.global_position.distance_to(origin)
				if d <= turret_range and (best == null or d < best.global_position.distance_to(origin)):
					best = e
		if best != null:
			var muzzle := origin + MUZZLE
			var dir: Vector2 = (_aim_point(best, muzzle) - muzzle).normalized()
			WeaponProjectile.shoot(get_parent().get_parent(), muzzle + dir * 6.0, dir, ARROW_SPEED, 1.5, Color(0.95, 0.85, 0.5), 0.55, 0, 50.0)
			ammo -= 1
			Sfx.play("whoosh", 0.1, 1.8)
			_cd = fire_delay
	queue_redraw()

## Remember where each enemy has been over the last third of a second, so its velocity can be measured
## smoothly (positions update in steps, so a frame-to-frame difference is far too noisy).
const TRACK_WINDOW := 0.33
func _track(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var live := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var id: int = e.get_instance_id()
		var hist: Array = _seen.get(id, [])
		if hist.is_empty() or e.global_position != hist[-1][1]:
			hist.append([now, e.global_position])
		while hist.size() > 2 and now - hist[0][0] > TRACK_WINDOW:
			hist.pop_front()
		live[id] = hist
	_seen = live

func _velocity_of(e: Node2D) -> Vector2:
	var hist: Array = _seen.get(e.get_instance_id(), [])
	if hist.size() < 2:
		return Vector2.ZERO
	var dt: float = hist[-1][0] - hist[0][0]
	return (hist[-1][1] - hist[0][1]) / dt if dt > 0.12 else Vector2.ZERO

## Where to aim so the arrow meets a moving enemy: the spot it will reach by the time the arrow gets there.
func _aim_point(e: Node2D, from: Vector2) -> Vector2:
	var v := _velocity_of(e)
	var p: Vector2 = e.global_position
	var t := 0.0
	for i in 3:
		t = from.distance_to(p + v * t) / ARROW_SPEED
	return p + v * t

## Returns true if the turret was reloaded.
func reload() -> bool:
	if !Game.in_base or Game.crystal_away() or ammo >= max_ammo() or !Game.can_afford(RELOAD_COST):
		return false
	Game.pay(RELOAD_COST)
	ammo = max_ammo()
	WeaponFx.spawn(get_parent().get_parent(), "ring", global_position + Vector2(0, -20), Color(1.0, 0.9, 0.5), {"radius": 18.0, "life": 0.3})
	return true

func _unhandled_input(event: InputEvent) -> void:
	if Game.in_base and !Game.card_aim_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_global_mouse_position().distance_to(global_position + Vector2(0, -16)) < 24.0:
			reload()

func _draw() -> void:
	if !Game.sector_at(get_parent().position) in Game.sectors_unlocked:
		return                       # a tower under a locked sector's cover shows nothing
	# ammo pips above the tower
	for i in max_ammo():
		var x := -13.0 + i * 2.3
		draw_rect(Rect2(x, -44, 1.8, 3.5), Color(1.0, 0.85, 0.3) if i < ammo else Color(0.15, 0.1, 0.1, 0.85))
	if ammo == 0:
		draw_string(ThemeDB.fallback_font, Vector2(-14, -48), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.4, 0.3))
	if Game.in_base:
		draw_arc(Vector2.ZERO, turret_range, 0, TAU, 48, Color(1, 1, 1, 0.12), 1.0)
		if ammo < max_ammo():
			draw_string(ThemeDB.fallback_font, Vector2(-16, 12), "click: reload (2 stick)", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 0.7, 0.8))

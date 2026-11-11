extends Node2D
class_name Guard
## A summoned defender (Guards card). It has health instead of a timer: it hunts the nearest enemy and fights it until it falls.
## Enemies treat a guard like a player (Enemy._aggro_candidates): a guard that walks up to one draws it, and the enemy hits back.

var data: Dictionary
var hp := 20.0
var max_hp := 20.0
var downed := false                 # (enemies ask this of everything they might attack)
var damage := 1.2                   # one slash (they swing about once a second)
var speed := 80.0
var _hit := 0.0
var _age := 0.0

func setup(card: Dictionary, pos: Vector2) -> void:
	data = card
	position = pos
	max_hp = card.hp
	hp = max_hp
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

## An enemy hits the guard (Enemy contact and its moves call this, the same as on a player).
func take_damage(_origin: Vector2, amount := 10.0) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 0.15
	if hp <= 0.0:
		WeaponFx.spawn(get_parent(), "burst", global_position, Color(0.7, 0.85, 1.0), {"radius": 10.0, "life": 0.2})
		queue_free()

var _flash := 0.0
var strikes := 0                       # swings so far
var _windup := 0.0                     # > 0: raising the blade, the strike lands when it runs out
var _swing := 0.0                      # > 0: the slash is showing
var _aim := Vector2.RIGHT
const REACH := 20.0                    # how far the slash reaches
const WINDUP := 0.3
const COOLDOWN := 1.1                  # a swing, a pause, a swing: not a constant stream

func _physics_process(delta: float) -> void:
	_age += delta
	_hit -= delta
	_flash -= delta
	_swing -= delta
	if _windup > 0.0:                                   # winding up: it stands still, then the slash lands
		_windup -= delta
		if _windup <= 0.0:
			_strike()
		queue_redraw()
		return
	var t = _nearest()
	if t != null:
		var to: Vector2 = t.global_position - global_position
		_aim = to.normalized() if to.length() > 0.1 else _aim
		if to.length() > REACH * 0.7:
			global_position += to.normalized() * speed * delta
		elif _hit <= 0.0:
			_windup = WINDUP
			_hit = COOLDOWN
	queue_redraw()

## The slash: everything in front of the guard within reach takes the hit.
func _strike() -> void:
	strikes += 1
	_swing = 0.18
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or (e.get("charm_time") != null and e.charm_time > 0.0):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= REACH and (to.length() < 4.0 or _aim.dot(to.normalized()) > 0.2):
			e.spell_damage(damage)

func _draw() -> void:
	var bob := sin(_age * 10.0) * 1.2
	draw_circle(Vector2(0, 7), 5.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-4, -4 + bob, 8, 10), Color.BLACK)
	draw_rect(Rect2(-3, -3 + bob, 6, 8), Color(0.55, 0.7, 1.0))
	draw_circle(Vector2(0, -7 + bob), 4.5, Color.BLACK)
	draw_circle(Vector2(0, -7 + bob), 3.5, Color(0.9, 0.9, 1.0))
	var blade := Vector2(5, -2 + bob)                                    # the blade: raised while winding up, then it slashes through an arc
	var tip := Vector2(9, -9 + bob)
	if _windup > 0.0:
		tip = blade + Vector2(1, -12)
	draw_line(blade, tip, Color(1, 1, 0.8), 1.5)
	if _swing > 0.0:
		draw_arc(Vector2.ZERO, REACH * 0.8, _aim.angle() - 0.9, _aim.angle() + 0.9, 10, Color(1, 1, 0.9, clampf(_swing / 0.18, 0.0, 1.0)), 2.0)
	modulate = Color(1, 0.5, 0.5) if _flash > 0.0 else Color.WHITE
	draw_rect(Rect2(-6, -16, 12, 2), Color(0, 0, 0, 0.7))           # health
	draw_rect(Rect2(-6, -16, 12.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Color(0.5, 0.9, 0.5))

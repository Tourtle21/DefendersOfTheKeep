extends Node2D
class_name Guard
## A summoned defender (Guards card). It has health instead of a timer: it hunts the nearest enemy and fights it until it falls.
## Enemies treat a guard like a player (Enemy._aggro_candidates): a guard that walks up to one draws it, and the enemy hits back.
## The card's tier changes the guard itself (look, reach, attack), on top of the usual health and damage scaling:
##   1 Squire     a short sword, one slash
##   2 Footman    + a shield and a longer reach
##   3 Knight     + a plumed helmet; every swing is a double strike
##   4 Captain    + a cape; draws enemies from further away; every third swing is a shockwave all round
##   5 Champion   + a glowing blade; every strike sends a sword beam down the line
##   6 Paladin    + a halo; every strike is a whirl all round, and it mends the guards and players beside it

const BODY := [Color(0.55, 0.7, 1.0), Color(0.45, 0.8, 0.85), Color(0.7, 0.75, 0.85), Color(0.85, 0.35, 0.35), Color(1.0, 0.82, 0.3), Color(0.95, 0.95, 1.0)]
const NAMES := ["Squire", "Footman", "Knight", "Captain", "Champion", "Paladin"]

var data: Dictionary
var tier := 1
var hp := 20.0
var max_hp := 20.0
var downed := false                 # (enemies ask this of everything they might attack)
var damage := 1.2                   # one slash (they swing about once a second)
var speed := 80.0
var pull := 0.0                     # tier 4+: extra distance enemies notice this guard from (Enemy._update_aggro)
var _hit := 0.0
var _age := 0.0
var _flash := 0.0
var strikes := 0                    # swings so far
var _windup := 0.0                  # > 0: raising the blade, the strike lands when it runs out
var _swing := 0.0                   # > 0: the slash is showing
var _echo := -1.0                   # tier 3+: the second strike of a double swing
var _aim := Vector2.RIGHT
const WINDUP := 0.3
const COOLDOWN := 1.1               # a swing, a pause, a swing: not a constant stream

func setup(card: Dictionary, pos: Vector2) -> void:
	data = card
	position = pos
	tier = clampi(int(card.get("tier", 1)), 1, 6)
	max_hp = card.hp
	hp = max_hp
	damage = card.damage
	pull = 40.0 if tier >= 4 else 0.0
	scale = Vector2.ONE * (1.0 + 0.06 * (tier - 1))

func reach() -> float:
	return 20.0 + (4.0 if tier >= 2 else 0.0) + (4.0 if tier >= 4 else 0.0)

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
		WeaponFx.spawn(get_parent(), "burst", global_position, BODY[tier - 1], {"radius": 10.0, "life": 0.2})
		queue_free()

func _physics_process(delta: float) -> void:
	_age += delta
	_hit -= delta
	_flash -= delta
	_swing -= delta
	if tier >= 6 and hp > 0.0:
		_mend(delta)
	if _echo > 0.0:                                     # a double strike: the second blow lands a moment after the first
		_echo -= delta
		if _echo <= 0.0:
			_strike(false)
	if _windup > 0.0:                                   # winding up: it stands still, then the slash lands
		_windup -= delta
		if _windup <= 0.0:
			_strike(true)
		queue_redraw()
		return
	var t = _nearest()
	if t != null:
		var to: Vector2 = t.global_position - global_position
		_aim = to.normalized() if to.length() > 0.1 else _aim
		if to.length() > reach() * 0.7:
			global_position += to.normalized() * speed * delta
		elif _hit <= 0.0:
			_windup = WINDUP
			_hit = COOLDOWN
	queue_redraw()

## Tier 6: a slow mend for the guards and players beside the paladin.
func _mend(delta: float) -> void:
	for g in get_tree().get_nodes_in_group("guard"):
		if g != self and is_instance_valid(g) and g.global_position.distance_to(global_position) <= 60.0:
			g.hp = minf(g.max_hp, g.hp + 1.5 * delta)
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.has_method("heal") and p.global_position.distance_to(global_position) <= 60.0:
			p.heal(1.0 * delta)

## One swing of the blade. `first` is the main blow (a Knight and above follow it with a second).
func _strike(first: bool) -> void:
	_swing = 0.18
	if first:
		strikes += 1
		if tier >= 3:
			_echo = 0.22
	var around: bool = tier >= 6 or (tier >= 4 and strikes % 3 == 0 and first)        # the Paladin always whirls, the Captain every third swing
	var r := reach() * (1.8 if (tier >= 4 and strikes % 3 == 0 and first and tier < 6) else 1.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or (e.get("charm_time") != null and e.charm_time > 0.0):
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() <= r and (around or to.length() < 4.0 or _aim.dot(to.normalized()) > 0.2):
			e.spell_damage(damage)
	if around:
		WeaponFx.spawn(get_parent(), "ring", global_position, BODY[tier - 1], {"radius": r, "life": 0.25})
	if tier >= 5 and first:
		_beam()

## Tier 5+: a sword beam down the line the guard is facing, hitting everything along it.
func _beam() -> void:
	var from := global_position
	var len := 78.0
	WeaponFx.spawn(get_parent(), "line", from, Color(1.0, 0.95, 0.6), {"dir": _aim, "length": len, "width": 4.0, "life": 0.2})
	for e in get_tree().get_nodes_in_group("enemy"):
		if !is_instance_valid(e) or (e.get("charm_time") != null and e.charm_time > 0.0):
			continue
		var rel: Vector2 = e.global_position - from
		var along := rel.dot(_aim)
		if along > reach() and along <= len and absf(rel.cross(_aim)) <= 9.0:          # (the close range is the slash's)
			e.spell_damage(damage * 0.8)

func _draw() -> void:
	var col: Color = BODY[tier - 1]
	var bob := sin(_age * 10.0) * 1.2
	draw_circle(Vector2(0, 7), 5.0, Color(0, 0, 0, 0.25))
	if tier >= 4:                                                                       # a cape behind
		draw_rect(Rect2(-5, -3 + bob, 10, 11), Color(0.7, 0.15, 0.2) if tier < 6 else Color(0.8, 0.8, 1.0))
	draw_rect(Rect2(-4, -4 + bob, 8, 10), Color.BLACK)
	draw_rect(Rect2(-3, -3 + bob, 6, 8), col)
	if tier >= 3:                                                                       # armour: a darker breastplate and belt
		draw_rect(Rect2(-3, -1 + bob, 6, 3), col.darkened(0.25))
	draw_circle(Vector2(0, -7 + bob), 4.5, Color.BLACK)
	draw_circle(Vector2(0, -7 + bob), 3.5, Color(0.9, 0.9, 1.0) if tier < 3 else col.lightened(0.2))        # a helmet from tier 3
	if tier >= 3:
		draw_rect(Rect2(-0.5, -14 + bob, 1.5, 4), Color(0.9, 0.2, 0.2) if tier < 5 else Color(1.0, 0.85, 0.3))   # the plume
	if tier >= 2:                                                                       # a shield on the other arm
		draw_rect(Rect2(-8, -3 + bob, 4, 7), Color.BLACK)
		draw_rect(Rect2(-7, -2 + bob, 2, 5), col.lightened(0.15))
	var blade := Vector2(5, -2 + bob)                                                   # the blade: raised while winding up, then it slashes
	var tip := Vector2(9, -9 + bob) if tier < 3 else Vector2(11, -12 + bob)
	if _windup > 0.0:
		tip = blade + Vector2(1, -12)
	draw_line(blade, tip, Color(1, 1, 0.8) if tier < 5 else Color(1.0, 0.95, 0.5), 1.5 if tier < 5 else 2.5)
	if tier >= 5:
		draw_circle(tip, 2.0 + sin(_age * 8.0) * 0.5, Color(1.0, 0.95, 0.5, 0.5))      # a glowing blade
	if tier >= 6:                                                                       # a halo
		draw_arc(Vector2(0, -15 + bob), 4.0, 0, TAU, 14, Color(1.0, 0.95, 0.6), 1.5)
	if _swing > 0.0:
		draw_arc(Vector2.ZERO, reach() * 0.8, _aim.angle() - 0.9, _aim.angle() + 0.9, 10, Color(1, 1, 0.9, clampf(_swing / 0.18, 0.0, 1.0)), 2.0)
	modulate = Color(1, 0.5, 0.5) if _flash > 0.0 else Color.WHITE
	draw_rect(Rect2(-6, -19 if tier >= 3 else -16, 12, 2), Color(0, 0, 0, 0.7))        # health
	draw_rect(Rect2(-6, -19 if tier >= 3 else -16, 12.0 * clampf(hp / max_hp, 0.0, 1.0), 2), Color(0.5, 0.9, 0.5))

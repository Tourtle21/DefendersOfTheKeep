extends Weapon
## Hammer: hold right click to charge a slam (you move slowly while charging).
## Bigger charge = bigger radius, damage and stun. Releasing in the gold window
## at the end of the charge is a perfect slam with extra damage.

const MAX_CHARGE := 1.2
const PERFECT_FROM := 0.95

var _charging := false
var _charge := 0.0

func _init() -> void:
	hold_ability = true
	weapon_id = "hammer"
	element = "crush"
	weapon_name = "Hammer"
	ability_name = "Charged Slam (hold)"
	attack_name = "Smash"
	dash_name = "Leap Slam"
	ultimate_name = "Meteor"
	preview_ultimate = {"kind": "circle", "range": 120.0, "radius": 60.0}
	dash_cooldown = 5.0
	preview_dash = 70.0
	icon_path = "res://items/weapons/icons/hammer.png"
	attack_cooldown = 0.85
	ability_cooldown = 7.0
	reach = 10.0
	icon_scale = 0.65

func attack() -> void:
	swing(1.1, 0.22)
	await get_tree().create_timer(0.2).timeout
	if !is_inside_tree():
		return
	var o: Vector2 = player.global_position
	var c: Vector2 = o + aim * 22.0
	fx("ring", c, Color(1.0, 0.6, 0.2), {"radius": 26.0, "life": 0.25})
	player.shake(1.5, 0.12)
	for e in WeaponUtil.enemies_in_circle(get_tree(), c, 26.0):
		WeaponUtil.hit(e, 3.0, o, 260.0)
	WeaponUtil.hit_breakables(get_tree(), c, 26.0, ["stone"])   # good at breaking rocks

func use_ability() -> void:
	if _ability_cd > 0.0 or _charging:
		return
	_charging = true
	_charge = 0.0
	player.speed_mult = 0.45

func _process(delta: float) -> void:
	super(delta)
	if _charging:
		_charge = min(MAX_CHARGE, _charge + delta)
		swing_offset = -0.9 - 0.4 * (_charge / MAX_CHARGE)
	queue_redraw()

func _draw() -> void:
	super()
	if !_charging:
		return
	var ratio := _charge / MAX_CHARGE
	var r := 30.0 + 40.0 * ratio
	var perfect := _charge >= PERFECT_FROM
	var col := Color(1.0, 0.85, 0.2) if perfect else Color(1.0, 0.5, 0.2)
	draw_circle(Vector2.ZERO, r, Color(col, 0.12))
	draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col, 0.9), 2.0 if !perfect else 3.0)

func dash_attack() -> void:
	# Leap Slam: jump toward the cursor and land with a shockwave
	var target := cursor_target(70.0)
	var d: Vector2 = target - player.global_position
	if d.length() < 8.0:
		d = aim * 20.0
	player.dash(d.normalized(), min(70.0, d.length()), 0.2)
	ground_strike(player.global_position + d.limit_length(70.0), 30.0, 0.22, 3.0, 260.0, Color(1.0, 0.5, 0.2), 0.5, ["stone"])

func release_ability() -> void:
	if !_charging:
		return
	_charging = false
	player.speed_mult = 1.0
	swing_offset = 0.0
	var ratio := _charge / MAX_CHARGE
	var perfect := _charge >= PERFECT_FROM
	var radius := 30.0 + 40.0 * ratio
	var dmg := 2.0 + 4.0 * ratio
	if perfect:
		dmg *= 1.5
	var stun := 0.5 + 1.5 * ratio
	_ability_cd = ability_cooldown
	var o: Vector2 = player.global_position
	var col := Color(1.0, 0.85, 0.2) if perfect else Color(1.0, 0.5, 0.15)
	fx("ring", o, col, {"radius": radius, "life": 0.4})
	player.shake(2.0 + 3.0 * ratio, 0.25)
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, radius):
		WeaponUtil.hit(e, dmg, o, 200.0 + 200.0 * ratio, stun)
	WeaponUtil.hit_breakables(get_tree(), o, radius, ["stone", "stick"])
	_charge = 0.0

func ultimate() -> void:
	# Meteor: after a long wind-up, a huge impact at the cursor
	ground_strike(cursor_target(120.0), 60.0, 1.0, 12.0, 400.0, Color(1.0, 0.4, 0.1), 2.0, ["stone", "stick"])

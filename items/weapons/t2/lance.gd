extends Weapon
## Siege Lance (Spear + Hammer). Keeps the spear's tip bonus and the hammer's
## hold-to-charge, but the charge is now a dash: the longer you hold, the farther
## and harder you ram, ending in a shockwave. Pole Vault hops over the front line.

const MAX_CHARGE := 1.0
var _charging := false
var _charge := 0.0

func _init() -> void:
	hold_ability = true
	weapon_id = "lance"
	element = "pierce"
	weapon_name = "Siege Lance"
	icon_path = "res://items/weapons/icons/lance.png"
	attack_name = "Impale (tip hits very hard)"
	ability_name = "Charge (hold, release to ram)"
	dash_name = "Pole Vault"
	ultimate_name = "Dragoon Dive"
	preview_ultimate = {"kind": "circle", "range": 130.0, "radius": 50.0}
	attack_cooldown = 0.5
	ability_cooldown = 7.0
	dash_cooldown = 4.0
	reach = 15.0
	icon_scale = 0.7
	preview_dash = 70.0

func attack() -> void:
	var o: Vector2 = player.global_position
	thrust(14.0, 0.2)
	fx("line", o, Color(1.0, 0.9, 0.5), {"dir": aim, "length": 52.0, "width": 3.0, "life": 0.15})
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 52.0, 10.0):
		if (e.global_position - o).dot(aim) >= 34.0:
			player.shake(2.0, 0.12)
			fx("ring", o + aim * 46.0, Color(1.0, 0.85, 0.3), {"radius": 14.0, "life": 0.2})
			WeaponUtil.hit(e, 6.0, o, 240.0)
		else:
			WeaponUtil.hit(e, 3.0, o, 140.0)

func use_ability() -> void:
	_claim()
	if !ability_unlocked():
		if ability_name != "":
			_locked_note("The ability", 2)
		return
	if _ability_cd > 0.0 or _charging:
		return
	_charging = true
	_charge = 0.0
	player.speed_mult = 0.5

func _process(delta: float) -> void:
	super(delta)
	if _charging:
		_charge = min(MAX_CHARGE, _charge + delta)

func _draw() -> void:
	super()
	if _charging:
		var ratio := _charge / MAX_CHARGE
		var dist := 60.0 + 90.0 * ratio
		var col := Color(1.0, 0.85, 0.3, 0.8)
		draw_line(Vector2(10, 0), Vector2(10 + dist, 0), col, 2.0)
		draw_arc(Vector2(10 + dist, 0), 14.0 + 12.0 * ratio, 0, TAU, 24, col, 1.5)

func release_ability() -> void:
	_claim()
	if !_charging:
		return
	_charging = false
	player.speed_mult = 1.0
	var ratio := _charge / MAX_CHARGE
	_ability_cd = ability_cooldown
	var dist := 60.0 + 90.0 * ratio
	var travel := 0.2 + 0.1 * ratio
	fx("line", player.global_position, Color(1.0, 0.85, 0.3), {"dir": aim, "length": dist, "width": 8.0, "life": 0.3})
	player.dash(aim, dist, travel)
	start_dash_hits(4.0 + 4.0 * ratio, 14.0, 260.0, travel + 0.05)
	await get_tree().create_timer(travel + 0.03).timeout
	if !is_inside_tree():
		return
	var end: Vector2 = player.global_position
	fx("ring", end, Color(1.0, 0.8, 0.2), {"radius": 26.0 + 20.0 * ratio, "life": 0.35})
	player.shake(2.0 + 3.0 * ratio, 0.2)
	for e in WeaponUtil.enemies_in_circle(get_tree(), end, 26.0 + 20.0 * ratio):
		WeaponUtil.hit(e, 3.0, end, 300.0, 0.8)
	_charge = 0.0

func dash_attack() -> void:
	var d: Vector2 = aim * 70.0          # the way you are moving (aim is set by use_dash)
	player.dash(d.normalized(), min(70.0, d.length()), 0.2)
	ground_strike(player.global_position + d.limit_length(70.0), 22.0, 0.22, 2.0, 200.0, Color(1.0, 0.85, 0.3), 0.3)

func ultimate() -> void:
	# Dragoon Dive: leap to the cursor and crash down
	var target := cursor_target(130.0)
	var d: Vector2 = target - player.global_position
	if d.length() > 6.0:
		player.dash(d.normalized(), d.length(), 0.35)
	ground_strike(target, 50.0, 0.4, 10.0, 360.0, Color(1.0, 0.8, 0.2), 1.5)

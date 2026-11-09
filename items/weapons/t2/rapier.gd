extends Weapon
## Rapier (Spear + Daggers). Footwork weapon: every thrust steps you forward, and
## the third thrust in a rhythm hits double. Fleche is a dash-stab you can chain
## by pressing right click again before it ends. Evade primes your next thrust.

var _combo := 0
var _combo_until := 0.0
var _chain := 0
var _chain_until := 0.0
var _primed_until := 0.0

func _init() -> void:
	weapon_id = "rapier"
	element = "pierce"
	weapon_name = "Rapier"
	icon_path = "res://items/weapons/icons/rapier.png"
	attack_name = "Thrust (3rd in rhythm is double)"
	ability_name = "Fleche (press again to chain)"
	dash_name = "Evade (primes next thrust)"
	ultimate_name = "Thousand Stabs"
	preview_ultimate = {"kind": "line", "length": 60.0}
	attack_cooldown = 0.28
	ability_cooldown = 6.0
	dash_cooldown = 3.5
	reach = 13.0
	icon_scale = 0.6
	preview_ability = {"kind": "line", "length": 110.0}
	preview_dash = 45.0

func attack() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _combo_until:
		_combo = 0
	_combo += 1
	_combo_until = now + 0.55
	var big := _combo >= 3 or now < _primed_until
	if now < _primed_until:
		_primed_until = 0.0
	player.dash(aim, 8.0, 0.06)
	thrust(10.0, 0.15)
	var o: Vector2 = player.global_position
	fx("line", o, Color(1.0, 0.9, 0.9), {"dir": aim, "length": 46.0, "width": 2.0 + (2.0 if big else 0.0), "life": 0.12})
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 46.0, 9.0):
		WeaponUtil.hit(e, 5.0 if big else 2.0, o, 200.0 if big else 60.0)
	if _combo >= 3:
		_combo = 0

func use_ability() -> void:
	_claim()
	if !ability_unlocked():
		if ability_name != "":
			_locked_note("The ability", 2)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _chain > 0 and now < _chain_until:
		_fleche()
		return
	if _ability_cd > 0.0:
		return
	_chain = 0
	_fleche()

func _fleche() -> void:
	var o: Vector2 = player.global_position
	var best = null
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 110.0, 60.0):
		if best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o):
			best = e
	if best == null:
		if _chain == 0:
			_ability_cd = 0.4
		return
	var to: Vector2 = best.global_position - o
	player.dash(to.normalized(), max(10.0, to.length() - 14.0), 0.12)
	fx("line", o, Color(1.0, 0.9, 0.9), {"dir": to.normalized(), "length": to.length(), "width": 5.0, "life": 0.2})
	WeaponUtil.hit(best, 4.0, o, 120.0)
	_chain += 1
	var now := Time.get_ticks_msec() / 1000.0
	_chain_until = now + 0.8
	if _chain >= 3:
		_chain = 0
		_ability_cd = ability_cooldown
		return
	await get_tree().create_timer(0.85).timeout
	if is_inside_tree() and _chain > 0 and Time.get_ticks_msec() / 1000.0 >= _chain_until - 0.05:
		_chain = 0
		_ability_cd = 4.0

func dash_attack() -> void:
	player.dash(aim, 45.0, 0.12)
	_primed_until = Time.get_ticks_msec() / 1000.0 + 1.2
	fx("ring", player.global_position, Color(1.0, 0.9, 0.5), {"radius": 14.0, "life": 0.3})

func ultimate() -> void:
	for i in 12:
		if !is_inside_tree():
			return
		var o: Vector2 = player.global_position
		fx("line", o, Color(1.0, 0.9, 0.9), {"dir": aim, "length": 56.0, "width": 3.0, "life": 0.1})
		thrust(8.0, 0.1)
		for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 56.0, 12.0):
			WeaponUtil.hit(e, 1.5, o, 40.0)
		await get_tree().create_timer(0.1).timeout

extends Weapon
## Knight's Blade (Sword + Shield). A three-hit combo whose third strike is huge.
## Riposte is a counter stance: get hit inside the window and you dash THROUGH the
## attacker for heavy damage; miss and you are punished with a long cooldown.
## Slash Dash primes the combo so your next hit is already the big third strike.

var _combo := 0
var _combo_until := 0.0
var _riposted := false
var parry_window := 0.7              # the riposte window and what a whiff costs (weapon tiers: Oathkeeper widens it, shortens the recovery)
var whiff_cd := 3.5

func _init() -> void:
	weapon_id = "knightblade"
	weapon_name = "Knight's Blade"
	icon_path = "res://items/weapons/icons/knightblade.png"
	attack_name = "3-hit combo (third is huge)"
	ability_name = "Riposte (counter stance)"
	dash_name = "Slash Dash (primes combo)"
	ultimate_name = "Judgment"
	preview_ultimate = {"kind": "self", "radius": 56.0}
	attack_cooldown = 0.32
	ability_cooldown = 3.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.6
	preview_dash = 60.0

func attack() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _combo_until:
		_combo = 0
	_combo += 1
	_combo_until = now + 0.7
	var big := _combo >= 3
	if int(_st.get("big_left", 0)) > 0:                   # weapon tiers: Vanguard Dash makes the next two strikes big
		_st["big_left"] = int(_st["big_left"]) - 1
		big = true
	_st["big"] = big
	swing(1.3 if big else (0.8 if _combo % 2 == 1 else -0.8), 0.15)
	var o: Vector2 = player.global_position
	var r := 40.0 if big else 30.0
	fx("arc", o, Color(1.0, 0.9, 0.6) if big else Color(0.9, 0.95, 1.0), {"radius": r, "dir": aim, "half_angle": 1.4 if big else 0.9, "life": 0.18})
	if big:
		player.shake(2.5, 0.15)
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, r, 80.0 if big else 55.0):
		WeaponUtil.hit(e, Game.basic_hit(weapon_id) * (2.5 if big else 1.0), o, 300.0 if big else 100.0)
	if big:
		_combo = 0

func ability() -> void:
	_riposted = false
	player.parry_time = parry_window
	player.on_parry = _on_riposte
	fx("ring", player.global_position, Color(1.0, 0.9, 0.4), {"radius": 18.0, "life": parry_window})
	await get_tree().create_timer(parry_window + 0.02).timeout
	if is_inside_tree() and !_riposted:
		_ability_cd = whiff_cd          # whiffed: long recovery

func _on_riposte(from_pos: Vector2) -> void:
	_riposted = true
	player.shake(3.0, 0.2)
	var o: Vector2 = player.global_position
	var to: Vector2 = from_pos - o
	var dir := to.normalized() if to.length() > 1.0 else aim
	player.dash(dir, min(70.0, to.length() + 20.0), 0.12)
	start_dash_hits(6.0, 18.0, 220.0, 0.2)
	fx("line", o, Color(1.0, 0.9, 0.4), {"dir": dir, "length": min(70.0, to.length() + 20.0), "width": 8.0, "life": 0.25})
	_ability_cd = 1.5
	WeaponTiers.run(self, "riposte", [from_pos, dir])

func dash_attack() -> void:
	fx("line", player.global_position, Color(1, 1, 1), {"dir": aim, "length": 60.0, "width": 5.0, "life": 0.2})
	player.dash(aim, 60.0, 0.16)
	_combo = 0 if tier >= 4 else 2                       # (tier 4+: the next TWO strikes are big, see tiers/knightblade.gd)
	_st["big_left"] = 2 if tier >= 4 else 0
	_combo_until = Time.get_ticks_msec() / 1000.0 + 1.0
	await get_tree().create_timer(0.18).timeout
	if !is_inside_tree():
		return
	var pos: Vector2 = player.global_position
	fx("arc", pos, Color(1, 1, 1), {"radius": 30.0, "dir": aim, "half_angle": 1.1, "life": 0.18})
	for e in WeaponUtil.enemies_in_arc(get_tree(), pos, aim, 30.0, 65.0):
		WeaponUtil.hit(e, 2.5, pos, 200.0)

func ultimate() -> void:
	# Judgment: three huge arcs in a row while you are untouchable
	player.shield_time = max(player.shield_time, 1.2)
	if tier >= 5 and WeaponTiers.run(self, "vow") == true:             # weapon tiers: Knight's Vow replaces the plain pulses
		return
	pulse_around(6.0, 56.0, 300.0, 0.3, 3, 0.3, Color(1.0, 0.9, 0.5))

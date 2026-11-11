extends Weapon
## Shield: Bash is a short knockback with a brief stun. Guard is a PARRY: get hit
## in the first 0.35 seconds and you release a stunning shockwave and get most of
## the cooldown back. Mistime it and you only get a short protective shield.

const PARRY_WINDOW := 0.35

func _init() -> void:
	weapon_id = "shield"
	weapon_name = "Shield"
	ability_name = "Parry"
	attack_name = "Bash"
	dash_name = "Shield Charge"
	ultimate_name = "Bastion"
	preview_ultimate = {"kind": "self", "radius": 42.0}
	dash_cooldown = 5.0
	preview_dash = 55.0
	icon_path = "res://items/weapons/icons/shield.png"
	attack_cooldown = Game.basic_cd("shield")
	ability_cooldown = 8.0
	reach = 9.0
	icon_scale = 0.6

func attack() -> void:
	thrust(9.0, 0.18)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.5, 0.7, 1.0), {"radius": 22.0, "dir": aim, "half_angle": 1.0, "life": 0.15})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 22.0, 65.0):
		WeaponUtil.hit(e, Game.basic_hit(weapon_id), o, 300.0, 0.5)

func dash_attack() -> void:
	# Shield Charge: rush forward, shoving and briefly stunning whatever you hit
	fx("line", player.global_position, Color(0.5, 0.7, 1.0), {"dir": aim, "length": 55.0, "width": 8.0, "life": 0.25})
	player.dash(aim, 55.0, 0.2)
	start_dash_hits(1.0, 16.0, 320.0, 0.24)

func _on_dash_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.apply_slow(0.0, 0.6)

func ability() -> void:
	player.parry_time = PARRY_WINDOW
	player.on_parry = _on_parry
	fx("ring", player.global_position, Color(1.0, 0.9, 0.4), {"radius": 18.0, "life": PARRY_WINDOW})
	# if nothing parried, fall back to a short plain guard after the window
	await get_tree().create_timer(PARRY_WINDOW + 0.02).timeout
	if is_inside_tree() and _ability_cd > 0.0 and player.parry_time <= 0.0 and !_parried:
		player.shield_time = max(player.shield_time, 1.0)
		fx("ring", player.global_position, Color(0.5, 0.7, 1.0), {"radius": 16.0, "life": 0.4})
	_parried = false

var _parried := false

func _on_parry(_from: Vector2) -> void:
	_parried = true
	var o: Vector2 = player.global_position
	player.shield_time = max(player.shield_time, 0.4)
	player.shake(3.0, 0.25)
	fx("ring", o, Color(1.0, 0.9, 0.4), {"radius": 64.0, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 64.0):
		WeaponUtil.hit(e, 4.0, o, 340.0, 1.8)
	_ability_cd = min(_ability_cd, ability_cooldown * 0.2)    # perfect parry: mostly refunded

func ultimate() -> void:
	# Bastion: five seconds untouchable, with a shoving pulse every second
	player.shield_time = max(player.shield_time, 5.2)
	pulse_around(3.0, 52.0, 280.0, 0.4, 6, 0.85, Color(0.5, 0.7, 1.0))

extends Weapon
## Whip: long reach, weak up close. The crack at the very end of the whip hits
## twice as hard and slows. Hook yanks the nearest enemy in a line to you, stuns
## it and exposes it, so the next hit lands for double damage.

const CRACK_START := 34.0

func _init() -> void:
	weapon_id = "whip"
	weapon_name = "Whip"
	ability_name = "Hook"
	attack_name = "Crack (tip hits hard)"
	dash_name = "Whip Swing"
	ultimate_name = "Tempest Lash"
	preview_ultimate = {"kind": "self", "radius": 62.0}
	dash_cooldown = 4.0
	preview_ability = {"kind": "line", "length": 110.0}
	preview_dash = 60.0
	icon_path = "res://items/weapons/icons/whip.png"
	attack_cooldown = Game.basic_cd("whip")
	ability_cooldown = 6.0
	reach = 12.0

func attack() -> void:
	swing(0.45, 0.15)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.8, 0.5, 0.3), {"radius": 46.0, "dir": aim, "half_angle": 0.35, "life": 0.15})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 46.0, 20.0):
		var d: float = e.global_position.distance_to(o)
		var dmg := Game.basic_hit(weapon_id)
		if d >= CRACK_START:
			dmg *= 2.5
			e.apply_slow(0.5, 0.8)
			fx("ring", e.global_position, Color(1.0, 0.85, 0.3), {"radius": 10.0, "life": 0.2})
		if WeaponUtil.is_exposed(e):
			dmg *= 2.0
			WeaponUtil.clear_exposed(e)
		WeaponUtil.hit(e, dmg, o, 90.0)

func dash_attack() -> void:
	# Whip Swing: swing yourself toward the cursor, lashing what you pass
	fx("line", player.global_position, Color(0.9, 0.7, 0.4), {"dir": aim, "length": 60.0, "width": 3.0, "life": 0.2})
	player.dash(aim, 60.0, 0.14)
	start_dash_hits(1.5, 14.0, 100.0, 0.18)

func ability() -> void:
	# Hook: yank the nearest enemy in the line to you, stun and expose it
	var o: Vector2 = player.global_position
	var best = null
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 110.0, 12.0):
		if best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o):
			best = e
	if best == null:
		_ability_cd = 0.4      # missed: no real cooldown
		return
	fx("line", o, Color(0.9, 0.7, 0.4), {"dir": aim, "length": best.global_position.distance_to(o), "width": 3.0, "life": 0.2})
	WeaponUtil.hit(best, 1.0, o)
	if is_instance_valid(best) and !best.is_queued_for_deletion():
		best.push((o - best.global_position).normalized() * 330.0, 0.3)
		best.apply_slow(0.0, 1.2)
		WeaponUtil.expose(best, 1.5)
		for e in WeaponUtil.enemies_in_circle(get_tree(), best.global_position, 46.0):      # the hook catches the pack around it too
			if e != best and is_instance_valid(e):
				e.push((o - e.global_position).normalized() * 220.0, 0.25)
				e.apply_slow(0.2, 0.8)

func ultimate() -> void:
	# Tempest Lash: three big whip rings around you
	pulse_around(3.2, 72.0, 220.0, 0.6, 5, 0.25, Color(0.9, 0.6, 0.3))

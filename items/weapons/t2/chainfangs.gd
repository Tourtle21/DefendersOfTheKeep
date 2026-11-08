extends Weapon
## Chain Fangs (Daggers + Whip). Fast two-hit combo with a longer reach; the second
## hit reels the target in. Grapple reverses the whip's hook: YOU fly to the
## enemy and expose it for a backstab. Chain Sweep slows whatever it spins through.

var _combo := 0
var _combo_until := 0.0

func _init() -> void:
	weapon_id = "chainfangs"
	weapon_name = "Chain Fangs"
	icon_path = "res://items/weapons/icons/chainfangs.png"
	attack_name = "Chain slash (2nd hit reels in, backstab exposed)"
	ability_name = "Grapple (fly to enemy)"
	dash_name = "Chain Sweep"
	ultimate_name = "Hunt"
	preview_ultimate = {"kind": "self", "radius": 170.0}
	attack_cooldown = 0.3
	ability_cooldown = 6.0
	dash_cooldown = 4.0
	reach = 10.0
	icon_scale = 0.55
	preview_ability = {"kind": "line", "length": 130.0}
	preview_dash = 40.0

func attack() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _combo_until:
		_combo = 0
	_combo += 1
	_combo_until = now + 0.6
	swing(0.8 if _combo % 2 == 1 else -0.8, 0.12)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.8, 0.85, 1.0), {"radius": 36.0, "dir": aim, "half_angle": 0.7, "life": 0.14})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 36.0, 40.0):
		var dmg := 1.5
		if WeaponUtil.is_exposed(e):
			WeaponUtil.clear_exposed(e)
			dmg = 4.5
			player.shake(2.0, 0.12)
			fx("ring", e.global_position, Color(1.0, 0.3, 0.3), {"radius": 14.0, "life": 0.25})
		WeaponUtil.hit(e, dmg, o, 60.0)
		if _combo >= 2 and is_instance_valid(e) and !e.is_queued_for_deletion():
			e.push((o - e.global_position).normalized() * 170.0, 0.12)
	if _combo >= 2:
		_combo = 0

func ability() -> void:
	var o: Vector2 = player.global_position
	var best = null
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 130.0, 12.0):
		if best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o):
			best = e
	if best == null:
		_ability_cd = 0.4
		return
	var to: Vector2 = best.global_position - o
	fx("line", o, Color(0.8, 0.85, 1.0), {"dir": to.normalized(), "length": to.length(), "width": 3.0, "life": 0.2})
	if to.length() > 20.0:
		player.dash(to.normalized(), to.length() - 16.0, 0.14)
	WeaponUtil.hit(best, 1.0, o)
	if is_instance_valid(best) and !best.is_queued_for_deletion():
		WeaponUtil.expose(best, 2.0)

func dash_attack() -> void:
	player.dash(aim, 40.0, 0.1)
	fx("ring", player.global_position + aim * 20.0, Color(0.8, 0.85, 1.0), {"radius": 22.0, "life": 0.25})
	start_dash_hits(1.5, 18.0, 120.0, 0.14)

func _on_dash_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.apply_slow(0.4, 1.0)

func ultimate() -> void:
	# Hunt: chain through up to five enemies, exposing and backstabbing each
	var hit_list := []
	for i in 5:
		if !is_inside_tree():
			return
		var o: Vector2 = player.global_position
		var best = null
		for e in WeaponUtil.enemies_in_circle(get_tree(), o, 170.0):
			if !(e in hit_list) and (best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o)):
				best = e
		if best == null:
			return
		hit_list.append(best)
		var to: Vector2 = best.global_position - o
		player.dash(to.normalized(), max(6.0, to.length() - 10.0), 0.1)
		fx("line", o, Color(0.8, 0.85, 1.0), {"dir": to.normalized(), "length": to.length(), "width": 5.0, "life": 0.2})
		WeaponUtil.hit(best, 5.0, o, 80.0)
		await get_tree().create_timer(0.16).timeout

extends Weapon
## Scimitar (desert). Fast slashes that make enemies bleed. Crescent Wave throws a piercing
## wave that bleeds everything it cuts; Mirage Step dashes and bleeds what you pass; the
## ultimate is a cyclone that drags enemies into the middle while it cuts them.

func _init() -> void:
	weapon_id = "scimitar"
	element = "earth"
	weapon_name = "Scimitar"
	icon_path = "res://items/weapons/icons/scimitar.png"
	attack_name = "Slash (causes bleeding)"
	ability_name = "Crescent Wave (piercing, bleeds)"
	dash_name = "Mirage Step"
	ultimate_name = "Sand Cyclone"
	preview_ability = {"kind": "line", "length": 140.0}
	preview_dash = 50.0
	preview_ultimate = {"kind": "self", "radius": 52.0}
	attack_cooldown = 0.3
	ability_cooldown = 5.0
	dash_cooldown = 4.0
	reach = 11.0
	icon_scale = 0.6
var _flip := false

func attack() -> void:
	_flip = !_flip
	swing(1.0 if _flip else -1.0, 0.14)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.95, 0.8, 0.45), {"radius": 30.0, "dir": aim, "half_angle": 1.2, "life": 0.14})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 30.0, 70.0):
		WeaponUtil.hit(e, 1.6, o, 60.0)
		WeaponUtil.bleed(get_tree(), e, 3, 0.7)

func ability() -> void:
	thrust(8.0, 0.2)
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 12.0, aim, 260.0, 2.5, Color(0.95, 0.8, 0.45), 0.55, 3, 80.0, {"bleed_ticks": 4, "bleed_dmg": 0.8})

func dash_attack() -> void:
	fx("line", player.global_position, Color(0.95, 0.8, 0.45), {"dir": aim, "length": 50.0, "width": 6.0, "life": 0.25})
	player.dash(aim, 50.0, 0.13)
	start_dash_hits(1.5, 14.0, 80.0, 0.18)

func _on_dash_hit(e) -> void:
	WeaponUtil.bleed(get_tree(), e, 3, 0.8)

func ultimate() -> void:
	for i in 5:
		if !is_inside_tree():
			return
		var o: Vector2 = player.global_position
		fx("ring", o, Color(0.95, 0.8, 0.45), {"radius": 52.0, "life": 0.25})
		for e in WeaponUtil.enemies_in_circle(get_tree(), o, 52.0):
			WeaponUtil.hit(e, 2.0, o)
			if is_instance_valid(e) and !e.is_queued_for_deletion():
				e.push((o - e.global_position).normalized() * 160.0, 0.15)     # pulled in
		player.shake(1.5, 0.1)
		await get_tree().create_timer(0.3).timeout

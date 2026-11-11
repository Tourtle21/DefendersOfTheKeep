extends "res://items/weapons/t1x/frostglaive.gd"
## Rimelance (Frost Glaive + Spear). Thrusts instead of cleaving, with the spear's tip bonus. The
## right click hurls the glaive down a line, chilling what it hits and leaving an icy patch.

func _init() -> void:
	weapon_id = "rimelance"
	element = "ice"
	weapon_name = "Rimelance"
	icon_path = "res://items/weapons/icons/rimelance.png"
	attack_name = "Frost thrust (tip hits hard, chills)"
	ability_name = "Glaive Throw (pierces, leaves ice)"
	dash_name = "Skate"
	ultimate_name = "Deep Freeze"
	preview_ability = {"kind": "line", "length": 150.0}
	reach = 14.0

func attack() -> void:
	thrust(12.0, 0.2)
	var o: Vector2 = player.global_position
	fx("line", o, Color(0.7, 0.9, 1.0), {"dir": aim, "length": 52.0, "width": 3.0, "life": 0.15})
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 52.0, 9.0):
		var tip: bool = (e.global_position - o).dot(aim) >= 32.0
		WeaponUtil.hit(e, Game.basic_hit(weapon_id) * (1.0 if tip else 0.45), o, 160.0)
		_chill(e)

func ability() -> void:
	thrust(10.0, 0.25)
	var land: Vector2 = player.global_position + aim * 130.0
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 12.0, aim, 300.0, 4.5, Color(0.7, 0.9, 1.0), 0.45, 3, 120.0, {"expose_secs": 2.0})
	await get_tree().create_timer(0.45).timeout
	WeaponUtil.patch(game_world(), land, "slow", 26.0, Color(0.7, 0.9, 1.0, 0.5), 4.0, 0.45)

extends Weapon
## Quake Pick (Pickaxe + Hammer). Mining swing that shatters rocks and trees. Fissure
## sends a line of eruptions along the ground that pop one after another, so
## time them where enemies are walking. Burrow rams forward and erupts on arrival.

func _init() -> void:
	weapon_id = "quakepick"
	element = "crush"
	weapon_name = "Quake Pick"
	icon_path = "res://items/weapons/icons/quakepick.png"
	attack_name = "Heavy pick (breaks rocks and trees)"
	ability_name = "Fissure (line of eruptions)"
	dash_name = "Burrow"
	ultimate_name = "Cataclysm"
	preview_ultimate = {"kind": "self", "radius": 90.0}
	attack_cooldown = 0.6
	ability_cooldown = 7.0
	dash_cooldown = 5.0
	reach = 11.0
	icon_scale = 0.65
	preview_ability = {"kind": "line", "length": 112.0}
	preview_dash = 70.0

func attack() -> void:
	swing(1.0, 0.2)
	await get_tree().create_timer(0.18).timeout
	if !is_inside_tree():
		return
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.9, 0.7, 0.4), {"radius": 30.0, "dir": aim, "half_angle": 1.0, "life": 0.18})
	player.shake(1.5, 0.1)
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 30.0, 60.0):
		WeaponUtil.hit(e, 3.5, o, 160.0)
	for i in 3:
		WeaponUtil.hit_breakables(get_tree(), o + aim * 14.0, 26.0)

func ability() -> void:
	var o: Vector2 = player.global_position
	for i in 5:
		ground_strike(o + aim * (22.0 + i * 18.0), 18.0, 0.4 + i * 0.1, 3.0, 220.0, Color(0.8, 0.6, 0.3), 0.3, ["stone", "stick"])

func dash_attack() -> void:
	player.dash(aim, 70.0, 0.16)
	ground_strike(player.global_position + aim * 70.0, 26.0, 0.35, 3.5, 260.0, Color(0.8, 0.6, 0.3), 0.6, ["stone"])

func ultimate() -> void:
	var o: Vector2 = player.global_position
	for ring in 3:
		for i in 6:
			var p := o + Vector2.from_angle(i * TAU / 6.0 + ring * 0.5) * (30.0 + 30.0 * ring)
			ground_strike(p, 22.0, 0.3 + ring * 0.35, 4.0, 240.0, Color(0.8, 0.5, 0.2), 0.5, ["stone", "stick"])

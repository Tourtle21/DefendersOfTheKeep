extends "res://items/weapons/t1x/crystalwand.gd"
## Prismatic Staff (Crystal Wand + Staff). A five-shard fan, and the right click fires a prism
## beam: everything along the line is hit and stunned at once.

func _init() -> void:
	weapon_id = "prismstaff"
	element = "pierce"
	weapon_name = "Prismatic Staff"
	icon_path = "res://items/weapons/icons/prismstaff.png"
	attack_name = "Shard fan (5 piercing shards)"
	ability_name = "Prism Beam (hits the whole line)"
	dash_name = "Refract"
	ultimate_name = "Geode Storm"
	preview_ability = {"kind": "line", "length": 130.0}

func attack() -> void:
	thrust(5.0, 0.2)
	for i in 5:
		var d := aim.rotated((i - 2) * 0.1)
		WeaponProjectile.shoot(game_world(), player.global_position + d * 10.0, d, 310.0, Game.basic_hit(weapon_id) / 5.0, Color(0.85, 0.65, 1.0), 0.8, 1, 60.0)

func ability() -> void:
	var o: Vector2 = player.global_position
	fx("line", o, Color(0.9, 0.75, 1.0), {"dir": aim, "length": 130.0, "width": 8.0, "life": 0.35})
	player.shake(2.0, 0.15)
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 130.0, 10.0):
		WeaponUtil.hit(e, 4.0, o, 100.0, 1.2)

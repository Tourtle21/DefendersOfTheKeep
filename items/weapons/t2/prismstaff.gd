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
	# Prism Beam: the beam splits in three and every line is hit and stunned, leaving crystals along it
	var o: Vector2 = player.global_position
	player.shake(3.0, 0.2)
	for k in 3:
		var d := aim.rotated((k - 1) * 0.28)
		fx("line", o, Color(0.9, 0.75, 1.0), {"dir": d, "length": 150.0, "width": 8.0, "life": 0.4})
		for e in WeaponUtil.enemies_in_line(get_tree(), o, d, 150.0, 10.0):
			WeaponUtil.hit(e, 5.0, o, 120.0, 1.4)
		for j in 4:
			ground_strike(o + d * (40.0 + j * 34.0), 16.0, 0.3 + j * 0.08, 2.5, 100.0, Color(0.85, 0.65, 1.0), 0.3)

func ultimate() -> void:
	# Geode Storm, then a crystal nova rips out of you
	super()
	var o: Vector2 = player.global_position
	await get_tree().create_timer(0.5).timeout
	if !is_inside_tree():
		return
	fx("ring", o, Color(0.9, 0.7, 1.0), {"radius": 150.0, "life": 0.5})
	for i in 16:
		ground_strike(o + Vector2.from_angle(i * TAU / 16.0) * 120.0, 22.0, 0.2 + i * 0.03, 5.0, 240.0, Color(0.85, 0.65, 1.0), 0.6)
	ground_strike(o, 90.0, 0.9, 12.0, 300.0, Color(0.95, 0.8, 1.0), 1.2)

extends Weapon
## LEGENDARY. Dawnbringer: a blade of daylight. It glows brighter than any torch, every slash lights what
## it hits, and its hits are never weakened by the night. Sun Dash leaves a lit trail, Daybreak turns an
## area into daylight for a while (heals you, burns shrouded enemies) and Solar Judgment rains light.

func _init() -> void:
	weapon_id = "dawnbringer"
	weapon_name = "Dawnbringer"
	element = "fire"
	light_radius = 130.0
	attack_name = "Radiant Slash"
	dash_name = "Sun Dash"
	ability_name = "Daybreak"
	ultimate_name = "Solar Judgment"
	preview_ability = {"kind": "circle", "range": 90.0, "radius": 80.0}
	preview_ultimate = {"kind": "circle", "range": 120.0, "radius": 90.0}
	preview_dash = 60.0
	icon_path = "res://items/weapons/icons/dawnbringer.png"
	attack_cooldown = Game.basic_cd("dawnbringer")
	ability_cooldown = 9.0
	dash_cooldown = 3.5
	ultimate_cooldown = 50.0
	reach = 12.0
	icon_scale = 0.62

func attack() -> void:
	swing(0.7, 0.15)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(1.0, 0.9, 0.5), {"radius": 46.0, "dir": aim, "half_angle": 0.7, "life": 0.16})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 46.0, 42.0):
		WeaponUtil.hit(e, Game.basic_hit("dawnbringer"), o, 120.0)

func dash_attack() -> void:
	var start: Vector2 = player.global_position
	fx("line", start, Color(1.0, 0.9, 0.5), {"dir": aim, "length": 60.0, "width": 6.0, "life": 0.25})
	player.dash(aim, 60.0, 0.14)
	start_dash_hits(2.2, 16.0, 110.0, 0.2)
	LightSource.spawn(game_world(), start + aim * 30.0, 80.0, 4.0, Color(1.0, 0.92, 0.6))

func ability() -> void:
	# Daybreak: an area of daylight that heals you and burns what stands in it
	var c := cursor_target(90.0)
	fx("ring", c, Color(1.0, 0.92, 0.55), {"radius": 80.0, "life": 0.5})
	LightSource.spawn(game_world(), c, 170.0, 12.0, Color(1.0, 0.92, 0.6))
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.global_position.distance_to(c) <= 90.0:
			p.heal(30.0)
	for e in WeaponUtil.enemies_in_circle(get_tree(), c, 80.0):
		WeaponUtil.hit(e, 3.5, c, 80.0)
		Game.light_up(e, 10.0)

func ultimate() -> void:
	# Solar Judgment: beams of light fall all over a wide area
	var c := cursor_target(120.0)
	LightSource.spawn(game_world(), c, 150.0, 6.0, Color(1.0, 0.95, 0.7))
	rain(c, 90.0, 14, 2.6, 6.0, 24.0, Color(1.0, 0.9, 0.45), 0.4)

extends "res://items/weapons/t1x/bogstaff.gd"
## Witch Staff (Bog Staff + Staff). Poison bolts that pierce. Hex curses everything around the
## cursor: exposed for five seconds and rotting. Bog Hop leaves mud and blinks farther.

func _init() -> void:
	weapon_id = "witchstaff"
	element = "poison"
	weapon_name = "Witch Staff"
	icon_path = "res://items/weapons/icons/witchstaff.png"
	attack_name = "Poison bolt (pierces)"
	ability_name = "Hex (curse everything at cursor)"
	dash_name = "Bog Hop (far)"
	ultimate_name = "Swamp Swell"
	preview_ability = {"kind": "circle", "range": 120.0, "radius": 44.0}
	ability_cooldown = 7.0

func attack() -> void:
	thrust(5.0, 0.2)
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 10.0, aim, 240.0, Game.basic_hit(weapon_id), Color(0.55, 0.9, 0.35), 1.0, 1, 40.0, {"bleed_ticks": 5, "bleed_dmg": 0.9})

func ability() -> void:
	var c := cursor_target(120.0)
	fx("ring", c, Color(0.6, 0.9, 0.4), {"radius": 44.0, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(get_tree(), c, 44.0):
		WeaponUtil.expose(e, 5.0)
		WeaponUtil.bleed(get_tree(), e, 6, 1.0)

func dash_attack() -> void:
	var from: Vector2 = player.global_position
	player.blink(aim * 75.0)
	_mud(from, 30.0, 5.0)
	fx("ring", from, Color(0.5, 0.7, 0.3), {"radius": 24.0, "life": 0.3})

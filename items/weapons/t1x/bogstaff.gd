extends Weapon
## Bog Staff (swamp). Poison globs that rot enemies over time. Mire drops a sticky mud patch at
## the cursor, Bog Hop blinks and leaves mud behind you, and the ultimate floods the area.

func _init() -> void:
	weapon_id = "bogstaff"
	element = "poison"
	weapon_name = "Bog Staff"
	icon_path = "res://items/weapons/icons/bogstaff.png"
	attack_name = "Poison glob (damage over time)"
	ability_name = "Mire (mud patch at cursor)"
	dash_name = "Bog Hop"
	ultimate_name = "Swamp Swell"
	preview_ability = {"kind": "circle", "range": 110.0, "radius": 34.0}
	preview_dash = 50.0
	preview_ultimate = {"kind": "self", "radius": 100.0}
	attack_cooldown = 0.55
	ability_cooldown = 6.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.6

func _mud(pos: Vector2, r: float, secs: float, factor := 0.4) -> void:
	WeaponUtil.patch(game_world(), pos, "slow", r, Color(0.25, 0.3, 0.12, 0.6), secs, factor)

func attack() -> void:
	thrust(5.0, 0.2)
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 10.0, aim, 210.0, 1.0, Color(0.5, 0.85, 0.3), 0.9, 0, 40.0, {"bleed_ticks": 4, "bleed_dmg": 0.8})

func ability() -> void:
	var c := cursor_target(110.0)
	fx("ring", c, Color(0.5, 0.7, 0.3), {"radius": 34.0, "life": 0.3})
	_mud(c, 34.0, 6.0)

func dash_attack() -> void:
	var from: Vector2 = player.global_position
	player.blink(aim * 50.0)
	_mud(from, 28.0, 5.0)
	fx("ring", from, Color(0.5, 0.7, 0.3), {"radius": 22.0, "life": 0.3})

func ultimate() -> void:
	var o: Vector2 = player.global_position
	_mud(o, 100.0, 8.0, 0.35)
	fx("ring", o, Color(0.5, 0.7, 0.3), {"radius": 100.0, "life": 0.5})
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 100.0):
		WeaponUtil.bleed(get_tree(), e, 8, 1.0)

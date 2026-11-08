extends "res://items/weapons/t2/juggernaut.gd"
## Worldbreaker (Juggernaut + Earthshaker), tier 4. Releasing a brace erupts the ground in a
## ring around you on top of the slam, and the ultimate rains eruptions for three seconds.

func _init() -> void:
	weapon_id = "worldbreaker"
	element = "crush"
	weapon_name = "Worldbreaker"
	icon_path = "res://items/weapons/icons/worldbreaker.png"
	attack_name = "Maul swing (slow, huge knockback)"
	ability_name = "Fortress (hold), ring of eruptions on release"
	dash_name = "Shoulder Charge"
	ultimate_name = "Cataclysm Fortress"
	preview_ultimate = {"kind": "self", "radius": 90.0}
	max_store = 10
	ability_cooldown = 6.0

func release_ability() -> void:
	var stored := _stored
	var was := _braced
	super()
	if !was:
		return
	var o: Vector2 = player.global_position
	for i in 8:
		var p := o + Vector2.from_angle(i * TAU / 8.0) * 62.0
		ground_strike(p, 22.0, 0.25 + i * 0.04, 2.0 + stored * 0.8, 260.0, Color(0.85, 0.6, 0.3), 0.6, ["stone", "stick"])

func ultimate() -> void:
	player.shield_time = max(player.shield_time, 6.0)
	pulse_around(3.0, 58.0, 300.0, 0.6, 6, 1.0, Color(1.0, 0.85, 0.4))
	rain(player.global_position, 90.0, 10, 3.0, 4.0, 22.0, Color(0.85, 0.5, 0.2), 0.5)

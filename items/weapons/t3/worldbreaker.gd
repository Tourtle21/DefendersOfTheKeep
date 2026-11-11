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
	_claim()
	var stored := _stored
	var was := _braced
	super()
	if !was:
		return
	var o: Vector2 = player.global_position
	for i in 12:
		var p := o + Vector2.from_angle(i * TAU / 12.0) * 62.0
		ground_strike(p, 24.0, 0.25 + i * 0.03, 2.4 + stored * 0.9, 280.0, Color(0.85, 0.6, 0.3), 0.7, ["stone", "stick"])
	for i in 8:                                                    # a second, wider ring a beat later
		var p2 := o + Vector2.from_angle(i * TAU / 8.0 + 0.4) * 112.0
		ground_strike(p2, 26.0, 0.7 + i * 0.04, 2.0 + stored * 0.8, 260.0, Color(0.9, 0.65, 0.3), 0.6, ["stone", "stick"])

func ultimate() -> void:
	player.shield_time = max(player.shield_time, 6.0)
	pulse_around(3.0, 58.0, 300.0, 0.6, 6, 1.0, Color(1.0, 0.85, 0.4))
	rain(player.global_position, 135.0, 20, 3.4, 4.6, 24.0, Color(0.85, 0.5, 0.2), 0.6)
	ground_strike(player.global_position, 130.0, 2.2, 12.0, 420.0, Color(1.0, 0.7, 0.3), 1.4, ["stone", "stick"])      # the final quake

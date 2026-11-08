extends "res://items/weapons/t2/quakepick.gd"
## Earthshaker (Quake Pick + Bulwark Maul). Fissure splits into three diverging lines,
## and Burrow leaves you braced for half a second on arrival.

func _init() -> void:
	weapon_id = "earthshaker"
	element = "crush"
	weapon_name = "Earthshaker"
	icon_path = "res://items/weapons/icons/earthshaker.png"
	attack_name = "Heavy pick (breaks rocks and trees)"
	ability_name = "Triple Fissure"
	dash_name = "Burrow (arrive braced)"
	ultimate_name = "Cataclysm"
	ability_cooldown = 8.0
	preview_ability = {"kind": "line", "length": 112.0}

func ability() -> void:
	var o: Vector2 = player.global_position
	for off in [-0.35, 0.0, 0.35]:
		var d := aim.rotated(off)
		for i in 5:
			ground_strike(o + d * (22.0 + i * 18.0), 18.0, 0.4 + i * 0.1, 3.0, 220.0, Color(0.8, 0.6, 0.3), 0.5, ["stone", "stick"])

func dash_attack() -> void:
	super()
	player.shield_time = max(player.shield_time, 0.8)

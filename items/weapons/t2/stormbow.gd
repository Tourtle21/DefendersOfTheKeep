extends "res://items/weapons/t2/warpbow.gd"
## Stormcaller Bow (Warp Bow + Tempest Lash). The warp is now a storm: arriving
## calls lightning down in a ring around you, and the ultimate rains it.

func _init() -> void:
	weapon_id = "stormbow"
	weapon_name = "Stormcaller Bow"
	icon_path = "res://items/weapons/icons/stormbow.png"
	attack_name = "Storm draw (hold, release)"
	ability_name = "Storm Warp (press again to warp)"
	dash_name = "Phase Step"
	ultimate_name = "Thunder Volley"
	preview_ultimate = {"kind": "circle", "range": 130.0, "radius": 70.0}
	ability_cooldown = 5.0

func _on_warped(dest: Vector2) -> void:
	for i in 3:
		ground_strike(dest + Vector2.from_angle(i * TAU / 3.0 + randf() * 0.5) * 34.0, 20.0, 0.2 + i * 0.15, 3.0, 160.0, Color(0.7, 0.85, 1.0), 0.4)

func ultimate() -> void:
	super()
	rain(cursor_target(130.0), 70.0, 8, 2.0, 3.5, 22.0, Color(0.7, 0.85, 1.0), 0.4)

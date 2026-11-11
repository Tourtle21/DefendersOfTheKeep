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
	for i in 6:                                                    # arriving calls a ring of lightning around you
		ground_strike(dest + Vector2.from_angle(i * TAU / 6.0 + randf() * 0.3) * 40.0, 22.0, 0.2 + i * 0.1, 3.5, 180.0, Color(0.7, 0.85, 1.0), 0.5)

func ultimate() -> void:
	super()
	var c := cursor_target(130.0)
	rain(c, 110.0, 18, 2.6, 4.2, 24.0, Color(0.7, 0.85, 1.0), 0.5)
	ground_strike(c, 56.0, 1.6, 10.0, 260.0, Color(0.85, 0.95, 1.0), 1.0)          # and the one big bolt at the end

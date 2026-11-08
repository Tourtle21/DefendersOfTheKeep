extends "res://items/weapons/t2/bulwark.gd"
## Juggernaut (Bulwark Maul + Knight's Blade). Bracing keeps you moving at a near
## walk, stores up to eight hits, and every blocked hit instantly shoves enemies
## back with a counter-pulse.

func _init() -> void:
	weapon_id = "juggernaut"
	element = "crush"
	weapon_name = "Juggernaut"
	icon_path = "res://items/weapons/icons/juggernaut.png"
	attack_name = "Maul swing (slow, huge knockback)"
	ability_name = "Fortress (hold, counter-pulses)"
	dash_name = "Shoulder Charge"
	ultimate_name = "Unbreakable"
	preview_ultimate = {"kind": "self", "radius": 58.0}
	max_store = 8
	brace_speed = 0.7
	ability_cooldown = 7.0

func _on_absorb(from: Vector2) -> void:
	super(from)
	var o: Vector2 = player.global_position
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 30.0):
		WeaponUtil.hit(e, 2.0, o, 220.0, 0.3)

func ultimate() -> void:
	player.shield_time = max(player.shield_time, 6.0)
	pulse_around(3.0, 58.0, 300.0, 0.6, 6, 1.0, Color(1.0, 0.85, 0.4))

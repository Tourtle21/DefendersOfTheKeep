extends "res://items/weapons/t2/spellblade.gd"
## Starfall (Spellblade + Tempest Lash). The orbiting blades leave CHARGES on every enemy
## they cut, and when the storm ends all charges detonate at once.

func _init() -> void:
	weapon_id = "starfall"
	weapon_name = "Starfall"
	icon_path = "res://items/weapons/icons/starfall.png"
	attack_name = "Wave slash (piercing wave)"
	ability_name = "Blade Storm (charges, then detonates)"
	dash_name = "Arcane Dash"
	ultimate_name = "Blade Dance"
	blade_count = 5

func _on_blade_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.set_meta("charge", min(5, e.get_meta("charge", 0) + 1))

func ability() -> void:
	super()
	await get_tree().create_timer(storm_len + 0.05).timeout
	if !is_inside_tree():
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_queued_for_deletion() and e.has_meta("charge"):
			var n: int = e.get_meta("charge")
			e.remove_meta("charge")
			fx("ring", e.global_position, Color(0.8, 0.9, 1.0), {"radius": 14.0 + 4.0 * n, "life": 0.3})
			WeaponUtil.hit(e, 1.5 * n, player.global_position, 80.0, 0.6 if n >= 3 else 0.0)
			if n >= 3:                                              # a heavily charged enemy calls a star down on itself
				ground_strike(e.global_position, 22.0 + 5.0 * n, 0.35, 2.5 * n, 200.0, Color(0.85, 0.9, 1.0), 0.7)

func _draw() -> void:
	super()
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_meta("charge"):
			var n: int = e.get_meta("charge")
			var base := to_local(e.global_position + Vector2(-3.0 * (n - 1), -16))
			for i in n:
				draw_circle(base + Vector2(6.0 * i, 0), 2.0, Color(0.7, 0.9, 1.0))

func ultimate() -> void:
	# Blade Dance, then a meteor shower of stars over the whole area
	super()
	var o: Vector2 = player.global_position
	rain(o, 140.0, 18, 3.0, 4.2, 22.0, Color(0.85, 0.9, 1.0), 0.4)

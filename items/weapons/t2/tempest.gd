extends Weapon
## Tempest Lash (Staff + Whip). Lightning lash that chains between enemies and
## leaves CHARGES on everything it touches (shown as dots). Thunderclap detonates
## every charge at once, so build stacks first, then clap. Static Dash charges
## whatever you run through.

func _init() -> void:
	weapon_id = "tempest"
	weapon_name = "Tempest Lash"
	icon_path = "res://items/weapons/icons/tempest.png"
	attack_name = "Chain lightning (adds charges)"
	ability_name = "Thunderclap (detonate charges)"
	dash_name = "Static Dash"
	ultimate_name = "Storm"
	preview_ultimate = {"kind": "self", "radius": 140.0}
	attack_cooldown = 0.45
	ability_cooldown = 6.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.6
	preview_dash = 50.0

func _charge(e, n := 1) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.set_meta("charge", min(5, e.get_meta("charge", 0) + n))

func attack() -> void:
	var o: Vector2 = player.global_position
	var first = null
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 75.0, 28.0):
		if first == null or e.global_position.distance_to(o) < first.global_position.distance_to(o):
			first = e
	thrust(5.0, 0.2)
	if first == null:
		fx("line", o, Color(0.7, 0.8, 1.0), {"dir": aim, "length": 60.0, "width": 2.0, "life": 0.1})
		return
	var chain := [first]
	for step in 2:
		var best = null
		for e in WeaponUtil.enemies_in_circle(get_tree(), chain[-1].global_position, 45.0):
			if !(e in chain) and (best == null or e.global_position.distance_to(chain[-1].global_position) < best.global_position.distance_to(chain[-1].global_position)):
				best = e
		if best == null:
			break
		chain.append(best)
	var prev: Vector2 = o
	for i in chain.size():
		var e = chain[i]
		var p: Vector2 = e.global_position
		fx("line", prev, Color(0.7, 0.85, 1.0), {"dir": (p - prev).normalized(), "length": prev.distance_to(p), "width": 3.0, "life": 0.15})
		prev = p
		WeaponUtil.hit(e, 2.0 * pow(0.6, i), o, 40.0)
		_charge(e)

func ability() -> void:
	var o: Vector2 = player.global_position
	var any := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_queued_for_deletion() and e.has_meta("charge"):
			var n: int = e.get_meta("charge")
			e.remove_meta("charge")
			any = true
			fx("ring", e.global_position, Color(0.8, 0.9, 1.0), {"radius": 14.0 + 4.0 * n, "life": 0.3})
			WeaponUtil.hit(e, 1.5 * n, o, 100.0, 0.8 if n >= 2 else 0.0)
	if any:
		player.shake(3.0, 0.2)
	else:
		_ability_cd = 0.6      # nothing charged

func dash_attack() -> void:
	player.dash(aim, 50.0, 0.12)
	start_dash_hits(1.0, 16.0, 80.0, 0.15)

func _on_dash_hit(e) -> void:
	_charge(e)

func _draw() -> void:
	super()
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_meta("charge"):
			var n: int = e.get_meta("charge")
			var base := to_local(e.global_position + Vector2(-3.0 * (n - 1), -16))
			for i in n:
				draw_circle(base + Vector2(6.0 * i, 0), 2.0, Color(0.7, 0.9, 1.0))

func ultimate() -> void:
	var o: Vector2 = player.global_position
	fx("ring", o, Color(0.7, 0.85, 1.0), {"radius": 140.0, "life": 0.5})
	await get_tree().create_timer(0.4).timeout
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 140.0):
		_charge(e, 3)
	ability()

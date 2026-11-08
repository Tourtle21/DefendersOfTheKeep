extends Weapon
## LEGENDARY. Voidreaver: a scythe that drinks the dark. Its wide sweep pierces armor and heals you for
## every enemy it cuts. Void Step slips you forward and leaves a clinging patch, Rift pulls everything
## near a point together and holds it, and Event Horizon drags the whole area in around you.

func _init() -> void:
	weapon_id = "voidreaver"
	weapon_name = "Voidreaver"
	element = "pierce"
	attack_name = "Reap"
	dash_name = "Void Step"
	ability_name = "Rift"
	ultimate_name = "Event Horizon"
	preview_ability = {"kind": "circle", "range": 110.0, "radius": 90.0}
	preview_ultimate = {"kind": "self", "radius": 140.0}
	preview_dash = 70.0
	icon_path = "res://items/weapons/icons/voidreaver.png"
	attack_cooldown = 0.55
	ability_cooldown = 8.0
	dash_cooldown = 4.0
	ultimate_cooldown = 55.0
	reach = 12.0
	icon_scale = 0.62

func attack() -> void:
	swing(0.9, 0.18)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.65, 0.35, 1.0), {"radius": 52.0, "dir": aim, "half_angle": 1.0, "life": 0.18})
	var cut := 0
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 52.0, 58.0):
		WeaponUtil.hit(e, 3.2, o, 90.0)
		cut += 1
	if cut > 0:
		player.heal(minf(3.0, 1.0 * cut))                # drinks what it cuts

func dash_attack() -> void:
	var start: Vector2 = player.global_position
	fx("line", start, Color(0.55, 0.3, 0.9), {"dir": aim, "length": 70.0, "width": 5.0, "life": 0.3})
	player.dash(aim, 70.0, 0.1)
	start_dash_hits(2.0, 14.0, 60.0, 0.15)
	WeaponUtil.patch(game_world(), start + aim * 35.0, "slow", 30.0, Color(0.4, 0.2, 0.7, 0.45), 3.0, 0.4)

func ability() -> void:
	# Rift: everything near the cursor is dragged in and held
	var c := cursor_target(110.0)
	fx("ring", c, Color(0.6, 0.3, 1.0), {"radius": 90.0, "life": 0.45})
	await get_tree().create_timer(0.4).timeout
	if !is_inside_tree():
		return
	for e in WeaponUtil.enemies_in_circle(get_tree(), c, 90.0):
		WeaponUtil.hit(e, 3.0, c, 0.0)
		if is_instance_valid(e) and !e.is_queued_for_deletion():
			e.push((c - e.global_position).normalized() * 220.0, 0.35)
			e.apply_slow(0.0, 1.4)
			WeaponUtil.expose(e, 2.0)

func ultimate() -> void:
	# Event Horizon: five pulls in a row, dragging everything in and hurting it
	for i in 5:
		if !is_inside_tree():
			return
		var o: Vector2 = player.global_position
		fx("ring", o, Color(0.6, 0.3, 1.0), {"radius": 140.0, "life": 0.4})
		for e in WeaponUtil.enemies_in_circle(get_tree(), o, 140.0):
			WeaponUtil.hit(e, 3.5, o, 0.0)
			if is_instance_valid(e) and !e.is_queued_for_deletion():
				e.push((o - e.global_position).normalized() * 200.0, 0.3)
		await get_tree().create_timer(0.5).timeout

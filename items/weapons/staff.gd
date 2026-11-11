extends Weapon
## Staff: arcane bolts. Blink teleports toward the cursor and leaves a rift
## behind that explodes after one second, hurting and slowing anything that
## chased you through it. Bait enemies onto the rift, then blink away.

func _init() -> void:
	weapon_id = "staff"
	element = "fire"
	weapon_name = "Staff"
	ability_name = "Arcane Burst"
	attack_name = "Bolt"
	dash_name = "Blink (leaves a rift)"
	ultimate_name = "Arcane Storm"
	preview_ultimate = {"kind": "circle", "range": 110.0, "radius": 70.0}
	dash_cooldown = 4.0
	preview_ability = {"kind": "circle", "range": 100.0, "radius": 26.0}
	icon_path = "res://items/weapons/icons/staff.png"
	attack_cooldown = Game.basic_cd("staff")
	ability_cooldown = 5.0
	reach = 12.0
	icon_scale = 0.6

func attack() -> void:
	thrust(5.0, 0.2)
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 10.0, aim, 230.0, Game.basic_hit("staff"), Color(0.6, 0.45, 1.0), 1.2, 0, 60.0)

func ability() -> void:
	# Arcane Burst: a blast at the cursor after a short delay (lead moving targets)
	ground_strike(cursor_target(100.0), 26.0, 0.5, 3.5, 120.0, Color(0.6, 0.45, 1.0), 0.4)

func dash_attack() -> void:
	# Blink: teleport toward the cursor, leaving a rift that explodes a second later
	var tree := get_tree()
	var from: Vector2 = player.global_position
	player.blink(aim * 64.0)
	fx("ring", player.global_position, Color(0.6, 0.45, 1.0), {"radius": 14.0, "life": 0.3})
	fx("ring", from, Color(0.6, 0.45, 1.0), {"radius": 32.0, "life": 1.0})   # the rift, charging up
	await tree.create_timer(1.0).timeout
	for e in WeaponUtil.enemies_in_circle(tree, from, 32.0):
		WeaponUtil.hit(e, 3.5, from, 160.0)
		if is_instance_valid(e) and !e.is_queued_for_deletion():
			e.apply_slow(0.4, 1.0)
	WeaponFx.spawn(game_world_safe(from), "ring", from, Color(0.8, 0.6, 1.0), {"radius": 36.0, "life": 0.3})

func game_world_safe(_p: Vector2) -> Node:
	return player.get_parent() if is_instance_valid(player) else null

func ultimate() -> void:
	# Arcane Storm: a barrage of delayed bursts around the cursor
	rain(cursor_target(110.0), 70.0, 8, 2.0, 4.0, 28.0, Color(0.6, 0.45, 1.0), 0.4)

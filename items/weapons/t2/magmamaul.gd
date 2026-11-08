extends "res://items/weapons/t1x/emberflail.gd"
## Magma Maul (Ember Flail + Hammer). Slower, heavier swings that crack the ground; Magma Slam
## drops a huge burning crater; Leap Burn jumps and lands in flames.

func _init() -> void:
	weapon_id = "magmamaul"
	element = "fire"
	weapon_name = "Magma Maul"
	icon_path = "res://items/weapons/icons/magmamaul.png"
	attack_name = "Heavy swing (cracks the ground)"
	ability_name = "Magma Slam (crater at cursor)"
	dash_name = "Leap Burn"
	ultimate_name = "Magma Ring"
	attack_cooldown = 0.85
	ability_cooldown = 7.0

func attack() -> void:
	swing(1.3, 0.25)
	await get_tree().create_timer(0.22).timeout
	if !is_inside_tree():
		return
	var o: Vector2 = player.global_position
	var c: Vector2 = o + aim * 24.0
	player.shake(2.0, 0.12)
	fx("ring", c, Color(1.0, 0.5, 0.2), {"radius": 34.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(get_tree(), c, 34.0):
		WeaponUtil.hit(e, 4.5, o, 280.0, 0.4)
	WeaponUtil.hit_breakables(get_tree(), c, 30.0, ["stone"])
	_fire(c, 20.0, 4.0)

func ability() -> void:
	var c := cursor_target(100.0)
	ground_strike(c, 44.0, 0.6, 8.0, 320.0, Color(1.0, 0.4, 0.1), 0.8, ["stone"])
	await get_tree().create_timer(0.62).timeout
	if is_inside_tree():
		_fire(c, 44.0, 6.0)

func dash_attack() -> void:
	var d: Vector2 = cursor_target(70.0) - player.global_position
	if d.length() < 8.0:
		d = aim * 40.0
	player.dash(d.normalized(), min(70.0, d.length()), 0.2)
	var land: Vector2 = player.global_position + d.limit_length(70.0)
	ground_strike(land, 30.0, 0.22, 4.0, 240.0, Color(1.0, 0.4, 0.1), 0.5)
	await get_tree().create_timer(0.24).timeout
	if is_inside_tree():
		_fire(land, 26.0, 4.0)

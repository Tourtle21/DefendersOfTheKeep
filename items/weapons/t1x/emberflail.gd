extends Weapon
## Ember Flail (volcano). Each swing scorches the ground where it lands. Eruption blasts the
## cursor spot and leaves a burning pool; Lava Surge dashes leaving a fire trail; the
## ultimate rings you with fire.

func _init() -> void:
	weapon_id = "emberflail"
	element = "fire"
	weapon_name = "Ember Flail"
	icon_path = "res://items/weapons/icons/emberflail.png"
	attack_name = "Swing (scorches the ground)"
	ability_name = "Eruption (at cursor)"
	dash_name = "Lava Surge (fire trail)"
	ultimate_name = "Magma Ring"
	preview_ability = {"kind": "circle", "range": 90.0, "radius": 30.0}
	preview_dash = 60.0
	preview_ultimate = {"kind": "self", "radius": 70.0}
	attack_cooldown = 0.6
	ability_cooldown = 6.0
	dash_cooldown = 5.0
	reach = 11.0
	icon_scale = 0.65

func _fire(pos: Vector2, r: float, secs: float) -> void:
	WeaponUtil.patch(game_world(), pos, "burn", r, Color(1.0, 0.35, 0.1, 0.5), secs)

func attack() -> void:
	swing(1.2, 0.2)
	await get_tree().create_timer(0.17).timeout
	if !is_inside_tree():
		return
	var o: Vector2 = player.global_position
	var c: Vector2 = o + aim * 26.0
	fx("arc", o, Color(1.0, 0.5, 0.2), {"radius": 32.0, "dir": aim, "half_angle": 1.0, "life": 0.18})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 34.0, 60.0):
		WeaponUtil.hit(e, 2.5, o, 140.0)
	_fire(c, 14.0, 3.0)

func ability() -> void:
	var c := cursor_target(90.0)
	ground_strike(c, 30.0, 0.45, 5.0, 220.0, Color(1.0, 0.4, 0.1), 0.4)
	await get_tree().create_timer(0.47).timeout
	if is_inside_tree():
		_fire(c, 30.0, 4.0)

func dash_attack() -> void:
	var o: Vector2 = player.global_position
	player.dash(aim, 60.0, 0.15)
	for i in 4:
		_fire(o + aim * (12.0 + i * 15.0), 12.0, 4.0)

func ultimate() -> void:
	var o: Vector2 = player.global_position
	for i in 8:
		var p := o + Vector2.from_angle(i * TAU / 8.0) * 70.0
		_fire(p, 18.0, 6.0)
		ground_strike(p, 20.0, 0.3 + i * 0.05, 4.0, 200.0, Color(1.0, 0.4, 0.1), 0.3)

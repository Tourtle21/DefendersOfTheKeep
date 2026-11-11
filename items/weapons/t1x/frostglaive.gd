extends Weapon
## Frost Glaive (tundra). Every hit CHILLS: slowed and exposed. Glacial Line raises a row of ice
## spikes, Skate is a long slippery dash, and the ultimate freezes everything nearby.

func _init() -> void:
	weapon_id = "frostglaive"
	element = "ice"
	weapon_name = "Frost Glaive"
	icon_path = "res://items/weapons/icons/frostglaive.png"
	attack_name = "Cleave (chills)"
	ability_name = "Glacial Line (ice spikes)"
	dash_name = "Skate"
	ultimate_name = "Deep Freeze"
	preview_ability = {"kind": "line", "length": 112.0}
	preview_dash = 90.0
	preview_ultimate = {"kind": "self", "radius": 130.0}
	attack_cooldown = Game.basic_cd("frostglaive")
	ability_cooldown = 6.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.65

func _chill(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.apply_slow(0.5, 1.5)
		WeaponUtil.expose(e, 1.5)

func attack() -> void:
	swing(1.0, 0.16)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.7, 0.9, 1.0), {"radius": 30.0, "dir": aim, "half_angle": 0.9, "life": 0.15})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 30.0, 55.0):
		var dmg := Game.basic_hit("frostglaive") * (1.5 if WeaponUtil.is_exposed(e) else 1.0)
		WeaponUtil.hit(e, dmg, o, 80.0)
		_chill(e)

func ability() -> void:
	var o: Vector2 = player.global_position
	for i in 5:
		ground_strike(o + aim * (22.0 + i * 18.0), 18.0, 0.35 + i * 0.1, 2.5, 120.0, Color(0.7, 0.9, 1.0), 0.5)

func dash_attack() -> void:
	fx("line", player.global_position, Color(0.7, 0.9, 1.0), {"dir": aim, "length": 90.0, "width": 6.0, "life": 0.3})
	player.dash(aim, 90.0, 0.25)
	start_dash_hits(1.0, 14.0, 60.0, 0.3)

func _on_dash_hit(e) -> void:
	_chill(e)

func ultimate() -> void:
	var o: Vector2 = player.global_position
	fx("ring", o, Color(0.7, 0.95, 1.0), {"radius": 130.0, "life": 0.6})
	await get_tree().create_timer(0.3).timeout
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 130.0):
		WeaponUtil.hit(e, 3.0, o, 0.0, 2.5)
		WeaponUtil.expose(e, 4.0)

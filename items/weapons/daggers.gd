extends Weapon
## Twin Daggers: very fast, weak hits. Shadow Step dashes through enemies and
## EXPOSES them for two seconds (also exposed: anything stunned). Attacking an
## exposed enemy is a backstab for triple damage and refunds half the Shadow
## Step cooldown. Step in, stab, step out.

var _flip := false

func _init() -> void:
	weapon_id = "daggers"
	weapon_name = "Twin Daggers"
	ability_name = "Throwing Knives"
	attack_name = "Slash (backstab exposed)"
	dash_name = "Shadow Step"
	ultimate_name = "Death Mark"
	preview_ultimate = {"kind": "self", "radius": 150.0}
	dash_cooldown = 4.0
	preview_ability = {"kind": "line", "length": 100.0}
	preview_dash = 44.0
	icon_path = "res://items/weapons/icons/daggers.png"
	attack_cooldown = Game.basic_cd("daggers")
	ability_cooldown = 5.0
	reach = 9.0
	icon_scale = 0.5

func attack() -> void:
	_flip = !_flip
	swing(0.9 if _flip else -0.9, 0.12)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.85, 0.9, 1.0), {"radius": 28.0, "dir": aim, "half_angle": 0.9, "life": 0.12})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 28.0, 55.0):
		if WeaponUtil.is_exposed(e):
			WeaponUtil.clear_exposed(e)
			fx("ring", e.global_position, Color(1.0, 0.3, 0.3), {"radius": 16.0, "life": 0.25})
			player.shake(2.0, 0.15)
			_dash_cd = max(0.0, _dash_cd - dash_cooldown * 0.5)
			WeaponUtil.hit(e, Game.basic_hit(weapon_id) * 3.0, o, 100.0)          # backstab (3x)
		else:
			WeaponUtil.hit(e, Game.basic_hit(weapon_id), o, 60.0)

func ability() -> void:
	# Throwing Knives: three knives that expose whatever they hit
	for i in 3:
		var d := aim.rotated((i - 1) * 0.16)
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 280.0, 1.0, Color(0.8, 0.85, 1.0), 0.36, 0, 60.0, {"expose_secs": 2.0})

func dash_attack() -> void:
	fx("line", player.global_position, Color(0.6, 0.5, 0.9), {"dir": aim, "length": 44.0, "width": 6.0, "life": 0.3})
	player.dash(aim, 44.0, 0.11)
	start_dash_hits(1.0, 13.0, 80.0, 0.16)

func _on_dash_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		WeaponUtil.expose(e, 2.0)
		fx("ring", e.global_position, Color(0.7, 0.4, 1.0), {"radius": 14.0, "life": 0.5})

func ultimate() -> void:
	# Death Mark: everything nearby is exposed for six seconds, and you are faster
	fx("ring", player.global_position, Color(0.7, 0.3, 0.9), {"radius": 150.0, "life": 0.5})
	for e in WeaponUtil.enemies_in_circle(get_tree(), player.global_position, 150.0):
		WeaponUtil.expose(e, 6.0)
	player.speed_mult = 1.4
	await get_tree().create_timer(6.0).timeout
	if is_inside_tree():
		player.speed_mult = 1.0

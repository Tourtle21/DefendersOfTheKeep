extends "res://items/weapons/t2/chainfangs.gd"
## Soulreaper (Chain Fangs + Spellblade). Every slash throws a piercing wave, and
## Grapple exposes everything around the target for four seconds.

func _init() -> void:
	weapon_id = "soulreaper"
	weapon_name = "Soulreaper"
	icon_path = "res://items/weapons/icons/soulreaper.png"
	attack_name = "Chain slash + piercing wave"
	ability_name = "Grapple (exposes the whole group)"
	dash_name = "Chain Sweep"
	ultimate_name = "Reap"
	preview_ultimate = {"kind": "self", "radius": 170.0}

func attack() -> void:
	super()
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 14.0, aim, 250.0, 2.0, Color(0.7, 0.5, 1.0), 0.5, 2, 80.0)

func ability() -> void:
	super()
	await get_tree().create_timer(0.2).timeout
	if !is_inside_tree():
		return
	for e in WeaponUtil.enemies_in_circle(get_tree(), player.global_position, 55.0):
		WeaponUtil.expose(e, 4.0)
		fx("ring", e.global_position, Color(0.7, 0.4, 1.0), {"radius": 12.0, "life": 0.4})

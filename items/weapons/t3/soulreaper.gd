extends "res://items/weapons/t2/chainfangs.gd"
## Soulreaper (Chain Fangs + Spellblade). Every slash throws a piercing wave, and
## Grapple exposes everything around the target for four seconds.

func _init() -> void:
	weapon_id = "soulreaper"
	melee_share = 2.0 / 3.0                 # the melee takes two thirds of the attack damage, the extra projectile the rest
	weapon_name = "Soulreaper"
	icon_path = "res://items/weapons/icons/soulreaper.png"
	attack_name = "Chain slash + piercing wave"
	ability_name = "Grapple (exposes the whole group)"
	dash_name = "Chain Sweep"
	ultimate_name = "Reap"
	preview_ultimate = {"kind": "self", "radius": 170.0}

func attack() -> void:
	super()
	var extra := {"style": "crescent", "size": 1.0, "trail": 3}          # weapon tiers: the wave is a crescent with a trail
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 14.0, aim, 250.0, Game.basic_hit(weapon_id) / 3.0, Color(0.7, 0.5, 1.0), 0.5, 2, 80.0, extra)

func ability() -> void:
	super()
	await get_tree().create_timer(0.2).timeout
	if !is_inside_tree():
		return
	for e in WeaponUtil.enemies_in_circle(get_tree(), player.global_position, 55.0):
		WeaponUtil.expose(e, 4.0)
		fx("ring", e.global_position, Color(0.7, 0.4, 1.0), {"radius": 12.0, "life": 0.4})

func ultimate() -> void:
	# Reap: a ring of dark light tears out of you, then the souls it freed rain back down on the whole area
	var o: Vector2 = player.global_position
	fx("ring", o, Color(0.7, 0.4, 1.0), {"radius": 170.0, "life": 0.6})
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 170.0):
		WeaponUtil.hit(e, 5.0, o, 200.0, 0.8)
		WeaponUtil.expose(e, 5.0)
		WeaponUtil.bleed(get_tree(), e, 8, 1.0)
	for i in 8:
		ground_strike(o + Vector2.from_angle(i * TAU / 8.0) * 100.0, 26.0, 0.5 + i * 0.07, 5.0, 220.0, Color(0.75, 0.45, 1.0), 0.5)
	rain(o, 150.0, 16, 2.6, 4.5, 24.0, Color(0.7, 0.4, 1.0), 0.4)

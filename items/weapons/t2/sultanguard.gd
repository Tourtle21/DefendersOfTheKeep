extends "res://items/weapons/t1x/scimitar.gd"
## Sultan's Guard (Scimitar + Shield). The right click becomes a bleeding parry: get hit in the
## window and a crescent wave fans out in four directions. Mirage Step leaves you shielded.

func _init() -> void:
	weapon_id = "sultanguard"
	element = "earth"
	weapon_name = "Sultan's Guard"
	icon_path = "res://items/weapons/icons/sultanguard.png"
	attack_name = "Slash (bleeds), pushes back"
	ability_name = "Riposte Wave (parry, 4 crescents)"
	dash_name = "Mirage Guard"
	ultimate_name = "Sand Cyclone"
	ability_cooldown = 7.0

func ability() -> void:
	_st["parried"] = false
	player.parry_time = 0.55 if tier >= 3 else 0.4          # (weapon tiers: Desert Shield widens the window)
	player.on_parry = _on_parry
	fx("ring", player.global_position, Color(0.95, 0.8, 0.45), {"radius": 18.0, "life": 0.4})

func _on_parry(_from: Vector2) -> void:
	player.shake(2.5, 0.2)
	player.shield_time = max(player.shield_time, 0.5)
	_st["parried"] = true
	var n := 6 if tier >= 2 else 4                             # (weapon tiers: Mirrored Wave sends six bigger crescents)
	var extra := {"bleed_ticks": 4, "bleed_dmg": 1.0}
	if tier >= 2:
		extra.merge({"style": "crescent", "size": 1.2})
	for i in n:
		var d := Vector2.from_angle(i * TAU / float(n) + aim.angle())
		WeaponProjectile.shoot(game_world(), player.global_position + d * 12.0, d, 260.0, 3.0, Color(0.95, 0.8, 0.45), 0.5, 3, 100.0, extra)
	_ability_cd = 1.5
	WeaponTiers.run(self, "parry", [_from])

func dash_attack() -> void:
	super()
	player.shield_time = max(player.shield_time, 0.7)

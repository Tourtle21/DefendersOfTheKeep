extends "res://items/weapons/t2/lance.gd"
## Dragoon Pike (Siege Lance + Rapier). The charge ram is followed by three automatic
## lunges at the nearest enemies, and Sky Vault leaps much farther.

func _init() -> void:
	weapon_id = "dragoonpike"
	element = "pierce"
	weapon_name = "Dragoon Pike"
	icon_path = "res://items/weapons/icons/dragoonpike.png"
	attack_name = "Impale (tip hits very hard)"
	ability_name = "Charge (hold), then 3 chain lunges"
	dash_name = "Sky Vault"
	ultimate_name = "Dragon Dive"
	ability_cooldown = 6.0
	preview_dash = 110.0

func release_ability() -> void:
	_claim()
	var was := _charging
	super()
	if !was:
		return
	await get_tree().create_timer(0.55).timeout
	var hit_list := []
	var lunges := 4 if tier >= 4 else 3                       # (weapon tiers: Dragonfire adds a fourth lunge)
	for i in lunges:
		if !is_inside_tree():
			return
		var o: Vector2 = player.global_position
		var best = null
		for e in WeaponUtil.enemies_in_circle(get_tree(), o, 130.0):
			if !(e in hit_list) and (best == null or e.global_position.distance_to(o) < best.global_position.distance_to(o)):
				best = e
		if best == null:
			return
		hit_list.append(best)
		var to: Vector2 = best.global_position - o
		player.dash(to.normalized(), max(8.0, to.length() - 12.0), 0.1)
		fx("line", o, Color(1.0, 0.9, 0.5), {"dir": to.normalized(), "length": to.length(), "width": 5.0, "life": 0.2})
		WeaponUtil.hit(best, 4.0, o, 160.0)
		WeaponTiers.run(self, "lunge", [best, o])
		await get_tree().create_timer(0.16).timeout

func dash_attack() -> void:
	var d: Vector2 = aim * 110.0          # the way you are moving (aim is set by use_dash)
	player.dash(d.normalized(), min(110.0, d.length()), 0.28)
	var land: Vector2 = player.global_position + d.limit_length(110.0)
	ground_strike(land, 30.0, 0.3, 3.0, 240.0, Color(1.0, 0.85, 0.3), 0.6)
	ground_strike(land, 52.0, 0.55, 2.0, 200.0, Color(1.0, 0.7, 0.2), 0.3)

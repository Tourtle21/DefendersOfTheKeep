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
	var dmg := Game.basic_hit(weapon_id)
	var extra := {}
	if tier >= 2:                                    # the tier riders (items/weapons/tiers/staff.gd): an orb that bursts, a big bolt, chains, a nova
		_st["bolts"] = int(_st.get("bolts", 0)) + 1
		var n: int = _st.bolts
		var big: bool = tier >= 3 and n % 4 == 0
		extra = {"style": "orb", "size": 1.1, "trail": 4, "burst_r": 18.0, "burst_mult": 0.4}
		if tier >= 4:
			extra["chain"] = 1 if big else 2
		if big:
			dmg *= 2.0
			extra["size"] = 1.8
			extra["burst_r"] = 28.0
			extra["burst_mult"] = 0.6
			extra["on_hit_fx"] = "star"
		if tier >= 6 and n % 8 == 0:
			extra["nova"] = 8
			extra["nova_mult"] = 0.4 * Game.basic_hit(weapon_id) / maxf(dmg, 0.1)       # each small bolt hits for 0.4 H
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 10.0, aim, 230.0, dmg, Color(0.6, 0.45, 1.0), 1.2, 0, 60.0, extra)

func ability() -> void:
	# Arcane Burst: a blast at the cursor after a short delay (lead moving targets). The echo blasts spiral out from the first (tier 2+: five)
	var c := cursor_target(100.0)
	ground_strike(c, 30.0, 0.5, 3.8, 140.0, Color(0.6, 0.45, 1.0), 0.4)
	var n := 5 if tier >= 2 else 3
	for i in n:
		ground_strike(c + Vector2.from_angle(i * TAU / float(n) + 0.5) * 38.0, 20.0, 0.7 + i * 0.1, 2.5, 100.0, Color(0.7, 0.55, 1.0), 0.2)

func dash_attack() -> void:
	# Blink: teleport toward the cursor, leaving a rift that explodes a second later
	var tree := get_tree()
	var from: Vector2 = player.global_position
	player.blink(aim * 64.0)
	fx("ring", player.global_position, Color(0.6, 0.45, 1.0), {"radius": 14.0, "life": 0.3})
	fx("ring", from, Color(0.6, 0.45, 1.0), {"radius": 32.0, "life": 1.0})   # the rift, charging up
	await tree.create_timer(1.0).timeout
	for e in WeaponUtil.enemies_in_circle(tree, from, 44.0):
		WeaponUtil.hit(e, 4.2, from, 200.0)
		if is_instance_valid(e) and !e.is_queued_for_deletion():
			e.apply_slow(0.4, 1.0)
	WeaponFx.spawn(game_world_safe(from), "ring", from, Color(0.8, 0.6, 1.0), {"radius": 36.0, "life": 0.3})

func game_world_safe(_p: Vector2) -> Node:
	return player.get_parent() if is_instance_valid(player) else null

func ultimate() -> void:
	# Arcane Storm: a barrage of delayed bursts around the cursor
	var each := Callable()
	if tier >= 5:
		each = func(p: Vector2): WeaponTiers.run(self, "rain_point", [p])      # the strikes are comets
	rain(cursor_target(110.0), 70.0, 8, 2.0, 4.0, 28.0, Color(0.6, 0.45, 1.0), 0.4, each)

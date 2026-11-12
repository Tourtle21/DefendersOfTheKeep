extends Weapon
## Torch: a burning brand and the weapon that answers the night. Its glow cuts a wide circle in the dark
## around you, and every hit lights the enemy (so it loses its night shroud) and sets it burning.
## Flame Dash leaves a burning, lit trail, Flare throws a bright flare that lights a big area for a
## while, and Sunburst floods everything near you with light and fire and exposes it.

const LIGHT := 110.0

func _init() -> void:
	weapon_id = "torch"
	weapon_name = "Torch"
	element = "fire"
	light_radius = LIGHT
	ability_name = "Flare"
	attack_name = "Burn"
	dash_name = "Flame Dash"
	ultimate_name = "Sunburst"
	preview_ability = {"kind": "circle", "range": 110.0, "radius": 55.0}
	preview_ultimate = {"kind": "self", "radius": 120.0}
	preview_dash = 55.0
	icon_path = "res://items/weapons/icons/torch.png"
	attack_cooldown = Game.basic_cd("torch")
	ability_cooldown = 8.0
	dash_cooldown = 4.0
	ultimate_cooldown = 55.0
	reach = 11.0
	icon_scale = 0.6

func attack() -> void:
	swing(0.5, 0.14)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(1.0, 0.6, 0.2), {"radius": 36.0, "dir": aim, "half_angle": 0.6, "life": 0.15})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 36.0, 35.0):
		WeaponUtil.hit(e, Game.basic_hit(weapon_id), o, 70.0)
		if is_instance_valid(e) and !e.is_queued_for_deletion():
			WeaponUtil.bleed(get_tree(), e, 3, 0.6)          # it keeps burning for a moment

func dash_attack() -> void:
	# Flame Dash: dash the way you are moving, leaving a burning patch that lights the ground
	var start: Vector2 = player.global_position
	fx("line", start, Color(1.0, 0.6, 0.2), {"dir": aim, "length": 55.0, "width": 5.0, "life": 0.25})
	player.dash(aim, 55.0, 0.14)
	start_dash_hits(1.2, 14.0, 80.0, 0.18)
	WeaponUtil.patch(game_world(), start + aim * 25.0, "burn", 26.0 if tier >= 4 else 20.0, Color(1.0, 0.5, 0.15, 0.5), 3.0)      # (tier 4 Blaze Trail: a wider patch)
	LightSource.spawn(game_world(), start + aim * 25.0, 70.0, 4.0)

func ability() -> void:
	# Flare: a bright flare lands at the cursor and lights a big area for 10 seconds
	var target := cursor_target(110.0)
	fx("ring", target, Color(1.0, 0.85, 0.4), {"radius": 55.0, "life": 0.4})
	await get_tree().create_timer(0.4).timeout
	if !is_inside_tree():
		return
	LightSource.spawn(game_world(), target, 95.0, 10.0, Color(1.0, 0.9, 0.55))
	for e in WeaponUtil.enemies_in_circle(get_tree(), target, 55.0):
		WeaponUtil.hit(e, 2.0, target, 120.0)
		Game.light_up(e, 8.0)

func ultimate() -> void:
	# Sunburst: light and fire all around you; everything caught is lit for a long while and exposed
	var o: Vector2 = player.global_position
	LightSource.spawn(game_world(), o, 150.0 + [0.0, 0.0, 20.0, 20.0, 20.0, 40.0][tier - 1], 8.0, Color(1.0, 0.92, 0.6))      # (the tiers brighten it)
	fx("ring", o, Color(1.0, 0.9, 0.5), {"radius": 120.0, "life": 0.6})
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, 120.0):
		Game.light_up(e, 8.0)
		WeaponUtil.expose(e, 4.0)
	pulse_around(3.0, 120.0, 200.0, 0.4, 2, 0.3, Color(1.0, 0.8, 0.35))

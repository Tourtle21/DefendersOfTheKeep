extends Weapon
## Crystal Wand (caverns). Fires a fan of three piercing shards. Crystal Ring erupts spikes all
## around you, Refract jumps toward the cursor with a burst at both ends, and the ultimate
## rains shards around the cursor.

func _init() -> void:
	weapon_id = "crystalwand"
	element = "pierce"
	weapon_name = "Crystal Wand"
	icon_path = "res://items/weapons/icons/crystalwand.png"
	attack_name = "Shard fan (3 piercing shards)"
	ability_name = "Crystal Ring"
	dash_name = "Refract"
	ultimate_name = "Geode Storm"
	preview_dash = 60.0
	preview_ultimate = {"kind": "circle", "range": 110.0, "radius": 80.0}
	attack_cooldown = Game.basic_cd("crystalwand")
	ability_cooldown = 6.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.6

func attack() -> void:
	thrust(5.0, 0.2)
	for i in 3:
		var d := aim.rotated((i - 1) * 0.12)
		WeaponProjectile.shoot(game_world(), player.global_position + d * 10.0, d, 300.0, Game.basic_hit(weapon_id) / 3.0, Color(0.8, 0.6, 1.0), 0.8, 1, 60.0)

func ability() -> void:
	var o: Vector2 = player.global_position
	for i in 6:                                                    # two rings of crystals, the outer one a beat later
		ground_strike(o + Vector2.from_angle(i * TAU / 6.0) * 40.0, 20.0, 0.3 + i * 0.04, 3.6, 200.0, Color(0.8, 0.6, 1.0), 0.3)
	for i in 10:
		ground_strike(o + Vector2.from_angle(i * TAU / 10.0 + 0.3) * 74.0, 20.0, 0.65 + i * 0.03, 3.6, 200.0, Color(0.9, 0.7, 1.0), 0.3)

func dash_attack() -> void:
	var from: Vector2 = player.global_position
	player.blink((cursor_target(60.0) - from))
	ground_strike(from, 22.0, 0.2, 2.5, 160.0, Color(0.8, 0.6, 1.0), 0.3)
	ground_strike(player.global_position, 22.0, 0.25, 2.5, 160.0, Color(0.8, 0.6, 1.0), 0.3)

func ultimate() -> void:
	rain(cursor_target(110.0), 105.0, 22, 2.4, 4.4, 24.0, Color(0.8, 0.6, 1.0), 0.5)

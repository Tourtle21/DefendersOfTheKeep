extends Weapon
## Spear: spacing weapon. The very tip hits twice as hard, so keep enemies at the
## end of your reach. Lunge dashes through enemies and refunds most of its
## cooldown if it connects, so you can chain lunges through a pack.

const TIP_START := 30.0

func _init() -> void:
	weapon_id = "spear"
	element = "pierce"
	weapon_name = "Spear"
	ability_name = "Javelin"
	attack_name = "Thrust (tip hits hard)"
	dash_name = "Lunge"
	ultimate_name = "Spear Rain"
	preview_ultimate = {"kind": "circle", "range": 120.0, "radius": 55.0}
	dash_cooldown = 5.0
	preview_ability = {"kind": "line", "length": 130.0}
	preview_dash = 80.0
	icon_path = "res://items/weapons/icons/spear.png"
	attack_cooldown = Game.basic_cd("spear")
	ability_cooldown = 6.0
	reach = 13.0
	icon_scale = 0.65

func attack() -> void:
	var o: Vector2 = player.global_position
	thrust(12.0, 0.2)
	fx("line", o, Color(0.9, 0.95, 1.0), {"dir": aim, "length": 44.0, "width": 3.0, "life": 0.15})
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 44.0, 9.0):
		var along: float = (e.global_position - o).dot(aim)
		if along >= TIP_START:
			fx("ring", o + aim * 40.0, Color(1.0, 0.85, 0.3), {"radius": 12.0, "life": 0.2})
			player.shake(1.5, 0.12)
			WeaponUtil.hit(e, Game.basic_hit("spear"), o, 200.0)       # tip hit
		else:
			WeaponUtil.hit(e, Game.basic_hit("spear") * 0.5, o, 120.0)

func ability() -> void:
	# Javelin: throw the spear at the cursor, pierces two enemies
	thrust(10.0, 0.25)
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 12.0, aim, 330.0, 4.0, Color(0.85, 0.92, 1.0), 0.4, 2, 160.0)

func dash_attack() -> void:
	thrust(16.0, 0.25)
	fx("line", player.global_position, Color(0.8, 0.9, 1.0), {"dir": aim, "length": 80.0, "width": 6.0, "life": 0.25})
	player.dash(aim, 80.0, 0.18)
	start_dash_hits(4.0, 14.0, 220.0, 0.22)

func _on_dash_hit(_e) -> void:
	# connecting refunds most of the cooldown: chain lunges
	_dash_cd = min(_dash_cd, dash_cooldown * 0.35)
	fx("ring", player.global_position, Color(1.0, 0.85, 0.3), {"radius": 16.0, "life": 0.2})

func ultimate() -> void:
	# Spear Rain: javelins crash down around the cursor
	rain(cursor_target(120.0), 55.0, 12, 1.5, 4.0, 14.0, Color(0.85, 0.92, 1.0))

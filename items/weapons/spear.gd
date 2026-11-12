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
	var skewer: bool = _st.get("skewer", false)          # tier 3+: every third thrust is longer (items/weapons/tiers/spear.gd)
	var primed: bool = _st.get("primed_now", false)     # tier 4+: a connecting Lunge primed this thrust
	var length := 62.0 if skewer else 44.0
	var tip_start := 44.0 if skewer else TIP_START
	thrust(12.0, 0.2)
	fx("line", o, Color(0.9, 0.95, 1.0), {"dir": aim, "length": length, "width": 3.0, "life": 0.15})
	for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, length, 9.0):
		var along: float = (e.global_position - o).dot(aim)
		if along >= tip_start or primed:
			fx("ring", o + aim * 40.0, Color(1.0, 0.85, 0.3), {"radius": 12.0, "life": 0.2})
			player.shake(1.5, 0.12)
			WeaponUtil.hit(e, Game.basic_hit(weapon_id) * (2.0 if skewer and along >= tip_start else 1.0), o, 200.0)       # tip hit
		else:
			WeaponUtil.hit(e, Game.basic_hit(weapon_id) * 0.5, o, 120.0)

func ability() -> void:
	# Javelin: throw the spear at the cursor, pierces two enemies (tier 2+: three, a long gold lance that exposes what it passes)
	thrust(10.0, 0.25)
	var extra := {}
	var pierce := 2
	var col := Color(0.85, 0.92, 1.0)
	if tier >= 2:
		pierce = 3
		col = Color(1.0, 0.85, 0.3)
		extra = {"style": "lance", "size": 1.2, "trail": 4, "expose_secs": 1.5, "on_hit_fx": "burst"}
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 12.0, aim, 330.0, 4.0, col, 0.4, pierce, 160.0, extra)

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
	var each := Callable()
	if tier >= 3:
		each = func(p: Vector2): WeaponTiers.run(self, "rain_point", [p])      # a javelin falls into each strike
	rain(cursor_target(120.0), 55.0, 12, 1.5, 4.0, 14.0, Color(0.85, 0.92, 1.0), 0.0, each)

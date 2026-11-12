extends Weapon
## Bow: hold left click to draw, release to fire. A longer draw hits harder and
## flies faster; a full draw pierces. Releasing in the gold window right at full
## draw is a perfect shot (extra damage). An aim line shows your shot while drawing.
## Right click: Volley, a fan of five quick arrows.

const FULL_DRAW := 0.8
const PERFECT_END := 1.1

var _drawing := false
var _draw_t := 0.0

func _init() -> void:
	weapon_id = "bow"
	weapon_name = "Bow"
	ability_name = "Volley"
	attack_name = "Draw & release (hold)"
	dash_name = "Backflip Shot"
	ultimate_name = "Arrow Storm"
	preview_ultimate = {"kind": "line", "length": 150.0}
	dash_cooldown = 4.0
	preview_ability = {"kind": "line", "length": 120.0}
	icon_path = "res://items/weapons/icons/bow.png"
	attack_cooldown = Game.basic_cd("bow")
	ability_cooldown = 6.0
	reach = 9.0

func use_item() -> void:
	_claim()
	if _attack_cd > 0.0 or _drawing:
		return
	_drawing = true
	_draw_t = 0.0
	player.speed_mult = 0.6
	_st["draw_ms"] = Time.get_ticks_msec()

func _process(delta: float) -> void:
	super(delta)
	if _drawing:
		_draw_t += delta
		sprite.position.x = reach - 4.0 * min(1.0, _draw_t / FULL_DRAW)   # pull back
		if _draw_t > PERFECT_END + 0.4:
			release_item()      # held too long: fires at the end of the window
	queue_redraw()

func _draw() -> void:
	super()
	if !_drawing:
		return
	var ratio: float = min(1.0, _draw_t / FULL_DRAW)
	var perfect := _draw_t >= FULL_DRAW and _draw_t <= PERFECT_END
	var col := Color(1.0, 0.85, 0.2, 0.8) if perfect else Color(1, 1, 1, 0.25 + 0.35 * ratio)
	draw_line(Vector2(10, 0), Vector2(10 + 60.0 + 120.0 * ratio, 0), col, 1.0 + 1.5 * float(perfect))

func release_item() -> void:
	_claim()
	if !_drawing:
		return
	_drawing = false
	player.speed_mult = 1.0
	sprite.position.x = reach
	_attack_cd = attack_cooldown
	var ratio: float = min(1.0, _draw_t / FULL_DRAW)
	var perfect := _draw_t >= FULL_DRAW and _draw_t <= PERFECT_END
	var dmg := Game.basic_hit(weapon_id) * (0.33 + 0.67 * ratio)
	var speed := 200.0 + 160.0 * ratio
	var col := Color(0.9, 0.8, 0.5)
	if perfect:
		dmg *= 1.6
		col = Color(1.0, 0.85, 0.2)
		fx("ring", player.global_position + aim * 10.0, col, {"radius": 12.0, "life": 0.2})
		player.shake(1.5, 0.12)
	var pierce := 1 if ratio >= 1.0 else 0
	thrust(-3.0, 0.15)
	var extra := {}
	var finisher := false
	if weapon_id == "bow" and tier >= 2:          # (the tier riders of items/weapons/tiers/bow.gd; fused bows keep the plain shot)
		extra["trail"] = 3
		if tier >= 3 and perfect:
			extra["split"] = 2                  # Overdraw: a perfect shot splits in two on its first hit
		elif tier >= 3 and ratio >= 1.0:
			col = Color(1, 1, 1)                # fully drawn, not perfect: a white trail
		if tier >= 6 and ratio >= 1.0:
			_st["full"] = int(_st.get("full", 0)) + 1
			finisher = int(_st.full) % 6 == 0   # every sixth full draw: Piercing Gale
			if finisher:
				pierce = 4
	_st["shot"] = {"ratio": ratio, "perfect": perfect, "finisher": finisher, "dir": aim, "o": player.global_position}
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 8.0, aim, speed, dmg, col, 1.1, pierce, 80.0 + 60.0 * ratio, extra)
	if weapon_id == "bow":
		WeaponTiers.run(self, "release_item")

func dash_attack() -> void:
	# Roll Shot: dash the way you are moving (`aim` is the dash direction here) while firing at the cursor
	var shot: Vector2 = player.aim_point() - player.global_position
	shot = shot.normalized() if shot.length() > 1.0 else aim
	player.dash(aim, 46.0, 0.15)
	var roll := weapon_id == "bow" and tier >= 4          # Smoke Roll: a three-arrow fan
	var ex := {"trail": 3} if weapon_id == "bow" and tier >= 2 else {}
	WeaponProjectile.shoot(game_world(), player.global_position + shot * 8.0, shot, 300.0, 2.0, Color(1.0, 0.85, 0.4), 1.0, 0, 90.0, ex)
	if roll:
		for sd in [-0.2, 0.2]:
			WeaponProjectile.shoot(game_world(), player.global_position + shot * 8.0, shot.rotated(sd), 300.0, 0.6, Color(1.0, 0.85, 0.4), 1.0, 0, 60.0, ex)
	fx("line", player.global_position, Color(1, 1, 1), {"dir": -aim, "length": 30.0, "width": 4.0, "life": 0.2})

func ability() -> void:
	thrust(-6.0, 0.3)
	var fan_n := 7 if weapon_id == "bow" and tier >= 2 else 5          # Fan: seven arrows, the middle one a lead arrow
	var gap := 0.14 if fan_n == 7 else 0.17
	for i in fan_n:
		var d := aim.rotated((i - fan_n / 2) * gap)
		var extra := {}
		var pierce := 0
		var col := Color(1.0, 0.85, 0.4)
		if fan_n == 7:
			extra["trail"] = 3
			if i == fan_n / 2:
				pierce = 2
				col = Color(1.0, 0.85, 0.2)
				extra = {"trail": 3, "expose_secs": 1.5, "size": 1.2}
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 290.0, 1.5, col, 1.0, pierce, 80.0, extra)

func ultimate() -> void:
	# Arrow Storm: two seconds of rapid fire toward the cursor (you can still move)
	player.speed_mult = 0.6
	for i in 13:                                                   # a shorter storm than before (13 shots), then a finale
		if !is_inside_tree():
			return
		var d := aim.rotated(randf_range(-0.18, 0.18))
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 320.0, 1.7, Color(1.0, 0.85, 0.4), 0.9, 0, 70.0)
		await get_tree().create_timer(0.1).timeout
	if is_inside_tree():                                           # finale: one big arrow slams down at the cursor
		var big := weapon_id == "bow" and tier >= 6
		_st["finale_c"] = cursor_target(150.0)
		WeaponTiers.run(self, "finale")
		ground_strike(_st["finale_c"], 48.0 if big else 38.0, 0.4, 4.0, 200.0, Color(1.0, 0.9, 0.4), 0.6 if big else 0.4)
	if is_inside_tree():
		player.speed_mult = 1.0

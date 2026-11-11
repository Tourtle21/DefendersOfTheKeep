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
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 8.0, aim, speed, dmg, col, 1.1, pierce, 80.0 + 60.0 * ratio)

func dash_attack() -> void:
	# Roll Shot: dash the way you are moving (`aim` is the dash direction here) while firing at the cursor
	var shot: Vector2 = player.aim_point() - player.global_position
	shot = shot.normalized() if shot.length() > 1.0 else aim
	player.dash(aim, 46.0, 0.15)
	WeaponProjectile.shoot(game_world(), player.global_position + shot * 8.0, shot, 300.0, 2.0, Color(1.0, 0.85, 0.4), 1.0, 0, 90.0)
	fx("line", player.global_position, Color(1, 1, 1), {"dir": -aim, "length": 30.0, "width": 4.0, "life": 0.2})

func ability() -> void:
	thrust(-6.0, 0.3)
	for i in 5:
		var d := aim.rotated((i - 2) * 0.17)
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 290.0, 1.5, Color(1.0, 0.85, 0.4), 1.0, 0, 80.0)

func ultimate() -> void:
	# Arrow Storm: two seconds of rapid fire toward the cursor (you can still move)
	player.speed_mult = 0.6
	for i in 20:
		if !is_inside_tree():
			return
		var d := aim.rotated(randf_range(-0.18, 0.18))
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 320.0, 1.5, Color(1.0, 0.85, 0.4), 0.9, 0, 70.0)
		await get_tree().create_timer(0.1).timeout
	if is_inside_tree():
		player.speed_mult = 1.0

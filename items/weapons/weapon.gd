extends Node2D
class_name Weapon
## Base class for code-driven weapons held in the player's right hand. It follows
## the player, points at the mouse, and has a basic attack (left click) and an
## ability (right click) with a cooldown. Subclasses set the fields in _init and
## override attack() / ability().

var weapon_id := ""
var element := ""              # "", fire, ice, poison, earth or pierce (ignores armor): see enemy traits
var tier := 1                  # 1-6: fusion tier + Forge awakenings (ability needs 2, ultimate needs 3)
var awakened := 0
var bonus_tier := 0            # this copy's tier bonus (rare drop or Forge combining), set before it enters the tree
var twist := ""                # this copy's twist (see Game.TWISTS)
var weapon_name := ""
var icon_path := ""
var ability_name := ""
var attack_name := "Attack"
var hold_ability := false      # true = right click is press-to-start / release-to-finish (charge style)
var ultimate_name := ""
var ultimate_cooldown := 60.0
var _ult_cd := 0.0
var dash_name := ""
var dash_cooldown := 4.0
var preview_ability := {}      # {"kind": "circle"|"line", ...} shown while the ability is ready
var preview_ultimate := {}     # shown while Space is held and the ultimate is ready
var preview_dash := 0.0        # dash distance, drawn as a chevron when ready
var attack_cooldown := 0.5
var ability_cooldown := 5.0
var reach := 11.0              # how far out the sprite sits from the player
var icon_scale := 0.55
var swing_offset := 0.0        # extra rotation, animated by swing()
var player                     # untyped on purpose: calls dash()/blink()/shield_time
var aim := Vector2.RIGHT
var sprite: Sprite2D
var _attack_cd := 0.0
var _ability_cd := 0.0
var _dash_cd := 0.0
var _dash_until := 0.0
var _dash_dmg := 0.0
var _dash_radius := 12.0
var _dash_knock := 0.0
var _dash_hit := []

func equip() -> void:
	pass

func _ready() -> void:
	tier = clampi(Fusion.tier_of(weapon_id) + bonus_tier, 1, 6)
	awakened = bonus_tier
	var cd_mult := pow(0.92, awakened) * maxf(0.4, 1.0 - Game.bonus("weapon_cd"))
	attack_cooldown *= cd_mult
	ability_cooldown *= cd_mult
	dash_cooldown *= cd_mult * maxf(0.4, 1.0 - Game.bonus("dash_cd"))
	ultimate_cooldown *= cd_mult * maxf(0.4, 1.0 - Game.bonus("ult_cd"))
	WeaponUtil.element = element
	WeaponUtil.twist = twist
	WeaponUtil.power = (1.0 + 0.2 * awakened) * (1.0 + Game.bonus("weapon_dmg"))
	top_level = true
	z_as_relative = false
	z_index = 5
	player = get_parent().get_parent()
	sprite = Sprite2D.new()
	sprite.texture = load(icon_path)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.rotation = PI / 2.0     # icons are drawn tip-up; point the tip along +x
	sprite.position = Vector2(reach, 0)
	sprite.scale = Vector2(icon_scale, icon_scale)
	add_child(sprite)
	_follow()

func _follow() -> void:
	global_position = player.global_position + Vector2(0, -3)
	var m: Vector2 = player.aim_point() - player.global_position
	if m.length() > 2.0:
		aim = m.normalized()
	rotation = aim.angle() + swing_offset

func _process(delta: float) -> void:
	_attack_cd = max(0.0, _attack_cd - delta)
	_ability_cd = max(0.0, _ability_cd - delta)
	_dash_cd = max(0.0, _dash_cd - delta)
	_ult_cd = max(0.0, _ult_cd - delta)
	_follow()
	queue_redraw()
	if Time.get_ticks_msec() / 1000.0 < _dash_until:
		for e in WeaponUtil.enemies_in_circle(get_tree(), player.global_position, _dash_radius):
			if !(e in _dash_hit):
				_dash_hit.append(e)
				WeaponUtil.hit(e, _dash_dmg, player.global_position, _dash_knock)
				_on_dash_hit(e)

func use_item() -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_cooldown
	Sfx.play("whoosh", 0.15)
	attack()

func ability_unlocked() -> bool:
	return tier >= 2

func ultimate_unlocked() -> bool:
	return tier >= 3

var _lock_note_ms := 0

func _locked_note(what: String, need: int) -> void:
	if Time.get_ticks_msec() - _lock_note_ms > 1500:
		_lock_note_ms = Time.get_ticks_msec()
		Game.announce.emit("%s needs tier %d. Awaken or fuse this weapon at the Forge." % [what, need])

func use_ability() -> void:
	if !ability_unlocked():
		if ability_name != "":
			_locked_note("The ability", 2)
		return
	if _ability_cd > 0.0:
		return
	_ability_cd = ability_cooldown
	Sfx.play("cast", 0.05, 0.8)
	ability()

## (seconds left, total cooldown, display name) for the ability HUD.
func cd_info(slot: String) -> Array:
	match slot:
		"attack": return [_attack_cd, attack_cooldown, attack_name]
		"ability": return [_ability_cd, ability_cooldown, ability_name, !ability_unlocked(), 2]
		"dash": return [_dash_cd, dash_cooldown, dash_name]
		"ultimate": return [_ult_cd, ultimate_cooldown, ultimate_name, !ultimate_unlocked(), 3]
	return [0.0, 1.0, ""]

func ability_cd_left() -> float:
	return _ability_cd

func dash_cd_left() -> float:
	return _dash_cd

func ult_cd_left() -> float:
	return _ult_cd

func use_ultimate() -> void:
	if !ultimate_unlocked():
		if ultimate_name != "":
			_locked_note("The ultimate", 3)
		return
	if _ult_cd > 0.0 or ultimate_name == "":
		return
	_ult_cd = ultimate_cooldown
	Sfx.play("ultimate", 0.02)
	player.shake(3.0, 0.3)
	ultimate()

func ultimate() -> void:
	pass

func pulse_around(dmg: float, radius: float, knock: float, stun: float, count: int, interval: float, color := Color(1, 1, 1)) -> void:
	WeaponUtil.pulses(get_tree(), game_world(), player, dmg, radius, knock, stun, count, interval, color)

func rain(center: Vector2, radius: float, count: int, duration: float, dmg: float, strike_r: float, color: Color, stun := 0.0) -> void:
	WeaponUtil.rain(get_tree(), game_world(), center, radius, count, duration, dmg, strike_r, color, stun)

func use_dash() -> void:
	if _dash_cd > 0.0 or dash_name == "":
		return
	_dash_cd = dash_cooldown
	Sfx.play("whoosh", 0.05, 1.5)
	dash_attack()

func dash_attack() -> void:
	pass

## Cursor position clamped to a maximum range from the player.
func cursor_target(max_range: float) -> Vector2:
	var d: Vector2 = player.aim_point() - player.global_position
	return player.global_position + d.limit_length(max_range)

## Telegraphed strike on the ground: a ring shows where it will land, then it hits.
func ground_strike(center: Vector2, radius: float, delay: float, dmg: float, knock: float, color: Color, stun := 0.0, breakable_types: Array = []) -> void:
	WeaponUtil.ground_strike(get_tree(), game_world(), center, radius, delay, dmg, knock, color, stun, breakable_types)

func _draw() -> void:
	# previews, in this node's rotated space (x axis = aim direction)
	if player == null:
		return
	if _ability_cd <= 0.0 and ability_unlocked() and !preview_ability.is_empty() and player.aim_time("ability") >= 1.0:
		var col := Color(1, 1, 1, 0.55)
		if preview_ability.kind == "circle":
			var tgt := cursor_target(preview_ability.range)
			var local := to_local(tgt)
			draw_arc(local, preview_ability.radius, 0, TAU, 28, col, 1.0)
		elif preview_ability.kind == "line":
			draw_dashed_line(Vector2(10, 0), Vector2(10 + preview_ability.length, 0), col, 1.0, 4.0)
	if _ult_cd <= 0.0 and ultimate_unlocked() and ultimate_name != "" and !preview_ultimate.is_empty() and player.aim_time("ultimate") >= 1.0:
		var ucol := Color(1.0, 0.85, 0.3, 0.9)
		var up: Dictionary = preview_ultimate
		if up.kind == "circle":
			draw_arc(to_local(cursor_target(up.range)), up.radius, 0, TAU, 36, ucol, 2.0)
			draw_dashed_line(Vector2.ZERO, to_local(cursor_target(up.range)), Color(ucol, 0.5), 1.0, 5.0)
		elif up.kind == "line":
			draw_line(Vector2(10, 0), Vector2(10 + up.length, 0), ucol, 2.0)
		else:
			draw_arc(Vector2.ZERO, up.radius, 0, TAU, 36, ucol, 2.0)
	if _dash_cd <= 0.0 and preview_dash > 0.0 and player.aim_time("dash") >= 1.0:
		var tip := Vector2(preview_dash, 0)
		draw_line(tip + Vector2(-3, -3), tip, Color(1, 1, 1, 0.3), 1.0)
		draw_line(tip + Vector2(-3, 3), tip, Color(1, 1, 1, 0.3), 1.0)

func release_item() -> void:
	pass

func release_ability() -> void:
	pass

func _on_dash_hit(_e) -> void:
	pass

func _exit_tree() -> void:
	if player != null and is_instance_valid(player):
		player.speed_mult = 1.0
		player.parry_time = 0.0

func attack() -> void:
	pass

func ability() -> void:
	pass

# ---- helpers for subclasses ----

func swing(span: float, t: float) -> void:
	swing_offset = -span
	var tw := create_tween()
	tw.tween_property(self, "swing_offset", span, t)
	tw.tween_property(self, "swing_offset", 0.0, 0.08)

func thrust(dist: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", reach + dist, t * 0.4)
	tw.tween_property(sprite, "position:x", reach, t * 0.6)

func start_dash_hits(dmg: float, radius: float, knock: float, duration: float) -> void:
	_dash_dmg = dmg
	_dash_radius = radius
	_dash_knock = knock
	_dash_hit = []
	_dash_until = Time.get_ticks_msec() / 1000.0 + duration

func game_world() -> Node:
	return player.get_parent()

func fx(kind: String, pos: Vector2, color: Color, params := {}) -> void:
	WeaponFx.spawn(game_world(), kind, pos, color, params)

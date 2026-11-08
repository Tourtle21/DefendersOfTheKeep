extends Node2D
class_name Tool

@export var starting_position: Vector2 = Vector2(5, 5)

var ability_name := ""
var attack_name := ""
var dash_name := ""
var _ability_cd := 0.0
var _dash_cd := 0.0
var ultimate_name := ""
var _ult_cd := 0.0
# Sword and Pickaxe use the same tier ladder as every weapon: tier 1 attack + dash, tier 2 the right-click
# ability, tier 3 the ultimate, tiers 4 to 6 stronger and faster. A copy's tier is 1 + its bonus.
var bonus_tier := 0
var twist := ""
var tier := 1
var attack_cooldown := 0.5
var ability_cooldown := 6.0
var dash_cooldown := 4.0
var ultimate_cooldown := 60.0
var _lock_note_ms := 0

## "sword" or "pickaxe". From the scene file, because the node can be renamed when a copy replaces another in the same frame.
func _id() -> String:
	return scene_file_path.get_file().get_basename()

## Size of this tool's areas: +12% per tier above 1.
func area() -> float:
	return 1.0 + 0.12 * (tier - 1)

func ability_unlocked() -> bool:
	return tier >= 2

func ultimate_unlocked() -> bool:
	return tier >= 3

func _locked_note(what: String, need: int) -> void:
	if Time.get_ticks_msec() - _lock_note_ms > 1500:
		_lock_note_ms = Time.get_ticks_msec()
		Game.announce.emit("%s needs tier %d. Combine two copies of this tool at the Forge." % [what, need])

## (seconds left, total cooldown, display name, locked, tier needed) for the ability HUD.
func cd_info(slot: String) -> Array:
	match slot:
		"attack": return [0.0, attack_cooldown, attack_name]
		"ability": return [_ability_cd, ability_cooldown, ability_name, !ability_unlocked(), 2]
		"dash": return [_dash_cd, dash_cooldown, dash_name]
		"ultimate": return [_ult_cd, ultimate_cooldown, ultimate_name, !ultimate_unlocked(), 3]
	return [0.0, 1.0, ""]

func ability_cd_left() -> float:
	return _ability_cd

func dash_cd_left() -> float:
	return _dash_cd

func _process(delta: float) -> void:
	_ability_cd = max(0.0, _ability_cd - delta)
	_dash_cd = max(0.0, _dash_cd - delta)
	_ult_cd = max(0.0, _ult_cd - delta)

func use_ability() -> void:
	if !ability_unlocked():
		_locked_note("The ability", 2)
		return
	if _ability_cd > 0.0:
		return
	Sfx.play("cast", 0.05, 0.8)
	var player = get_parent().get_parent()
	var o: Vector2 = player.global_position
	var world = player.get_parent()
	match _id():
		"sword":
			# Whirlwind: spin for ~1s, three pulses around you. You keep moving, so
			# spin through a group instead of standing still.
			_ability_cd = ability_cooldown
			for i in 3:
				if !is_inside_tree():
					return
				var pos: Vector2 = player.global_position
				WeaponFx.spawn(world, "ring", pos, Color(1, 1, 1), {"radius": 34.0 * area(), "life": 0.25})
				for e in WeaponUtil.enemies_in_circle(get_tree(), pos, 34.0 * area()):
					WeaponUtil.hit(e, 2.0, pos, 160.0)
				WeaponUtil.hit_breakables(get_tree(), pos, 34.0 * area())
				player.shake(1.0, 0.1)
				await get_tree().create_timer(0.3).timeout
		"pickaxe":
			# Seismic Strike: the ground erupts at the cursor after a beat (lead targets)
			# It mines an area: everything breakable in the blast is broken, and the area grows with tier.
			_ability_cd = ability_cooldown
			var c: Vector2 = o + (player.aim_point() - o).limit_length(80.0)
			var r: float = 24.0 * area() * (1.0 + 0.25 * maxi(0, tier - 2))
			await WeaponUtil.ground_strike(get_tree(), world, c, r, 0.5, 3.0, 260.0, Color(0.9, 0.7, 0.4))
			for i in 3 + 2 * tier:                 # mining power grows with tier (a big rock has 64 health)
				WeaponUtil.hit_breakables(get_tree(), c, r)

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
	var player = get_parent().get_parent()
	var world = player.get_parent()
	player.shake(3.0, 0.3)
	match _id():
		"sword":
			# Blade Tempest: a long, fast spin that keeps hitting while you move
			WeaponUtil.pulses(get_tree(), world, player, 2.0, 44.0 * area(), 140.0, 0.0, 16, 0.15, Color(1, 1, 1))
		"pickaxe":
			# Earthquake: the whole area shudders, stunning and hurting everything nearby
			var o: Vector2 = player.global_position
			var er: float = 150.0 * area()
			WeaponFx.spawn(world, "ring", o, Color(0.9, 0.7, 0.4), {"radius": er, "life": 0.7})
			await get_tree().create_timer(0.6).timeout
			for e in WeaponUtil.enemies_in_circle(get_tree(), o, er):
				WeaponUtil.hit(e, 4.0, o, 200.0, 1.5)
			for i in 6 + 3 * tier:
				WeaponUtil.hit_breakables(get_tree(), o, er)
			player.shake(6.0, 0.5)

func use_dash() -> void:
	if _dash_cd > 0.0:
		return
	Sfx.play("whoosh", 0.05, 1.5)
	var player = get_parent().get_parent()
	var o: Vector2 = player.global_position
	var aim: Vector2 = (player.aim_point() - o).normalized()
	var world = player.get_parent()
	match _id():
		"sword":
			# Slash Dash: dash forward and finish with a wide slash
			_dash_cd = dash_cooldown
			WeaponFx.spawn(world, "line", o, Color(1, 1, 1), {"dir": aim, "length": 50.0, "width": 5.0, "life": 0.2})
			player.dash(aim, 50.0, 0.14)
			await get_tree().create_timer(0.16).timeout
			if !is_inside_tree():
				return
			var pos: Vector2 = player.global_position
			WeaponFx.spawn(world, "arc", pos, Color(1, 1, 1), {"radius": 28.0, "dir": aim, "half_angle": 1.1, "life": 0.18})
			for e in WeaponUtil.enemies_in_arc(get_tree(), pos, aim, 28.0, 65.0):
				WeaponUtil.hit(e, 2.5, pos, 200.0)
			WeaponUtil.hit_breakables(get_tree(), pos + aim * 14.0, 20.0)
		"pickaxe":
			# Dash-Mine: lunge forward breaking whatever is in the way
			_dash_cd = dash_cooldown
			WeaponFx.spawn(world, "line", o, Color(0.9, 0.7, 0.4), {"dir": aim, "length": 72.0, "width": 6.0, "life": 0.25})
			for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 72.0, 12.0):
				WeaponUtil.hit(e, 2.0, o, 120.0)
			WeaponUtil.hit_breakables(get_tree(), o + aim * 36.0, 40.0)
			WeaponUtil.hit_breakables(get_tree(), o + aim * 36.0, 40.0)
			player.dash(aim, 70.0, 0.16)

func _ready() -> void:
	tier = clampi(1 + bonus_tier, 1, 6)
	var cd_mult := pow(0.92, bonus_tier) * maxf(0.4, 1.0 - Game.bonus("weapon_cd"))
	ability_cooldown *= cd_mult
	dash_cooldown = (4.0 if _id() == "sword" else 5.0) * cd_mult * maxf(0.4, 1.0 - Game.bonus("dash_cd"))
	ultimate_cooldown *= cd_mult * maxf(0.4, 1.0 - Game.bonus("ult_cd"))
	WeaponUtil.element = ""
	WeaponUtil.twist = twist
	WeaponUtil.power = (1.0 + 0.2 * bonus_tier) * (1.0 + Game.bonus("weapon_dmg"))
	match _id():
		"sword":
			ability_name = "Whirlwind"
			ultimate_name = "Blade Tempest"
			dash_name = "Slash Dash"
			attack_name = "Slash"
		"pickaxe":
			ability_name = "Seismic Strike"
			ultimate_name = "Earthquake"
			dash_name = "Dash-Mine"
			attack_name = "Mine"
	var animation_player = $AnimationPlayer
	if animation_player and !animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.connect("animation_finished", _on_animation_player_animation_finished)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "use_item":
		$AnimationPlayer.play("RESET")
		get_parent().get_parent().is_using_item = false

func equip() -> void:
	position = starting_position
	
func use_item() -> void:
	pass

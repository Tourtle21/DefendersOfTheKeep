extends Weapon
class_name Tool
## Sword and Pickaxe: the two starting tools. They are weapons like every other (same cooldowns, tier ladder, WeaponUtil power and
## twist, WeaponTiers modules, aura and hooks): they only differ in how they are drawn and how the basic attack hits. They are scenes
## with their own animation, and the swing's hitbox does the basic damage (the Hitbox node), so attack() does nothing and the picture
## is not a code-drawn sprite. Ability, dash and ultimate are the ordinary verbs below (the base class does the cooldowns, sounds and hooks).
## A copy's tier is 1 + its bonus.

@export var starting_position: Vector2 = Vector2(5, 5)

## "sword" or "pickaxe". From the scene file, because the node can be renamed when a copy replaces another in the same frame.
func _id() -> String:
	return scene_file_path.get_file().get_basename()

## Size of this tool's areas: +12% per tier above 1.
func area() -> float:
	return 1.0 + 0.12 * (tier - 1)

func _init() -> void:
	ability_cooldown = 6.0
	attack_cooldown = 0.5
	reach = 12.0
	lock_hint = "Combine two copies of this tool at the Forge."

func _ready() -> void:
	weapon_id = _id()
	match weapon_id:
		"sword":
			weapon_name = "Sword"
			ability_name = "Whirlwind"
			ultimate_name = "Blade Tempest"
			dash_name = "Slash Dash"
			attack_name = "Slash"
			dash_cooldown = 4.0
		"pickaxe":
			weapon_name = "Pickaxe"
			ability_name = "Seismic Strike"
			ultimate_name = "Earthquake"
			dash_name = "Dash-Mine"
			attack_name = "Mine"
			dash_cooldown = 5.0
	super()
	var animation_player = $AnimationPlayer
	if animation_player and !animation_player.is_connected("animation_finished", _on_animation_player_animation_finished):
		animation_player.connect("animation_finished", _on_animation_player_animation_finished)

func _attach_visual() -> void:
	pass                                   # the scene is the picture

## The tool stays in the hand where the animation puts it; only the aim follows the cursor.
func _follow() -> void:
	var m: Vector2 = player.aim_point() - player.global_position
	if m.length() > 2.0:
		aim = m.normalized()

func _orient() -> void:
	pass

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "use_item":
		$AnimationPlayer.play("RESET")
		get_parent().get_parent().is_using_item = false

func equip() -> void:
	position = starting_position

## The swing is the animation (the player starts it); the usual verb bookkeeping and tier riders run without a cooldown.
func use_item() -> void:
	_claim()
	_verb_ms["attack"] = Time.get_ticks_msec()
	WeaponTiers.run(self, "pre_attack")
	WeaponTiers.run(self, "attack")

func ability() -> void:
	match weapon_id:
		"sword":
			# Whirlwind: spin for ~1s, three pulses around you. You keep moving, so spin through a group instead of standing still.
			for i in 3:
				if !is_inside_tree():
					return
				var pos: Vector2 = player.global_position
				var grow = WeaponTiers.run(self, "whirl_scale", [i])          # tier 2: the pulses grow (Gale)
				var rr: float = 34.0 * area() * (float(grow) if grow != null else 1.0)
				if grow == null:
					fx("ring", pos, Color(1, 1, 1), {"radius": rr, "life": 0.25})
				for e in WeaponUtil.enemies_in_circle(get_tree(), pos, rr):
					WeaponUtil.hit(e, 2.0, pos, 160.0)
				WeaponTiers.run(self, "whirl_pulse", [i, pos, rr])
				player.shake(1.0, 0.1)
				await get_tree().create_timer(0.3).timeout
		"pickaxe":
			# Seismic Strike: the ground erupts at the cursor after a beat (lead targets). It mines an area: everything breakable in
			# the blast is broken, and the area grows with tier.
			var o: Vector2 = player.global_position
			var c: Vector2 = o + (player.aim_point() - o).limit_length(80.0)
			var r: float = 24.0 * area() * (1.0 + 0.25 * maxi(0, tier - 2))
			await WeaponUtil.ground_strike(get_tree(), game_world(), c, r, 0.5, 3.0, 260.0, Color(0.9, 0.7, 0.4))
			for i in 3 + 2 * tier:                 # mining power grows with tier (a big rock has 64 health)
				WeaponUtil.hit_breakables(get_tree(), c, r)

func ultimate() -> void:
	match weapon_id:
		"sword":
			# Blade Tempest: a long, fast spin that keeps hitting while you move
			pulse_around(2.0, 44.0 * area(), 140.0, 0.0, 16, 0.15, Color(1, 1, 1))
		"pickaxe":
			# Earthquake: the whole area shudders, stunning and hurting everything nearby
			var o: Vector2 = player.global_position
			var er: float = 150.0 * area()
			fx("ring", o, Color(0.9, 0.7, 0.4), {"radius": er, "life": 0.7})
			await get_tree().create_timer(0.6).timeout
			for e in WeaponUtil.enemies_in_circle(get_tree(), o, er):
				WeaponUtil.hit(e, 4.0, o, 200.0, 1.5)
			for i in 6 + 3 * tier:
				WeaponUtil.hit_breakables(get_tree(), o, er)
			player.shake(6.0, 0.5)

func dash_attack() -> void:
	var o: Vector2 = player.global_position
	match weapon_id:
		"sword":
			# Slash Dash: dash forward and finish with a wide slash
			fx("line", o, Color(1, 1, 1), {"dir": aim, "length": 50.0, "width": 5.0, "life": 0.2})
			player.dash(aim, 50.0, 0.14)
			await get_tree().create_timer(0.16).timeout
			if !is_inside_tree():
				return
			var pos: Vector2 = player.global_position
			fx("arc", pos, Color(1, 1, 1), {"radius": 28.0, "dir": aim, "half_angle": 1.1, "life": 0.18})
			for e in WeaponUtil.enemies_in_arc(get_tree(), pos, aim, 28.0, 65.0):
				WeaponUtil.hit(e, 2.5, pos, 200.0)
		"pickaxe":
			# Dash-Mine: lunge forward breaking whatever is in the way
			fx("line", o, Color(0.9, 0.7, 0.4), {"dir": aim, "length": 72.0, "width": 6.0, "life": 0.25})
			for e in WeaponUtil.enemies_in_line(get_tree(), o, aim, 72.0, 12.0):
				WeaponUtil.hit(e, 2.0, o, 120.0)
			WeaponUtil.hit_breakables(get_tree(), o + aim * 36.0, 40.0)
			WeaponUtil.hit_breakables(get_tree(), o + aim * 36.0, 40.0)
			player.dash(aim, 70.0, 0.16)

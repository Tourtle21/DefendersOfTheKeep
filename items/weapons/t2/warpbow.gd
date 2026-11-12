extends "res://items/weapons/bow.gd"
## Warp Bow (Bow + Staff). Same hold-to-draw bow, but the right click is a Warp
## Arrow: it plants an anchor where it lands and a second right click teleports
## you there with a burst. Phase Step is a short, safe blink.

var _anchor := Vector2.ZERO
var _anchor_until := 0.0

func _init() -> void:
	weapon_id = "warpbow"
	weapon_name = "Warp Bow"
	icon_path = "res://items/weapons/icons/warpbow.png"
	attack_name = "Arcane draw (hold, release)"
	ability_name = "Warp Arrow (press again to warp)"
	dash_name = "Phase Step"
	ultimate_name = "Rift Volley"
	preview_ultimate = {"kind": "line", "length": 160.0}
	ability_cooldown = 6.0
	dash_cooldown = 3.0
	preview_ability = {"kind": "line", "length": 150.0}
	preview_dash = 0.0

func use_ability() -> void:
	_claim()
	if !ability_unlocked():
		if ability_name != "":
			_locked_note("The ability", 2)
		return
	if WeaponTiers.has_fn(weapon_id, "use_ability"):        # the Warp Bow's tier module plants and chains Rift Gates
		WeaponTiers.run(self, "use_ability")
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _anchor_until > now:
		_anchor_until = 0.0
		var from: Vector2 = player.global_position
		player.blink(_anchor - from)
		fx("ring", from, Color(0.6, 0.45, 1.0), {"radius": 16.0, "life": 0.3})
		fx("ring", player.global_position, Color(0.8, 0.6, 1.0), {"radius": 26.0, "life": 0.3})
		ground_strike(player.global_position, 26.0, 0.05, 3.0, 200.0, Color(0.6, 0.45, 1.0), 0.5)
		_on_warped(player.global_position)
		_ability_cd = ability_cooldown
		return
	if _ability_cd > 0.0:
		return
	var dist: float = min(150.0, (player.aim_point() - player.global_position).length())
	var land: Vector2 = player.global_position + aim * dist
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 8.0, aim, 300.0, 0.5, Color(0.7, 0.5, 1.0), dist / 300.0, 0, 20.0)
	_anchor = land
	_anchor_until = now + 2.5
	fx("ring", land, Color(0.7, 0.5, 1.0), {"radius": 14.0, "life": 2.5})
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree() and _anchor_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _anchor_until - 0.05:
		_anchor_until = 0.0
		_ability_cd = 3.0          # anchor expired unused

func _on_warped(_dest: Vector2) -> void:
	pass

func release_item() -> void:
	var was := _drawing
	super()
	if was:
		WeaponTiers.run(self, "attack")                     # one arrow released (the Bow's release does not run the hook)

func dash_attack() -> void:
	player.blink(aim * 40.0)
	player.shield_time = max(player.shield_time, 0.3)
	fx("ring", player.global_position, Color(0.6, 0.45, 1.0), {"radius": 14.0, "life": 0.3})

func ultimate() -> void:
	# Rift Volley: nine piercing arrows in a wide fan
	for i in 9:
		var d := aim.rotated((i - 4) * 0.12)
		WeaponProjectile.shoot(game_world(), player.global_position + d * 8.0, d, 330.0, 3.0, Color(0.8, 0.6, 1.0), 0.9, 3, 100.0)

extends Weapon
## Bulwark Maul (Shield + Hammer). Brace is the shield's parry stretched into a
## stance: hold right click to take no damage while STORING each hit you block,
## then release to slam for everything you absorbed. Shoulder Charge rams through.

var max_store := 5
var brace_speed := 0.4
var _braced := false
var _stored := 0
var _brace_t := 0.0
var brace_secs := 3.0                # how long a brace may last (a shield bash at tier 3+ extends it, see tiers/bulwark.gd)

func _init() -> void:
	hold_ability = true
	weapon_id = "bulwark"
	element = "crush"
	weapon_name = "Bulwark Maul"
	icon_path = "res://items/weapons/icons/bulwark.png"
	attack_name = "Maul swing (slow, huge knockback)"
	ability_name = "Brace (hold, release to slam)"
	dash_name = "Shoulder Charge"
	ultimate_name = "Quake Fortress"
	preview_ultimate = {"kind": "self", "radius": 52.0}
	attack_cooldown = 0.8
	ability_cooldown = 8.0
	dash_cooldown = 5.0
	reach = 10.0
	icon_scale = 0.7
	preview_dash = 60.0

func attack() -> void:
	swing(1.1, 0.25)
	await get_tree().create_timer(0.22).timeout
	if !is_inside_tree():
		return
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.7, 0.8, 1.0), {"radius": 32.0, "dir": aim, "half_angle": 1.0, "life": 0.2})
	player.shake(2.0, 0.12)
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 32.0, 60.0):
		WeaponUtil.hit(e, Game.basic_hit(weapon_id), o, 340.0, 0.4)
	WeaponUtil.hit_breakables(get_tree(), o + aim * 16.0, 24.0, ["stone"])

func use_ability() -> void:
	_claim()
	if !ability_unlocked():
		if ability_name != "":
			_locked_note("The ability", 2)
		return
	if _ability_cd > 0.0 or _braced:
		return
	_braced = true
	_stored = 0
	_brace_t = 0.0
	brace_secs = 3.0
	player.speed_mult = brace_speed
	player.parry_time = 99.0
	player.on_parry = _on_absorb
	fx("ring", player.global_position, Color(0.6, 0.75, 1.0), {"radius": 20.0, "life": 0.3})

func use_item() -> void:
	if _braced and tier >= 3:                  # weapon tiers: a shield bash while braced (the module answers true when it handled the click)
		_claim()
		if _attack_cd > 0.0:
			return
		if WeaponTiers.run(self, "bash") == true:
			_attack_cd = attack_cooldown * 0.6
			return
	super()

func _on_absorb(_from: Vector2) -> void:
	_stored = min(max_store, _stored + 1)
	WeaponTiers.run(self, "absorb", [_from])
	player.parry_time = 99.0         # stay braced
	player.shake(1.5, 0.1)
	fx("ring", player.global_position, Color(1.0, 0.9, 0.5), {"radius": 14.0 + 4.0 * _stored, "life": 0.25})

func _process(delta: float) -> void:
	super(delta)
	if _braced:
		_brace_t += delta
		if _brace_t >= brace_secs:
			release_ability()

func release_ability() -> void:
	_claim()
	if !_braced:
		return
	_braced = false
	player.speed_mult = 1.0
	player.parry_time = 0.0
	_ability_cd = ability_cooldown
	var o: Vector2 = player.global_position
	var r := 30.0 + 8.0 * _stored
	_st["released"] = _stored
	fx("ring", o, Color(1.0, 0.85, 0.4), {"radius": r, "life": 0.4})
	player.shake(2.0 + _stored, 0.25)
	for e in WeaponUtil.enemies_in_circle(get_tree(), o, r):
		WeaponUtil.hit(e, 2.0 + 1.5 * _stored, o, 240.0 + 40.0 * _stored, 0.5 + 0.2 * _stored)
	_stored = 0
	WeaponTiers.run(self, "release")

func dash_attack() -> void:
	fx("line", player.global_position, Color(0.6, 0.75, 1.0), {"dir": aim, "length": 60.0, "width": 10.0, "life": 0.25})
	player.dash(aim, 60.0, 0.2)
	start_dash_hits(2.0, 16.0, 380.0, 0.24)

func _on_dash_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.apply_slow(0.0, 0.8)

func ultimate() -> void:
	# Quake Fortress: untouchable for four seconds with a stunning pulse each second
	player.shield_time = max(player.shield_time, 4.0)
	if tier >= 5 and WeaponTiers.run(self, "fortress") == true:        # weapon tiers: Citadel Pulse replaces the plain pulses
		return
	pulse_around(2.0, 52.0, 280.0, 0.5, 4, 1.0, Color(0.6, 0.75, 1.0))

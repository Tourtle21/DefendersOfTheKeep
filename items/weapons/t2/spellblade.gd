extends Weapon
## Spellblade (Sword + Staff). Slashes throw a piercing wave. Blade Storm summons
## orbiting blades for four seconds, so walk INTO enemies to use it. Arcane Dash
## exposes what it cuts through.

var blade_count := 3
var storm_len := 4.0
var _storm_until := 0.0
var _angle := 0.0
var _blade_hit := {}
var storm_bonus := 0                 # weapon tiers (spellblade): extra storm blades while the Blade Storm runs
var storm_r := 26.0                  # the storm's radius and the gap between two touches of one enemy
var hit_gap := 0.45

func _init() -> void:
	weapon_id = "spellblade"
	element = "fire"
	weapon_name = "Spellblade"
	icon_path = "res://items/weapons/icons/spellblade.png"
	attack_name = "Wave slash (piercing wave)"
	ability_name = "Blade Storm (orbiting blades)"
	dash_name = "Arcane Dash"
	ultimate_name = "Blade Dance"
	preview_ultimate = {"kind": "self", "radius": 30.0}
	attack_cooldown = 0.4
	ability_cooldown = 9.0
	dash_cooldown = 4.0
	reach = 12.0
	icon_scale = 0.6
	preview_dash = 55.0

func attack() -> void:
	swing(1.0, 0.15)
	var o: Vector2 = player.global_position
	fx("arc", o, Color(0.7, 0.8, 1.0), {"radius": 28.0, "dir": aim, "half_angle": 0.9, "life": 0.15})
	for e in WeaponUtil.enemies_in_arc(get_tree(), o, aim, 28.0, 55.0):
		WeaponUtil.hit(e, Game.basic_hit(weapon_id) * 0.5, o, 100.0)
	var extra := {}
	if weapon_id == "spellblade" or weapon_id == "starfall":     # weapon tiers: crescent waves with a trail, chaining at tier 4 (_st.chain)
		extra = {"style": "crescent", "size": 1.0, "trail": 3, "chain": int(_st.get("chain", 0))}
	WeaponProjectile.shoot(game_world(), o + aim * 14.0, aim, 240.0, Game.basic_hit(weapon_id) * 0.5, Color(0.7, 0.8, 1.0), 0.5, 1, 100.0, extra)

func ability() -> void:
	_storm_until = Time.get_ticks_msec() / 1000.0 + storm_len
	_blade_hit = {}

func _process(delta: float) -> void:
	super(delta)
	var now := Time.get_ticks_msec() / 1000.0
	if now < _storm_until:
		_angle += 6.0 * delta
		var n := blades_now()
		for i in n:
			var pos: Vector2 = player.global_position + Vector2.from_angle(_angle + i * TAU / n) * storm_r
			for e in WeaponUtil.enemies_in_circle(get_tree(), pos, 9.0):
				if !_blade_hit.has(e) or now - _blade_hit[e] > hit_gap:
					_blade_hit[e] = now
					WeaponUtil.hit(e, 1.5, pos, 80.0)
					_on_blade_hit(e)

func blades_now() -> int:
	return blade_count + storm_bonus

func _on_blade_hit(_e) -> void:
	WeaponTiers.run(self, "blade_hit", [_e])

func _draw() -> void:
	super()
	if weapon_id == "spellblade" or weapon_id == "starfall":     # (the blades are drawn by its WeaponAura, so LAN clients see them too)
		return
	if Time.get_ticks_msec() / 1000.0 < _storm_until:
		for i in blade_count:
			var p := to_local(player.global_position + Vector2.from_angle(_angle + i * TAU / blade_count) * 26.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(3, 0), p + Vector2(0, 6), p + Vector2(-3, 0)]), Color(0.75, 0.85, 1.0))

func dash_attack() -> void:
	fx("line", player.global_position, Color(0.7, 0.8, 1.0), {"dir": aim, "length": 55.0, "width": 6.0, "life": 0.25})
	player.dash(aim, 55.0, 0.15)
	start_dash_hits(2.5, 16.0, 140.0, 0.18)

func _on_dash_hit(e) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		WeaponUtil.expose(e, 1.5)

func ultimate() -> void:
	var old := blade_count
	blade_count = 6
	_storm_until = Time.get_ticks_msec() / 1000.0 + 5.0
	_blade_hit = {}
	await get_tree().create_timer(5.0).timeout
	blade_count = old

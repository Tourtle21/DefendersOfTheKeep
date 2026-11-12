extends Weapon
## LEGENDARY. Mindbender: a scepter that bends wills. Its bolts hit hard and mark the target; Turncoat turns every enemy in a small
## circle to your side for a while, Mind Step slips you forward and charms what it brushes, and Mass Conversion turns a whole
## crowd. Converted enemies fight the rest, and the rest fight them. (Bosses cannot be bent.)

func _init() -> void:
	weapon_id = "mindbender"
	weapon_name = "Mindbender"
	element = "magic"
	attack_name = "Mind Bolt"
	dash_name = "Mind Step"
	ability_name = "Turncoat"
	ultimate_name = "Mass Conversion"
	preview_ability = {"kind": "circle", "range": 110.0, "radius": 45.0}
	preview_ultimate = {"kind": "circle", "range": 100.0, "radius": 120.0}
	preview_dash = 60.0
	icon_path = "res://items/weapons/icons/mindbender.png"
	attack_cooldown = Game.basic_cd("mindbender")
	ability_cooldown = 11.0
	dash_cooldown = 4.0
	ultimate_cooldown = 60.0
	reach = 12.0
	icon_scale = 0.62

func attack() -> void:
	thrust(5.0, 0.2)
	var extra = WeaponTiers.run(self, "bolt_extra")             # tier 2+: an orb with a spiral trail that adds Will
	WeaponProjectile.shoot(game_world(), player.global_position + aim * 10.0, aim, 240.0, Game.basic_hit(weapon_id), Color(0.55, 0.9, 1.0), 1.2, 0, 60.0, extra if extra != null else {})

func dash_attack() -> void:
	# Mind Step: a short slip forward that charms whatever it brushes for a moment
	var start: Vector2 = player.global_position
	fx("line", start, Color(0.55, 0.9, 1.0), {"dir": aim, "length": 60.0, "width": 4.0, "life": 0.3})
	player.dash(aim, 60.0, 0.1)
	for e in WeaponUtil.enemies_in_circle(get_tree(), start + aim * 30.0, 34.0):
		if is_instance_valid(e) and e.has_method("charm"):
			e.charm(3.0)

## Turn the enemies in a circle to your side for `seconds` (bosses are not Enemies with a charm, so they are left alone).
func _convert(center: Vector2, radius: float, seconds: float) -> int:
	fx("ring", center, Color(0.55, 0.9, 1.0), {"radius": radius, "life": 0.5})
	var n := 0
	for e in WeaponUtil.enemies_in_circle(get_tree(), center, radius):
		if is_instance_valid(e) and !e.is_queued_for_deletion() and e.has_method("charm"):
			if WeaponTiers.has_fn(weapon_id, "conv") and tier >= 2:     # the tier module converts (power, healing, army cap)
				if WeaponTiers.run(self, "conv", [e, seconds]):
					n += 1
			else:
				e.charm(seconds)
				n += 1
	return n

## Puppeteer: a second right click inside the window commands the army (no cooldown of its own).
func use_ability() -> void:
	_claim()
	if ability_unlocked() and WeaponTiers.run(self, "command_ready") == true:
		WeaponTiers.run(self, "command")
		return
	super()

func ability() -> void:
	# Turncoat: a ring at the cursor; everything inside changes sides
	var c := cursor_target(110.0)
	var r := 45.0
	var rr = WeaponTiers.run(self, "ring_r")
	if rr != null:
		r = float(rr)
	fx("ring", c, Color(0.55, 0.9, 1.0), {"radius": r, "life": 0.35})
	await get_tree().create_timer(0.3).timeout
	if !is_inside_tree():
		return
	_claim()
	_convert(c, r, 12.0)

func ultimate() -> void:
	# Mass Conversion: a wide wave around the cursor, a long while
	var c := cursor_target(100.0)
	fx("ring", c, Color(0.55, 0.9, 1.0), {"radius": 120.0, "life": 0.6})
	await get_tree().create_timer(0.5).timeout
	if !is_inside_tree():
		return
	if tier >= 6 and WeaponTiers.has_fn(weapon_id, "ultimate"):
		return                                                  # Sovereign: the tier module runs the whole show
	_claim()
	_convert(c, 120.0, 25.0)

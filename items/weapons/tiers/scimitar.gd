extends RefCounted
## Scimitar tiers (docs/weapon_tiers/scimitar.md): 2 Wide Crescent, 3 Dune Dance, 4 Afterimages, 5 Sandstorm, 6 Desert Wrath.
## Uncommon: still slash and bleed, but now several bleeding targets and an ultimate with two layers. (The Sultan's Guard has its own module.)

const BRASS := Color(0.95, 0.80, 0.45)
const SAND := Color(0.92, 0.75, 0.40)
const BLOOD := Color(0.80, 0.20, 0.15)
const DUST := Color(0.85, 0.75, 0.60)
const DANCE_EVERY := 3
const DANCE_MULT := 0.6
const AFTER_R := 22.0
const AFTER_MULT := 0.4
const ZONE_SECS := 4.0
const BLADES := 6
const BLADE_MULT := 1.0
const FINISHER_EVERY := 6
const NAMES := ["", "Scimitar", "Wide Crescent", "Dune Dance", "Afterimages", "Sandstorm", "Desert Wrath"]

static func palette() -> Array:
	return [BRASS, SAND, BLOOD]

static func equip(w) -> void:
	w._st = {"slashes": 0, "drip_t": 0.0, "ult_id": 0}

## What this weapon has cut is marked for a moment; bleeding enemies near you drip red (tier 2+).
static func on_hit(w, e, _dmg: float) -> void:
	if is_instance_valid(e):
		WeaponTiers.mark(e, "bleed", 2.0)

static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	w._st.drip_t = float(w._st.get("drip_t", 0.0)) - delta
	if float(w._st.drip_t) > 0.0:
		return
	w._st.drip_t = 0.6
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 120.0):
		if n >= 4:
			break
		if WeaponTiers.marked(e, "bleed"):
			n += 1
			w.fx("motes", e.global_position + Vector2(0, -6), BLOOD, {"radius": 3.0, "count": 2, "rise": 8.0, "life": 0.5})

static func attack(w) -> void:
	w._st.slashes = int(w._st.get("slashes", 0)) + 1
	var n: int = int(w._st.slashes)
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	w.fx("motes", o + w.aim * 28.0, SAND, {"radius": 5.0, "count": 2, "rise": 3.0, "life": 0.3})
	if w.tier >= 3 and n % DANCE_EVERY == 0:
		_dance(w)
	if w.tier >= 6 and n % FINISHER_EVERY == 0:
		WeaponProjectile.shoot(w.game_world(), o + w.aim * 12.0, w.aim, 260.0, 2.5 * 0.5, BRASS, 0.55, 3, 80.0, {"bleed_ticks": 4, "bleed_dmg": 0.8, "style": "crescent", "size": 1.0, "trail": 3})

## Tier 3 Dune Dance: a second arc on the other side, 0.1 s later.
static func _dance(w) -> void:
	if !await WeaponTiers.pause(w, 0.1):
		return
	var o: Vector2 = w.player.global_position
	w.fx("slash", o, SAND, {"radius": 30.0, "dir": w.aim.rotated(-0.5), "half_angle": 1.2, "thick": 5.0, "life": 0.2, "col2": Color(1, 1, 1)})
	w.fx("motes", o + w.aim * 22.0, SAND, {"radius": 14.0, "count": 6, "rise": 8.0, "life": 0.4})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 30.0, 70.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * DANCE_MULT, o, 40.0)
		if is_instance_valid(e):
			WeaponUtil.bleed(w.get_tree(), e, 3, 0.7)             # refreshes the bleed

## Tier 4 Afterimages: two afterimages along the dash cut a full circle after you pass.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, SAND, {"dir": w.aim, "length": 50.0, "width": 6.0, "life": 0.3, "col2": Color(1, 1, 1)})
	for k in 2:
		var p: Vector2 = o + w.aim * (50.0 * float(k + 1) / 3.0)
		w.fx("orbit", p, SAND, {"radius": 10.0, "count": 3, "spin": 8.0, "shape": "blade", "life": 0.3})
		_afterimage(w, p, 0.043 * float(k + 1) + 0.2)

static func _afterimage(w, p: Vector2, at: float) -> void:
	if !await WeaponTiers.pause(w, at):
		return
	w.fx("slash", p, BRASS, {"radius": AFTER_R, "dir": Vector2.RIGHT, "half_angle": PI, "thick": 4.0, "life": 0.2, "col2": Color(1, 1, 1)})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, AFTER_R):
		WeaponUtil.hit(e, WeaponTiers.H(w) * AFTER_MULT, p, 30.0, 0.0, "", true)
		if is_instance_valid(e):
			WeaponUtil.bleed(w.get_tree(), e, 3, 0.8)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	w.fx("sigil", w.player.global_position, SAND, {"radius": 52.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": BRASS})
	if w.tier >= 5:
		_sandstorm(w, my)
	if w.tier >= 6:
		_wrath(w, my)

## Stage 2 Sandstorm: the cyclone leaves a slowing sand zone and its last victims bleed.
static func _sandstorm(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.5) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	WeaponUtil.patch(w.game_world(), o, "slow", 52.0, Color(SAND, 0.35), ZONE_SECS, 0.5)
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 52.0):
		if n >= 8:
			break
		n += 1
		WeaponUtil.bleed(w.get_tree(), e, 3, 0.8)
	for k in 3:
		w.fx("vortex", o, SAND, {"radius": 52.0, "count": 3, "spin": 5.0, "life": 1.0})
		if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
			return

## FINALE Desert Wrath: a sand pillar and six scimitars flying outward.
static func _wrath(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.7) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("pillar", o, SAND, {"height": 100.0, "width": 26.0, "life": 0.6})
	for i in BLADES:
		var d: Vector2 = w.aim.rotated(float(i) * TAU / float(BLADES))
		WeaponProjectile.shoot(w.game_world(), o + d * 8.0, d, 240.0, WeaponTiers.H(w) * BLADE_MULT, BRASS, 0.4, 2, 60.0, {"style": "crescent", "size": 1.0, "bleed_ticks": 3, "bleed_dmg": 0.8, "trail": 3})
	w.player.shake(4.0, 0.3)
	Sfx.play("big_hit", 0.05)

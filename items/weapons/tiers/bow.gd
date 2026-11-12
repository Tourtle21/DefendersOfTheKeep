extends RefCounted
## Bow tiers (docs/weapon_tiers/bow.md): 2 Fan, 3 Overdraw, 4 Smoke Roll, 5 Rainstorm, 6 Skyfall. Uncommon: draw timing and aim, one more arrow trick per tier.
## Only the Bow itself: the fused bows have their own modules (bow.gd checks weapon_id before it changes a shot).

const WOOD := Color(0.72, 0.52, 0.28)
const ARROW := Color(0.90, 0.80, 0.50)
const GOLD := Color(1.0, 0.85, 0.20)
const FLETCH := Color(0.95, 0.95, 0.95)
const RAIN_N := 8
const RAIN_R := 60.0
const RAIN_MULT := 0.54
const FINISHER_EVERY := 6
const FINALE_R := 48.0
const NAMES := ["", "Bow", "Fan", "Overdraw", "Smoke Roll", "Rainstorm", "Skyfall"]

static func palette() -> Array:
	return [WOOD, GOLD, FLETCH]

static func equip(w) -> void:
	w._st = {"full": 0, "ult_id": 0}

## The aura's state is the draw, 0 to 100: the ring closes around the nock.
static func tick(w, _delta: float) -> void:
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.state = minf(100.0, w._draw_t / w.FULL_DRAW * 100.0) if w._drawing else 0.0

static func aura(a, c) -> void:
	if a.state <= 0.0:
		return
	var nock: Vector2 = a.aim.rotated(a.swing) * (a.reach - 4.0)
	var k: float = a.state / 100.0
	if a.tier >= 3:
		c.draw_arc(nock, lerpf(10.0, 3.0, k), 0, TAU, 20, Color(1, 1, 1, 0.3 + 0.6 * k), 1.0)
	if k >= 1.0:
		var d: Vector2 = a.aim.rotated(a.swing)
		c.draw_line(nock - d.orthogonal() * 6.0, nock + d.orthogonal() * 6.0, Color(GOLD, 0.7), 1.0)   # the string glows at full draw

## Tier 6 Piercing Gale: every sixth full draw adds a thin beam down the line.
static func release_item(w) -> void:
	var s: Dictionary = w._st.get("shot", {})
	if w.tier < 3 or s.is_empty():
		return
	var o: Vector2 = s.o
	if s.perfect:
		w.fx("star", o + s.dir * 8.0, GOLD, {"radius": 12.0, "count": 5, "spin": 1.5, "life": 0.35})
		w.fx("flash", o + s.dir * 8.0, GOLD, {"radius": 10.0, "life": 0.2})
	if w.tier >= 6 and s.finisher:
		w.fx("beam", o + s.dir * 8.0, FLETCH, {"dir": s.dir, "length": 110.0, "width": 4.0, "life": 0.3, "col2": Color(1, 1, 1)})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), o, s.dir, 110.0, 6.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, o, 40.0, 0.0, "", true, true)
		Sfx.play("whoosh", 0.05, 1.3)

## Tier 4 Smoke Roll: a puff of smoke slows what follows.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, ARROW, {"dir": -w.aim, "length": 46.0, "width": 5.0, "life": 0.3, "col2": FLETCH})
	w.fx("motes", o, FLETCH, {"radius": 24.0, "count": 8, "rise": 10.0, "life": 0.6})
	WeaponUtil.patch(w.game_world(), o, "slow", 24.0, Color(0.8, 0.8, 0.8, 0.35), 2.0, 0.55)

## Called by the Arrow Storm just before the finale slam.
static func finale(w) -> void:
	if w.tier < 3:
		return
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	var c: Vector2 = w._st.finale_c
	w.fx("sigil", c, GOLD, {"radius": 38.0, "count": 6, "spin": 1.5, "life": 0.4, "col2": FLETCH})
	if w.tier >= 5:
		_rain(w, my, c)
	if w.tier >= 6:
		_skyfall(w, c)

## Stage 2 Rainstorm: eight arrows fall around the cursor.
static func _rain(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
		return
	w.fx("ripple", c, GOLD, {"radius": RAIN_R, "rings": 2, "life": 0.5})
	for i in RAIN_N:
		var p: Vector2 = c + Vector2.from_angle(float(i) * TAU / float(RAIN_N) + 0.4) * RAIN_R * (0.45 + 0.55 * fposmod(float(i) * 0.618, 1.0))
		w.fx("fall", p, ARROW, {"radius": 2.0, "height": 80.0, "rise": 4.0, "life": 0.45, "core": FLETCH})
		w.ground_strike(p, 10.0, 0.45, WeaponTiers.H(w) * RAIN_MULT, 80.0, ARROW)

## FINALE Skyfall: the slam is a giant arrow that bursts into six.
static func _skyfall(w, c: Vector2) -> void:
	w.fx("fall", c, GOLD, {"radius": 6.0, "height": 150.0, "rise": 6.0, "life": 0.4, "core": FLETCH})
	if !await WeaponTiers.pause(w, 0.4):
		return
	w.fx("pillar", c, GOLD, {"height": 90.0, "width": 20.0, "life": 0.5})
	for i in 6:
		var d := Vector2.from_angle(float(i) * TAU / 6.0)
		WeaponProjectile.shoot(w.game_world(), c + d * 6.0, d, 260.0, 1.2, ARROW, 0.35, 1, 40.0, {"trail": 2})
	w.player.shake(5.0, 0.3)
	Sfx.play("big_hit", 0.05)

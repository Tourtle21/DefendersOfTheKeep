extends RefCounted
## Hammer tiers (docs/weapon_tiers/hammer.md): 2 Ripple, 3 Ground Pound, 4 Crater Leap, 5 Shatter, 6 Worldfall. Common: heavy, readable and slow.

const IRON := Color(0.62, 0.66, 0.72)
const EMBER := Color(1.0, 0.55, 0.20)
const GOLD := Color(1.0, 0.85, 0.20)
const DUST := Color(0.80, 0.70, 0.50)
const RIPPLE_DELAY := 0.25
const RIPPLE_R := 1.5
const RIPPLE_MULT := 0.4
const POUND_EVERY := 3
const POUND_R := 36.0
const LEAP_R := 40.0
const FRAGMENTS := 6
const ECHO_MULT := 1.2
const NAMES := ["", "Hammer", "Ripple", "Ground Pound", "Crater Leap", "Shatter", "Worldfall"]

static func palette() -> Array:
	return [IRON, EMBER, GOLD]

static func equip(w) -> void:
	w._st = {"smashes": 0, "ult_id": 0, "leap_until": 0.0}

## The head glows with the charge (the aura's state), and the weapon rises during a leap.
static func tick(w, _delta: float) -> void:
	if w._aura == null or !is_instance_valid(w._aura):
		return
	w._aura.state = float(int(w._charge / w.MAX_CHARGE * 100.0)) if w._charging else 0.0
	var leaping: bool = float(w._st.get("leap_until", 0.0)) > Time.get_ticks_msec() / 1000.0
	w._aura.kind = "leap" if leaping else "hand"
	if leaping:
		w.sprite.position.y = -4.0
	elif w.sprite.position.y != 0.0:
		w.sprite.position.y = 0.0

static func attack(w) -> void:
	w._st.smashes = int(w._st.get("smashes", 0)) + 1
	if w.tier < 2:
		return
	_smash(w, w.tier >= 3 and int(w._st.smashes) % POUND_EVERY == 0)

static func _smash(w, pound: bool) -> void:
	if !await WeaponTiers.pause(w, 0.2):
		return
	var o: Vector2 = w.player.global_position
	var c: Vector2 = o + w.aim * 22.0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 26.0):
		w.fx("shards", e.global_position, DUST, {"radius": 14.0, "count": 3, "life": 0.3})
	if pound:
		w.fx("shock", c, EMBER, {"radius": 40.0, "thick": 6.0, "life": 0.35, "col2": GOLD})
		w.fx("crack", c, IRON, {"radius": 38.0, "count": 6, "life": 0.5})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, POUND_R):
			WeaponUtil.hit(e, WeaponTiers.H(w), o, 340.0, 0.0, "", true)
		WeaponUtil.hit_breakables(w.get_tree(), c, POUND_R, ["stone"])
		Sfx.play("thump", 0.1)

## Tier 2 Ripple: a second, wider ring follows the Charged Slam.
static func release(w) -> void:
	if w.tier < 2 or !w._st.has("slam"):
		return
	_ripple(w, w._st.slam.duplicate())

static func _ripple(w, s: Dictionary) -> void:
	if s.perfect:
		w.fx("star", s.o, GOLD, {"radius": 22.0, "count": 6, "spin": 1.5, "life": 0.4})
	if !await WeaponTiers.pause(w, RIPPLE_DELAY):
		return
	var r: float = s.radius * RIPPLE_R
	w.fx("ripple", s.o, EMBER, {"radius": r, "rings": 2, "life": 0.5})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), s.o, r):
		if e.global_position.distance_to(s.o) <= float(s.radius):
			continue                          # the slam itself already hit these
		WeaponUtil.hit(e, float(s.dmg) * RIPPLE_MULT, s.o, 200.0, 0.0, "", true)
		if is_instance_valid(e) and e.has_method("apply_slow"):
			e.apply_slow(0.5, 1.5)

## Tier 4 Crater Leap: the landing is a crater with flying rubble that hits the ring outside it.
static func dash(w) -> void:
	w._st.leap_until = Time.get_ticks_msec() / 1000.0 + 0.3
	if w.tier < 4:
		return
	_crater(w, w.player.global_position + w.aim * 70.0)

static func _crater(w, land: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	w.fx("shock", land, EMBER, {"radius": 38.0, "thick": 6.0, "life": 0.35, "col2": GOLD})
	w.fx("crack", land, IRON, {"radius": 38.0, "count": 6, "life": 0.6})
	w.fx("shards", land, DUST, {"radius": 55.0, "count": 8, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), land, 55.0):
		if e.global_position.distance_to(land) > LEAP_R:
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, land, 80.0, 0.0, "", true)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var c: Vector2 = w.cursor_target(120.0)
	w.fx("sigil", c, EMBER, {"radius": 60.0, "count": 8, "spin": 1.2, "life": 1.0, "col2": GOLD})
	if w.tier >= 6:
		w.fx("fall", c, EMBER, {"radius": 8.0, "height": 140.0, "rise": 10.0, "life": 1.0, "core": GOLD})
	if w.tier >= 5:
		_after(w, int(w._st.ult_id), c)

static func _after(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
		return
	if w.tier >= 6:                                     # impact: the Worldfall look and a slowing crater
		w.fx("flash", c, GOLD, {"radius": 70.0, "life": 0.4})
		w.fx("shock", c, EMBER, {"radius": 70.0, "thick": 8.0, "life": 0.5, "col2": GOLD})
		w.fx("crack", c, IRON, {"radius": 70.0, "count": 10, "life": 1.0})
		WeaponUtil.patch(w.game_world(), c, "slow", 60.0, Color(EMBER, 0.4), 4.0, 0.5)
		Sfx.play("thump", 0.05)
		w.player.shake(5.0, 0.4)
		_echo(w, my, c)
	if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
		return
	w.fx("crack", c, IRON, {"radius": 50.0, "count": 4, "life": 2.0})
	for i in FRAGMENTS:
		var p: Vector2 = c + Vector2.from_angle(float(i) * TAU / float(FRAGMENTS) + 0.3) * 50.0
		w.fx("fall", p, IRON, {"radius": 3.0, "height": 60.0, "rise": 8.0, "life": 0.45, "core": EMBER})
		w.ground_strike(p, 16.0, 0.45, WeaponTiers.H(w) * 0.6, 220.0, IRON)

## FINALE Worldfall: 1.2 s after the impact an echo quake.
static func _echo(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.2) or int(w._st.ult_id) != my:
		return
	w.fx("shock", c, EMBER, {"radius": 84.0, "thick": 6.0, "life": 0.5, "col2": GOLD})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 84.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * ECHO_MULT, c, 260.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.5)
	w.player.shake(5.0, 0.3)
	Sfx.play("big_hit", 0.05)

## The head glows ember with the charge; during a leap a shadow stays on the ground.
static func aura(a, c) -> void:
	var head: Vector2 = a.aim.rotated(a.swing) * (a.reach + 4.0)
	if a.state > 0.0:
		var k: float = a.state / 100.0
		c.draw_circle(head, 2.0 + 3.0 * k, Color(EMBER, 0.25 + 0.5 * k))
	if a.kind == "leap":
		c.draw_circle(Vector2(0, 8), 7.0, Color(0, 0, 0, 0.18))

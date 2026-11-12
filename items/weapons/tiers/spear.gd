extends RefCounted
## Spear tiers (docs/weapon_tiers/spear.md): 2 Barbed, 3 Skewer, 4 Primed, 5 Second Wave, 6 Heaven's Spear. Common: every upgrade is about reach and spacing.

const STEEL := Color(0.90, 0.95, 1.0)
const GOLD := Color(1.0, 0.85, 0.30)
const SHINE := Color(1.0, 1.0, 1.0)
const SHAFT := Color(0.70, 0.50, 0.30)
const SKEWER_EVERY := 3
const PRIMED_T := 1.5
const WAVE_N := 6
const WAVE_MULT := 1.1
const FINALE_MULT := 1.5
const NAMES := ["", "Spear", "Barbed", "Skewer", "Primed", "Second Wave", "Heaven's Spear"]

static func palette() -> Array:
	return [STEEL, GOLD, SHINE]

static func equip(w) -> void:
	w._st = {"thrusts": 0, "skewer": false, "primed_until": 0.0, "primed_now": false, "ult_id": 0}

## Before the thrust: is this one a Skewer (every third), or primed by a Lunge?
static func pre_attack(w) -> void:
	w._st.skewer = false
	w._st.primed_now = false
	if w.tier < 3:
		return
	w._st.thrusts = int(w._st.get("thrusts", 0)) + 1
	w._st.skewer = int(w._st.thrusts) % SKEWER_EVERY == 0
	if w.tier >= 4 and float(w._st.get("primed_until", 0.0)) > Time.get_ticks_msec() / 1000.0:
		w._st.primed_now = true
		w._st.primed_until = 0.0

static func attack(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	if w._st.get("skewer", false):
		w.fx("streak", o, GOLD, {"dir": dir, "length": 62.0, "width": 4.0, "life": 0.25, "col2": SHINE})
		w.fx("star", o + dir * 62.0, GOLD, {"radius": 10.0, "count": 4, "spin": 2.0, "life": 0.3})
	if w._st.get("primed_now", false):
		w.fx("streak", o, GOLD, {"dir": dir, "length": 44.0, "width": 5.0, "life": 0.25, "col2": SHINE})
		w.fx("flash", o + dir * 44.0, GOLD, {"radius": 14.0, "life": 0.25})
		Sfx.play("whoosh", 0.05, 1.4)

static func on_hit(w, e, _dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e) or w.verb() != "attack":
		return
	w.fx("shards", e.global_position, GOLD, {"radius": 10.0, "count": 2, "life": 0.25})

static func dash(w) -> void:
	if w.tier < 4:
		return
	w.fx("streak", w.player.global_position, STEEL, {"dir": w.aim, "length": 80.0, "width": 6.0, "life": 0.3, "col2": GOLD})

## Tier 4 Primed: a Lunge that connects primes the next thrust for 1.5 s (the whole line counts as the tip).
static func dash_hit(w, _e) -> void:
	if w.tier < 4:
		return
	w._st.primed_until = Time.get_ticks_msec() / 1000.0 + PRIMED_T
	w.fx("flash", w.player.global_position + w.aim * 12.0, GOLD, {"radius": 14.0, "life": 0.25})

## Tier 3: a javelin falls into each Spear Rain strike (its telegraph is the fall).
static func rain_point(w, p: Vector2) -> void:
	w.fx("fall", p, STEEL, {"radius": 3.0, "height": 70.0, "rise": 6.0, "life": 0.45, "core": SHINE})
	_land(w, p)

static func _land(w, p: Vector2) -> void:
	if await WeaponTiers.pause(w, 0.45):
		w.fx("burst", p, GOLD, {"radius": 10.0, "life": 0.2})

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var c: Vector2 = w.cursor_target(120.0)
	w._st.rain_c = c
	w.fx("sigil", c, STEEL, {"radius": 55.0, "count": 6, "spin": 1.2, "life": 0.25, "col2": GOLD})
	if w.tier >= 5:
		_wave(w, int(w._st.ult_id), c)
	if w.tier >= 6:
		_finale(w, int(w._st.ult_id), c)

## Stage 2 Second Wave: six more spears at the enemies nearest the cursor.
static func _wave(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 2.5) or int(w._st.ult_id) != my:
		return
	w.fx("ripple", c, GOLD, {"radius": 60.0, "rings": 2, "life": 0.5})
	var spots: Array = []
	var near := WeaponUtil.enemies_in_circle(w.get_tree(), c, 110.0)
	near.sort_custom(func(a, b): return a.global_position.distance_to(c) < b.global_position.distance_to(c))
	for e in near.slice(0, WAVE_N):
		spots.append(e.global_position)
	while spots.size() < WAVE_N:
		spots.append(c + Vector2.from_angle(float(spots.size()) * 1.1) * 40.0)
	for p in spots:
		w.fx("fall", p, STEEL, {"radius": 3.0, "height": 70.0, "rise": 6.0, "life": 0.45, "core": SHINE})
		w.ground_strike(p, 14.0, 0.45, WeaponTiers.H(w) * WAVE_MULT, 160.0, STEEL)

## FINALE Heaven's Spear: a gigantic spear drops on the cursor.
static func _finale(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 3.0) or int(w._st.ult_id) != my:
		return
	w.fx("fall", c, STEEL, {"radius": 7.0, "height": 130.0, "rise": 8.0, "life": 0.5, "core": SHINE})
	w.fx("ring", c, GOLD, {"radius": 32.0, "life": 0.5})
	if !await WeaponTiers.pause(w, 0.5):
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 32.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * FINALE_MULT, c, 300.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.6)
	w.fx("pillar", c, GOLD, {"height": 100.0, "width": 24.0, "life": 0.6})
	w.fx("shock", c, STEEL, {"radius": 38.0, "thick": 5.0, "life": 0.4, "col2": GOLD})
	w.player.shake(4.5, 0.3)
	Sfx.play("big_hit", 0.05)

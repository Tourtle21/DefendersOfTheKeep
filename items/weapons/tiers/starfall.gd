extends RefCounted
## Starfall tiers (docs/weapon_tiers/starfall.md): 3 Star Charts (entry), 4 Constellation, 5 Meteor Rain, 6 Cosmic Dance.
## Ancient: CONSTELLATIONS. The Tempest's charge (meta "charge", max 5) becomes geometry: an enemy with 3+ charges is a STAR, stars within 110 px are joined by lines that cut whatever
## crosses them (0.3 H, +1 charge), and a closed triangle of stars calls a falling star on its centre. The blades (storm, planets) are drawn by the WeaponAura through the
## Spellblade module's draw_blades() from `data`. The old script (t3/starfall.gd) calls the `cascade` and `meteors` hooks; the old Spellblade script makes the crescent wave.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const Blades := preload("res://items/weapons/tiers/spellblade.gd")
const STAR := Color(0.85, 0.92, 1.0)
const GOLD := Color(1.0, 0.92, 0.55)
const NIGHT := Color(0.08, 0.10, 0.30)
const VIOLET := Color(0.55, 0.45, 0.95)
const SF_STORM_LEN := 5.0
const SF_LINE_R := 110.0
const SF_LINE_MAX := 8
const SF_LINE_MULT := 0.3
const SF_LINE_TICK := 0.5
const SF_TRIANGLE_MULT := 1.5
const SF_CASCADE_GAP := 0.1
const SF_CASCADE_R := 70.0
const SF_METEORS := 18
const SF_GIANTS := 6
const SF_GIANT_MULT := 1.2
const SF_DANCE_SECS := 12.0
const SF_DANCE_METEOR_EVERY := 0.7
const SF_NOVA_EVERY := 2.0
const SF_SUPERNOVA_R := 160.0
const SF_SUPERNOVA_MULT := 1.5
const SF_FINISHER_EVERY := 6
const SF_LIGHT_BONUS := [0, 0, 10, 15, 20, 30]
const NAMES := ["", "", "", "Star Charts", "Constellation", "Meteor Rain", "Cosmic Dance"]

static func palette() -> Array:
	return [STAR, GOLD, STAR]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"slashes": 0, "chain": 0, "ult_id": 0, "stars_t": 0.0, "line_t": 0.0, "tri": {}, "lines": [], "dash_lines": [], "dash_fx": 0.0,
		"dance_until": 0.0, "dance_ph": 0.0, "meteor_t": 0.0, "nova_t": 0.0, "planet_t": 0.0, "cross": {}, "storm_was": false}
	w.storm_len = SF_STORM_LEN
	WeaponTiers.light_bonus(w, SF_LIGHT_BONUS)

static func charge_of(e) -> int:
	return int(e.get_meta("charge", 0)) if Kit.alive(e) else 0

static func charge(e, n := 1) -> void:
	if Kit.alive(e):
		e.set_meta("charge", mini(5, charge_of(e) + n))

static func dancing(w) -> bool:
	return now() < float(w._st.get("dance_until", 0.0))

# ---- every frame: star motes, the lines and what crosses them, the blades for the aura ----
static func tick(w, delta: float) -> void:
	if w.tier < 3:
		return
	var t := now()
	w._st.dance_ph = float(w._st.dance_ph) + 2.5 * delta
	w._st.stars_t = float(w._st.stars_t) + delta
	if float(w._st.stars_t) >= 0.5:
		w._st.stars_t = 0.0
		var shown := 0
		for e in w.get_tree().get_nodes_in_group("enemy"):
			if shown >= 10:
				break
			var n := charge_of(e)
			if n > 0 and e.global_position.distance_to(w.player.global_position) < 260.0:
				shown += 1
				w.fx("star", e.global_position + Vector2(0, -12), STAR, {"radius": 4.0, "count": 4, "spin": 1.0, "life": 0.5})
		if w.tier >= 4:
			_lines(w, t)
	if w.tier >= 4:
		_cross(w, t)
	if dancing(w):
		_dance_tick(w, t)
	var storm: bool = t < w._storm_until
	if storm and !w._st.storm_was:
		w._st.storm_was = true
	elif !storm:
		w._st.storm_was = false
	if w._aura != null and is_instance_valid(w._aura):
		var d := {"ph": w._angle, "n": w.blades_now() if storm else 0, "r": w.storm_r, "sp": 0, "sph": 0.0, "av": 0}
		if dancing(w):
			d = {"ph": w._st.dance_ph, "n": 6, "r": 40.0, "sp": 0, "sph": 0.0, "av": 0, "dn": 1}
		w._aura.data = d

static func aura(a, c) -> void:
	Blades.draw_blades(a, c)
	if int(a.data.get("dn", 0)) == 1:                                 # Cosmic Dance: a night sky round you
		c.draw_circle(Vector2.ZERO, 160.0, Color(NIGHT, 0.10))
		c.draw_arc(Vector2.ZERO, 160.0, 0.0, TAU, 48, Color(VIOLET, 0.5), 1.0)
		for k in 8:
			var an: float = float(k) * TAU / 8.0 + a._age * 0.1
			c.draw_circle(Vector2.from_angle(an) * (40.0 + 14.0 * WeaponAura.jit(k, 1.0) * 8.0), 0.8 + 0.5 * sin(a._age * 3.0 + float(k)), Color(GOLD, 0.8))
	if a.tier >= 6:                                                   # an orrery: three small planets on rings round the halo
		for k in 3:
			var an2: float = a._age * (0.7 + 0.3 * float(k)) + float(k) * 2.1
			var r := 9.0 + 3.0 * float(k)
			c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(STAR, 0.15), 1.0)
			c.draw_circle(Vector2.from_angle(an2) * r, 1.2, Color(GOLD if k != 1 else VIOLET, 0.9))

## The stars: enemies with 3+ charges (all charged enemies during the Cosmic Dance), each joined to its two nearest neighbours.
static func _stars(w) -> Array:
	var need := 1 if dancing(w) else 3
	var list := []
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if charge_of(e) >= need and e.global_position.distance_to(w.player.global_position) < 280.0:
			list.append(e)
	return list

static func _lines(w, t: float) -> void:
	var stars := _stars(w)
	var lines := []
	var reach := 9999.0 if dancing(w) else SF_LINE_R
	var linked := {}
	for e in stars:
		var near := stars.duplicate()
		near.erase(e)
		near.sort_custom(func(a, b): return a.global_position.distance_to(e.global_position) < b.global_position.distance_to(e.global_position))
		for o in near.slice(0, 2):
			if e.global_position.distance_to(o.global_position) > reach or lines.size() >= SF_LINE_MAX:
				continue
			var key := "%d-%d" % [mini(e.get_instance_id(), o.get_instance_id()), maxi(e.get_instance_id(), o.get_instance_id())]
			if linked.has(key):
				continue
			linked[key] = [e, o]
			lines.append([e.global_position, o.global_position])
			Kit.line(w, e.global_position, o.global_position, STAR, 2.0, 0.55)
	w._st.lines = lines
	# a closed triangle of stars calls a falling star on its centre (cooldown 4 s per triangle)
	var fired := 0
	var ids := linked.keys()
	for i in stars.size():
		for j in range(i + 1, stars.size()):
			for k in range(j + 1, stars.size()):
				if fired >= 2:
					return
				var a = stars[i]
				var b = stars[j]
				var c = stars[k]
				if _linked(linked, a, b) and _linked(linked, b, c) and _linked(linked, a, c):
					var tid := "%d-%d-%d" % [a.get_instance_id(), b.get_instance_id(), c.get_instance_id()]
					if t - float(w._st.tri.get(tid, -10.0)) >= 4.0:
						w._st.tri[tid] = t
						fired += 1
						var mid: Vector2 = (a.global_position + b.global_position + c.global_position) / 3.0
						_falling(w, mid, 24.0, WeaponTiers.H(w) * SF_TRIANGLE_MULT)

static func _linked(linked: Dictionary, a, b) -> bool:
	return linked.has("%d-%d" % [mini(a.get_instance_id(), b.get_instance_id()), maxi(a.get_instance_id(), b.get_instance_id())])

static func _falling(w, at: Vector2, r: float, dmg: float) -> void:
	w._claim()
	w.fx("fall", at, GOLD, {"radius": 5.0, "height": 100.0, "rise": 0.0, "life": 0.35})
	WeaponUtil.ground_strike(w.get_tree(), w.game_world(), at, r, 0.35, dmg, 120.0, GOLD, 0.0, [], "")

## An enemy crossing a line (star line or a dash line) takes 0.3 H (quiet) and gains a charge, at most every 0.5 s.
static func _cross(w, t: float) -> void:
	var segs: Array = w._st.lines.duplicate()
	var keep := []
	for dl in w._st.dash_lines:
		if t < float(dl[2]):
			segs.append([dl[0], dl[1]])
			keep.append(dl)
	w._st.dash_lines = keep
	if segs.is_empty():
		return
	var cd: Dictionary = w._st.cross
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if !Kit.alive(e):
			continue
		var id: int = e.get_instance_id()
		if t - float(cd.get(id, -10.0)) < SF_LINE_TICK:
			continue
		for s in segs:
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(e.global_position, s[0], s[1])
			if cp.distance_to(e.global_position) <= 6.0 + float(e.get("hit_radius") if e.get("hit_radius") != null else 0.0):
				cd[id] = t
				w._claim()
				WeaponUtil.hit(e, WeaponTiers.H(w) * SF_LINE_MULT, cp, 0.0, 0.0, "", true, true)
				charge(e, 1)
				break
	if cd.size() > 60:
		cd.clear()

# ---- attack ----
static func pre_attack(w) -> void:
	w._st.chain = 2 if w.tier >= 4 else 0

static func attack(w) -> void:
	w._st.slashes = int(w._st.slashes) + 1
	var n: int = w._st.slashes
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var first = null
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 28.0, 55.0):
		if first == null or e.global_position.distance_to(o) < first.global_position.distance_to(o):
			first = e
	if first != null:
		w.fx("star", first.global_position, GOLD, {"radius": 8.0, "count": 4, "spin": 1.0, "life": 0.3})
		if n % 3 == 0:
			charge(first, 1)
		if w.tier >= 4 and charge_of(first) >= 3:                      # a slash that hits a star charges its neighbours
			for o2 in WeaponUtil.enemies_in_circle(w.get_tree(), first.global_position, SF_LINE_R):
				if o2 != first:
					Kit.bolt(w, first.global_position, o2.global_position, STAR, 1.5, 0.2)
					charge(o2, 1)
	if w.tier >= 6 and n % SF_FINISHER_EVERY == 0:
		WeaponProjectile.shoot(w.game_world(), o + dir * 14.0, dir, 280.0, WeaponTiers.H(w), GOLD, 0.6, 4, 100.0, {"style": "orb", "size": 2.0, "glow": 0.5, "trail": 8, "burst_r": 30.0})
		_comet_charges(w, o, dir)

static func _comet_charges(w, o: Vector2, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.25):
		return
	var k := 0
	for e in Kit.nearest_n(w.get_tree(), o + dir * 80.0, 90.0, 4):
		charge(e, 1)
		w.fx("star", e.global_position, GOLD, {"radius": 8.0, "count": 4, "spin": 1.0, "life": 0.3})
		k += 1

# ---- ability: the storm detonates as a cascade (tier 4+) ----
static func cascade(w) -> bool:
	_cascade(w)
	return true

static func _cascade(w) -> void:
	var o: Vector2 = w.player.global_position
	var list := []
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if charge_of(e) > 0:
			list.append(e)
	list.sort_custom(func(a, b): return a.global_position.distance_to(o) < b.global_position.distance_to(o))
	var h := WeaponTiers.H(w)
	for e in list:
		if !Kit.alive(e) or charge_of(e) <= 0:
			continue
		var n := charge_of(e)
		var at: Vector2 = e.global_position
		e.remove_meta("charge")
		w.fx("ring", at, STAR, {"radius": 14.0 + 4.0 * float(n), "life": 0.3})
		w.fx("star", at, GOLD, {"radius": 10.0, "count": 4, "spin": 1.0, "life": 0.3})
		for o2 in WeaponUtil.enemies_in_circle(w.get_tree(), at, SF_CASCADE_R):
			if o2 != e:
				Kit.bolt(w, at, o2.global_position, STAR, 1.2, 0.2)
				charge(o2, 1)                                          # the neighbours are charged before their turn
		WeaponUtil.hit(e, 1.5 * float(n) * 1.0, o, 80.0, 0.6 if n >= 3 else 0.0)
		if n >= 3 and Kit.alive(e):
			_falling(w, e.global_position, 22.0 + 5.0 * float(n), 2.5 * float(n))
		if !await WeaponTiers.pause(w, SF_CASCADE_GAP):
			return

# ---- dash: Comet Dash and Constellation Step ----
static func dash(w) -> void:
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, GOLD, {"dir": dir, "length": 55.0, "width": 7.0, "life": 0.25, "col2": STAR})
	if w.tier >= 4:                                                    # a lingering line from start to end for 3 s
		var a: Vector2 = o
		var b: Vector2 = o + dir * 55.0
		w._st.dash_lines.append([a, b, now() + 3.0])
		_line_fx(w, a, b)

static func _line_fx(w, a: Vector2, b: Vector2) -> void:
	for k in 10:
		Kit.line(w, a, b, GOLD, 2.0, 0.35)
		if !await WeaponTiers.pause(w, 0.3):
			return

static func dash_hit(w, e) -> void:
	if Kit.alive(e):
		charge(e, 1)

# ---- ultimate: Blade Dance, Meteor Rain, Cosmic Dance ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	w.fx("sigil", w.player.global_position, GOLD, {"radius": 100.0, "count": 7, "spin": 1.5, "life": 0.3, "col2": STAR})
	if w.tier >= 6:
		_dance(w, my)

## Tier 5: the rain (18 stars from the press) becomes a meteor shower with giant meteors aimed at the Stars. True: the plain rain is not wanted.
static func meteors(w, o: Vector2) -> bool:
	_shower(w, int(w._st.ult_id), o)
	return true

static func _shower(w, my: int, o: Vector2) -> void:
	var h := WeaponTiers.H(w)
	w.fx("sigil", o, GOLD, {"radius": 140.0, "count": 7, "spin": 1.0, "life": 3.0, "col2": STAR})
	var stars := _stars(w)
	stars.sort_custom(func(a, b): return charge_of(a) > charge_of(b))
	var giants := 0
	var gi := 0
	for i in SF_METEORS:
		if int(w._st.ult_id) != my or !WeaponTiers.alive(w):
			return
		var p: Vector2 = o + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 140.0)
		w.fx("fall", p, STAR, {"radius": 4.0, "height": 110.0, "rise": 60.0, "core": GOLD, "life": 0.45})
		w.ground_strike(p, 24.0, 0.45, 4.2, 140.0, GOLD, 0.4)
		if giants < SF_GIANTS and i % 3 == 1:                          # a giant meteor: at a Star first, then at a random enemy
			giants += 1
			var tgt = stars[gi] if gi < stars.size() else WeaponUtil.nearest(w.get_tree(), o, 140.0)
			gi += 1
			if tgt != null and Kit.alive(tgt):
				var tp: Vector2 = tgt.global_position
				w.fx("fall", tp, GOLD, {"radius": 9.0, "height": 130.0, "rise": 70.0, "core": STAR, "life": 0.5})
				w.ground_strike(tp, 36.0, 0.5, h * SF_GIANT_MULT, 200.0, GOLD, 0.0)
		if !await WeaponTiers.pause(w, 3.0 / float(SF_METEORS)):
			return

## FINALE + TRANSFORMATION Cosmic Dance (12 s) after the shower, then the Supernova.
static func _dance(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 5.5) or int(w._st.ult_id) != my:         # (the old rain starts at the press, not 5 s later: the dance follows the blades)
		return
	w._st.dance_until = now() + SF_DANCE_SECS
	w._st.meteor_t = 0.0
	w._st.nova_t = now()
	w.fx("flash", w.player.global_position, GOLD, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05, 0.8)
	if !await WeaponTiers.pause(w, SF_DANCE_SECS) or int(w._st.ult_id) != my:
		return
	_supernova(w)

static func _dance_tick(w, t: float) -> void:
	var o: Vector2 = w.player.global_position
	if t - float(w._st.meteor_t) >= SF_DANCE_METEOR_EVERY:
		w._st.meteor_t = t
		var pool := WeaponUtil.random_enemies(w.get_tree(), o, 140.0, 1)
		if !pool.is_empty():
			w._claim()
			var at: Vector2 = pool[0].global_position
			w.fx("fall", at, STAR, {"radius": 5.0, "height": 100.0, "rise": 30.0, "core": GOLD, "life": 0.4})
			w.ground_strike(at, 20.0, 0.4, WeaponTiers.H(w), 140.0, GOLD, 0.0)
	if t - float(w._st.nova_t) >= SF_NOVA_EVERY:
		w._st.nova_t = t
		w.fx("star", o, STAR, {"radius": 100.0, "count": 8, "spin": 1.5, "life": 0.5})
		w.fx("ripple", o, VIOLET, {"radius": 140.0, "rings": 2, "life": 0.5})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 140.0):
			charge(e, 1)
	if t - float(w._st.planet_t) >= 0.5:                               # the six planets spread charges
		w._st.planet_t = t
		var ph: float = float(w._st.dance_ph)
		for k in 6:
			var p: Vector2 = o + Vector2.from_angle(ph + float(k) * TAU / 6.0) * 40.0
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 9.0):
				charge(e, 1)

static func _supernova(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GOLD, {"radius": 120.0, "count": 7, "spin": 2.0, "life": 0.4, "col2": STAR})
	if !await WeaponTiers.pause(w, 0.4):
		return
	o = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("flash", o, STAR, {"radius": 100.0, "life": 0.4})
	w.fx("star", o, GOLD, {"radius": 130.0, "count": 12, "spin": 2.0, "life": 0.6})
	w.fx("ripple", o, VIOLET, {"radius": SF_SUPERNOVA_R, "rings": 4, "life": 0.7})
	w.fx("pillar", o, GOLD, {"height": 170.0, "width": 34.0, "life": 0.6})
	w.player.shake(8.0, 0.4)
	Sfx.play("ultimate", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, SF_SUPERNOVA_R):
		var n := charge_of(e)
		var at: Vector2 = e.global_position
		e.remove_meta("charge")
		WeaponUtil.hit(e, h * SF_SUPERNOVA_MULT * float(maxi(n, 1)), o, 200.0, 0.0, "", true)
		if n >= 3 and Kit.alive(e):
			w.fx("fall", at, GOLD, {"radius": 5.0, "height": 100.0, "rise": 0.0, "life": 0.35})

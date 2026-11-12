extends RefCounted
## Chain Fangs tiers (docs/weapon_tiers/chainfangs.md): 2 Barbed Chain, 3 Reel, 4 Chain Lightning, 5 Dragnet, 6 Execution.
## Epic: a tether system. Every verb makes or uses a visible chain between you and the enemies; the ultimate nets the whole group.
## Old weapon (t2/chainfangs.gd) leaves `_st.second` (this swing closed a pair), `_st.grapple` (the grappled enemy) and `_st.hunt` (the hunted list).

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const STEEL := Color(0.80, 0.85, 1.0)
const LINK := Color(0.55, 0.60, 0.75)
const BLOOD := Color(1.0, 0.30, 0.30)
const SILVER := Color(0.95, 0.97, 1.0)
const CF_BLEED_TICKS := 3
const CF_BLEED_MULT := 0.15
const CF_YANK_PAIRS := 3
const CF_YANK_R := 60.0
const CF_JUMPS := 2
const CF_JUMP_R := 60.0
const CF_JUMP_MULT := 0.5
const CF_NET_R := 100.0
const CF_EXECUTE := 0.15
const CF_FINALE_EXECUTE := 0.25
const CF_FINALE_MULT := 0.5
const CF_FINISHER_EVERY := 6
const NAMES := ["", "Chain Fangs", "Barbed Chain", "Reel", "Chain Lightning", "Dragnet", "Execution"]

static func palette() -> Array:
	return [STEEL, BLOOD, SILVER]

static func equip(w) -> void:
	w._st = {"hits": 0, "pairs": 0, "ult_id": 0, "second": false, "grapple": null, "hunt": []}

# ---- attack: the reel streak, the yank, the executing finisher ----
static func attack(w) -> void:
	w._st.hits = int(w._st.hits) + 1
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var victims := WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 36.0, 40.0)
	var second: bool = w._st.get("second", false)
	if second:
		w._st.pairs = int(w._st.pairs) + 1
		for e in victims:
			Kit.line(w, e.global_position, o, LINK, 3.0, 0.2)             # the reel-in is a line of links
	var first = null
	for e in victims:
		if first == null or e.global_position.distance_to(o) < first.global_position.distance_to(o):
			first = e
	if first != null and w.tier >= 3 and second and int(w._st.pairs) % CF_YANK_PAIRS == 0:
		_yank(w, first, o)
	if first != null and w.tier >= 6 and int(w._st.hits) % CF_FINISHER_EVERY == 0:
		_finisher(w, first)

## Tier 3: every third pair the target is yanked and takes its neighbours with it.
static func _yank(w, target, o: Vector2) -> void:
	var at: Vector2 = target.global_position
	w.fx("slash", o, STEEL, {"radius": 36.0, "dir": w.aim, "half_angle": 1.0, "thick": 4.0, "life": 0.25, "col2": SILVER})
	w.fx("shards", at, LINK, {"radius": 22.0, "count": 6, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, CF_YANK_R):
		if e == target:
			continue
		Kit.pull(e, o, 260.0, 0.2)
		if Kit.alive(e):
			e.apply_slow(0.4, 1.0)
			Kit.line(w, e.global_position, o, LINK, 3.0, 0.2)
	Sfx.play("hit", 0.1)

## Tier 6: an executing double cut; under 15% health the target just dies.
static func _finisher(w, target) -> void:
	var o: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("cut", target.global_position, SILVER, {"radius": 20.0, "spin": 0.0, "life": 0.3, "col2": BLOOD})
	if Kit.execute(target, CF_EXECUTE):
		w.fx("flash", target.global_position, BLOOD, {"radius": 14.0, "life": 0.25})
		Sfx.play("big_hit", 0.1)
		return
	WeaponUtil.hit(target, h * 0.8, o, 40.0)
	if await WeaponTiers.pause(w, 0.1) and Kit.alive(target):
		WeaponUtil.hit(target, h * 0.8, o, 40.0, 0.0, "", false, true)

# ---- ability: the tether stays, bleeds and jumps ----
static func ability(w) -> void:
	var t = w._st.get("grapple")
	w._st.grapple = null
	if w.tier < 2 or !Kit.alive(t):
		return
	var h := WeaponTiers.H(w)
	WeaponUtil.expose(t, 3.0)
	WeaponUtil.bleed(w.get_tree(), t, CF_BLEED_TICKS, h * CF_BLEED_MULT)
	w.fx("flash", t.global_position, STEEL, {"radius": 14.0, "life": 0.25})
	Kit.tether(w, t, 1.5, STEEL, 2.0)
	if w.tier >= 4:
		_jump(w, t)

## Tier 4: the chain arcs from the target to the nearest enemy, and once more.
static func _jump(w, from) -> void:
	var done: Array = [from]
	var cur = from
	var h := WeaponTiers.H(w)
	for i in CF_JUMPS:
		if !await WeaponTiers.pause(w, 0.12):
			return
		if !Kit.alive(cur):
			return
		var nxt = WeaponUtil.nearest(w.get_tree(), cur.global_position, CF_JUMP_R, done)
		if nxt == null:
			return
		Kit.bolt(w, cur.global_position, nxt.global_position, SILVER, 2.0, 0.2)
		w.fx("burst", nxt.global_position, STEEL, {"radius": 9.0, "life": 0.2})
		WeaponUtil.hit(nxt, h * CF_JUMP_MULT, cur.global_position, 20.0, 0.0, "", true, true)
		if Kit.alive(nxt):
			WeaponUtil.expose(nxt, 2.0)
		done.append(nxt)
		cur = nxt

# ---- dash: Chain Lash reels in everything beside the path ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, STEEL, {"dir": dir, "length": 46.0, "width": 7.0, "life": 0.25, "col2": SILVER})
	_lash(w, o)

static func _lash(w, o: Vector2) -> void:
	if await WeaponTiers.pause(w, 0.16):
		var end: Vector2 = w.player.global_position
		for e in Kit.near_segment(w.get_tree(), o, end, 30.0):
			Kit.pull(e, end, 400.0, 0.2)
			Kit.line(w, e.global_position, end, LINK, 3.0, 0.2)
		w.fx("shock", end, STEEL, {"radius": 26.0, "thick": 4.0, "life": 0.3, "col2": SILVER})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), end, 26.0):
			WeaponUtil.hit(e, WeaponTiers.H(w), end, 0.0, 0.0, "", true)

# ---- ultimate: Hunt, then the Dragnet, then the Execution ----
static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, STEEL, {"radius": 90.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": SILVER})
	if w.tier < 5:
		return
	_after_hunt(w, my)

static func _after_hunt(w, my: int) -> void:
	var list: Array = w._st.get("hunt", [])
	var n: int = await Kit.settle(w, list, 5, 1.4)
	if n <= 0 or int(w._st.ult_id) != my:
		return
	await _dragnet(w, my, list.duplicate())

static func _dragnet(w, my: int, hunted: Array) -> void:
	var fin: Vector2 = w.player.global_position
	w.fx("vortex", fin, STEEL, {"radius": CF_NET_R, "count": 4, "spin": 3.0, "inward": true, "life": 0.5})
	for e in hunted:
		Kit.tether(w, e, 1.5, LINK, 2.0)
	Sfx.play("cast", 0.1)
	for k in 4:
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), fin, CF_NET_R):
			Kit.pull(e, fin, 250.0, 0.12)
			if k == 0 and Kit.alive(e):
				WeaponUtil.expose(e, 3.0)
				e.apply_slow(0.2, 1.5)
		if !await WeaponTiers.pause(w, 0.1) or int(w._st.ult_id) != my:
			return
	if w.tier >= 6:
		_finale(w, my, fin)

## FINALE Execution: three rapid cuts on every exposed enemy in the net; the nearly dead are executed.
static func _finale(w, my: int, fin: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.3) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	w.fx("shock", fin, STEEL, {"radius": CF_NET_R, "thick": 6.0, "life": 0.4, "col2": BLOOD})
	w.player.shake(5.5, 0.3)
	Sfx.play("ultimate", 0.05)
	Sfx.play("big_hit", 0.05)
	var targets := []
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), fin, CF_NET_R):
		if WeaponUtil.is_exposed(e):
			targets.append(e)
	var shown := Kit.nearest_n(w.get_tree(), fin, CF_NET_R, 5)
	for cut in 3:
		for e in targets:
			if Kit.alive(e):
				WeaponUtil.hit(e, h * CF_FINALE_MULT, fin, 0.0, 0.0, "", true, cut > 0)
		for e in shown:
			if Kit.alive(e):
				w.fx("cut", e.global_position, SILVER, {"radius": 14.0, "spin": float(cut) * 0.5, "life": 0.25, "col2": BLOOD})
		if !await WeaponTiers.pause(w, 0.12) or int(w._st.ult_id) != my:
			return
	for e in targets:
		if Kit.execute(e, CF_FINALE_EXECUTE):
			w.fx("flash", e.global_position, BLOOD, {"radius": 14.0, "life": 0.25})

# ---- the swaying chain from the hand to the blade ----
static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var tip: Vector2 = d * (a.reach + 6.0)
	var n := d.orthogonal()
	var prev: Vector2 = d * 3.0
	for i in 6:
		var u := float(i + 1) / 7.0
		var p: Vector2 = tip * u + n * sin(a._age * 6.0 + float(i) * 1.3) * 1.5 * sin(u * PI)
		c.draw_line(prev, p, Color(LINK, 0.9), 1.0)
		c.draw_circle(p, 1.0, Color(SILVER, 0.95))
		prev = p

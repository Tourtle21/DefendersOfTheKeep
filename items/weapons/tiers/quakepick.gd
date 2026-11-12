extends RefCounted
## Quake Pick tiers (docs/weapon_tiers/quakepick.md): 2 Branching Fissure, 3 Rock Spike, 4 Tunnel, 5 Chasm, 6 Cataclysm Prime.
## Uncommon: terrain-flavoured and rhythmic, with a pattern to read (lines, forks, rings). The finale is a second layer round the first.
## Every eruption breaks rocks and trees the same way as the old weapon (["stone", "stick"]).

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const EARTH := Color(0.80, 0.60, 0.30)
const GLOW := Color(1.0, 0.60, 0.20)
const DUST := Color(0.88, 0.76, 0.55)
const DARK := Color(0.30, 0.20, 0.10)
const BREAK := ["stone", "stick"]
const QP_FORK_EVERY := [1, 3]
const QP_FORK_MULT := 0.4
const QP_SPIKE_EVERY := 3
const QP_TUNNEL_N := 3
const QP_TUNNEL_MULT := 0.8
const QP_CHASM_PULL := 200.0
const QP_PILLARS := 4
const QP_FINALE_MULT := 1.2
const QP_FINISHER_EVERY := 6
const NAMES := ["", "Quake Pick", "Branching Fissure", "Rock Spike", "Tunnel", "Chasm", "Cataclysm Prime"]

static func palette() -> Array:
	return [EARTH, GLOW, DUST]

static func equip(w) -> void:
	w._st = {"swings": 0, "ult_id": 0, "ember_until": 0.0}

## The head glows ember for 0.1 s after a swing lands.
static func tick(w, _delta: float) -> void:
	if w.tier < 2:
		return
	var left: float = float(w._st.get("ember_until", 0.0)) - Time.get_ticks_msec() / 1000.0
	w.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.25, 0.9), clampf(left / 0.1, 0.0, 1.0))

# ---- attack: shards off the rocks, a spike every 3rd swing, three spikes every 6th ----
static func attack(w) -> void:
	w._st.swings = int(w._st.swings) + 1
	if w.tier < 2:
		return
	var n: int = w._st.swings
	_after_swing(w, w.tier >= 3 and n % QP_SPIKE_EVERY == 0, w.tier >= 6 and n % QP_FINISHER_EVERY == 0)

static func _after_swing(w, spike: bool, finisher: bool) -> void:
	if !await WeaponTiers.pause(w, 0.2):
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	for b in w.get_tree().get_nodes_in_group("breakable"):
		if Kit.alive(b) and b.global_position.distance_to(o + dir * 14.0) <= 28.0:
			w.fx("shards", b.global_position, DUST, {"radius": 12.0, "count": 4, "life": 0.25})
			w._st.ember_until = Time.get_ticks_msec() / 1000.0 + 0.1
	var h := WeaponTiers.H(w)
	if spike:                                                      # Rock Spike: a stone spike 40 px ahead
		var at: Vector2 = o + dir * 40.0
		w.fx("crack", at, EARTH, {"radius": 14.0, "count": 4, "life": 0.5})
		w.fx("shards", at, DUST, {"radius": 14.0, "count": 4, "life": 0.3})
		w.ground_strike(at, 14.0, 0.3, h, 220.0, EARTH, 0.0, BREAK)
	if finisher:                                                   # Cataclysm Prime: three spikes in a line, cracks between them
		for k in 3:
			var at2: Vector2 = o + dir * (40.0 + 26.0 * float(k))
			w.fx("crack", at2, GLOW, {"radius": 16.0, "count": 3, "life": 0.5})
			w.ground_strike(at2, 14.0, 0.3 + 0.08 * float(k), h * 0.8, 200.0, GLOW, 0.0, BREAK)

# ---- ability: Fissure forks ----
static func ability(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var side: Vector2 = dir.orthogonal()
	var h := WeaponTiers.H(w)
	for i in 5:
		var c: Vector2 = o + dir * (22.0 + 18.0 * float(i))
		w.fx("crack", c, GLOW, {"radius": 20.0, "count": 3, "life": 0.6 + 0.1 * float(i)})        # every eruption draws a crack toward the next
		if i in QP_FORK_EVERY:
			for s in [-1.0, 1.0]:
				w.ground_strike(c + side * 26.0 * s, 12.0, 0.45 + 0.1 * float(i), h * QP_FORK_MULT, 120.0, EARTH, 0.0, BREAK)

# ---- dash: Tunnel ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var h := WeaponTiers.H(w)
	w.fx("streak", o, DARK, {"dir": dir, "length": 70.0, "width": 8.0, "life": 0.3, "col2": DUST})
	w.fx("motes", o + dir * 20.0, DUST, {"radius": 14.0, "count": 8, "rise": 12.0, "life": 0.5})
	w.player.shield_time = maxf(w.player.shield_time, 0.3)
	for k in QP_TUNNEL_N:
		var c: Vector2 = o + dir * (20.0 + 20.0 * float(k))
		w.ground_strike(c, 14.0, 0.15 * float(k + 1), h * QP_TUNNEL_MULT, 200.0, DARK, 0.0, BREAK)

# ---- ultimate: Cataclysm ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, EARTH, {"radius": 90.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": DUST})
	if w.tier >= 5:
		_chasm(w, my)
	if w.tier >= 6:
		_finale(w, my)

## Tier 5: 0.4 s after ring 3 the centre collapses: a pull, a strike and a slow patch.
static func _chasm(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.4) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("vortex", o, EARTH, {"radius": 70.0, "count": 3, "spin": 3.0, "inward": true, "life": 1.0})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 70.0):
		Kit.pull(e, o, QP_CHASM_PULL, 0.3)
	WeaponUtil.patch(w.game_world(), o, "slow", 40.0, Color(0.55, 0.40, 0.25, 0.5), 4.0, 0.5)
	w.ground_strike(o, 40.0, 0.5, h * 0.6, 160.0, EARTH, 0.5, BREAK)

## FINALE Cataclysm Prime: four pillars at the compass points, a ring of cracks, then the centre blast.
static func _finale(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 2.4) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("crack", o, GLOW, {"radius": 100.0, "count": 12, "life": 0.9})
	for k in QP_PILLARS:
		var c: Vector2 = o + Vector2.from_angle(float(k) * TAU / float(QP_PILLARS)) * 90.0
		w.fx("pillar", c + Vector2(0, 8), EARTH, {"height": 90.0, "width": 18.0, "life": 0.55})
		w.ground_strike(c, 20.0, 0.45, h, 220.0, EARTH, 0.5, BREAK)
	w.player.shake(3.0, 0.2)
	if !await WeaponTiers.pause(w, 0.55) or int(w._st.ult_id) != my:
		return
	o = w.player.global_position
	w.fx("flash", o, DUST, {"radius": 70.0, "life": 0.3})
	w.fx("shock", o, EARTH, {"radius": 90.0, "thick": 8.0, "life": 0.4, "col2": DUST})
	w.player.shake(5.0, 0.3)
	Sfx.play("thump", 0.05)
	Sfx.play("big_hit", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 80.0):
		WeaponUtil.hit(e, h * QP_FINALE_MULT, o, 300.0, 0.0, "", true)

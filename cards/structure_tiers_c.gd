extends RefCounted
## Tier abilities of the sentry towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower, Sunspire, the Magma Wall and the
## menders Healing Grove and Phoenix Shrine (designs: docs/card_tiers/<card id>.md). It plugs into the hooks of StructureTiers
## (cards/structure_tiers.gd), which delegate here for the ids in OWN. Everything runs on the host; visuals go through
## WeaponFx.spawn / Sfx.play, and what a client must draw is a public var of Structure (`charge`, `aim`, `vis`, ...).
## Host-only state of a card lives in `st._tdata` and `st._timers`.

const OWN := ["crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine"]

static func world_of(st) -> Node:
	return st.get_parent()

static func id_of(st) -> String:
	return String(st.data.get("id", ""))

## Run `f` after `secs`, unless the building is gone by then.
static func later(st, secs: float, f: Callable) -> void:
	var tree = st.get_tree()
	if tree == null:
		return
	await tree.create_timer(secs).timeout
	if is_instance_valid(st) and st.is_inside_tree():
		f.call()

## Where a tower's shots start (the tip of its head).
static func muzzle(st) -> Vector2:
	return st.global_position + Vector2(0, -20)

static func alive(e) -> bool:
	return is_instance_valid(e) and e.get("dead") != true and float(e.health) > 0.0

## Set the night light of a building to `r` (adds the light group and glow when it had none).
static func ensure_light(st, r: float) -> void:
	st.data.light = r
	st.light_radius = r
	if !st.is_inside_tree():
		return                      # _ready attaches the glow when the building enters the tree
	if st._glow == null:
		st.add_to_group("light")
		st._glow = GlowLight.attach(st, r, st._color().lerp(Color(1.0, 0.85, 0.5), 0.5), 0.6)
	else:
		st._glow.texture_scale = maxf(0.1, r * 2.0 / 128.0)

static func state(st, key: String, default):
	if !st._tdata.has(key):
		st._tdata[key] = default
	return st._tdata[key]

# ---------------------------------------------------------------- hooks (dispatch)

static func tick(st, delta: float) -> void:
	match id_of(st):
		"crystal_pylon":
			tick_crystal_pylon(st, delta)
		"storm_spire":
			tick_storm_spire(st, delta)
		"magma_wall":
			tick_magma_wall(st, delta)
		"venom_tower":
			tick_venom_tower(st, delta)
		"prism_tower":
			tick_prism_tower(st, delta)

static func on_gnaw(st, e) -> void:
	match id_of(st):
		"magma_wall":
			on_gnaw_magma_wall(st, e)

static func interval_mult(st) -> float:
	match id_of(st):
		"crystal_pylon":
			return interval_crystal_pylon(st)
	return 1.0

static func shot_mult(st, target) -> float:
	match id_of(st):
		"prism_tower":
			return shot_prism_tower(st)
	return 1.0

static func on_shot(st, target) -> void:
	match id_of(st):
		"crystal_pylon":
			on_shot_crystal_pylon(st, target)
		"storm_spire":
			on_shot_storm_spire(st, target)
		"venom_tower":
			on_shot_venom_tower(st, target)
		"prism_tower":
			on_shot_prism_tower(st, target)

static func budget_mult(st) -> float:
	return 1.0

static func on_setup(st) -> void:
	match id_of(st):
		"crystal_pylon":
			setup_crystal_pylon(st)
		"magma_wall":
			setup_magma_wall(st)

static func on_promote(st, new_tier: int) -> void:
	match id_of(st):
		"crystal_pylon":
			setup_crystal_pylon(st)
		"magma_wall":
			setup_magma_wall(st)
			st._thr.clear()

static func on_expire(st) -> void:
	match id_of(st):
		"magma_wall":
			on_expire_magma_wall(st)

# ================================================================ Crystal Pylon
const PYLON_AMETHYST := Color(0.8, 0.6, 1.0)
const PYLON_WHITE := Color(0.95, 0.92, 1.0)
const PYLON_STACKS := 4
const PYLON_STACK_T := 5.0
const PYLON_BURST := 4.0
const PYLON_BURST_SPLASH := 2.0
const PYLON_LINK_R := 100.0
const PYLON_LINK := 0.25
const PYLON_LANCE_EVERY := 10
const PYLON_LANCE := 5.0
const PYLON_STAR_T := 10.0
const PYLON_STAR_N := 6
const PYLON_STAR := 3.0
const PYLON_SUPER := 0.5
const PYLON_SUPER_T := 4.0

## Other Pylons / Prism Towers of tier 3 or more within reach (at most two): they resonate with this one, and it with them.
static func linked(st) -> Array:
	var out := []
	if st.tier < 3 or !st.is_inside_tree():
		return out
	for o in st.get_tree().get_nodes_in_group("structure"):
		if o == st or !is_instance_valid(o) or o.is_queued_for_deletion() or int(o.tier) < 3:
			continue
		if !(String(o.data.get("id", "")) in ["crystal_pylon", "prism_tower"]):
			continue
		if o.global_position.distance_to(st.global_position) <= PYLON_LINK_R:
			out.append(o)
	out.sort_custom(func(a, b): return a.global_position.distance_to(st.global_position) < b.global_position.distance_to(st.global_position))
	return out.slice(0, 2)

## Brilliance (tier 5): the night light is twice as wide. Called with fresh card data on setup and on every promotion.
static func setup_crystal_pylon(st) -> void:
	if st.tier >= 5 and float(st.data.get("light", 0.0)) > 0.0:
		ensure_light(st, float(st.data.light) * 2.0)

static func interval_crystal_pylon(st) -> float:
	var m := 1.0
	var n := linked(st).size()
	if n > 0:
		m /= 1.0 + PYLON_LINK * n
	if float(st._timers.get("super", 0.0)) > 0.0:
		m *= PYLON_SUPER
	return m

static func on_shot_crystal_pylon(st, target) -> void:
	var t: int = st.tier
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	# 2 Shardburst: every hit embeds a shard; the fourth bursts them all
	if t >= 2:
		var stacks: Dictionary = state(st, "stacks", {})
		var id: int = target.get_instance_id()
		var rec: Array = stacks.get(id, [0, PYLON_STACK_T])
		rec[0] += 1
		rec[1] = PYLON_STACK_T
		stacks[id] = rec
		if rec[0] >= PYLON_STACKS:
			stacks.erase(id)
			var at: Vector2 = target.global_position
			WeaponFx.spawn(w, "shards", at, PYLON_AMETHYST, {"radius": 30.0, "count": 8, "life": 0.4})
			WeaponFx.spawn(w, "flash", at, PYLON_AMETHYST, {"radius": 22.0, "life": 0.25})
			for e in StructureTiers.enemies_at(st, at, 30.0):
				if e != target:
					e.spell_damage(dmg * PYLON_BURST_SPLASH, "pierce", true)
			if alive(target):
				target.spell_damage(dmg * PYLON_BURST, "pierce", true)
			StructureTiers.sfx(st, "big_hit", 0.2)
		else:
			WeaponFx.spawn(w, "burst", target.global_position, PYLON_AMETHYST, {"radius": 5.0, "life": 0.2})
	# 4 Laser lance: every tenth shot also sends a beam through everything on the line
	if t >= 4:
		st.charge = float(st._shots % PYLON_LANCE_EVERY) / PYLON_LANCE_EVERY
		if st._shots % PYLON_LANCE_EVERY == 0:
			var from := muzzle(st)
			var dir: Vector2 = (target.global_position - from).normalized()
			var rng: float = float(st.data.range)
			WeaponFx.spawn(w, "line", from, PYLON_AMETHYST.lerp(PYLON_WHITE, 0.5), {"dir": dir, "length": rng, "width": 8.0, "life": 0.25})
			WeaponFx.spawn(w, "line", from, Color.WHITE, {"dir": dir, "length": rng, "width": 3.0, "life": 0.25})
			WeaponFx.spawn(w, "flash", from, PYLON_AMETHYST, {"radius": 14.0, "life": 0.2})
			for e in WeaponUtil.enemies_in_line(st.get_tree(), from, dir, rng, 8.0):
				e.spell_damage(dmg * PYLON_LANCE, "pierce", true)
			StructureTiers.sfx(st, "ultimate", 0.3, 1.4)
			st.fx_pulse = 0.0
	elif t >= 2:
		var rec2 = state(st, "stacks", {}).get(target.get_instance_id(), [0])
		st.charge = float(rec2[0]) / PYLON_STACKS

static func tick_crystal_pylon(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	st._timers["super"] = maxf(0.0, float(st._timers.get("super", 0.0)) - delta)
	# shards fade out of enemies that are left alone; the picture of them is published for the clients
	var stacks: Dictionary = state(st, "stacks", {})
	for id in stacks.keys():
		var o = instance_from_id(id)
		stacks[id][1] -= delta
		if o == null or !alive(o) or stacks[id][1] <= 0.0:
			stacks.erase(id)
	if StructureTiers.pace(st, "marks", 0.1, delta):
		var marks := []
		for id in stacks.keys():
			if marks.size() >= 6:
				break
			marks.append([instance_from_id(id).global_position, stacks[id][0]])
		st.vis["marks"] = marks
		st.vis["super"] = float(st._timers["super"]) > 0.0
	# 5 Brilliance: whoever stands in the light is dazzled
	if t >= 5 and StructureTiers.pace(st, "dazzle", 0.2, delta):
		for e in StructureTiers.enemies(st, st.light_radius):
			StructureTiers.keep_slow(e, 0.8, 0.4)
			WeaponUtil.expose(e, 0.5)
	# 6 Starfall: six crystals fall on six enemies, then the pylon is supercharged
	if t >= 6 and StructureTiers.ready(st, "star", PYLON_STAR_T, delta):
		var pool := []
		for e in StructureTiers.enemies(st, float(st.data.range)):
			if Game.defence_sees(e, st.global_position):
				pool.append(e)
		if !pool.is_empty():
			StructureTiers.reset(st, "star")
			pool.shuffle()
			var dmg: float = float(st.data.damage) * PYLON_STAR
			for e in pool.slice(0, PYLON_STAR_N):
				var at: Vector2 = e.global_position
				WeaponFx.spawn(w, "fall", at, PYLON_AMETHYST, {"radius": 4.0, "height": 120.0, "rise": 30.0, "life": 0.4})
				WeaponUtil.ground_strike(st.get_tree(), w, at, 14.0, 0.4, dmg, 100.0, PYLON_AMETHYST, 0.3, [], "pierce")
				later(st, 0.4, func():
					WeaponFx.spawn(w, "shards", at, PYLON_AMETHYST, {"radius": 22.0, "count": 6, "life": 0.35})
					Sfx.play("big_hit"))
			st._timers["super"] = PYLON_SUPER_T
			st.fx_pulse = 0.0
			StructureTiers.sfx(st, "ultimate", 0.5, 1.2)
	if t >= 6:
		st.vis["star"] = StructureTiers.fill(st, "star", PYLON_STAR_T)

# ================================================================ Storm Spire
const SPIRE_BOLT := Color(0.95, 0.97, 1.0)
const SPIRE_STORM := Color(0.35, 0.45, 0.75)
const SPIRE_SPARK := Color(1.0, 0.95, 0.6)
const SPIRE_CHAIN := 0.5
const SPIRE_CHAIN_R := 45.0
const SPIRE_CHARGE_T := 2.5
const SPIRE_DISCHARGE := 1.5
const SPIRE_DISCHARGE_R := 30.0
const SPIRE_CLAP_T := 6.0
const SPIRE_CLAP_R := 70.0
const SPIRE_CLAP := 3.0
const SPIRE_SKY_T := 3.0
const SPIRE_SKY := 4.0
const SPIRE_GALE := 0.7
const SPIRE_CLOUD := Vector2(0, -40)

## A jagged bolt between two points of the world.
static func zap(w: Node, from: Vector2, to: Vector2, col: Color, width := 3.0) -> void:
	var d := to - from
	if d.length() < 1.0:
		return
	WeaponFx.spawn(w, "bolt", from, col, {"dir": d.normalized(), "length": d.length(), "width": width, "life": 0.18, "radius": float(int(from.x + from.y) % 7)})

## The bolt jumps from `first` to the nearest other enemy within reach, `jumps` times, each for half the damage and a chill.
static func chain_storm(st, first, jumps: int) -> void:
	var w := world_of(st)
	var hit: Array = [first]
	var at: Vector2 = first.global_position
	var dmg: float = float(st.data.damage) * SPIRE_CHAIN
	for j in jumps:
		var nxt = null
		var bd := SPIRE_CHAIN_R
		for e in StructureTiers.enemies_at(st, at, SPIRE_CHAIN_R):
			if e in hit or !alive(e):
				continue
			var d: float = e.global_position.distance_to(at)
			if d < bd:
				bd = d
				nxt = e
		if nxt == null:
			break
		var to: Vector2 = nxt.global_position
		zap(w, at, to, SPIRE_BOLT, 2.5)
		nxt.spell_damage(dmg, "")
		if is_instance_valid(nxt) and st.data.has("slow"):
			StructureTiers.keep_slow(nxt, float(st.data.slow), 1.2)
		hit.append(nxt)
		at = to

static func on_shot_storm_spire(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var from := muzzle(st)
	zap(w, from, target.global_position, SPIRE_BOLT)
	StructureTiers.sfx(st, "hit", 0.2)
	chain_storm(st, target, 4 if t >= 6 else 1)
	# 3 Conductor: a hit charges the enemy; a hit on a charged one discharges it as an explosion
	if t >= 3 and is_instance_valid(target):
		var charged: Dictionary = state(st, "charged", {})
		var id: int = target.get_instance_id()
		if charged.has(id):
			charged.erase(id)
			var at: Vector2 = target.global_position
			WeaponFx.spawn(w, "burst", at, SPIRE_BOLT, {"radius": 22.0, "life": 0.25})
			WeaponFx.spawn(w, "ring", at, SPIRE_BOLT, {"radius": SPIRE_DISCHARGE_R, "life": 0.3})
			for e in StructureTiers.enemies_at(st, at, SPIRE_DISCHARGE_R):
				e.spell_damage(float(st.data.damage) * SPIRE_DISCHARGE, "", true)
			StructureTiers.sfx(st, "big_hit", 0.2)
		else:
			charged[id] = SPIRE_CHARGE_T

static func tick_storm_spire(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	# the charged enemies wear off; their places are published so the clients can draw the sparks
	var charged: Dictionary = state(st, "charged", {})
	for id in charged.keys():
		charged[id] -= delta
		var o = instance_from_id(id)
		if o == null or !alive(o) or charged[id] <= 0.0:
			charged.erase(id)
	if t >= 3 and StructureTiers.pace(st, "marks", 0.1, delta):
		var marks := []
		for id in charged.keys():
			if marks.size() >= 8:
				break
			marks.append(instance_from_id(id).global_position)
		st.vis["charged"] = marks
		var near := StructureTiers.enemies(st, float(st.data.range))
		st.charge = clampf(float(charged.size()) / float(maxi(near.size(), 1)), 0.0, 1.0) if !charged.is_empty() else 0.0
	# 4 Thunderclap: the spire cracks and everything close is hurt and stunned
	if t >= 4 and StructureTiers.ready(st, "clap", SPIRE_CLAP_T, delta):
		var close := StructureTiers.enemies(st, SPIRE_CLAP_R)
		if !close.is_empty():
			StructureTiers.reset(st, "clap")
			var cloud: Vector2 = st.global_position + SPIRE_CLOUD
			WeaponFx.spawn(w, "flash", st.global_position, Color(0.8, 0.9, 1.0), {"radius": SPIRE_CLAP_R, "life": 0.2})
			WeaponFx.spawn(w, "ripple", st.global_position, SPIRE_BOLT, {"radius": SPIRE_CLAP_R, "rings": 2, "life": 0.45})
			var n := 0
			for e in close:
				if n < 3:
					zap(w, cloud, e.global_position, SPIRE_BOLT, 2.5)
					n += 1
				e.spell_damage(dmg * SPIRE_CLAP, "", true)
				if alive(e) and !StructureTiers._boss(e) and e.has_method("apply_slow"):
					e.apply_slow(0.0, 0.5)
			st.fx_pulse = 0.0
			StructureTiers.sfx(st, "thump", 0.3)
	# 5 Skybolt: lightning from the sky on the toughest enemy it can see
	if t >= 5 and StructureTiers.ready(st, "sky", SPIRE_SKY_T, delta):
		var best = null
		var hp := -1.0
		for e in StructureTiers.enemies(st, float(st.data.range)):
			if Game.defence_sees(e, st.global_position) and float(e.max_health) > hp:
				hp = float(e.max_health)
				best = e
		if best != null:
			StructureTiers.reset(st, "sky")
			var at: Vector2 = best.global_position
			WeaponFx.spawn(w, "bolt", at + Vector2(0, -120), SPIRE_BOLT, {"dir": Vector2.DOWN, "length": 120.0, "width": 4.0, "life": 0.25})
			WeaponFx.spawn(w, "flash", at, SPIRE_BOLT, {"radius": 26.0, "life": 0.25})
			WeaponFx.spawn(w, "ring", at, SPIRE_BOLT, {"radius": 26.0, "life": 0.3})
			best.spell_damage(dmg * SPIRE_SKY, "")
			if alive(best) and !StructureTiers._boss(best) and best.has_method("apply_slow"):
				best.apply_slow(0.0, 0.3)
			st.fx_pulse = 0.0
			StructureTiers.sfx(st, "big_hit", 0.3)
	# 6 Tempest: a gale slows everything in range; a ripple rolls out every two seconds
	if t >= 6:
		if StructureTiers.pace(st, "gale", 0.1, delta):
			for e in StructureTiers.enemies(st, float(st.data.range)):
				StructureTiers.keep_slow(e, SPIRE_GALE, 0.3)
		if StructureTiers.pace(st, "gale_fx", 2.0, delta):
			WeaponFx.spawn(w, "ripple", st.global_position, Color(SPIRE_BOLT, 0.6), {"radius": float(st.data.range), "rings": 1, "life": 0.9})
			StructureTiers.sfx(st, "whoosh", 2.0, 0.8)

# ================================================================ Magma Wall
const MAGMA_LAVA := Color(1.0, 0.55, 0.15)
const MAGMA_HOT := Color(1.0, 0.95, 0.7)
const MAGMA_BLEED := 0.3
const MAGMA_SPIT_T := 3.0
const MAGMA_SPIT_R := 90.0
const MAGMA_SPIT := 1.2
const MAGMA_HEAT_R := 40.0
const MAGMA_HEAT := 0.4
const MAGMA_ERUPT_R := 55.0
const MAGMA_ERUPT := 4.0
const MAGMA_LIGHT := 60.0
const MAGMA_RAGE_AT := 0.3

static func magma_rage(st) -> bool:
	return st.tier >= 6 and st.hp < MAGMA_RAGE_AT * st.max_hp

## Heat wall (tier 4): the wall is a light at night.
static func setup_magma_wall(st) -> void:
	if st.tier >= 4:
		ensure_light(st, MAGMA_LIGHT)

## Burning: `ticks` hits of `dmg` half a second apart; a new gnaw refreshes the count instead of starting another fire.
static func ignite(tree: SceneTree, e, ticks: int, dmg: float) -> void:
	var running: bool = int(e.get_meta("mw_burn", 0)) > 0
	e.set_meta("mw_burn", ticks)
	e.set_meta("mw_burn_dmg", dmg)
	if running:
		return
	while is_instance_valid(e) and int(e.get_meta("mw_burn", 0)) > 0:
		await tree.create_timer(0.5).timeout
		if !alive(e):
			return
		e.set_meta("mw_burn", int(e.get_meta("mw_burn", 0)) - 1)
		e.spell_damage(float(e.get_meta("mw_burn_dmg", 0.0)), "fire", false)

static func on_gnaw_magma_wall(st, e) -> void:
	if st.tier < 2 or !is_instance_valid(e):
		return
	var thorns: float = float(st.data.get("thorns", 0.0))
	WeaponFx.spawn(world_of(st), "burst", e.global_position, MAGMA_LAVA, {"radius": 8.0, "life": 0.2})
	ignite(st.get_tree(), e, 3, thorns * MAGMA_BLEED * (2.0 if magma_rage(st) else 1.0))

static func tick_magma_wall(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var thorns: float = float(st.data.get("thorns", 0.0))
	var pos: Vector2 = st.global_position
	# 3 Lava spit: a glob at the nearest enemy it can see
	if t >= 3 and StructureTiers.ready(st, "spit", MAGMA_SPIT_T, delta):
		var target = StructureTiers.nearest(st, MAGMA_SPIT_R)
		if target != null:
			StructureTiers.reset(st, "spit")
			var to: Vector2 = target.global_position - pos
			WeaponProjectile.shoot(w, pos + Vector2(0, 8), to, 200.0, thorns * MAGMA_SPIT, MAGMA_LAVA, to.length() / 200.0 + 0.3, 0, 40.0, {"bleed_ticks": 3, "bleed_dmg": thorns * 0.2})
			var at: Vector2 = target.global_position
			later(st, to.length() / 200.0, func(): WeaponFx.spawn(w, "burst", at, MAGMA_LAVA, {"radius": 10.0, "life": 0.2}))
			StructureTiers.sfx(st, "hit", 0.4)
	# 4 Heat wall: whoever is close burns, chewing or not
	if t >= 4 and StructureTiers.pace(st, "heat", 0.5, delta):
		var mult := 2.0 if magma_rage(st) else 1.0
		var n := 0
		for e in StructureTiers.enemies(st, MAGMA_HEAT_R):
			e.spell_damage(thorns * MAGMA_HEAT * mult, "fire", true)
			if n < 2 and is_instance_valid(e):
				WeaponFx.spawn(w, "motes", e.global_position, MAGMA_LAVA, {"radius": 8.0, "count": 2, "rise": 10.0, "life": 0.5})
				n += 1
	# 5 Eruption: at two thirds and at one third of its health
	if t >= 5:
		for key in [["r66", 0.66], ["r33", 0.33]]:
			if StructureTiers.threshold(st, key[0], key[1]):
				StructureTiers.pulse(st, MAGMA_ERUPT_R, thorns * MAGMA_ERUPT, 240.0, 0.6, MAGMA_LAVA, "fire")
				WeaponFx.spawn(w, "flash", pos, MAGMA_LAVA, {"radius": MAGMA_ERUPT_R, "life": 0.3})
				WeaponFx.spawn(w, "ripple", pos, MAGMA_LAVA, {"radius": MAGMA_ERUPT_R, "rings": 2, "life": 0.5})
				WeaponFx.spawn(w, "pillar", pos, MAGMA_LAVA, {"height": 60.0, "width": 20.0, "life": 0.5})
				StructureTiers.cast(st, "lava_pool", pos, 0.8, -2)
				Sfx.play("big_hit")

static func on_expire_magma_wall(st) -> void:
	if st.tier < 6 or st.hp > 0.0:
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	WeaponFx.spawn(w, "flash", pos, Color.WHITE, {"radius": 70.0, "life": 0.4})
	WeaponFx.spawn(w, "pillar", pos, MAGMA_LAVA, {"height": 100.0, "width": 40.0, "life": 0.6})
	StructureTiers.cast(st, "lava_pool", pos, 1.0, -1)
	Sfx.play("ultimate")

# ================================================================ Venom Tower
const VENOM := Color(0.55, 0.9, 0.25)
const VENOM_SPORE := Color(0.8, 1.0, 0.5)
const VENOM_STACKS := 5
const VENOM_STACK_T := 6.0
const VENOM_STACK_BONUS := 0.3
const VENOM_ACID_T := 4.0
const VENOM_ACID := 3.0
const VENOM_ACID_R := 22.0
const VENOM_SPREAD_R := 35.0
const VENOM_SPREAD_T := 1.0
const VENOM_PLAGUE_T := 15.0

static func on_shot_venom_tower(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var poison: float = float(st.data.get("poison", 0.0))
	var stacks: Dictionary = state(st, "stacks", {})
	var id: int = target.get_instance_id()
	var rec: Array = stacks.get(id, [0, VENOM_STACK_T, target.global_position])
	rec[0] = mini(int(rec[0]) + 1, VENOM_STACKS)
	rec[1] = VENOM_STACK_T
	rec[2] = target.global_position
	stacks[id] = rec
	# the poison bites harder the more stacks it has: an extra dot on top of the plain one
	WeaponUtil.bleed(st.get_tree(), target, 4, poison * 0.25 * VENOM_STACK_BONUS * float(rec[0]))
	WeaponFx.spawn(w, "burst", target.global_position, VENOM_SPORE, {"radius": 8.0, "life": 0.2})
	StructureTiers.sfx(st, "hit", 0.2)

## One enemy gets a stack and the poison dot (from the contagion).
static func poison_one(st, e, n := 1) -> void:
	var stacks: Dictionary = state(st, "stacks", {})
	var id: int = e.get_instance_id()
	var rec: Array = stacks.get(id, [0, VENOM_STACK_T, e.global_position])
	rec[0] = maxi(int(rec[0]), n)
	rec[1] = VENOM_STACK_T
	stacks[id] = rec
	WeaponUtil.bleed(st.get_tree(), e, 4, float(st.data.get("poison", 0.0)) * 0.25)

static func tick_venom_tower(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var stacks: Dictionary = state(st, "stacks", {})
	# stacks wear off; a poisoned enemy that dies leaves a spore cloud (tier 3)
	for id in stacks.keys():
		var o = instance_from_id(id)
		var rec: Array = stacks[id]
		if o != null and alive(o):
			rec[2] = o.global_position
			rec[1] -= delta
			if rec[1] <= 0.0:
				stacks.erase(id)
		else:
			stacks.erase(id)
			if t >= 3 and rec[2].distance_to(st.global_position) <= float(st.data.range) + 20.0 and float(st._timers.get("pod", 99.0)) >= 1.0:
				st._timers["pod"] = 0.0
				var at: Vector2 = rec[2]
				StructureTiers.cast(st, "poison_cloud", at, 0.45, -2)
				WeaponFx.spawn(w, "ripple", at, VENOM_SPORE, {"radius": 30.0, "rings": 2, "life": 0.5})
				WeaponFx.spawn(w, "motes", at, VENOM_SPORE, {"radius": 14.0, "count": 10, "rise": 24.0, "life": 0.7})
				StructureTiers.sfx(st, "thump", 0.5)
	st._timers["pod"] = float(st._timers.get("pod", 99.0)) + delta
	if StructureTiers.pace(st, "marks", 0.1, delta):
		var marks := []
		for id in stacks.keys():
			if marks.size() >= 8:
				break
			marks.append([stacks[id][2], stacks[id][0]])
		st.vis["stack_pos"] = marks
	# 4 Acid spit: a glob on the densest group, a slow patch where it lands
	if t >= 4 and StructureTiers.ready(st, "acid", VENOM_ACID_T, delta):
		var target = StructureTiers.densest(st, float(st.data.range))
		if target != null and Game.defence_sees(target, st.global_position):
			StructureTiers.reset(st, "acid")
			var at: Vector2 = target.global_position
			WeaponFx.spawn(w, "fall", at, VENOM, {"radius": 4.0, "height": 50.0, "rise": 30.0, "life": 0.5})
			WeaponUtil.ground_strike(st.get_tree(), w, at, VENOM_ACID_R, 0.5, dmg * VENOM_ACID, 40.0, VENOM, 0.0, [], "poison")
			later(st, 0.5, func():
				WeaponFx.spawn(w, "burst", at, VENOM, {"radius": 14.0, "life": 0.25})
				WeaponUtil.patch(w, at, "slow", VENOM_ACID_R, Color(VENOM, 0.3), 5.0, 0.6))
			StructureTiers.sfx(st, "cast", 0.5)
	# 5 Contagion: an enemy with two stacks poisons one neighbour
	if t >= 5 and StructureTiers.pace(st, "spread", VENOM_SPREAD_T, delta):
		for id in stacks.keys():
			var o = instance_from_id(id)
			if o == null or !alive(o) or int(stacks[id][0]) < 2:
				continue
			var best = null
			var bd := VENOM_SPREAD_R
			for e in StructureTiers.enemies_at(st, o.global_position, VENOM_SPREAD_R):
				if e == o or !alive(e):
					continue
				var rec2 = stacks.get(e.get_instance_id(), [0])
				if int(rec2[0]) >= int(stacks[id][0]):
					continue
				var d: float = e.global_position.distance_to(o.global_position)
				if d < bd:
					bd = d
					best = e
			if best != null:
				poison_one(st, best, 1)
				zap(w, o.global_position, best.global_position, VENOM, 2.0)
				WeaponFx.spawn(w, "burst", best.global_position, VENOM, {"radius": 8.0, "life": 0.2})
				StructureTiers.sfx(st, "whoosh", 1.0)
	# 6 Plague spire: a cloud on the densest group
	if t >= 6 and StructureTiers.ready(st, "plague", VENOM_PLAGUE_T, delta):
		var tg = StructureTiers.densest(st, float(st.data.range))
		if tg != null and Game.defence_sees(tg, st.global_position):
			StructureTiers.reset(st, "plague")
			var at2: Vector2 = tg.global_position
			WeaponFx.spawn(w, "flash", at2, VENOM_SPORE, {"radius": 40.0, "life": 0.35})
			WeaponFx.spawn(w, "ripple", at2, VENOM, {"radius": 40.0, "rings": 3, "life": 0.6})
			StructureTiers.cast(st, "poison_cloud", at2, 0.9, -1)
			StructureTiers.sfx(st, "ultimate", 1.0, 0.8)
			st.fx_pulse = 0.0
	if t >= 6:
		st.charge = StructureTiers.fill(st, "plague", VENOM_PLAGUE_T)

# ================================================================ Prism Tower
const PRISM_RED := Color(1.0, 0.35, 0.3)
const PRISM_BLUE := Color(0.4, 0.6, 1.0)
const PRISM_YELLOW := Color(1.0, 0.9, 0.4)
const PRISM_WHITE := Color(1.0, 0.97, 1.0)
const PRISM_FOCUS := 2.0
const PRISM_BURST_EVERY := 8
const PRISM_BURST := 0.8
const PRISM_REFRACT_R := 70.0
const PRISM_REFRACT := 0.6
const PRISM_LANCE_T := 15.0
const PRISM_LANCE := 8.0
const PRISM_LANCE_W := 18.0

static func prism_colour(i: int) -> Color:
	return [PRISM_RED, PRISM_BLUE, PRISM_YELLOW][i % 3]

## The colour effect on one enemy: red burns, blue chills, yellow exposes.
static func prism_effect(st, e, ci: int, dmg: float) -> void:
	if !alive(e):
		return
	match ci % 3:
		0:
			WeaponUtil.bleed(st.get_tree(), e, 3, dmg * 0.3)
		1:
			StructureTiers.keep_slow(e, 0.5, 1.5)
		2:
			WeaponUtil.expose(e, 2.0)

## Focus lens (tier 3): a lone visible enemy takes a double hit.
static func shot_prism_tower(st) -> float:
	if st.tier < 3:
		return 1.0
	var n := 0
	for e in StructureTiers.enemies(st, float(st.data.range)):
		if Game.defence_sees(e, st.global_position):
			n += 1
	st._tdata["focus"] = n == 1
	return PRISM_FOCUS if n == 1 else 1.0

static func on_shot_prism_tower(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var ci: int = (st._shots - 1) % 3
	var col := prism_colour(ci)
	var from := muzzle(st)
	var at: Vector2 = target.global_position
	var focus: bool = t >= 3 and bool(st._tdata.get("focus", false))
	st.charge = float(st._shots % 3) / 3.0
	st.vis["focus"] = focus
	WeaponFx.spawn(w, "line", from, PRISM_WHITE if focus else col, {"dir": (at - from).normalized(), "length": (at - from).length(), "width": 5.0 if focus else 3.0, "life": 0.18})
	WeaponFx.spawn(w, "burst", at, col, {"radius": 8.0, "life": 0.2})
	if focus:
		WeaponFx.spawn(w, "flash", at, PRISM_WHITE, {"radius": 14.0, "life": 0.2})
		StructureTiers.sfx(st, "big_hit", 0.3)
	else:
		StructureTiers.sfx(st, "whoosh", 0.3)
	prism_effect(st, target, ci, dmg)
	# 4 Prismatic burst: every eighth shot sends twelve rays round the tower
	if t >= 4 and st._shots % PRISM_BURST_EVERY == 0:
		var hub: Vector2 = st.global_position + Vector2(0, -8)
		var rng: float = float(st.data.range) * 0.6
		var done := {}
		for i in 12:
			var dir := Vector2.from_angle(i * TAU / 12.0)
			WeaponFx.spawn(w, "line", hub, prism_colour(i), {"dir": dir, "length": rng, "width": 2.0, "life": 0.3})
			for e in WeaponUtil.enemies_in_line(st.get_tree(), hub, dir, rng, 5.0):
				if !done.has(e.get_instance_id()):
					done[e.get_instance_id()] = true
					e.spell_damage(dmg * PRISM_BURST, "", true)
		WeaponFx.spawn(w, "ripple", hub, PRISM_WHITE, {"radius": 40.0, "rings": 2, "life": 0.5})
		StructureTiers.sfx(st, "ultimate", 0.5, 1.5)
		st.fx_pulse = 0.0
	# 5 Refraction: the shot bends to a neighbour, and once more
	if t >= 5:
		var hit: Array = [target]
		var cur: Vector2 = at
		for j in 2:
			var nxt = null
			var bd := PRISM_REFRACT_R
			for e in StructureTiers.enemies_at(st, cur, PRISM_REFRACT_R):
				if e in hit or !alive(e):
					continue
				var d: float = e.global_position.distance_to(cur)
				if d < bd:
					bd = d
					nxt = e
			if nxt == null:
				break
			var to: Vector2 = nxt.global_position
			WeaponFx.spawn(w, "line", cur, PRISM_WHITE.lerp(col, 0.4), {"dir": (to - cur).normalized(), "length": (to - cur).length(), "width": 2.0, "life": 0.2})
			WeaponFx.spawn(w, "burst", to, col, {"radius": 8.0, "life": 0.2})
			nxt.spell_damage(dmg * PRISM_REFRACT, "")
			prism_effect(st, nxt, ci, dmg)
			hit.append(nxt)
			cur = to

static func tick_prism_tower(st, delta: float) -> void:
	var t: int = st.tier
	if t < 6:
		return
	var w := world_of(st)
	# 6 Spectrum lance: a white beam through the toughest enemy and everything behind it
	if StructureTiers.ready(st, "lance", PRISM_LANCE_T, delta):
		var best = null
		var hp := -1.0
		for e in StructureTiers.enemies(st, float(st.data.range)):
			if Game.defence_sees(e, st.global_position) and float(e.max_health) > hp:
				hp = float(e.max_health)
				best = e
		if best != null:
			StructureTiers.reset(st, "lance")
			var from := muzzle(st)
			var dir: Vector2 = (best.global_position - from).normalized()
			var rng: float = float(st.data.range)
			var dmg: float = float(st.data.damage)
			WeaponFx.spawn(w, "line", from, PRISM_WHITE, {"dir": dir, "length": rng, "width": PRISM_LANCE_W, "life": 0.5})
			for i in 6:
				WeaponFx.spawn(w, "line", from + dir.orthogonal() * (i - 2.5) * 2.4, Color.from_hsv(i / 6.0, 0.7, 1.0), {"dir": dir, "length": rng, "width": 3.0, "life": 0.5})
			WeaponFx.spawn(w, "flash", from, PRISM_WHITE, {"radius": 28.0, "life": 0.3})
			WeaponFx.spawn(w, "ripple", from, PRISM_WHITE, {"radius": 40.0, "rings": 3, "life": 0.6})
			for e in WeaponUtil.enemies_in_line(st.get_tree(), from, dir, rng, PRISM_LANCE_W * 0.5):
				e.spell_damage(dmg * PRISM_LANCE, "", true)
				for ci in 3:
					prism_effect(st, e, ci, dmg)
			StructureTiers.sfx(st, "ultimate", 0.5)
			st.fx_pulse = 0.0
	st.vis["lance"] = StructureTiers.fill(st, "lance", PRISM_LANCE_T)

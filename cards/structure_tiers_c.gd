extends RefCounted
## Tier abilities of the sentry towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower, Sunspire, the Magma Wall and the
## menders Healing Grove and Phoenix Shrine (designs: docs/card_tiers/<card id>.md). It plugs into the hooks of StructureTiers
## (cards/structure_tiers.gd), which delegate here for the ids in OWN. Everything runs on the host; visuals go through
## WeaponFx.spawn / Sfx.play, and what a client must draw is a public var of Structure (`charge`, `aim`, `vis`, ...).
## Host-only state of a card lives in `st._tdata` and `st._timers`.

const OWN := ["crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove", "sunspire", "phoenix_shrine", "healing_lantern", "beacon_turret", "bonfire_wall", "spiked_sentry", "spiked_wall"]

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
		"healing_grove":
			tick_healing_grove(st, delta)
		"sunspire":
			tick_sunspire(st, delta)
		"phoenix_shrine":
			tick_phoenix_shrine(st, delta)
		"healing_lantern":
			tick_healing_lantern(st, delta)
		"beacon_turret":
			tick_beacon_turret(st, delta)
		"bonfire_wall":
			tick_bonfire_wall(st, delta)
		"spiked_wall":
			tick_spiked_wall(st, delta)
		"spiked_sentry":
			tick_spiked_sentry(st, delta)

static func on_gnaw(st, e) -> void:
	match id_of(st):
		"magma_wall":
			on_gnaw_magma_wall(st, e)
		"spiked_wall":
			on_gnaw_spiked_wall(st, e)

static func interval_mult(st) -> float:
	match id_of(st):
		"crystal_pylon":
			return interval_crystal_pylon(st)
		"sunspire":
			return 0.7 if float(st._timers.get("noon_on", 0.0)) > 0.0 else 1.0
		"spiked_sentry":
			return 0.5 if st.tier >= 6 and float(st._tdata.get("spool", 0.0)) >= 1.0 else 1.0
	return 1.0

static func shot_mult(st, target) -> float:
	match id_of(st):
		"prism_tower":
			return shot_prism_tower(st)
		"spiked_sentry":
			return shot_spiked_sentry(st, target)
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
		"sunspire":
			on_shot_sunspire(st, target)
		"beacon_turret":
			on_shot_beacon_turret(st, target)
		"spiked_sentry":
			on_shot_spiked_sentry(st, target)

static func budget_mult(st) -> float:
	match id_of(st):
		"healing_grove":
			return 0.5 if st.tier >= 6 else 1.0
	return 1.0

static func on_setup(st) -> void:
	match id_of(st):
		"crystal_pylon":
			setup_crystal_pylon(st)
		"magma_wall":
			setup_magma_wall(st)
		"healing_lantern":
			setup_healing_lantern(st)
		"bonfire_wall":
			setup_bonfire_wall(st)

static func on_promote(st, new_tier: int) -> void:
	match id_of(st):
		"crystal_pylon":
			setup_crystal_pylon(st)
		"magma_wall":
			setup_magma_wall(st)
			st._thr.clear()
		"healing_lantern":
			setup_healing_lantern(st)
		"bonfire_wall":
			setup_bonfire_wall(st)
			st._thr.clear()
		"spiked_wall":
			st._tdata.erase("base_thorns")
			st._tdata["porc"] = false
			st._thr.clear()

static func on_expire(st) -> void:
	match id_of(st):
		"phoenix_shrine":
			on_expire_phoenix_shrine(st)
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
		st.vis["star"] = snappedf(StructureTiers.fill(st, "star", PYLON_STAR_T), 0.02)

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
		st.charge = snappedf(StructureTiers.fill(st, "plague", VENOM_PLAGUE_T), 0.02)

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
	st.vis["lance"] = snappedf(StructureTiers.fill(st, "lance", PRISM_LANCE_T), 0.02)

# ================================================================ Healing Grove
const GROVE_FRUIT_COL := Color(1.0, 0.55, 0.2)
const GROVE_BLOSSOM := Color(1.0, 0.75, 0.85)
const GROVE_LEAF := Color(0.3, 0.75, 0.35)
const GROVE_GOLD := Color(1.0, 0.9, 0.5)
const GROVE_HOT := 0.4
const GROVE_HOT_T := 3.0
const GROVE_FRUIT_T := 10.0
const GROVE_FRUIT := 0.15
const GROVE_FRUIT_MAX := 2
const GROVE_ROOT := 0.65
const GROVE_BLOOM_T := 8.0
const GROVE_BLOOM := 1.5
const GROVE_SEED_T := 40.0
const GROVE_SEED_WAIT := 3.0

static func players(st) -> Array:
	var out := []
	for p in st.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p):
			out.append(p)
	return out

static func tick_healing_grove(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var hps: float = float(st.data.heal_per_sec)
	var pos: Vector2 = st.global_position
	var r: float = st.radius
	var ps := players(st)
	# 2 Regrowth: a player healed here keeps healing for a few seconds after leaving (not counted against the budget)
	var hot: Dictionary = state(st, "hot", {})
	for p in ps:
		var id: int = p.get_instance_id()
		var inside: bool = p.global_position.distance_to(pos) <= r
		if inside:
			if p.needs_health():
				hot[id] = GROVE_HOT_T
		elif hot.has(id):
			hot[id] -= delta
			if hot[id] <= 0.0 or !p.needs_health():
				hot.erase(id)
			else:
				p.heal(hps * GROVE_HOT * delta)
				if StructureTiers.pace(st, "trail", 0.5, delta):
					WeaponFx.spawn(w, "motes", p.global_position, GROVE_LEAF, {"radius": 6.0, "count": 3, "rise": 10.0, "life": 0.5})
	# 3 Orchard: a fruit ripens somewhere in the field; a hurt player who touches it eats it
	if t >= 3:
		var fruit: Array = state(st, "fruit", [])
		if fruit.size() < GROVE_FRUIT_MAX and StructureTiers.ready(st, "fruit", GROVE_FRUIT_T, delta):
			StructureTiers.reset(st, "fruit")
			var n: int = int(state(st, "spawned", 0)) + 1
			st._tdata["spawned"] = n
			fruit.append(Vector2.from_angle(SpellArt.jit(n, 1.0) * TAU) * r * 0.6 * (0.3 + 0.7 * SpellArt.jit(n, 2.0)))
		for f in fruit.duplicate():
			for p in ps:
				if p.needs_health() and p.global_position.distance_to(pos + f) <= 12.0:
					fruit.erase(f)
					p.heal(GROVE_FRUIT * 228.0 * Game.hp_scale())
					WeaponFx.spawn(w, "star", pos + f, GROVE_FRUIT_COL, {"radius": 12.0, "count": 5, "spin": 2.0, "life": 0.4})
					WeaponFx.spawn(w, "motes", pos + f, GROVE_FRUIT_COL, {"radius": 8.0, "count": 6, "rise": 18.0, "life": 0.6})
					Sfx.play("coin")
					break
		st.vis["fruit_pos"] = fruit.duplicate()
	# 4 Grasping roots: enemies in the field are slowed (a safe place to stand)
	if t >= 4:
		var inside_now := StructureTiers.enemies(st, r)
		var rooted: Dictionary = state(st, "rooted", {})
		var ids := {}
		for e in inside_now:
			StructureTiers.keep_slow(e, GROVE_ROOT, 0.3)
			var id2: int = e.get_instance_id()
			ids[id2] = true
			if !rooted.has(id2):
				WeaponFx.spawn(w, "burst", e.global_position, GROVE_LEAF, {"radius": 10.0, "life": 0.25})
			rooted[id2] = true
		for id3 in rooted.keys():
			if !ids.has(id3):
				rooted.erase(id3)
		st.vis["roots"] = !inside_now.is_empty()
	# 5 Blossom pulse: a wave heals every player and guard in the field and clears confusion
	if t >= 5 and StructureTiers.pace(st, "bloom", GROVE_BLOOM_T, delta):
		for p in ps:
			if !p.downed and p.global_position.distance_to(pos) <= r:
				p.heal(hps * GROVE_BLOOM)
				p.confused_time = 0.0
		for g in st.get_tree().get_nodes_in_group("guard"):
			if is_instance_valid(g) and !g.get("downed") and g.global_position.distance_to(pos) <= r:
				g.hp = minf(g.max_hp, g.hp + hps * GROVE_BLOOM)
		WeaponFx.spawn(w, "ripple", pos, GROVE_LEAF.lerp(GROVE_BLOSSOM, 0.5), {"radius": r, "rings": 2, "life": 0.7})
		WeaponFx.spawn(w, "motes", pos, GROVE_BLOSSOM, {"radius": r * 0.8, "count": 14, "rise": 30.0, "life": 0.9})
		st.fx_pulse = 0.0
		Sfx.play("unlock")
	# 6 Seed of life: the tree calls a fallen player back (once every forty seconds)
	if t >= 6 and StructureTiers.ready(st, "seed", GROVE_SEED_T, delta):
		for p in ps:
			if p.downed and p.respawn_left > GROVE_SEED_WAIT:
				StructureTiers.reset(st, "seed")
				p.respawn_left = GROVE_SEED_WAIT
				WeaponFx.spawn(w, "pillar", pos, GROVE_GOLD, {"height": 80.0, "width": 30.0, "life": 0.7})
				WeaponFx.spawn(w, "star", pos, GROVE_GOLD, {"radius": 30.0, "count": 8, "spin": 2.0, "life": 0.7})
				StructureTiers.sfx(st, "ultimate", 0.5)
				break

# ================================================================ Sunspire
const SUN_GOLD := Color(1.0, 0.8, 0.3)
const SUN_WHITE := Color(1.0, 0.99, 0.9)
const SUN_AMBER := Color(1.0, 0.6, 0.2)
const SUN_FLARE := 0.25
const SUN_LANCE_T := 4.0
const SUN_LANCE := 3.0
const SUN_PULSE_T := 6.0
const SUN_PULSE_R := 80.0
const SUN_PULSE := 2.5
const SUN_PULSE_HEAL := 0.05
const SUN_HELIO := 0.5
const SUN_HELIO_R := 26.0
const SUN_NOON_T := 20.0
const SUN_NOON := 6.0
const SUN_NOON_LEN := 10.0

## Where heliostat mirror `i` is (a function of the building's clock, so a LAN client draws it in the same place).
static func orb_pos(st, i: int) -> Vector2:
	return st.global_position + Vector2.from_angle(st._age * 0.6 + i * TAU / 4.0) * SUN_HELIO_R

static func on_shot_sunspire(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var from := muzzle(st)
	var at: Vector2 = target.global_position
	# 2 Solar flare: the hit sets the target ablaze and lights it
	WeaponFx.spawn(w, "line", from, SUN_GOLD, {"dir": (at - from).normalized(), "length": (at - from).length(), "width": 3.0, "life": 0.18})
	WeaponFx.spawn(w, "burst", at, SUN_AMBER, {"radius": 10.0, "life": 0.2})
	WeaponFx.spawn(w, "star", at, SUN_WHITE, {"radius": 8.0, "count": 4, "spin": 1.5, "life": 0.25})
	StructureTiers.sfx(st, "big_hit", 0.4)
	WeaponUtil.bleed(st.get_tree(), target, 3, dmg * SUN_FLARE)
	Game.light_up(target, 3.0)
	# 3 Solar lance: every four seconds a line of light goes through the target out to the edge of its range
	if t >= 3 and float(st._timers.get("lance", 0.0)) >= SUN_LANCE_T:
		st._timers["lance"] = 0.0
		var dir: Vector2 = (at - from).normalized()
		var rng: float = float(st.data.range)
		WeaponFx.spawn(w, "line", from, SUN_GOLD.lerp(SUN_WHITE, 0.5), {"dir": dir, "length": rng, "width": 10.0, "life": 0.3})
		WeaponFx.spawn(w, "line", from, SUN_WHITE, {"dir": dir, "length": rng, "width": 3.0, "life": 0.3})
		WeaponFx.spawn(w, "flash", from, SUN_GOLD, {"radius": 16.0, "life": 0.2})
		for e in WeaponUtil.enemies_in_line(st.get_tree(), from, dir, rng, 8.0):
			e.spell_damage(dmg * SUN_LANCE, "fire", true)
		StructureTiers.sfx(st, "ultimate", 0.5, 1.5)
		st.fx_pulse = 0.0

static func tick_sunspire(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var pos: Vector2 = st.global_position
	st._timers["noon_on"] = maxf(0.0, float(st._timers.get("noon_on", 0.0)) - delta)
	if t >= 3:
		st._timers["lance"] = minf(SUN_LANCE_T, float(st._timers.get("lance", 0.0)) + delta)
		st.vis["lance"] = snappedf(float(st._timers["lance"]) / SUN_LANCE_T, 0.02)
		st.charge = st.vis["lance"]
	# 4 Radiant pulse: a ring of sunlight when something is close
	if t >= 4 and StructureTiers.ready(st, "pulse", SUN_PULSE_T, delta):
		if !StructureTiers.enemies(st, 100.0).is_empty():
			StructureTiers.reset(st, "pulse")
			StructureTiers.pulse(st, SUN_PULSE_R, dmg * SUN_PULSE, 220.0, 0.4, SUN_GOLD, "fire")
			WeaponFx.spawn(w, "ripple", pos, SUN_GOLD, {"radius": SUN_PULSE_R, "rings": 3, "life": 0.6})
			WeaponFx.spawn(w, "flash", pos, SUN_WHITE, {"radius": 60.0, "life": 0.25})
			for p in st.get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and p.global_position.distance_to(pos) <= SUN_PULSE_R:
					p.heal(SUN_PULSE_HEAL * 228.0 * Game.hp_scale())
			StructureTiers.sfx(st, "whoosh", 0.5)
	# 5 Heliostats: four mirrors circle the spire, each firing at the nearest enemy it can see
	if t >= 5:
		for i in 4:
			var key := "m%d" % i
			if !st._timers.has(key):
				st._timers[key] = -0.25 * i                      # staggered by a quarter second
			st._timers[key] += delta
			if st._timers[key] >= 1.0:
				var mp := orb_pos(st, i)
				var best = null
				var bd := float(st.data.range)
				for e in StructureTiers.enemies_at(st, mp, float(st.data.range)):
					if !Game.defence_sees(e, pos):
						continue
					var d: float = e.global_position.distance_to(mp)
					if d < bd:
						bd = d
						best = e
				if best != null:
					st._timers[key] = 0.0
					var to: Vector2 = best.global_position
					WeaponFx.spawn(w, "line", mp, SUN_GOLD, {"dir": (to - mp).normalized(), "length": (to - mp).length(), "width": 1.5, "life": 0.2})
					WeaponFx.spawn(w, "burst", to, SUN_GOLD, {"radius": 8.0, "life": 0.2})
					best.spell_damage(dmg * SUN_HELIO, "fire")
				else:
					st._timers[key] = 1.0
	# 6 High noon: a judgement on everything in range
	if t >= 6:
		if StructureTiers.ready(st, "noon", SUN_NOON_T, delta):
			var judged := StructureTiers.enemies(st, float(st.data.range))
			if !judged.is_empty():
				StructureTiers.reset(st, "noon")
				st._timers["noon_on"] = SUN_NOON_LEN
				WeaponFx.spawn(w, "pillar", pos, SUN_WHITE.lerp(SUN_GOLD, 0.4), {"height": 160.0, "width": 60.0, "life": 0.8})
				WeaponFx.spawn(w, "flash", pos, SUN_GOLD, {"radius": 120.0, "life": 0.4})
				WeaponFx.spawn(w, "ripple", pos, SUN_GOLD, {"radius": 170.0, "rings": 4, "life": 0.9})
				var n := 0
				for e in judged:
					if n < 12:
						WeaponFx.spawn(w, "flash", e.global_position, SUN_WHITE, {"radius": 16.0, "life": 0.3})
						n += 1
					e.spell_damage(dmg * SUN_NOON, "fire", true)
					Game.light_up(e, SUN_NOON_LEN)
				StructureTiers.sfx(st, "ultimate", 0.5)
				st.fx_pulse = 0.0
		st.vis["noon"] = float(st._timers["noon_on"]) > 0.0
		st.charge = snappedf(StructureTiers.fill(st, "noon", SUN_NOON_T), 0.02)

# ================================================================ Phoenix Shrine
const PHX_FLAME := Color(1.0, 0.55, 0.2)
const PHX_GOLD := Color(1.0, 0.82, 0.35)
const PHX_WHITE := Color(1.0, 0.96, 0.8)
const PHX_SCORCH := 0.12
const PHX_ASH := 0.06
const PHX_DIVE_T := 5.0
const PHX_DIVE := 0.2
const PHX_DIVE_R := 30.0
const PHX_LIFE_AT := 0.10
const PHX_LIFE_TO := 0.7
const PHX_LIFE_CD := 45.0
const PHX_SONG := 6.0

## A burst of fire centred on `at` (the pulse helper centres on the building): damage, shove, stun.
static func nova(st, at: Vector2, r: float, dmg: float, push_speed: float, stun: float, col: Color, elem := "fire") -> void:
	var w := world_of(st)
	WeaponFx.spawn(w, "ring", at, col, {"radius": r, "life": 0.3})
	WeaponFx.spawn(w, "shards", at, col, {"radius": r, "count": 8, "life": 0.35})
	for e in StructureTiers.enemies_at(st, at, r):
		var dir: Vector2 = (e.global_position - at).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		e.spell_damage(dmg, elem, true)
		if !alive(e):
			continue
		if push_speed > 0.0 and e.has_method("push"):
			e.push(dir * push_speed, 0.15)
		if stun > 0.0 and !StructureTiers._boss(e) and e.has_method("apply_slow"):
			e.apply_slow(0.0, stun)

static func tick_phoenix_shrine(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var hps: float = float(st.data.heal_per_sec)
	var pos: Vector2 = st.global_position
	var r: float = st.radius
	var ps: Array = []
	for p in st.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.downed and p.global_position.distance_to(pos) <= r:
			ps.append(p)
	# the budget left, for the last-breath glow of the phoenix
	if st._heal_budget > 0.0:
		st.charge = snappedf(clampf(st._healed / st._heal_budget, 0.0, 1.0), 0.02)
	# 2 Purifying flame: what stands in the field is scorched
	if StructureTiers.pace(st, "scorch", 0.5, delta):
		var n := 0
		for e in StructureTiers.enemies(st, r):
			e.spell_damage(hps * PHX_SCORCH * 0.5, "fire", true)
			if n < 2 and is_instance_valid(e):
				WeaponFx.spawn(w, "burst", e.global_position, PHX_FLAME, {"radius": 6.0, "life": 0.2})
				n += 1
	# 3 Ashes to ashes: every enemy that dies in the field heals the hurt players in it
	if t >= 3:
		for at in StructureTiers.deaths(st, r):
			for p in ps:
				if p.needs_health():
					p.heal(PHX_ASH * 228.0 * Game.hp_scale())
					WeaponFx.spawn(w, "motes", p.global_position, PHX_GOLD, {"radius": 8.0, "count": 8, "rise": 24.0, "life": 0.7})
			if !ps.is_empty():
				StructureTiers.sfx(st, "unlock", 0.4)
	# 4 Phoenix dive: the phoenix drops on the most hurt player
	if t >= 4:
		var dt: float = float(st.vis.get("dive_t", 9.0))
		if dt < 1.0:
			st.vis["dive_t"] = snappedf(minf(dt + delta, 1.0), 0.05)
		if StructureTiers.ready(st, "dive", PHX_DIVE_T, delta):
			var hurt = null
			var lowest := 0.95
			for p in ps:
				var f: float = StructureTiers.hp_frac(p)
				if f < lowest:
					lowest = f
					hurt = p
			if hurt != null:
				StructureTiers.reset(st, "dive")
				var at: Vector2 = hurt.global_position
				hurt.heal(PHX_DIVE * 228.0 * Game.hp_scale())
				nova(st, at, PHX_DIVE_R, hps * 0.5, 0.0, 0.0, PHX_FLAME)
				WeaponFx.spawn(w, "line", pos + Vector2(0, -10), PHX_GOLD, {"dir": (at - pos).normalized(), "length": at.distance_to(pos), "width": 4.0, "life": 0.25})
				WeaponFx.spawn(w, "pillar", at, PHX_FLAME, {"height": 40.0, "width": 16.0, "life": 0.4})
				st.vis["dive_to"] = at - pos
				st.vis["dive_t"] = 0.0
				StructureTiers.sfx(st, "cast", 0.4)
	# 5 Second life: a player about to fall in the field is saved (once per player in 45 s)
	if t >= 5:
		var saved: Dictionary = state(st, "saved", {})
		for id in saved.keys():
			saved[id] -= delta
			if saved[id] <= 0.0:
				saved.erase(id)
		for p in ps:
			var id2: int = p.get_instance_id()
			var f2: float = StructureTiers.hp_frac(p)
			if f2 < PHX_LIFE_AT and !saved.has(id2):
				saved[id2] = PHX_LIFE_CD
				p.heal((PHX_LIFE_TO - f2) * 228.0 * Game.hp_scale())
				p.shield_time = maxf(p.shield_time, 2.5)
				var at2: Vector2 = p.global_position
				nova(st, at2, 60.0, hps * 2.0, 260.0, 0.5, PHX_FLAME)
				WeaponFx.spawn(w, "pillar", at2, PHX_GOLD, {"height": 100.0, "width": 40.0, "life": 0.6})
				WeaponFx.spawn(w, "flash", at2, PHX_GOLD, {"radius": 40.0, "life": 0.3})
				WeaponFx.spawn(w, "ripple", at2, PHX_GOLD, {"radius": 60.0, "rings": 3, "life": 0.6})
				WeaponFx.spawn(w, "star", at2, PHX_GOLD, {"radius": 50.0, "count": 8, "spin": 2.0, "life": 0.6})
				StructureTiers.sfx(st, "ultimate", 0.5)

## 6 Phoenix song (FINALE): when its healing is spent the shrine sings once instead of just vanishing.
static func on_expire_phoenix_shrine(st) -> void:
	if st.tier < 6 or bool(st.data.get("copy", false)):
		return
	var w := world_of(st)
	var pos: Vector2 = st.global_position
	var r: float = st.radius * 1.5
	for p in st.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.downed and p.global_position.distance_to(pos) <= r:
			p.heal(228.0 * Game.hp_scale())
			p.shield_time = maxf(p.shield_time, 4.0)
	StructureTiers.pulse(st, r, float(st.data.heal_per_sec) * PHX_SONG, 300.0, 1.0, PHX_GOLD, "fire")
	WeaponFx.spawn(w, "flash", pos, PHX_WHITE, {"radius": 95.0, "life": 0.5})
	WeaponFx.spawn(w, "pillar", pos, PHX_GOLD, {"height": 160.0, "width": 70.0, "life": 0.8})
	WeaponFx.spawn(w, "ripple", pos, PHX_GOLD, {"radius": 140.0, "rings": 4, "life": 0.9})
	WeaponFx.spawn(w, "star", pos, PHX_GOLD, {"radius": 90.0, "count": 12, "spin": 2.0, "life": 0.9})
	Sfx.play("ultimate")

# ================================================================ Healing Lantern
const LANT_GOLD := Color(1.0, 0.85, 0.5)
const LANT_WHITE := Color(1.0, 0.97, 0.85)
const LANT_GREEN := Color(0.6, 1.0, 0.7)
const LANT_WISP := 0.5
const LANT_WISP_SPEED := 90.0
const LANT_REVEAL_SLOW := 0.85
const LANT_SHIELD_AT := 0.5
const LANT_SHIELD_CD := 15.0
const LANT_SHIELD_T := 1.5
const LANT_ZAP_T := 1.2
const LANT_ZAP := 0.6
const LANT_DAWN_T := 20.0
const LANT_DAWN_HEAL := 0.25
const LANT_DAWN_R := 1.5

## Dawn lantern (tier 6): the light is a third wider.
static func setup_healing_lantern(st) -> void:
	if st.tier >= 6 and float(st.data.get("light", 0.0)) > 0.0:
		ensure_light(st, float(st.data.light) * 1.3)

## Where lantern spirit `i` floats (a function of the building's clock, so a LAN client draws it in the same place).
static func spirit_pos(st, i: int) -> Vector2:
	return st.global_position + Vector2.from_angle(st._age * 1.2 + i * TAU / 3.0) * st.radius * 0.6

static func tick_healing_lantern(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var hps: float = float(st.data.heal_per_sec)
	var pos: Vector2 = st.global_position
	var r: float = st.radius
	var ps: Array = []
	for p in st.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.downed and p.global_position.distance_to(pos) <= r:
			ps.append(p)
	# the most hurt player in the field
	var hurt = null
	var lowest := 0.99
	for p in ps:
		var f: float = StructureTiers.hp_frac(p)
		if f < lowest:
			lowest = f
			hurt = p
	# 2 Healing wisp: it follows the most hurt player and heals them extra while it is on them (not counted against the budget)
	var wisp: Vector2 = state(st, "wisp", pos + Vector2(10, -16))
	var goal: Vector2 = pos + Vector2.from_angle(st._age * 1.5) * 12.0 + Vector2(0, -14)
	if hurt != null:
		goal = hurt.global_position + Vector2(0, -8)
	wisp = wisp.move_toward(goal, LANT_WISP_SPEED * delta)
	st._tdata["wisp"] = wisp
	if hurt != null and wisp.distance_to(hurt.global_position) <= 12.0:
		hurt.heal(hps * LANT_WISP * delta)
		if StructureTiers.pace(st, "wisp_fx", 0.5, delta):
			WeaponFx.spawn(w, "motes", hurt.global_position, LANT_GREEN, {"radius": 6.0, "count": 3, "rise": 10.0, "life": 0.5})
	st.vis["wisp"] = (wisp - pos).snapped(Vector2(0.5, 0.5))
	st.vis["wisp_to"] = hurt != null
	# 3 Revealing light: whoever is in the field is lit and slowed a little
	if t >= 3 and StructureTiers.pace(st, "reveal", 0.25, delta):
		var lit := []
		for e in StructureTiers.enemies(st, r):
			Game.light_up(e, 2.0)
			StructureTiers.keep_slow(e, LANT_REVEAL_SLOW, 0.3)
			if lit.size() < 8:
				lit.append(e.global_position - pos)
		st.vis["lit"] = lit
		if StructureTiers.pace(st, "reveal_fx", 2.0, 0.25):
			WeaponFx.spawn(w, "ring", pos, Color(LANT_GOLD, 0.6), {"radius": r, "life": 0.5})
			StructureTiers.sfx(st, "cast", 2.0, 0.8)
	# 4 Guiding light: a player who falls below half health is shielded for a moment (once per player per 15 s)
	if t >= 4:
		var cds: Dictionary = state(st, "shield", {})
		for id in cds.keys():
			cds[id] -= delta
			if cds[id] <= 0.0:
				cds.erase(id)
		var ribbon: float = float(st._timers.get("ribbon", 0.0)) - delta
		st._timers["ribbon"] = maxf(0.0, ribbon)
		if ribbon <= 0.0 and st.vis.has("ribbon"):
			st.vis.erase("ribbon")
		for p in ps:
			var id2: int = p.get_instance_id()
			if StructureTiers.hp_frac(p) < LANT_SHIELD_AT and !cds.has(id2):
				cds[id2] = LANT_SHIELD_CD
				p.shield_time = maxf(p.shield_time, LANT_SHIELD_T)
				WeaponFx.spawn(w, "star", p.global_position, LANT_WHITE, {"radius": 16.0, "count": 6, "spin": 1.5, "life": 0.5})
				st.vis["ribbon"] = (p.global_position - pos).snapped(Vector2(1, 1))
				st._timers["ribbon"] = LANT_SHIELD_T
				StructureTiers.sfx(st, "unlock", 0.4)
	# 5 Spirit lanterns: three spirits zap the nearest enemy in the field in turn, and each zap that hits mends the most hurt player a little
	if t >= 5:
		for i in 3:
			var key := "sp%d" % i
			if !st._timers.has(key):
				st._timers[key] = -0.4 * i
			st._timers[key] += delta
			if st._timers[key] >= LANT_ZAP_T:
				var sp := spirit_pos(st, i)
				var best = null
				var bd := INF
				for e in StructureTiers.enemies(st, r):
					var d: float = e.global_position.distance_to(sp)
					if d < bd:
						bd = d
						best = e
				if best != null:
					st._timers[key] = 0.0
					var to: Vector2 = best.global_position
					WeaponFx.spawn(w, "line", sp, LANT_GOLD, {"dir": (to - sp).normalized(), "length": (to - sp).length(), "width": 2.0, "life": 0.2})
					WeaponFx.spawn(w, "burst", to, LANT_GOLD, {"radius": 8.0, "life": 0.2})
					best.spell_damage(hps * LANT_ZAP, "fire")
					if hurt != null:
						hurt.heal(1.0)
					StructureTiers.sfx(st, "hit", 0.3)
				else:
					st._timers[key] = LANT_ZAP_T
	# 6 Dawn: every twenty seconds the lantern flares and heals, burns and shoves
	if t >= 6:
		if StructureTiers.pace(st, "dawn", LANT_DAWN_T, delta):
			var big: float = r * LANT_DAWN_R
			for p in st.get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and !p.downed and p.global_position.distance_to(pos) <= big:
					p.heal(LANT_DAWN_HEAL * 228.0 * Game.hp_scale())
			StructureTiers.pulse(st, big, hps * 3.0, 160.0, 0.0, LANT_GOLD, "fire")
			for e in StructureTiers.enemies(st, big):
				Game.light_up(e, 8.0)
			WeaponFx.spawn(w, "flash", pos, LANT_WHITE, {"radius": big, "life": 0.5})
			WeaponFx.spawn(w, "ripple", pos, LANT_GOLD, {"radius": big, "rings": 3, "life": 0.9})
			WeaponFx.spawn(w, "star", pos, LANT_GOLD, {"radius": r, "count": 10, "spin": 2.0, "life": 0.9})
			StructureTiers.sfx(st, "ultimate", 0.5)
		st.charge = snappedf(StructureTiers.fill(st, "dawn", LANT_DAWN_T), 0.02)

# ================================================================ Beacon Turret
const BEACON_FLAME := Color(1.0, 0.7, 0.25)
const BEACON_BRASS := Color(0.9, 0.75, 0.35)
const BEACON_WHITE := Color(1.0, 0.97, 0.85)
const BEACON_SIGNAL := 0.25
const BEACON_SWEEP := 0.8
const BEACON_SWEEP_SPEED := 1.3
const BEACON_SWEEP_HALF := 0.11
const BEACON_FLARE_EVERY := 6
const BEACON_HORN_T := 12.0
const BEACON_HORN_N := 3
const BEACON_SEARCH_T := 15.0
const BEACON_SEARCH_LEN := 4.0
const BEACON_SEARCH := 3.0

## The angle of the sweeping beam (the counter-beam of tier 6 is half a turn on).
static func beam_angle(st) -> float:
	return st._age * BEACON_SWEEP_SPEED

static func on_shot_beacon_turret(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var from := muzzle(st)
	var at: Vector2 = target.global_position
	# 2 Signal fire: the target burns on and is lit
	WeaponFx.spawn(w, "line", from, BEACON_FLAME, {"dir": (at - from).normalized(), "length": (at - from).length(), "width": 2.5, "life": 0.15})
	WeaponFx.spawn(w, "burst", at, BEACON_FLAME, {"radius": 8.0, "life": 0.2})
	StructureTiers.sfx(st, "hit", 0.2)
	WeaponUtil.bleed(st.get_tree(), target, 3, dmg * BEACON_SIGNAL)
	Game.light_up(target, 3.0)
	# 4 Flare shell: every sixth shot sends up a flare on the target spot
	if t >= 4:
		st.charge = float(st._shots % BEACON_FLARE_EVERY) / BEACON_FLARE_EVERY
		if st._shots % BEACON_FLARE_EVERY == 0:
			StructureTiers.cast(st, "flare", at, 0.8, -2)
			StructureTiers.sfx(st, "cast", 0.3)

static func tick_beacon_turret(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var pos: Vector2 = st.global_position
	var rng: float = float(st.data.range)
	# 3 Sweeping beam: whatever the beam crosses is hit, once per half second each
	if t >= 3:
		var cd: Dictionary = state(st, "beam_cd", {})
		for id in cd.keys():
			cd[id] -= delta
			if cd[id] <= 0.0:
				cd.erase(id)
		var angles := [beam_angle(st)]
		if t >= 6:
			angles.append(beam_angle(st) + PI)
		for e in StructureTiers.enemies(st, st.light_radius):
			var id2: int = e.get_instance_id()
			if cd.has(id2):
				continue
			var bearing: float = (e.global_position - pos).angle()
			for a in angles:
				if absf(angle_difference(bearing, a)) <= BEACON_SWEEP_HALF:
					cd[id2] = 0.5
					e.spell_damage(dmg * BEACON_SWEEP, "fire", true)
					if is_instance_valid(e):
						WeaponFx.spawn(w, "burst", e.global_position, BEACON_WHITE, {"radius": 7.0, "life": 0.2})
					break
	# 5 Alarm horn: three or more enemies in range and it blows
	if t >= 5:
		var near := StructureTiers.enemies(st, rng)
		if StructureTiers.pace(st, "alert", 0.2, delta):
			st.vis["alert"] = !near.is_empty()
		if StructureTiers.ready(st, "horn", BEACON_HORN_T, delta) and near.size() >= BEACON_HORN_N:
			StructureTiers.reset(st, "horn")
			for e in near:
				StructureTiers.keep_slow(e, 0.7, 3.0)
				Game.light_up(e, 6.0)
			WeaponFx.spawn(w, "ripple", pos, BEACON_BRASS, {"radius": rng, "rings": 2, "life": 0.7})
			StructureTiers.sfx(st, "boss_roar", 0.5, 1.6)
			st.fx_pulse = 0.0
	# 6 Searchlight: a beam locks on the toughest visible enemy for four seconds
	if t >= 6:
		var lock = st._tdata.get("lock", null)
		if lock != null and (!alive(lock[0]) or lock[1] <= 0.0):
			st._tdata.erase("lock")
			lock = null
			st.vis["lock_on"] = false
		if lock != null:
			lock[1] -= delta
			var e = lock[0]
			var to: Vector2 = e.global_position
			st.vis["lock"] = (to - pos).snapped(Vector2(1, 1))
			StructureTiers.keep_slow(e, 0.5, 0.3)
			e.set_meta("marked_until", Time.get_ticks_msec() / 1000.0 + 0.5)
			if StructureTiers.pace(st, "search_fx", 0.1, delta):
				var from2 := muzzle(st)
				WeaponFx.spawn(w, "line", from2, Color(1.0, 0.97, 0.8, 0.9), {"dir": (to - from2).normalized(), "length": (to - from2).length(), "width": 14.0, "life": 0.12})
			if StructureTiers.pace(st, "search_hit", 0.5, delta):
				e.spell_damage(dmg * BEACON_SEARCH * 0.5, "fire")
		elif StructureTiers.ready(st, "search", BEACON_SEARCH_T, delta):
			var best = null
			var hp := -1.0
			for e in StructureTiers.enemies(st, rng):
				if Game.defence_sees(e, pos) and float(e.max_health) > hp:
					hp = float(e.max_health)
					best = e
			if best != null:
				StructureTiers.reset(st, "search")
				st._tdata["lock"] = [best, BEACON_SEARCH_LEN]
				st.vis["lock_on"] = true
				WeaponFx.spawn(w, "flash", best.global_position, BEACON_WHITE, {"radius": 18.0, "life": 0.3})
				StructureTiers.sfx(st, "ultimate", 0.5)

# ================================================================ Bonfire Wall
const BONF_FIRE := Color(1.0, 0.55, 0.2)
const BONF_CORE := Color(1.0, 0.85, 0.4)
const BONF_WHITE := Color(1.0, 0.97, 0.8)
const BONF_SCORCH_R := 32.0
const BONF_SCORCH := 0.5
const BONF_BRAND_T := 3.0
const BONF_BRAND_R := 100.0
const BONF_BRAND := 2.0
const BONF_FEED := 0.5
const BONF_SPREAD_R := 25.0
const BONF_PYRE_T := 15.0
const BONF_PYRE := 4.0

## Spreading blaze (tier 5): the light ring is bigger.
static func setup_bonfire_wall(st) -> void:
	if st.tier >= 5 and float(st.data.get("light", 0.0)) > 0.0:
		ensure_light(st, float(st.data.light) * 1.4)

static func tick_bonfire_wall(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var thorns: float = float(st.data.get("thorns", 0.0))
	var pos: Vector2 = st.global_position
	var burning: Dictionary = state(st, "burning", {})
	for id in burning.keys():
		burning[id] -= delta
		var o = instance_from_id(id)
		if o == null or !alive(o) or burning[id] <= 0.0:
			burning.erase(id)
	# 2 Scorching flames: whoever is close burns, chewing or not; 4 Feeding flame: the wall mends on what it burns
	if StructureTiers.pace(st, "scorch", 0.5, delta):
		var near := StructureTiers.enemies(st, BONF_SCORCH_R)
		var n := 0
		for e in near:
			e.spell_damage(thorns * BONF_SCORCH, "fire", true)
			if is_instance_valid(e):
				burning[e.get_instance_id()] = 3.0
				if n < 2:
					WeaponFx.spawn(w, "burst", e.global_position, BONF_FIRE, {"radius": 6.0, "life": 0.2})
					if t >= 4:
						WeaponFx.spawn(w, "motes", e.global_position, BONF_CORE, {"radius": 6.0, "count": 2, "rise": 8.0, "life": 0.4})
					n += 1
		if t >= 4 and !near.is_empty():
			st.hp = minf(st.max_hp, st.hp + BONF_FEED * minf(float(near.size()), 4.0))
	if StructureTiers.pace(st, "marks", 0.2, delta):
		var marks := []
		for id in burning.keys():
			if marks.size() >= 8:
				break
			marks.append(instance_from_id(id).global_position - pos)
		st.vis["burning"] = marks
	# 3 Firebrand: a burning log flung at the nearest enemy it can see
	if t >= 3 and StructureTiers.ready(st, "brand", BONF_BRAND_T, delta):
		var target = StructureTiers.nearest(st, BONF_BRAND_R)
		if target != null:
			StructureTiers.reset(st, "brand")
			var at: Vector2 = target.global_position
			WeaponFx.spawn(w, "fall", at, BONF_FIRE, {"radius": 3.0, "height": 50.0, "rise": 20.0, "life": 0.3})
			WeaponUtil.ground_strike(st.get_tree(), w, at, 18.0, 0.3, thorns * BONF_BRAND, 100.0, BONF_FIRE, 0.0, [], "fire")
			later(st, 0.3, func():
				WeaponFx.spawn(w, "flash", at, BONF_FIRE, {"radius": 22.0, "life": 0.25})
				Sfx.play("big_hit"))
	# 5 Spreading blaze: a burning enemy sets one neighbour alight
	if t >= 5 and StructureTiers.pace(st, "spread", 1.0, delta):
		for id in burning.keys():
			var o = instance_from_id(id)
			if o == null or !alive(o):
				continue
			var best = null
			var bd := BONF_SPREAD_R
			for e in StructureTiers.enemies_at(st, o.global_position, BONF_SPREAD_R):
				if e == o or !alive(e) or burning.has(e.get_instance_id()):
					continue
				var d: float = e.global_position.distance_to(o.global_position)
				if d < bd:
					bd = d
					best = e
			if best != null:
				burning[best.get_instance_id()] = 3.0
				ignite(st.get_tree(), best, 3, thorns * 0.3)
				zap(w, o.global_position, best.global_position, BONF_FIRE, 2.0)
				WeaponFx.spawn(w, "burst", best.global_position, BONF_FIRE, {"radius": 8.0, "life": 0.2})
				StructureTiers.sfx(st, "whoosh", 1.0)
	# 6 Pyre: a firestorm round the wall every fifteen seconds (it waits for company)
	if t >= 6:
		if StructureTiers.ready(st, "pyre", BONF_PYRE_T, delta) and !StructureTiers.enemies(st, 120.0).is_empty():
			StructureTiers.reset(st, "pyre")
			WeaponFx.spawn(w, "flash", pos, BONF_WHITE.lerp(BONF_CORE, 0.4), {"radius": 80.0, "life": 0.4})
			for k in 3:
				WeaponFx.spawn(w, "pillar", pos + Vector2((k - 1) * 14.0, 0), BONF_FIRE, {"height": 80.0, "width": 24.0, "life": 0.6})
			WeaponFx.spawn(w, "ripple", pos, BONF_FIRE, {"radius": 80.0, "rings": 3, "life": 0.7})
			for k in 5:
				var a := k * TAU / 5.0 + 0.4
				var at2: Vector2 = pos + Vector2.from_angle(a) * (30.0 + 40.0 * SpellArt.jit(k, 3.0))
				WeaponUtil.ground_strike(st.get_tree(), w, at2, 22.0, 0.35, thorns * BONF_PYRE, 120.0, BONF_FIRE, 0.3, [], "fire")
			StructureTiers.sfx(st, "ultimate", 0.5)
			st.fx_pulse = 0.0
		st.charge = snappedf(StructureTiers.fill(st, "pyre", BONF_PYRE_T), 0.02)
	elif t >= 3:
		st.charge = snappedf(StructureTiers.fill(st, "brand", BONF_BRAND_T), 0.02)

# ================================================================ Spiked Sentry
const SSENT_IRON := Color(0.75, 0.75, 0.8)
const SSENT_RUST := Color(0.6, 0.3, 0.2)
const SSENT_CALTROP_R := 16.0
const SSENT_COLLAR_R := 30.0
const SSENT_COLLAR := 0.8
const SSENT_BARB := 0.3
const SSENT_FIELD_T := 6.0
const SSENT_FIELD := 3.0
const SSENT_SPOOL_SHOTS := 5
const SSENT_SPOOL_IDLE := 2.0

## Barbed bolts (tier 4): a bolt into an enemy that is already bleeding bites a quarter harder.
static func shot_spiked_sentry(st, target) -> float:
	if st.tier >= 4 and is_instance_valid(target) and state(st, "bleeding", {}).has(target.get_instance_id()):
		return 1.25
	return 1.0

static func on_shot_spiked_sentry(st, target) -> void:
	var t: int = st.tier
	if t < 2 or !is_instance_valid(target):
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var at: Vector2 = target.global_position
	# 2 Caltrop shots: a slow patch under the target (at most four at once)
	var patches: Array = state(st, "patches", [])
	var now := Time.get_ticks_msec() / 1000.0
	patches = patches.filter(func(x): return now - float(x) < 3.0)
	st._tdata["patches"] = patches
	WeaponFx.spawn(w, "burst", at, SSENT_IRON, {"radius": 8.0, "life": 0.2})
	WeaponFx.spawn(w, "motes", at, SSENT_IRON, {"radius": 6.0, "count": 3, "rise": 4.0, "life": 0.4})
	StructureTiers.sfx(st, "hit", 0.2)
	if patches.size() < 4:
		patches.append(now)
		WeaponUtil.patch(w, at, "slow", SSENT_CALTROP_R, Color(SSENT_IRON, 0.25), 3.0, 0.6)
	# 4 Barbed bolts: the hit bleeds and is pinned
	if t >= 4:
		var bleeding: Dictionary = state(st, "bleeding", {})
		bleeding[target.get_instance_id()] = 2.0
		WeaponUtil.bleed(st.get_tree(), target, 4, dmg * SSENT_BARB)
		StructureTiers.keep_slow(target, 0.5, 2.0)
		WeaponFx.spawn(w, "burst", at, SSENT_RUST, {"radius": 6.0, "life": 0.2})
		StructureTiers.sfx(st, "big_hit", 0.3)
	# 6 Gatling: every shot builds the spool; at full spool it fires three spikes and 50% faster
	if t >= 6:
		st._tdata["spool"] = minf(1.0, float(st._tdata.get("spool", 0.0)) + 1.0 / SSENT_SPOOL_SHOTS)
		st._tdata["idle"] = 0.0
		st.charge = snappedf(float(st._tdata["spool"]), 0.02)
		if float(st._tdata["spool"]) >= 1.0:
			var from := muzzle(st)
			var dir: Vector2 = (at - from).normalized()
			for k in 3:
				var d := dir.rotated((k - 1) * 0.12)
				WeaponProjectile.shoot(w, from, d, 320.0, dmg * 0.5, SSENT_IRON, 0.6, 0, 60.0)
				WeaponFx.spawn(w, "line", from, Color(0.95, 0.95, 1.0, 0.8), {"dir": d, "length": (at - from).length(), "width": 1.0, "life": 0.1})
			if st._shots % 3 == 0:
				WeaponFx.spawn(w, "ring", from, SSENT_IRON, {"radius": 14.0, "life": 0.15})

static func tick_spiked_sentry(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var dmg: float = float(st.data.damage)
	var pos: Vector2 = st.global_position
	# the barbs wear off an enemy; the places of the bleeding ones are published for the drips
	if t >= 4:
		var bleeding: Dictionary = state(st, "bleeding", {})
		for id in bleeding.keys():
			bleeding[id] -= delta
			var o = instance_from_id(id)
			if o == null or !alive(o) or bleeding[id] <= 0.0:
				bleeding.erase(id)
		if StructureTiers.pace(st, "marks", 0.2, delta):
			var marks := []
			for id in bleeding.keys():
				if marks.size() >= 8:
					break
				marks.append(instance_from_id(id).global_position - pos)
			st.vis["bleed_pos"] = marks
	# 3 Spike collar: whoever gets close is stabbed and shoved away
	if t >= 3 and StructureTiers.pace(st, "collar", 0.5, delta):
		var close := StructureTiers.enemies(st, SSENT_COLLAR_R)
		var n := 0
		for e in close:
			var dir: Vector2 = (e.global_position - pos).normalized()
			e.spell_damage(dmg * SSENT_COLLAR, "pierce", true)
			if is_instance_valid(e) and e.has_method("push"):
				e.push(dir * 100.0, 0.12)
			if n < 3 and is_instance_valid(e):
				WeaponFx.spawn(w, "burst", e.global_position, SSENT_IRON, {"radius": 8.0, "life": 0.2})
				n += 1
		if !close.is_empty():
			WeaponFx.spawn(w, "ring", pos, SSENT_IRON, {"radius": SSENT_COLLAR_R, "life": 0.3})
	# 5 Spike field: three spikes erupt under the densest group
	if t >= 5:
		if StructureTiers.ready(st, "field", SSENT_FIELD_T, delta):
			var target = StructureTiers.densest(st, float(st.data.range))
			if target != null and Game.defence_sees(target, pos):
				StructureTiers.reset(st, "field")
				var c: Vector2 = target.global_position
				for k in 3:
					var at: Vector2 = c + Vector2.from_angle(k * TAU / 3.0 + 0.5) * 12.0
					var delay := 0.3 + 0.15 * k
					WeaponUtil.ground_strike(st.get_tree(), w, at, 14.0, delay, dmg * SSENT_FIELD, 100.0, SSENT_IRON, 0.3, [], "")
					later(st, delay, func(): WeaponFx.spawn(w, "shards", at, SSENT_IRON, {"radius": 18.0, "count": 6, "life": 0.35}))
				StructureTiers.sfx(st, "thump", 0.5)
		if t < 6:
			st.charge = snappedf(StructureTiers.fill(st, "field", SSENT_FIELD_T), 0.02)
	# 6 Gatling: the spool runs down two seconds after the last target
	if t >= 6:
		var idle: float = float(st._tdata.get("idle", 0.0)) + delta
		st._tdata["idle"] = idle
		if idle > SSENT_SPOOL_IDLE and float(st._tdata.get("spool", 0.0)) > 0.0:
			st._tdata["spool"] = maxf(0.0, float(st._tdata["spool"]) - delta * 0.5)
			st.charge = snappedf(float(st._tdata["spool"]), 0.02)

# ================================================================ Spiked Wall
const SWALL_IRON := Color(0.8, 0.82, 0.88)
const SWALL_RUST := Color(0.6, 0.25, 0.2)
const SWALL_GOLD := Color(1.0, 0.85, 0.4)
const SWALL_STRIP := 0.4
const SWALL_STRIP_SLOW := 0.7
const SWALL_STRIP_R := 20.0
const SWALL_THRUST_T := 2.0
const SWALL_THRUST_R := 24.0
const SWALL_THRUST := 2.0
const SWALL_IMPALE := 0.3
const SWALL_VOLLEY_T := 3.0
const SWALL_VOLLEY_R := 110.0
const SWALL_VOLLEY := 0.8

static func base_thorns(st) -> float:
	if !st._tdata.has("base_thorns"):
		st._tdata["base_thorns"] = float(st.data.get("thorns", 0.0))
	return float(st._tdata["base_thorns"])

static func on_gnaw_spiked_wall(st, e) -> void:
	if st.tier < 4 or !is_instance_valid(e) or randf() >= SWALL_IMPALE:
		return
	if float(e.slow_mult) <= 0.0 and float(e.slow_time) > 0.0:
		return
	var w := world_of(st)
	var at: Vector2 = e.global_position
	WeaponFx.spawn(w, "pillar", at, SWALL_IRON, {"height": 24.0, "width": 6.0, "life": 0.35})
	WeaponFx.spawn(w, "shards", at, SWALL_IRON, {"radius": 14.0, "count": 4, "life": 0.3})
	if !StructureTiers._boss(e) and e.has_method("apply_slow"):
		e.apply_slow(0.0, 1.0)
	WeaponUtil.bleed(st.get_tree(), e, 4, base_thorns(st) * 0.3)
	StructureTiers.sfx(st, "big_hit", 0.3)

static func tick_spiked_wall(st, delta: float) -> void:
	var t: int = st.tier
	if t < 2:
		return
	var w := world_of(st)
	var thorns: float = float(st.data.get("thorns", 0.0))
	var pos: Vector2 = st.global_position
	var r: float = st.radius
	# 2 Spike strip: spikes lie in front of the wall; whoever steps there is stabbed and slowed
	if StructureTiers.pace(st, "strip", 0.5, delta):
		var n := 0
		for e in StructureTiers.enemies(st, r + SWALL_STRIP_R):
			e.spell_damage(thorns * SWALL_STRIP, "pierce", true)
			if is_instance_valid(e):
				StructureTiers.keep_slow(e, SWALL_STRIP_SLOW, 0.6)
				if n < 2:
					WeaponFx.spawn(w, "burst", e.global_position, SWALL_IRON, {"radius": 6.0, "life": 0.2})
					n += 1
	# 3 Spear thrust: spears slide out of the wall at what is in reach (it waits for a victim)
	if t >= 3 and StructureTiers.ready(st, "thrust", SWALL_THRUST_T, delta):
		var reach := StructureTiers.enemies(st, r + SWALL_THRUST_R)
		if !reach.is_empty():
			StructureTiers.reset(st, "thrust")
			var best = reach[0]
			for e in reach:
				if e.global_position.distance_to(pos) < best.global_position.distance_to(pos):
					best = e
			var dir: Vector2 = (best.global_position - pos).normalized()
			st.aim = dir
			for k in 3:
				WeaponFx.spawn(w, "line", pos + dir.orthogonal() * (k - 1) * 6.0, SWALL_IRON, {"dir": dir, "length": 24.0, "width": 3.0, "life": 0.2})
			for e in reach:
				e.spell_damage(thorns * SWALL_THRUST, "pierce", true)
				if is_instance_valid(e):
					if e.has_method("push"):
						e.push((e.global_position - pos).normalized() * 120.0, 0.12)
					WeaponFx.spawn(w, "burst", e.global_position, SWALL_IRON, {"radius": 8.0, "life": 0.2})
			st.fx_pulse = 0.0
			StructureTiers.sfx(st, "hit", 0.3)
	# 5 Spike volley: five spikes in a fan at the nearest enemy it can see
	if t >= 5 and StructureTiers.ready(st, "volley", SWALL_VOLLEY_T, delta):
		var target = StructureTiers.nearest(st, SWALL_VOLLEY_R)
		if target != null:
			StructureTiers.reset(st, "volley")
			var from := pos + Vector2(0, -r * 0.8)
			var dir2: Vector2 = (target.global_position - from).normalized()
			for k in 5:
				WeaponProjectile.shoot(w, from, dir2.rotated((k - 2) * 0.15), 260.0, thorns * SWALL_VOLLEY, SWALL_IRON, 0.6, 1, 60.0)
			StructureTiers.sfx(st, "whoosh", 0.3)
	# 6 Porcupine: below half health the thorns double; spikes fly in a ring at 75%, 50% and 25%
	if t >= 6:
		var base := base_thorns(st)
		var porc: bool = bool(st._tdata.get("porc", false))
		if !porc and st.hp < 0.5 * st.max_hp:
			st._tdata["porc"] = true
			st.data.thorns = base * 2.0
		elif porc and st.hp >= 0.6 * st.max_hp:
			st._tdata["porc"] = false
			st.data.thorns = base
		for key in [["p75", 0.75], ["p50", 0.5], ["p25", 0.25]]:
			if StructureTiers.threshold(st, key[0], key[1]):
				StructureTiers.radial(st, 16, float(st.data.get("thorns", base)), SWALL_IRON)
				WeaponFx.spawn(w, "shards", pos, SWALL_IRON, {"radius": 60.0, "count": 16, "life": 0.5})
				WeaponFx.spawn(w, "ripple", pos, SWALL_IRON, {"radius": 60.0, "rings": 2, "life": 0.5})
				Sfx.play("big_hit")

extends RefCounted
class_name SpellTiers
## What a spell card does at each tier (2 to 6), on top of the stacking "added" modifiers (Game.SPELL_TWISTS, Spell._apply_add).
## Spell calls the hooks below; each card is a few functions named <hook>_<card id>. Everything here runs on the host
## (a puppet spell never reaches it); visuals go through WeaponFx.spawn and Sfx.play, which are mirrored to clients.
## Designs: docs/card_tiers/<card id>.md

## A slow that does not undo a stronger, longer one already on the enemy (a freeze from a tier's ability survives the ring's steady chill).
static func keep_slow(e, mult: float, secs: float) -> void:
	if e.get("slow_time") != null and e.slow_time > secs + 0.05 and e.slow_mult < mult:
		return
	e.apply_slow(mult, secs)

# ---- Fireball
const FIREBALL_PUSH := 150.0            # tier 2: the blast shoves enemies away from the centre
const FIREBALL_CORE := 0.4              # tier 3: this much of the radius, from the centre, takes double damage
const FIREBALL_POP := 0.45              # tier 4: an enemy killed by the blast pops for this much of the damage
const FIREBALL_POP_RANGE := 30.0
const FIREBALL_PULSE := 0.4             # tier 5: three pulses of this much of the damage, 0.4 s apart
const FIREBALL_FINALE_KNOCK := 220.0    # tier 6: the finale shockwave
const FIREBALL_METEORS := 6
const HOT := Color(1.0, 0.8, 0.3)

## A named repeating clock on the spell: true once every `interval` seconds.
static func pace(s, key: String, interval: float, delta: float) -> bool:
	var t: float = float(s._clk.get(key, 0.0)) + delta
	if t >= interval:
		s._clk[key] = t - interval
		return true
	s._clk[key] = t
	return false

## True while a spell that has run its time should stay a little longer (the plague cloud waits for its plagued to fall).
static func keep_alive(s) -> bool:
	if String(s.data.get("id", "")) == "poison_cloud" and tier_of(s) >= 6 and s._finale_done and !s._plagued.is_empty():
		return s.age - s.flight < s.effect_time + 7.0
	return false

## One-time landing effects (a ring, motes, a sound) the first tick after landing.
static func first_tick(s) -> bool:
	if s._landed_fx:
		return false
	s._landed_fx = true
	return true

static func tier_of(s) -> int:
	return clampi(int(s.data.get("tier", 1)), 1, 6)

static func is_copy(s) -> bool:
	return bool(s.data.get("copy", false))

## How long the landed spell stays (a tier 5 fireball keeps burning on the spot).
static func effect_time(s, base: float) -> float:
	match String(s.data.get("id", "")):
		"fireball":
			return 1.6 if tier_of(s) >= 5 else base
		"gold_magnet":
			return MAGNET_STORM_TIME if tier_of(s) >= 5 else base
		"crystal_spikes":
			return 4.0 if tier_of(s) >= 3 else base
		"meteor_shower":
			return float(s.data.get("duration", 3.5)) + 3.0 if tier_of(s) >= 2 else base
		"charm":
			var t := tier_of(s)
			if t >= 5:
				return maxf(6.0, float(s.data.get("duration", 6.0)))
			if t >= 3:
				return maxf(3.0, float(s.data.get("duration", 6.0)) * 0.5)
			if t >= 2:
				return 1.0
	return base

## Runs once when the spell lands, right after its additions: the extra effects and sounds of the tier.
static func on_land(s) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			land_fireball(s, tier_of(s))
		"frost_ring":
			land_frost_ring(s, tier_of(s))

## Runs when the spell leaves the world (ended or freed): give back what it was holding.
static func on_end(s) -> void:
	if String(s.data.get("id", "")) == "stasis":
		for sh in s.get_tree().get_nodes_in_group("enemy_shot"):
			if is_instance_valid(sh) and sh.has_meta("held_by") and sh.get_meta("held_by") == s.get_instance_id():
				sh.vel = sh.get_meta("held_vel")
				sh.remove_meta("held_by")
				sh.remove_meta("held_vel")

## Runs every physics frame once landed.
static func tick(s, delta: float) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			tick_fireball(s, tier_of(s), delta)
		"frost_ring":
			tick_frost_ring(s, tier_of(s), delta)
		"flare":
			tick_flare(s, tier_of(s), delta)
		"rejuvenation":
			tick_rejuvenation(s, tier_of(s), delta)
		"gold_magnet":
			tick_gold_magnet(s, tier_of(s), delta)
		"aegis":
			tick_aegis(s, tier_of(s), delta)
		"charm":
			tick_charm(s, tier_of(s), delta)
		"sandstorm":
			tick_sandstorm(s, tier_of(s), delta)
		"blizzard":
			tick_blizzard(s, tier_of(s), delta)
		"lava_pool":
			tick_lava_pool(s, tier_of(s), delta)
		"poison_cloud":
			tick_poison_cloud(s, tier_of(s), delta)
		"crystal_spikes":
			tick_crystal_spikes(s, tier_of(s), delta)
		"meteor_shower":
			tick_meteor_shower(s, tier_of(s), delta)
		"stasis":
			tick_stasis(s, tier_of(s), delta)

# ---------------------------------------------------------------- Fireball

## [radius multiplier, seconds] of the light the blast leaves.
static func fireball_light(s) -> Array:
	match tier_of(s) if String(s.data.get("id", "")) == "fireball" else 1:
		4: return [2.2, 3.0]
		5: return [2.4, 1.8]
		6: return [3.0, 4.0]
	return [1.6, 2.0]

static func land_fireball(s, tier: int) -> void:
	var w: Node = s.get_parent()
	var pos: Vector2 = s.position
	var r: float = s.radius
	var col: Color = s.data.get("color", Color(1.0, 0.45, 0.1))
	if tier >= 2:
		WeaponFx.spawn(w, "flash", pos, HOT, {"radius": r, "life": 0.25})
		WeaponFx.spawn(w, "shards", pos, HOT, {"radius": r * 1.1, "count": 6, "life": 0.35})
		Sfx.play("big_hit")
	if tier >= 3:
		WeaponFx.spawn(w, "ring", pos, Color.WHITE, {"radius": r * FIREBALL_CORE, "life": 0.25})
		WeaponFx.spawn(w, "burst", pos, Color.WHITE, {"radius": r * FIREBALL_CORE, "life": 0.25})
	if tier >= 6 and !is_copy(s):
		WeaponFx.spawn(w, "flash", pos, col, {"radius": r * 1.6, "life": 0.4})
		WeaponFx.spawn(w, "ripple", pos, HOT, {"radius": r * 2.0, "rings": 3, "life": 0.7})
		Sfx.play("ultimate")

## The blast itself: damage (double in the core from tier 3), the shove (tier 2), and the kill pops (tier 4). Tier 6 follows with its finale.
static func blast_fireball(s) -> void:
	var tier := tier_of(s) if String(s.data.get("id", "")) == "fireball" else 1
	var c: Vector2 = s.global_position
	var dmg: float = s.data.damage
	var el: String = s.data.get("element", "")
	var pops := []
	for e in s._in_radius("enemy"):
		var ep: Vector2 = e.global_position            # (taken before the hit: a kill frees it)
		var d := ep.distance_to(c)
		var mult := 2.0 if tier >= 3 and d <= s.radius * FIREBALL_CORE else 1.0
		e.spell_damage(dmg * mult, el, true)
		var dead := _dead(e)
		if tier >= 2 and !dead and e.has_method("push"):
			var away := ep - c
			e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * FIREBALL_PUSH, 0.18)
		if tier >= 4 and dead:
			pops.append(ep)
	for ep in pops:                                    # (only the blast's own kills pop; a pop's kills do not)
		_pop(s, ep, dmg * FIREBALL_POP)
	if tier >= 6 and !is_copy(s):
		_finale_fireball(s, dmg)

static func _dead(e) -> bool:
	return !is_instance_valid(e) or e.get("dead") == true or (e.get("health") != null and e.health <= 0.0)

## Tier 4: a killed enemy bursts into flame and singes whatever stands next to it.
static func _pop(s, at: Vector2, amount: float) -> void:
	var w: Node = s.get_parent()
	WeaponFx.spawn(w, "burst", at, HOT, {"radius": 22.0, "life": 0.3})
	WeaponFx.spawn(w, "ring", at, HOT, {"radius": FIREBALL_POP_RANGE, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(s.get_tree(), at, FIREBALL_POP_RANGE):
		e.spell_damage(amount, s.data.get("element", ""), true)

## Tier 5: three pulses from the pillar of fire. Each hurts, and holds whoever it hits for a moment.
static func tick_fireball(s, tier: int, _delta: float) -> void:
	if tier < 5:
		return
	var since: float = s.age - s.flight
	while s._pulses < 3 and since >= FIREBALL_PULSE * (s._pulses + 1):
		s._pulses += 1
		var w: Node = s.get_parent()
		var r: float = s.radius * 0.8
		for e in WeaponUtil.enemies_in_circle(s.get_tree(), s.global_position, r):
			e.spell_damage(s.data.damage * FIREBALL_PULSE, s.data.get("element", ""), true)
			if is_instance_valid(e) and e.has_method("apply_slow"):
				e.apply_slow(0.3, 0.25)
		WeaponFx.spawn(w, "pillar", s.position, HOT, {"height": 60.0, "width": s.radius * 0.5, "life": 0.4})
		WeaponFx.spawn(w, "ring", s.position, HOT, {"radius": r, "life": 0.3})
		Sfx.play("thump")

## Tier 6: a shockwave, then a ring of small meteors. (A twin's copy does the plain blast.)
static func _finale_fireball(s, dmg: float) -> void:
	var tree: SceneTree = s.get_tree()
	var c: Vector2 = s.global_position
	for e in WeaponUtil.enemies_in_circle(tree, c, s.radius * 2.0):
		var away: Vector2 = e.global_position - c
		e.spell_damage(dmg * 0.35, s.data.get("element", ""), true)
		if is_instance_valid(e) and e.has_method("push"):
			e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * FIREBALL_FINALE_KNOCK, 0.25)
	WeaponUtil.rain(tree, s.get_parent(), s.position, s.radius * 1.3, FIREBALL_METEORS, 1.0, dmg * 0.4, 16.0, HOT)

# ---------------------------------------------------------------- Frost Ring

const FROST_BITE := [0.0, 0.0, 1.5, 2.5, 4.0, 6.0]       # ice damage per second inside the ring, by tier - 1
const ICE := Color(0.55, 0.85, 1.0)
const FROST := Color(0.9, 0.97, 1.0)

## Tier 2: whatever is inside when the ring lands is frozen solid for a moment, and the landing is a burst of ice.
static func land_frost_ring(s, tier: int) -> void:
	if tier < 2:
		return
	var w: Node = s.get_parent()
	WeaponFx.spawn(w, "ring", s.position, FROST, {"radius": s.radius, "life": 0.3})
	WeaponFx.spawn(w, "shards", s.position, FROST, {"radius": s.radius, "count": 8, "life": 0.4})
	Sfx.play("whoosh")
	for e in s._in_radius("enemy"):
		if e.has_method("apply_slow"):
			e.apply_slow(0.0, 0.6)

static func tick_frost_ring(s, tier: int, delta: float) -> void:
	if tier < 3:
		return
	var bite: float = FROST_BITE[tier - 1]
	var w: Node = s.get_parent()
	var inside: Array = s._in_radius("enemy")
	s._bite_t += delta
	if s._bite_t >= 0.5:                                 # frostbite: ice damage over time to everything inside
		s._bite_t = 0.0
		for e in inside:
			e.spell_damage(bite * 0.5, "ice", true)
			if inside.size() < 6 and is_instance_valid(e):
				WeaponFx.spawn(w, "burst", e.global_position, FROST, {"radius": 6.0, "life": 0.15})
	s._snow_t += delta
	if s._snow_t >= 1.0:                                 # a handful of snow
		s._snow_t = 0.0
		WeaponFx.spawn(w, "motes", s.position, Color.WHITE, {"radius": s.radius * 0.8, "count": 6, "rise": 22.0, "life": 0.9})
	if tier >= 4:                                        # icicle fall: up to three drop on different enemies every second
		s._ice_t += delta
		if s._ice_t >= 1.0:
			s._ice_t = 0.0
			var pool := inside.duplicate()
			pool.shuffle()
			for i in mini(3, pool.size()):
				if is_instance_valid(pool[i]):
					WeaponUtil.ground_strike(s.get_tree(), w, pool[i].global_position, 12.0, 0.3, bite * 1.5, 40.0, ICE, 0.25, [], "ice")
	if tier >= 5:
		_shatter(s, bite, inside)
	if tier >= 6 and !s._finale_done and !is_copy(s) and s.age - s.flight >= s.effect_time - 0.05:
		s._finale_done = true
		_finale_frost_ring(s, bite, inside)

## Tier 5: an enemy that dies inside the ring bursts into a frost nova that hurts and freezes its neighbours.
static func _shatter(s, bite: float, inside: Array) -> void:
	s._nova_clock += get_dt(s)
	if s._nova_clock >= 1.0:
		s._nova_clock = 0.0
		s._novas = 0
	var here := {}
	for e in inside:
		here[e.get_instance_id()] = true
		s._seen[e.get_instance_id()] = e.global_position
	for id in s._seen.keys():
		var o = instance_from_id(id)
		if o != null and !_dead(o):
			if !here.has(id):
				s._seen.erase(id)                         # left the ring alive
			continue
		var at: Vector2 = s._seen[id]
		s._seen.erase(id)
		if s._novas >= 4:
			continue
		s._novas += 1
		var w: Node = s.get_parent()
		WeaponFx.spawn(w, "ripple", at, FROST, {"radius": 40.0, "rings": 2, "life": 0.4})
		WeaponFx.spawn(w, "shards", at, FROST, {"radius": 36.0, "count": 8, "life": 0.35})
		Sfx.play("big_hit")
		for e in WeaponUtil.enemies_in_circle(s.get_tree(), at, 36.0):
			e.spell_damage(bite * 3.0, "ice", true)
			if _dead(e):
				s._seen.erase(e.get_instance_id())        # (a nova's kills do not make novas)
			elif e.has_method("apply_slow"):
				e.apply_slow(0.0, 0.5)

static func get_dt(s) -> float:
	return s.get_physics_process_delta_time()

## Tier 6: the ring ends in absolute zero.
static func _finale_frost_ring(s, bite: float, inside: Array) -> void:
	var w: Node = s.get_parent()
	WeaponFx.spawn(w, "flash", s.position, FROST, {"radius": s.radius, "life": 0.4})
	WeaponFx.spawn(w, "ripple", s.position, ICE, {"radius": s.radius * 1.25, "rings": 3, "life": 0.7})
	WeaponFx.spawn(w, "shards", s.position, FROST, {"radius": s.radius * 1.2, "count": 18, "life": 0.5})
	Sfx.play("ultimate")
	for e in inside:
		if !is_instance_valid(e):
			continue
		if e.has_method("apply_slow"):
			e.apply_slow(0.0, 1.5)
		WeaponUtil.expose(e, 2.5)
		e.spell_damage(bite * 4.0, "ice", true)

# ---------------------------------------------------------------- Flare

const FLARE_RAY_SPEED := 1.3
const FLARE_RAY_ARC := 0.14
const FLARE_PULSE := 3.0
const FLARE_SUN_SPEED := 1.8
const FLARE_SUN_INTERVAL := 0.8
const SUN := Color(1.0, 0.9, 0.5)
const AMBER := Color(1.0, 0.65, 0.2)

## The sweeping beam's angle, from the time since landing (the drawing and the damage use the same one).
static func ray_angle(since: float) -> float:
	return since * FLARE_RAY_SPEED

## Where tier 5's orbiting sun `i` (0 or 1) is.
static func sun_pos(s, i: int) -> Vector2:
	return s.global_position + Vector2.from_angle(s.age * FLARE_SUN_SPEED + i * PI) * s.radius * 0.6

## Night light: a higher flare shines a little wider and (tier 6) brighter.
static func flare_light(s) -> Array:
	var t := tier_of(s)
	match String(s.data.get("id", "")):
		"flare":
			return [1.15 if t >= 4 else 1.0, 0.8 if t >= 6 else 0.65]
		"lava_pool":
			return [1.2 if t >= 4 else 1.0, 0.85 if t >= 6 else 0.65]
	return [1.0, 0.65]

static func tick_flare(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var inside: Array = s._in_radius("enemy")
	if !s._landed_fx:                                                # (once, the first frame after landing)
		s._landed_fx = true
		WeaponFx.spawn(w, "star", s.position, SUN, {"radius": r * 0.5, "count": 4, "spin": 1.5, "life": 0.4})
		Sfx.play("cast")
	for e in inside:                                                 # dazzle: 20% slower
		if e.has_method("apply_slow"):
			e.apply_slow(0.8, 0.3)
	if tier >= 3:                                                    # searing rays: a beam pair sweeps round
		var a := ray_angle(since)
		for e in inside:
			var rel: Vector2 = e.global_position - c
			if rel.length() < 3.0:
				continue
			var ang := rel.angle()
			if absf(angle_difference(ang, a)) <= FLARE_RAY_ARC or absf(angle_difference(ang, a + PI)) <= FLARE_RAY_ARC:
				var id: int = e.get_instance_id()
				if s.age - float(s._ray_hit.get(id, -9.0)) >= 0.4:
					s._ray_hit[id] = s.age
					WeaponFx.spawn(w, "burst", e.global_position, AMBER, {"radius": 8.0, "life": 0.2})
					e.spell_damage(dps * 2.0, "fire", true)
	if tier >= 4 and since >= 1.0 + s._pulse_n * FLARE_PULSE:         # solar pulse every 3 s, the first a second in
		s._pulse_n += 1
		WeaponFx.spawn(w, "ripple", s.position, AMBER, {"radius": r, "rings": 2, "life": 0.6})
		Sfx.play("whoosh")
		for e in inside:
			if !is_instance_valid(e):
				continue
			var away: Vector2 = e.global_position - c
			e.spell_damage(dps * 1.5, "fire", true)
			if is_instance_valid(e) and e.has_method("push"):
				e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 90.0, 0.15)
	if tier >= 5:                                                    # two suns circle and shoot
		for i in 2:
			s._sun_t[i] += delta
			if s._sun_t[i] >= FLARE_SUN_INTERVAL:
				var from := sun_pos(s, i)
				var best = null
				for e in inside:
					if is_instance_valid(e) and (best == null or e.global_position.distance_to(from) < best.global_position.distance_to(from)):
						best = e
				if best != null:
					s._sun_t[i] = 0.0
					var to: Vector2 = best.global_position - from
					WeaponFx.spawn(w, "line", from, AMBER, {"dir": to.normalized(), "length": to.length(), "width": 2.5, "life": 0.12})
					WeaponProjectile.shoot(w, from, to, 260.0, dps * 1.6, AMBER, minf(1.2, to.length() / 260.0 + 0.2), 0, 40.0)
					WeaponFx.spawn(w, "burst", best.global_position, AMBER, {"radius": 8.0, "life": 0.2})
	if tier >= 6:
		for p in s._in_radius("player"):                             # daybreak: its light mends
			if p.has_method("heal"):
				p.heal(dps * 0.5 * delta)
		if !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
			s._finale_done = true
			WeaponFx.spawn(w, "flash", s.position, Color(1.0, 0.85, 0.3), {"radius": r * 1.4, "life": 0.4})
			WeaponFx.spawn(w, "ripple", s.position, Color(1.0, 0.85, 0.3), {"radius": r * 1.8, "rings": 3, "life": 0.7})
			WeaponFx.spawn(w, "star", s.position, SUN, {"radius": r * 1.2, "count": 8, "spin": 1.0, "life": 0.5})
			Sfx.play("ultimate")
			LightSource.spawn(w, s.position, r * 2.0, 6.0, SUN)
			for e in WeaponUtil.enemies_in_circle(s.get_tree(), c, r * 1.4):
				e.spell_damage(dps * 6.0, "fire", true)
			for e in WeaponUtil.enemies_in_circle(s.get_tree(), c, r * 2.0):
				Game.light_up(e, 6.0)

# ---------------------------------------------------------------- Rejuvenation

const REJUV_GUARD := 0.5
const REJUV_STRUCT := 0.25
const REJUV_WARD := 1.0
const REJUV_WARD_CD := 6.0
const REJUV_VINE := 0.15
const REJUV_WAVE := 2.0
const REJUV_FINALE := 3.0
const LEAF := Color(0.4, 1.0, 0.5)
const LIGHT_GREEN := Color(0.7, 1.0, 0.7)

static func tick_rejuvenation(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var hps: float = s.data.heal_per_sec
	var w: Node = s.get_parent()
	var c: Vector2 = s.global_position
	var r: float = s.radius
	if !s._landed_fx:
		s._landed_fx = true
		WeaponFx.spawn(w, "motes", s.position, LEAF, {"radius": r, "count": 10, "rise": 26.0, "life": 0.9})
		WeaponFx.spawn(w, "ring", s.position, LEAF, {"radius": r, "life": 0.3})
		Sfx.play("cast")
	for g in s.get_tree().get_nodes_in_group("guard"):               # shared mending: guards are healed too
		if is_instance_valid(g) and g.global_position.distance_to(c) <= r:
			g.hp = minf(g.max_hp, g.hp + hps * REJUV_GUARD * delta)
	if tier >= 3:                                                    # mending roots: buildings are repaired
		for st in s.get_tree().get_nodes_in_group("structure"):
			if is_instance_valid(st) and st.global_position.distance_to(c) <= r and st.hp < st.max_hp:
				st.hp = minf(st.max_hp, st.hp + hps * REJUV_STRUCT * delta)
				var id: int = st.get_instance_id()
				if since - float(s._house.get(id, -9.0)) >= 1.5:
					s._house[id] = since
					WeaponFx.spawn(w, "motes", st.global_position, LEAF, {"radius": 10.0, "count": 4, "rise": 14.0, "life": 0.6})
	var players: Array = s._in_radius("player")
	if tier >= 4:                                                    # sprout ward: a player who steps in is shielded for a moment
		for p in players:
			var pid: int = p.get_instance_id()
			if !s._warded.has(pid) or since - float(s._warded[pid]) > REJUV_WARD_CD:
				s._warded[pid] = since
				p.shield_time = maxf(p.shield_time, REJUV_WARD)
				WeaponFx.spawn(w, "star", p.global_position, LIGHT_GREEN, {"radius": 16.0, "count": 6, "spin": 1.5, "life": 0.4})
				Sfx.play("unlock")
	if tier >= 5:                                                    # entangling vines
		var foes: Array = s._in_radius("enemy")
		for e in foes:
			if e.has_method("apply_slow"):
				e.apply_slow(0.6, 0.3)
		s._vine_t += delta
		if s._vine_t >= 0.5:
			s._vine_t = 0.0
			for e in foes:
				if is_instance_valid(e):
					e.spell_damage(hps * REJUV_VINE, "", true)
					if foes.size() < 5 and is_instance_valid(e):
						WeaponFx.spawn(w, "burst", e.global_position, LEAF, {"radius": 8.0, "life": 0.2})
	if tier >= 6:                                                    # tree of life: a heal wave every two seconds
		s._wave_t += delta
		if s._wave_t >= REJUV_WAVE:
			s._wave_t = 0.0
			WeaponFx.spawn(w, "ripple", s.position, LIGHT_GREEN, {"radius": r, "rings": 2, "life": 0.6})
			WeaponFx.spawn(w, "motes", s.position, LEAF, {"radius": r, "count": 12, "rise": 30.0, "life": 0.9})
			for p in players:
				p.heal(hps * 1.0)
			for g in s.get_tree().get_nodes_in_group("guard"):
				if is_instance_valid(g) and g.global_position.distance_to(c) <= r:
					g.hp = minf(g.max_hp, g.hp + hps * 1.0)
		if !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
			s._finale_done = true
			WeaponFx.spawn(w, "star", s.position, Color(1.0, 0.85, 0.3), {"radius": r, "count": 8, "spin": 1.0, "life": 0.5})
			WeaponFx.spawn(w, "flash", s.position, LIGHT_GREEN, {"radius": r * 0.7, "life": 0.4})
			Sfx.play("ultimate")
			for p in players:
				p.heal(hps * REJUV_FINALE)
				p.shield_time = maxf(p.shield_time, 2.0)

# ---------------------------------------------------------------- Gold Magnet

const MAGNET_REACH := 1.6
const MAGNET_LUCK := 0.25
const MAGNET_TRIBUTE_PER := 5
const MAGNET_TRIBUTE_MAX := 4
const MAGNET_STORM_TIME := 2.5
const COIN_DMG := [0.0, 0.0, 0.0, 0.0, 2.5, 4.0]
const GOLD := Color(1.0, 0.85, 0.25)

## Gather what is in reach into the keep's pool: coins (tier 1), more of them in range (2), loose resources (3), a lucky double (4),
## coins hurled at the nearest enemy (5). Returns how many coins were taken.
static func magnet_sweep(s, tier: int, reach: float) -> int:
	var c: Vector2 = s.global_position
	var w: Node = s.get_parent()
	var taken := 0
	var lucky := false
	var hurled := false
	for g in s.get_tree().get_nodes_in_group("gold"):
		if !is_instance_valid(g) or g.is_queued_for_deletion() or g.global_position.distance_to(c) > reach:
			continue
		var at: Vector2 = g.global_position
		g.collect_to_pool()
		taken += 1
		s._coins += 1
		if tier >= 2:
			var to: Vector2 = Game.crystal_position() - at
			WeaponFx.spawn(w, "line", at, GOLD, {"dir": to.normalized(), "length": 30.0, "width": 2.0, "life": 0.25})
		if tier >= 4 and !is_copy(s) and randf() < MAGNET_LUCK:
			Game.add_resource("gold", 1)
			lucky = true
			WeaponFx.spawn(w, "star", at, GOLD, {"radius": 10.0, "count": 4, "spin": 1.0, "life": 0.3})
		if tier >= 5 and COIN_DMG[tier - 1] > 0.0:
			var best = null
			for e in s.get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and e.global_position.distance_to(at) <= 160.0 and (best == null or e.global_position.distance_to(at) < best.global_position.distance_to(at)):
					best = e
			if best != null:
				var dir: Vector2 = best.global_position - at
				WeaponProjectile.shoot(w, at, dir, 220.0, COIN_DMG[tier - 1], GOLD, minf(1.2, dir.length() / 220.0 + 0.1), 0, 30.0)
				WeaponFx.spawn(w, "burst", best.global_position, GOLD, {"radius": 8.0, "life": 0.2})
				hurled = true
	if tier >= 3:                                                    # haul: loose resources come too (never weapons)
		for n in s.get_tree().get_nodes_in_group("pickup"):
			if !is_instance_valid(n) or n.is_queued_for_deletion() or n.get("item_info") == null or n.global_position.distance_to(c) > reach:
				continue
			if str(n.item_info.items[n.item_type].get("type", "")) == "resource":
				WeaponFx.spawn(w, "motes", n.global_position, GOLD, {"radius": 8.0, "count": 4, "rise": 16.0, "life": 0.5})
				Game.add_resource(n.item_type, 1)
				n.queue_free()
				taken += 1
	if taken > 0:
		Sfx.play("coin")
	if hurled:
		Sfx.play("whoosh")
	return taken

## Tier 5: the spell stays and keeps sweeping, so coins that drop inside it are taken; tier 6 ends with a tribute.
static func tick_gold_magnet(s, tier: int, delta: float) -> void:
	if tier < 5:
		return
	var since: float = s.age - s.flight
	s._sweep_t += delta
	if s._sweep_t >= 0.2:
		s._sweep_t = 0.0
		magnet_sweep(s, tier, s.radius)
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
		s._finale_done = true
		var w: Node = s.get_parent()
		magnet_sweep(s, tier, s.radius * 2.2)
		WeaponFx.spawn(w, "flash", s.position, GOLD, {"radius": s.radius * 1.4, "life": 0.4})
		WeaponFx.spawn(w, "ripple", s.position, GOLD, {"radius": s.radius * 2.2, "rings": 3, "life": 0.7})
		WeaponFx.spawn(w, "motes", s.position, GOLD, {"radius": s.radius, "count": 16, "rise": 40.0, "life": 0.9})
		Sfx.play("ultimate")
		Game.add_resource("gold", mini(MAGNET_TRIBUTE_MAX, s._coins / MAGNET_TRIBUTE_PER))

# ---------------------------------------------------------------- Aegis Ward

const AEGIS_PULSE := [0.0, 0.0, 0.0, 3.0, 5.0, 8.0]
const AEGIS_REFLECT := 1.0
const AEGIS_SANCTUARY := 4.0
const WARD := Color(0.65, 0.75, 1.0)
const AEGIS_GOLD := Color(1.0, 0.88, 0.45)

static func tick_aegis(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var w: Node = s.get_parent()
	s._sfx_t -= delta
	s._repel_t += delta
	var near: Array = WeaponUtil.enemies_in_circle(s.get_tree(), c, r + 8.0)
	if s._repel_t >= 0.2:                                            # repel: the outer band shoves enemies away from the people inside
		s._repel_t = 0.0
		var pushed := false
		for e in near:
			var rel: Vector2 = e.global_position - c
			if rel.length() >= r * 0.8 and e.has_method("push"):
				e.push((rel.normalized() if rel.length() > 0.5 else Vector2.RIGHT) * 70.0, 0.15)
				WeaponFx.spawn(w, "burst", s.position + rel.normalized() * r, WARD, {"radius": 8.0, "life": 0.2})
				pushed = true
		if pushed and s._sfx_t <= 0.0:
			s._sfx_t = 0.5
			Sfx.play("whoosh")
	if tier >= 3:                                                    # bulwark: guards and buildings inside are mended
		for grp in ["guard", "structure"]:
			for n in s.get_tree().get_nodes_in_group(grp):
				if is_instance_valid(n) and n.global_position.distance_to(c) <= r and n.hp < n.max_hp:
					n.hp = minf(n.max_hp, n.hp + n.max_hp * 0.08 * delta)
					var id: int = n.get_instance_id()
					if since - float(s._house.get(id, -9.0)) >= 1.5:
						s._house[id] = since
						WeaponFx.spawn(w, "motes", n.global_position, WARD, {"radius": 8.0, "count": 3, "rise": 12.0, "life": 0.5})
	if tier >= 4:                                                    # rune pulse
		s._pulse_t += delta
		if s._pulse_t >= 1.2:
			s._pulse_t = 0.0
			WeaponFx.spawn(w, "ripple", s.position, WARD, {"radius": r + 10.0, "rings": 1, "life": 0.4})
			Sfx.play("hit")
			for e in near:
				if !is_instance_valid(e) or e.global_position.distance_to(c) > r + 10.0 + 4.0:
					continue
				e.spell_damage(AEGIS_PULSE[tier - 1], "", true)
				if is_instance_valid(e):
					if e.has_method("apply_slow"):
						e.apply_slow(0.5, 0.8)
					WeaponFx.spawn(w, "burst", e.global_position, WARD, {"radius": 8.0, "life": 0.2})
	if tier >= 5:                                                    # mirror: enemy shots that enter are sent back
		for sh in s.get_tree().get_nodes_in_group("enemy_shot"):
			if !is_instance_valid(sh) or sh.is_queued_for_deletion() or sh.global_position.distance_to(c) > r:
				continue
			var vel: Vector2 = sh.vel
			WeaponProjectile.shoot(w, sh.position, -vel.normalized(), vel.length() * 1.3, sh.damage / 10.0 * AEGIS_REFLECT, Color(0.95, 0.97, 1.0), 1.5, 0, 60.0)
			WeaponFx.spawn(w, "line", sh.position, Color.WHITE, {"dir": -vel.normalized(), "length": 30.0, "width": 2.0, "life": 0.15})
			WeaponFx.spawn(w, "burst", sh.position, Color.WHITE, {"radius": 10.0, "life": 0.2})
			Sfx.play("hit")
			sh.queue_free()
	if tier >= 6:
		for p in s._in_radius("player"):                             # sanctuary
			if p.has_method("heal"):
				p.heal(AEGIS_SANCTUARY * delta)
		if !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
			s._finale_done = true
			WeaponFx.spawn(w, "shards", s.position, AEGIS_GOLD, {"radius": r * 1.3, "count": 18, "life": 0.5})
			WeaponFx.spawn(w, "flash", s.position, AEGIS_GOLD, {"radius": r * 1.3, "life": 0.4})
			WeaponFx.spawn(w, "ripple", s.position, AEGIS_GOLD, {"radius": r * 1.6, "rings": 3, "life": 0.7})
			Sfx.play("ultimate")
			for e in WeaponUtil.enemies_in_circle(s.get_tree(), c, r * 1.3):
				var away: Vector2 = e.global_position - c
				e.spell_damage(3.0 * AEGIS_PULSE[5], "", true)
				if is_instance_valid(e) and e.has_method("push"):
					e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 160.0, 0.25)

# ---------------------------------------------------------------- Charm

const CHARM_BLAST := [0.0, 0.0, 0.0, 4.0, 7.0, 12.0]
const CHARM_SPREAD_MAX := 6
const CHARM_POWER := [1.0, 1.5, 1.5, 1.5, 1.5, 1.5]
const PINK := Color(1.0, 0.5, 0.7)

static func _can_charm(e) -> bool:
	return is_instance_valid(e) and e.has_method("charm") and !(e.get("charm_time") != null and e.charm_time > 0.0)

## Landing: charm what is in the area (with the tier's devotion), and from tier 6 crown a Favourite. Returns whether the spell stays to be drawn / keep working.
static func land_charm(s) -> bool:
	var dur: float = s.data.get("duration", 6.0)
	if String(s.data.get("id", "")) != "charm":
		for e in s._in_radius("enemy"):
			if e.has_method("charm"):
				e.charm(dur)
		return false
	var tier := tier_of(s)
	var w: Node = s.get_parent()
	var blast: float = CHARM_BLAST[tier - 1]
	var best = null
	for e in s._in_radius("enemy"):
		if e.has_method("charm"):
			e.charm(dur, CHARM_POWER[tier - 1], blast)
			if best == null or float(e.max_health) > float(best.max_health):
				best = e
	if tier >= 2:
		WeaponFx.spawn(w, "motes", s.position, PINK, {"radius": s.radius, "count": 8, "rise": 30.0, "life": 0.9})
		WeaponFx.spawn(w, "star", s.position, Color(1.0, 0.75, 0.85), {"radius": s.radius * 0.6, "count": 5, "spin": 1.0, "life": 0.4})
		Sfx.play("cast")
	if tier >= 6 and !is_copy(s):
		WeaponFx.spawn(w, "flash", s.position, Color(1.0, 0.7, 0.6), {"radius": s.radius, "life": 0.4})
		WeaponFx.spawn(w, "ripple", s.position, Color(1.0, 0.85, 0.4), {"radius": s.radius * 1.4, "rings": 3, "life": 0.7})
		WeaponFx.spawn(w, "star", s.position, Color(1.0, 0.85, 0.4), {"radius": s.radius, "count": 8, "spin": 1.0, "life": 0.5})
		Sfx.play("ultimate")
		if best != null:                                             # royal decree: the strongest becomes the Favourite
			best.charm(dur * 2.0, 3.0 * (1.25 if "potent" in s.data.get("adds", []) else 1.0), blast)
			best.charm_time = maxf(best.charm_time, dur * 2.0)
			if best._charm_scale == 1.0:
				best.scale *= 1.3
				best._charm_scale = 1.3
			s._fav = best
			s.favourite_on = true
			s.favourite_pos = best.global_position
	return tier >= 2

static func tick_charm(s, tier: int, delta: float) -> void:
	var since: float = s.age - s.flight
	var dur: float = s.data.get("duration", 6.0)
	var w: Node = s.get_parent()
	var c: Vector2 = s.global_position
	if tier >= 3 and since < maxf(3.0, dur * 0.5):                    # charm field: whoever steps in is charmed too
		s._field_t += delta
		if s._field_t >= 0.2:
			s._field_t = 0.0
			for e in s._in_radius("enemy"):
				if _can_charm(e):
					e.charm(dur, CHARM_POWER[tier - 1], CHARM_BLAST[tier - 1])
					WeaponFx.spawn(w, "burst", e.global_position, PINK, {"radius": 10.0, "life": 0.2})
	if tier >= 5:                                                    # contagion: charmed enemies infect a neighbour
		s._pulse_t += delta
		if s._pulse_t >= 0.5:
			s._pulse_t = 0.0
			for a in s.get_tree().get_nodes_in_group("ally"):
				if s._spread >= CHARM_SPREAD_MAX:
					break
				if !is_instance_valid(a) or a.get("charm_time") == null or a.charm_time <= 0.0:
					continue
				var victim = null
				for e in s.get_tree().get_nodes_in_group("enemy"):
					if _can_charm(e) and e.global_position.distance_to(a.global_position) <= 32.0 and (victim == null or e.global_position.distance_to(a.global_position) < victim.global_position.distance_to(a.global_position)):
						victim = e
				if victim != null:
					s._spread += 1
					victim.charm(3.0, 1.0, 0.0)
					var to: Vector2 = victim.global_position - a.global_position
					WeaponFx.spawn(w, "line", a.global_position, PINK, {"dir": to.normalized(), "length": to.length(), "width": 2.0, "life": 0.25})
					WeaponFx.spawn(w, "burst", victim.global_position, PINK, {"radius": 10.0, "life": 0.2})
					Sfx.play("whoosh")
	if tier >= 6 and s.favourite_on:                                  # the Favourite: crowned, and it leaves a trail
		var f = s._fav
		if f == null or !is_instance_valid(f) or f.get("dead") == true or f.charm_time <= 0.0:
			s.favourite_on = false
			s._fav = null
		else:
			s.favourite_pos = f.global_position
			s._sfx_t -= delta
			if s._sfx_t <= 0.0:
				s._sfx_t = 0.5
				WeaponFx.spawn(w, "burst", f.global_position, PINK, {"radius": 10.0, "life": 0.25})

# ---------------------------------------------------------------- Sandstorm

const SAND_PULL := 30.0
const SAND_GALE_T := 2.0
const SAND_GALE_PUSH := 150.0
const SAND_BURY_T := 2.5
const SAND_COLLAPSE := 260.0
const SAND := Color(0.92, 0.75, 0.4)

static func tick_sandstorm(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var inside: Array = s._in_radius("enemy")
	if first_tick(s):
		WeaponFx.spawn(w, "ring", s.position, SAND, {"radius": r, "life": 0.3})
		WeaponFx.spawn(w, "motes", s.position, SAND, {"radius": r, "count": 12, "rise": 14.0, "life": 0.8})
		Sfx.play("whoosh")
	if pace(s, "pull", 0.2, delta):                                   # dust devil: a steady pull to the middle
		for e in inside:
			var to: Vector2 = c - e.global_position
			if to.length() >= 6.0 and e.has_method("push"):
				e.push(to.normalized() * SAND_PULL, 0.12)
	if tier >= 3:                                                     # scour: an enemy that stays loses half its armour and shield
		var here := {}
		for e in inside:
			var id: int = e.get_instance_id()
			here[id] = true
			s._mem[id] = float(s._mem.get(id, 0.0)) + delta
			if s._mem[id] >= 1.0 and !e.has_meta("scoured"):
				e.set_meta("scoured", true)
				if e.get("armor") != null:
					e.armor *= 0.5
				if e.get("shield") != null:
					e.shield *= 0.5
				WeaponFx.spawn(w, "burst", e.global_position, Color(0.75, 0.6, 0.35), {"radius": 10.0, "life": 0.25})
				Sfx.play("hit")
		for id in s._mem.keys():
			if !here.has(id):
				s._mem.erase(id)
	if tier >= 4 and pace(s, "gale", SAND_GALE_T, delta):             # gale burst: a gust that turns round
		var gust := Vector2.from_angle(since * 0.9)
		WeaponFx.spawn(w, "ripple", s.position, SAND, {"radius": r, "rings": 2, "life": 0.5})
		WeaponFx.spawn(w, "shards", s.position, SAND, {"radius": r, "count": 10, "spin": gust.angle(), "life": 0.5})
		Sfx.play("thump")
		for e in inside:
			if !is_instance_valid(e):
				continue
			e.spell_damage(dps * 1.5, "earth", true)
			if is_instance_valid(e) and e.has_method("push"):
				e.push(gust * SAND_GALE_PUSH, 0.2)
	if tier >= 5 and pace(s, "bury", SAND_BURY_T, delta):             # burial: two enemies are swallowed for a moment
		var pool := inside.duplicate()
		pool.shuffle()
		for i in mini(2, pool.size()):
			var e = pool[i]
			if !is_instance_valid(e):
				continue
			WeaponFx.spawn(w, "pillar", e.global_position, SAND, {"height": 30.0, "width": 14.0, "life": 0.4})
			WeaponFx.spawn(w, "burst", e.global_position, SAND, {"radius": 14.0, "life": 0.3})
			Sfx.play("big_hit")
			if e.has_method("apply_slow"):
				e.apply_slow(0.0, 1.2)
			e.spell_damage(dps * 3.0, "earth", true)
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
		s._finale_done = true                                         # collapse: everything round it is dragged in
		WeaponFx.spawn(w, "flash", s.position, SAND, {"radius": r * 1.5, "life": 0.4})
		WeaponFx.spawn(w, "ripple", s.position, SAND, {"radius": r * 1.6, "rings": 3, "life": 0.7})
		WeaponFx.spawn(w, "shards", s.position, SAND, {"radius": r * 1.5, "count": 18, "life": 0.5})
		Sfx.play("ultimate")
		for e in WeaponUtil.enemies_in_circle(s.get_tree(), c, r * 1.5):
			var to2: Vector2 = c - e.global_position
			if e.has_method("push"):
				e.push(to2.normalized() * SAND_COLLAPSE, 0.25)
			if e.has_method("apply_slow"):
				e.apply_slow(0.0, 1.2)
			e.spell_damage(dps * 5.0, "earth", true)

# ---------------------------------------------------------------- Blizzard

const BLIZ_STACK_T := 0.6
const BLIZ_FREEZE := 1.0
const BLIZ_HAIL_T := 0.4
const BLIZ_BOLT_T := 1.5
const BLIZ_DRIFT := 18.0
const BLIZ_LEASH := 120.0
const SNOW := Color(0.9, 0.97, 1.0)
const BLIZ_ICE := Color(0.6, 0.85, 1.0)
const BOLT := Color(0.85, 0.9, 1.0)

## Where the biggest bunch of enemies within `reach` of `from` stands (`from` itself when there are none).
static func densest(tree: SceneTree, from: Vector2, reach: float) -> Vector2:
	var best := from
	var most := 0
	var near: Array = WeaponUtil.enemies_in_circle(tree, from, reach)
	for a in near:
		var n := 0
		for b in near:
			if a.global_position.distance_to(b.global_position) <= 40.0:
				n += 1
		if n > most:
			most = n
			best = a.global_position
	return best

static func tick_blizzard(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	if first_tick(s):
		s._home = s.position
	var inside: Array = s._in_radius("enemy")
	var here := {}
	for e in inside:                                                  # deep chill: frost builds up, then it freezes solid
		var id: int = e.get_instance_id()
		here[id] = true
		if float(s._cool.get(id, 0.0)) > 0.0:
			s._cool[id] = float(s._cool[id]) - delta
			continue
		s._mem[id] = float(s._mem.get(id, 0.0)) + delta / BLIZ_STACK_T
		if s._mem[id] >= 5.0:
			s._mem[id] = 0.0
			s._cool[id] = 4.0
			WeaponFx.spawn(w, "shards", e.global_position, BLIZ_ICE, {"radius": 20.0, "count": 8, "life": 0.35})
			WeaponFx.spawn(w, "ring", e.global_position, BLIZ_ICE, {"radius": 14.0, "life": 0.3})
			Sfx.play("big_hit")
			if e.has_method("apply_slow"):
				e.apply_slow(0.0, BLIZ_FREEZE)
			WeaponUtil.expose(e, 1.5)
	for id in s._mem.keys():
		if !here.has(id):
			s._mem[id] = float(s._mem[id]) - delta
			if s._mem[id] <= 0.0:
				s._mem.erase(id)
	if tier >= 3 and pace(s, "hail", BLIZ_HAIL_T, delta) and !inside.is_empty():     # hailstones
		var e2 = inside[randi() % inside.size()]
		if is_instance_valid(e2):
			WeaponUtil.ground_strike(tree, w, e2.global_position, 8.0, 0.25, dps * 0.8, 30.0, SNOW, 0.0, [], "ice")
	if tier >= 4 and pace(s, "bolt", BLIZ_BOLT_T, delta) and !inside.is_empty():     # thunder snow: lightning on the coldest enemy
		var top := -1.0
		var picks := []
		for e in inside:
			var st := float(s._mem.get(e.get_instance_id(), 0.0))
			if st > top + 0.001:
				top = st
				picks = [e]
			elif absf(st - top) <= 0.001:
				picks.append(e)
		var v = picks[randi() % picks.size()]
		if is_instance_valid(v):
			var at: Vector2 = v.global_position
			WeaponFx.spawn(w, "bolt", at + Vector2(0, -60), BOLT, {"dir": Vector2.DOWN, "length": 60.0, "width": 3.0, "life": 0.25})
			WeaponFx.spawn(w, "burst", at, Color.WHITE, {"radius": 12.0, "life": 0.25})
			WeaponFx.spawn(w, "flash", at, Color.WHITE, {"radius": 18.0, "life": 0.2})
			Sfx.play("big_hit")
			v.spell_damage(dps * 3.0, "ice")
			if is_instance_valid(v) and v.has_method("apply_slow"):
				v.apply_slow(0.0, 0.4)
			var nearest = null
			for o in WeaponUtil.enemies_in_circle(tree, at, 40.0):
				if o != v and is_instance_valid(o) and (nearest == null or o.global_position.distance_to(at) < nearest.global_position.distance_to(at)):
					nearest = o
			if nearest != null:
				nearest.spell_damage(dps * 3.0 * 0.4, "ice")
	if tier >= 5:                                                      # roaming front: it drifts toward the thickest crowd, on a leash
		var goal := densest(tree, s.global_position, 150.0)
		var dir: Vector2 = goal - s.global_position
		s.drift = dir.normalized() if dir.length() > 4.0 else Vector2.ZERO
		s.position += s.drift * BLIZ_DRIFT * delta
		var off: Vector2 = s.position - s._home
		if off.length() > BLIZ_LEASH:
			s.position = s._home + off.normalized() * BLIZ_LEASH
		if pace(s, "wake", 1.0, delta):
			WeaponFx.spawn(w, "ring", s.position, SNOW, {"radius": r * 0.6, "life": 0.4})
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
		s._finale_done = true                                           # ice age: a freeze wave, and the ground stays frozen
		WeaponFx.spawn(w, "flash", s.position, BOLT, {"radius": r * 1.4, "life": 0.4})
		WeaponFx.spawn(w, "ripple", s.position, BLIZ_ICE, {"radius": r * 1.6, "rings": 3, "life": 0.7})
		WeaponFx.spawn(w, "shards", s.position, SNOW, {"radius": r * 1.4, "count": 20, "life": 0.5})
		WeaponFx.spawn(w, "pillar", s.position, BLIZ_ICE, {"height": 80.0, "width": 30.0, "life": 0.5})
		Sfx.play("ultimate")
		for e in WeaponUtil.enemies_in_circle(tree, s.global_position, r * 1.4):
			if e.has_method("apply_slow"):
				e.apply_slow(0.0, 1.5)
			e.spell_damage(dps * 4.0, "ice", true)
		WeaponUtil.patch(w, s.position, "slow", 1.2 * r, BLIZ_ICE, 7.0, 0.35)

## The places where enemies that were inside the spell have died since the last call (and forget the ones that merely walked out).
static func deaths(s, inside: Array) -> Array:
	var out := []
	var here := {}
	for e in inside:
		here[e.get_instance_id()] = true
		s._seen[e.get_instance_id()] = e.global_position
	for id in s._seen.keys():
		var o = instance_from_id(id)
		if o != null and !_dead(o):
			if !here.has(id):
				s._seen.erase(id)
			continue
		out.append(s._seen[id])
		s._seen.erase(id)
	return out

# ---------------------------------------------------------------- Lava Pool

const LAVA_BUBBLE := 1.5
const LAVA_IGNITE := 0.3
const LAVA_CINDER := 0.6
const LAVA_GEYSER := 4.0
const LAVA_BOMBS := 8
const LAVA := Color(1.0, 0.4, 0.1)
const LAVA_GLOW := Color(1.0, 0.75, 0.25)

static func vent_angle(i: int) -> float:
	return fposmod(sin(i * 12.9898 + 3.0 * 78.233) * 43758.5453, 1.0) * TAU

static func tick_lava_pool(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	var inside: Array = s._in_radius("enemy")
	if pace(s, "bubble", 1.2, delta) and !inside.is_empty():          # magma bubbles burst under an enemy
		var e = inside[randi() % inside.size()]
		if is_instance_valid(e):
			WeaponUtil.ground_strike(tree, w, e.global_position, 14.0, 0.4, dps * LAVA_BUBBLE, 60.0, LAVA, 0.0, [], "fire")
	if tier >= 3:                                                      # molten touch: what stands in it keeps burning after it leaves
		var smoke := pace(s, "ember", 1.0, delta)
		for e in inside:
			var id: int = e.get_instance_id()
			if float(s._cool.get(id, 0.0)) <= 0.0:
				s._cool[id] = 2.0
				WeaponUtil.bleed(tree, e, 4, dps * LAVA_IGNITE)
			if smoke:
				WeaponFx.spawn(w, "motes", e.global_position, LAVA_GLOW, {"radius": 6.0, "count": 2, "rise": 10.0, "life": 0.5})
		for id in s._cool.keys():
			s._cool[id] = float(s._cool[id]) - delta
			if s._cool[id] < -5.0:
				s._cool.erase(id)
	if tier >= 4:                                                      # cinder fountain: a death spits burning cinders
		for at in deaths(s, inside):
			WeaponFx.spawn(w, "pillar", at, LAVA, {"height": 40.0, "width": 12.0, "life": 0.4})
			WeaponFx.spawn(w, "shards", at, LAVA_GLOW, {"radius": 30.0, "count": 6, "life": 0.35})
			Sfx.play("big_hit")
			var base: float = (at - c).angle()
			for i in 4:
				WeaponProjectile.shoot(w, at, Vector2.from_angle(base + (i - 1.5) * 0.35), 150.0, dps * LAVA_CINDER, LAVA_GLOW, 0.5, 0, 40.0)
	if tier >= 5 and pace(s, "geyser", 2.5, delta) and !inside.is_empty():   # geyser: a vent erupts under the thickest crowd
		var at2 := densest(tree, c, r)
		WeaponFx.spawn(w, "pillar", at2, LAVA, {"height": 70.0, "width": 22.0, "life": 0.5})
		WeaponFx.spawn(w, "ripple", at2, LAVA, {"radius": 30.0, "rings": 2, "life": 0.5})
		Sfx.play("thump")
		WeaponUtil.ground_strike(tree, w, at2, 26.0, 0.4, dps * LAVA_GEYSER, 160.0, LAVA, 0.6, [], "fire")
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:
		s._finale_done = true                                           # volcano: it erupts
		WeaponFx.spawn(w, "flash", s.position, Color(1.0, 0.95, 0.7), {"radius": r * 1.5, "life": 0.4})
		WeaponFx.spawn(w, "pillar", s.position, LAVA, {"height": 110.0, "width": 40.0, "life": 0.6})
		WeaponFx.spawn(w, "ripple", s.position, LAVA, {"radius": r * 1.8, "rings": 3, "life": 0.7})
		Sfx.play("ultimate")
		LightSource.spawn(w, s.position, r * 2.0, 2.0, Color(1.0, 0.7, 0.3))
		WeaponUtil.rain(tree, w, s.position, r * 1.3, LAVA_BOMBS, 1.2, dps * 3.0, 20.0, LAVA)
		for e in WeaponUtil.enemies_in_circle(tree, c, r):
			var away: Vector2 = e.global_position - c
			e.spell_damage(dps * 4.0, "fire", true)
			if is_instance_valid(e) and e.has_method("push"):
				e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 200.0, 0.25)

# ---------------------------------------------------------------- Poison Cloud

const POISON_INFECT_T := 1.5
const POISON_CARRIER_T := 5.0
const POISON_CARRIER_R := 34.0
const POISON_COUGH := 2.0
const POISON_POD := 2.5
const POISON_PLAGUE_MAX := 6
const TOXIC := Color(0.5, 0.9, 0.3)
const SPORE := Color(0.8, 1.0, 0.5)

static func pod_pos(s, i: int) -> Vector2:
	return s.global_position + Vector2.from_angle(SpellArt.jit(i, 5.0) * TAU) * s.radius * 0.35

static func tick_poison_cloud(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	var now := Time.get_ticks_msec() / 1000.0
	var inside: Array = s._in_radius("enemy") if since < s.effect_time else []
	var here := {}
	for e in inside:                                                   # weakening toxin: they take more from everything
		var id: int = e.get_instance_id()
		here[id] = true
		if !e.has_meta("toxic_until") or e.get_meta("toxic_until") < now:
			WeaponFx.spawn(w, "burst", e.global_position, TOXIC, {"radius": 6.0, "life": 0.2})
		e.set_meta("toxic_until", now + 1.0)
		s._mem[id] = float(s._mem.get(id, 0.0)) + delta
		if tier >= 3 and s._mem[id] >= POISON_INFECT_T and !s._cool.has(id):
			s._cool[id] = POISON_CARRIER_T                              # ...and one that has stood in it long enough carries it
	for id in s._mem.keys():
		if !here.has(id):
			s._mem.erase(id)
	if tier >= 3 and pace(s, "infect", 0.5, delta):
		for id in s._cool.keys():
			s._cool[id] = float(s._cool[id]) - 0.5
			var carrier = instance_from_id(id)
			if s._cool[id] <= 0.0 or carrier == null or _dead(carrier):
				s._cool.erase(id)
				continue
			for e in WeaponUtil.enemies_in_circle(tree, carrier.global_position, POISON_CARRIER_R):
				if e != carrier and is_instance_valid(e):
					e.spell_damage(dps * 0.25, "poison", true)
					if is_instance_valid(e):
						var to: Vector2 = e.global_position - carrier.global_position
						WeaponFx.spawn(w, "line", carrier.global_position, TOXIC, {"dir": to.normalized(), "length": to.length(), "width": 2.0, "life": 0.25})
						WeaponFx.spawn(w, "burst", e.global_position, TOXIC, {"radius": 8.0, "life": 0.2})
	if tier >= 4 and pace(s, "cough", POISON_COUGH, delta) and !inside.is_empty():    # choking fumes
		var v = inside[randi() % inside.size()]
		if is_instance_valid(v):
			WeaponFx.spawn(w, "burst", v.global_position, SPORE, {"radius": 12.0, "life": 0.25})
			WeaponFx.spawn(w, "motes", v.global_position, SPORE, {"radius": 8.0, "count": 6, "rise": 14.0, "life": 0.6})
			Sfx.play("hit")
			if v.has_method("apply_slow"):
				v.apply_slow(0.0, 0.8)
			v.spell_damage(dps * 2.0, "poison", true)
	if tier >= 5 and since < s.effect_time:                            # spore pods ripen in turn and burst
		for i in 3:
			var k := floori((since - i * POISON_POD / 3.0) / POISON_POD)
			if k >= 1 and k > int(s._clk.get("pod" + str(i), 0)):
				s._clk["pod" + str(i)] = k
				var pp := pod_pos(s, i)
				WeaponFx.spawn(w, "ripple", pp, SPORE, {"radius": 28.0, "rings": 2, "life": 0.4})
				WeaponFx.spawn(w, "motes", pp, SPORE, {"radius": 14.0, "count": 10, "rise": 24.0, "life": 0.7})
				Sfx.play("thump")
				for e in WeaponUtil.enemies_in_circle(tree, pp, 28.0):
					var away: Vector2 = e.global_position - pp
					e.spell_damage(dps * 4.0, "poison", true)
					if is_instance_valid(e):
						WeaponUtil.bleed(tree, e, 4, dps * 0.4)
						if e.has_method("push"):
							e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 90.0, 0.15)
	if tier >= 6:
		if !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:   # plague: everything near is plagued
			s._finale_done = true
			WeaponFx.spawn(w, "flash", s.position, SPORE, {"radius": r * 1.3, "life": 0.4})
			WeaponFx.spawn(w, "ripple", s.position, TOXIC, {"radius": r * 1.5, "rings": 3, "life": 0.7})
			WeaponFx.spawn(w, "motes", s.position, SPORE, {"radius": r * 1.2, "count": 20, "rise": 40.0, "life": 0.9})
			Sfx.play("ultimate")
			for e in WeaponUtil.enemies_in_circle(tree, c, r * 1.3):
				s._plagued[e.get_instance_id()] = e.global_position
				WeaponUtil.bleed(tree, e, 8, dps * 0.5)
		for id in s._plagued.keys():                                   # a plagued enemy that falls releases a small cloud
			var o = instance_from_id(id)
			if o != null and !_dead(o):
				s._plagued[id] = o.global_position
				continue
			var at: Vector2 = s._plagued[id]
			s._plagued.erase(id)
			WeaponFx.spawn(w, "burst", at, TOXIC, {"radius": 16.0, "life": 0.3})
			if s._plague_clouds < POISON_PLAGUE_MAX:
				s._plague_clouds += 1
				var small: Dictionary = s.data.duplicate()
				small.radius = r * 0.45
				small.duration = 3.0
				small.copy = true
				small.adds = []
				small.twist = ""
				Spell.cast_copy(w, small, at)

# ---------------------------------------------------------------- Crystal Spikes

const SPIKE_STUN := [0.3, 1.2, 1.2, 1.2, 1.2, 1.2]
const SPIKE_ZAP_T := 0.6
const SPIKE_ZAP_R := 20.0
const SPIKE_WEB_T := 0.25
const SPIKE_BLOOM := 2.0
const SPIKE_DELAYS := [0.3, 0.45, 0.6]
const AMETHYST := Color(0.8, 0.6, 1.0)

## The three spots the crystals rise from (a triangle round the target).
static func spike_spots(s) -> Array:
	var out := []
	for i in 3:
		out.append(s.global_position + Vector2.from_angle(i * TAU / 3.0 - PI / 2.0) * 22.0)
	return out

static func land_crystal_spikes(s) -> void:
	var tier := tier_of(s)
	var tree: SceneTree = s.get_tree()
	var w: Node = s.get_parent()
	var dmg: float = s.data.damage
	var col: Color = s.data.get("color", AMETHYST)
	var el: String = s.data.get("element", "")
	var expose := Callable()
	if tier >= 2:
		expose = func(e): WeaponUtil.expose(e, 2.0)                 # impale: a skewered enemy takes more from everything
	var spots := spike_spots(s)
	for i in 3:
		WeaponUtil.ground_strike(tree, w, spots[i], s.radius, SPIKE_DELAYS[i], dmg, 160.0, col, SPIKE_STUN[tier - 1], [], el, expose)
		if tier >= 4:                                               # fissure: a line of smaller spikes runs outward from each
			var dir: Vector2 = (spots[i] - s.global_position).normalized()
			for k in range(1, 4):
				WeaponUtil.ground_strike(tree, w, spots[i] + dir * 26.0 * k, 14.0, SPIKE_DELAYS[i] + 0.15 * k, dmg * 0.5, 160.0, col, 0.3, [], el)

static func tick_crystal_spikes(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var tree: SceneTree = s.get_tree()
	var w: Node = s.get_parent()
	var dmg: float = s.data.damage
	var spots := spike_spots(s)
	for i in 3:                                                       # each eruption: shards and a burst
		if since >= SPIKE_DELAYS[i] and !s._clk.has("sp" + str(i)):
			s._clk["sp" + str(i)] = true
			WeaponFx.spawn(w, "shards", spots[i], AMETHYST, {"radius": 20.0, "count": 6, "life": 0.3})
			WeaponFx.spawn(w, "burst", spots[i], AMETHYST, {"radius": 14.0, "life": 0.25})
			Sfx.play("big_hit")
	if since < SPIKE_DELAYS[2]:
		return
	if tier >= 3 and pace(s, "zap", SPIKE_ZAP_T, delta):               # crystal garden: each crystal zaps what comes near
		for sp in spots:
			for e in WeaponUtil.enemies_in_circle(tree, sp, SPIKE_ZAP_R):
				var to: Vector2 = e.global_position - sp
				WeaponFx.spawn(w, "bolt", sp + Vector2(0, -18), Color(0.85, 1.0, 1.0), {"dir": (e.global_position - sp - Vector2(0, -18)).normalized(), "length": (e.global_position - sp - Vector2(0, -18)).length(), "width": 2.0, "life": 0.15})
				e.spell_damage(dmg * 0.3, "pierce", true)
	if tier >= 5 and pace(s, "web", SPIKE_WEB_T, delta):               # prism web: the three crystals are linked
		for i in 3:
			var a: Vector2 = spots[i]
			var b: Vector2 = spots[(i + 1) % 3]
			var d := (b - a).normalized()
			for e in WeaponUtil.enemies_in_line(tree, a, d, a.distance_to(b), 5.0):
				e.spell_damage(dmg * 0.4, "pierce", true)
				if is_instance_valid(e):
					keep_slow(e, 0.5, 0.4)
					WeaponFx.spawn(w, "burst", e.global_position, Color.from_hsv(fposmod(since * 0.3 + i * 0.33, 1.0), 0.35, 1.0), {"radius": 8.0, "life": 0.2})
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= 0.9:   # crystal bloom: a huge crystal erupts at the cast point
		s._finale_done = true
		var r: float = s.radius * 1.6
		var c: Vector2 = s.position
		var gp: Vector2 = s.global_position
		WeaponUtil.ground_strike(tree, w, gp, r, 0.4, dmg * SPIKE_BLOOM, 220.0, AMETHYST, 0.8, [], "pierce")
		tree.create_timer(0.4).timeout.connect(func():
			if !is_instance_valid(w):
				return
			WeaponFx.spawn(w, "flash", c, AMETHYST, {"radius": r, "life": 0.4})
			WeaponFx.spawn(w, "shards", c, AMETHYST, {"radius": r, "count": 14, "life": 0.5})
			WeaponFx.spawn(w, "ripple", c, AMETHYST, {"radius": r, "rings": 2, "life": 0.6})
			Sfx.play("ultimate")
			for i in 12:
				WeaponProjectile.shoot(w, c, Vector2.from_angle(i * TAU / 12.0), 200.0, dmg * 0.5, AMETHYST, 0.6, 1, 40.0))

# ---------------------------------------------------------------- Meteor Shower

const METEOR_BOULDER_EVERY := 3
const METEOR_BOULDER_MULT := 2.0
const METEOR_SPLINTER := 0.3
const METEOR_SEEK := 0.7
const METEOR_BIG := 6.0
const METEOR_FIRE := Color(1.0, 0.5, 0.15)
const METEOR_HOT := Color(1.0, 0.85, 0.4)

## From tier 2 the shower is run by `tick_meteor_shower` (looks, abilities, craters); tier 1 keeps the plain rain.
static func meteors_by_tier(s) -> bool:
	return String(s.data.get("id", "")) == "meteor_shower" and tier_of(s) >= 2

static func meteor_light(s) -> float:
	if String(s.data.get("id", "")) != "meteor_shower":
		return 1.4
	var t := tier_of(s)
	return 2.4 if t >= 6 else (1.8 if t >= 4 else 1.4)

## Where meteor i lands (when nothing seeks): a steady spot in the disc, the same on every machine.
static func meteor_spot(s, i: int) -> Vector2:
	return s.position + Vector2.from_angle(SpellArt.jit(i, 1.0) * TAU) * sqrt(SpellArt.jit(i, 2.0)) * s.radius

static func is_boulder(tier: int, i: int) -> bool:
	return tier >= 3 and i % METEOR_BOULDER_EVERY == 2

## When meteor i is launched (seconds after landing) and when it hits.
static func meteor_launch(s, i: int) -> float:
	return float(i) * float(s.data.get("duration", 3.5)) / float(maxi(int(s.data.get("count", 10)), 1))

static func meteor_fall_time(tier: int, i: int) -> float:
	return 0.55 if is_boulder(tier, i) else 0.45

static func tick_meteor_shower(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	var dmg: float = s.data.damage
	var count := int(s.data.get("count", 10))
	var dur: float = s.data.get("duration", 3.5)
	var launched := int(s._clk.get("launched", 0))
	while launched < count and since >= meteor_launch(s, launched):     # launch the next meteor
		var i := launched
		launched += 1
		var spot := meteor_spot(s, i)
		var boulder := is_boulder(tier, i)
		var seeker := false
		if tier >= 5 and SpellArt.jit(i, 3.0) < METEOR_SEEK:             # seeker stars: most of them pick a real enemy
			var near: Array = s._in_radius("enemy")
			if !near.is_empty():
				var pick = near[int(SpellArt.jit(i, 4.0) * near.size()) % near.size()]
				if is_instance_valid(pick):
					spot = pick.global_position
					seeker = true
					WeaponFx.spawn(w, "line", spot + Vector2(-7, 0), METEOR_HOT, {"dir": Vector2.RIGHT, "length": 14.0, "width": 1.5, "life": 0.45})
					WeaponFx.spawn(w, "line", spot + Vector2(0, -7), METEOR_HOT, {"dir": Vector2.DOWN, "length": 14.0, "width": 1.5, "life": 0.45})
					Sfx.play("whoosh")
		s.spots.append(spot)
		var fall_t := meteor_fall_time(tier, i)
		var rad := 7.0 if boulder else (5.0 if tier >= 5 else 4.0)
		WeaponFx.spawn(w, "fall", spot, METEOR_FIRE, {"radius": rad, "height": 130.0 if boulder else 90.0, "rise": 40.0, "life": fall_t, "core": Color(0.8, 0.9, 1.0) if tier >= 5 else Color(1.0, 0.97, 0.85)})
		WeaponFx.spawn(w, "ring", spot, METEOR_FIRE, {"radius": 26.0 * (1.6 if boulder else 1.0), "life": fall_t})
		s._queue.append({"t": since + fall_t, "spot": spot, "i": i, "boulder": boulder})
	s._clk["launched"] = launched
	for q in s._queue.duplicate():                                       # impacts
		if since < float(q.t):
			continue
		s._queue.erase(q)
		_meteor_hit(s, tier, q.spot, int(q.i), q.boulder, dmg)
	if tier >= 4 and pace(s, "streak", 0.5, delta) and since < dur:      # shooting streaks across the sky
		var k := int(since * 2.0)
		var a: Vector2 = s.position + Vector2(-s.radius, -s.radius * 0.9) + Vector2(SpellArt.jit(k, 6.0) * s.radius * 0.6, SpellArt.jit(k, 7.0) * s.radius * 0.5)
		WeaponFx.spawn(w, "line", a, METEOR_HOT, {"dir": Vector2(1, 0.6).normalized(), "length": s.radius * 1.4, "width": 1.0, "life": 0.3})
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= dur + 0.8:   # extinction: one gigantic meteor
		s._finale_done = true
		var gp: Vector2 = s.global_position
		var c: Vector2 = s.position
		var r: float = s.radius
		WeaponFx.spawn(w, "fall", c, METEOR_FIRE, {"radius": 18.0, "height": 260.0, "rise": 120.0, "life": 1.2, "core": Color(1.0, 0.97, 0.85)})
		WeaponUtil.ground_strike(tree, w, gp, r * 0.7, 1.2, dmg * METEOR_BIG, 260.0, METEOR_FIRE, 1.0, [], "fire")
		tree.create_timer(1.2).timeout.connect(func():
			if !is_instance_valid(w):
				return
			WeaponFx.spawn(w, "flash", c, Color(1.0, 0.97, 0.85), {"radius": r * 1.2, "life": 0.4})
			WeaponFx.spawn(w, "ripple", c, METEOR_FIRE, {"radius": r * 1.5, "rings": 3, "life": 0.7})
			WeaponFx.spawn(w, "pillar", c, METEOR_FIRE, {"height": 120.0, "width": 50.0, "life": 0.6})
			WeaponFx.spawn(w, "shards", c, METEOR_FIRE, {"radius": r * 1.2, "count": 20, "life": 0.5})
			Sfx.play("ultimate")
			LightSource.spawn(w, c, r * 2.4, 5.0, Color(1.0, 0.7, 0.3)))

static func _meteor_hit(s, tier: int, spot: Vector2, i: int, boulder: bool, dmg: float) -> void:
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	var rad: float = 26.0 * (1.6 if boulder else 1.0)
	var d := dmg * (METEOR_BOULDER_MULT if boulder else 1.0)
	WeaponFx.spawn(w, "flash", spot, METEOR_FIRE, {"radius": 34.0 if boulder else 18.0, "life": 0.25})
	WeaponFx.spawn(w, "burst", spot, METEOR_FIRE, {"radius": 22.0, "life": 0.25})
	if boulder:
		WeaponFx.spawn(w, "ripple", spot, METEOR_HOT, {"radius": 34.0, "rings": 2, "life": 0.4})
		Sfx.play("thump")
	elif i % 2 == 0:
		Sfx.play("big_hit")
	for e in WeaponUtil.enemies_in_circle(tree, spot, rad):
		WeaponUtil.hit(e, d, spot, 220.0 if boulder else 140.0, 0.6 if boulder else 0.0, "fire", true)
		if is_instance_valid(e):
			WeaponUtil.bleed(tree, e, 3, dmg * 0.2)                      # burning rocks: whatever is hit catches fire
	WeaponFx.spawn(w, "ring", spot, METEOR_HOT, {"radius": rad * 1.1, "life": 0.25})
	if tier >= 4:                                                        # splinters
		WeaponFx.spawn(w, "shards", spot, METEOR_FIRE, {"radius": 26.0, "count": 5, "life": 0.3})
		var n := 5 if boulder else 3
		var base := SpellArt.jit(i, 7.0) * TAU
		for k in n:
			WeaponProjectile.shoot(w, spot, Vector2.from_angle(base + k * TAU / float(n)), 170.0, dmg * METEOR_SPLINTER, METEOR_FIRE, 0.4, 0, 60.0)

# ---------------------------------------------------------------- Stasis Field

const STASIS_ENTROPY := 0.01
const STASIS_REWIND_T := 1.5
const STASIS_REWIND_PUSH := 600.0
const STASIS_BREAK := 0.15
const STASIS_BREAK_BOSS := 0.02
const TIME := Color(0.75, 0.9, 1.0)

static func tick_stasis(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var w: Node = s.get_parent()
	var tree: SceneTree = s.get_tree()
	var inside: Array = s._in_radius("enemy") if since < s.effect_time else []
	for sh in tree.get_nodes_in_group("enemy_shot"):                  # suspension: enemy shots hang in the air
		if is_instance_valid(sh) and !sh.has_meta("held_by") and sh.global_position.distance_to(c) <= r and since < s.effect_time:
			sh.set_meta("held_by", s.get_instance_id())
			sh.set_meta("held_vel", sh.vel)
			sh.vel = Vector2.ZERO
			WeaponFx.spawn(w, "ring", sh.global_position, TIME, {"radius": 10.0, "life": 0.3})
			Sfx.play("whoosh")
	if tier >= 3 and pace(s, "entropy", 0.5, delta):                  # entropy: time eats the frozen
		var boss_cut := 0.3
		for e in inside:
			var cut: float = maxf(0.5, float(e.max_health) * STASIS_ENTROPY * (boss_cut if e.is_in_group("boss") else 1.0))
			e.spell_damage(cut, "pierce", true)
		if pace(s, "sand", 1.0, 0.5):
			for k in mini(6, inside.size()):
				if is_instance_valid(inside[k]):
					WeaponFx.spawn(w, "motes", inside[k].global_position, TIME, {"radius": 8.0, "count": 4, "rise": 16.0, "life": 0.6})
	if tier >= 4:                                                      # brittle: the frozen take more from everything
		var now := Time.get_ticks_msec() / 1000.0
		for e in inside:
			e.set_meta("brittle_until", now + 0.5)
		if pace(s, "crack", 2.0, delta):
			WeaponFx.spawn(w, "ripple", s.position, TIME, {"radius": r, "rings": 2, "life": 0.6})
	if tier >= 5 and pace(s, "rewind", STASIS_REWIND_T, delta):       # rewind: time runs backwards, they are thrown back the way they came
		WeaponFx.spawn(w, "ripple", s.position, TIME, {"radius": r, "rings": 2, "life": 0.6})
		Sfx.play("thump")
		var keep: Vector2 = Game.crystal_position()
		for e in inside:
			if is_instance_valid(e) and e.has_method("push"):
				e.push((e.global_position - keep).normalized() * STASIS_REWIND_PUSH, 0.15)
	if tier >= 6 and !s._finale_done and !is_copy(s) and since >= s.effect_time - 0.05:   # time break: the held time catches up in one blow
		s._finale_done = true
		WeaponFx.spawn(w, "flash", s.position, Color.WHITE, {"radius": r, "life": 0.4})
		WeaponFx.spawn(w, "ripple", s.position, TIME, {"radius": r * 1.3, "rings": 3, "life": 0.7})
		WeaponFx.spawn(w, "shards", s.position, TIME, {"radius": r, "count": 24, "life": 0.5})
		Sfx.play("ultimate")
		for e in WeaponUtil.enemies_in_circle(tree, c, r):
			var boss: bool = e.is_in_group("boss")
			var away: Vector2 = e.global_position - c
			e.spell_damage(maxf(8.0, float(e.max_health) * (STASIS_BREAK_BOSS if boss else STASIS_BREAK)), "pierce", true)
			if is_instance_valid(e) and e.has_method("push"):
				e.push((away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * 600.0, 0.25)

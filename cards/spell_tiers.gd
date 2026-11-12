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

static func tier_of(s) -> int:
	return clampi(int(s.data.get("tier", 1)), 1, 6)

static func is_copy(s) -> bool:
	return bool(s.data.get("copy", false))

## How long the landed spell stays (a tier 5 fireball keeps burning on the spot).
static func effect_time(s, base: float) -> float:
	match String(s.data.get("id", "")):
		"fireball":
			return 1.6 if tier_of(s) >= 5 else base
	return base

## Runs once when the spell lands, right after its additions: the extra effects and sounds of the tier.
static func on_land(s) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			land_fireball(s, tier_of(s))
		"frost_ring":
			land_frost_ring(s, tier_of(s))

## Runs every physics frame once landed.
static func tick(s, delta: float) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			tick_fireball(s, tier_of(s), delta)
		"frost_ring":
			tick_frost_ring(s, tier_of(s), delta)
		"flare":
			tick_flare(s, tier_of(s), delta)

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
	if String(s.data.get("id", "")) != "flare":
		return [1.0, 0.65]
	var t := tier_of(s)
	return [1.15 if t >= 4 else 1.0, 0.8 if t >= 6 else 0.65]

static func tick_flare(s, tier: int, delta: float) -> void:
	if tier < 2:
		return
	var since: float = s.age - s.flight
	var c: Vector2 = s.global_position
	var r: float = s.radius
	var dps: float = s.data.dps
	var w: Node = s.get_parent()
	var inside: Array = s._in_radius("enemy")
	if since < delta * 1.5:                                          # (the first frame after landing)
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

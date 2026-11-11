extends RefCounted
class_name SpellTiers
## What a spell card does at each tier (2 to 6), on top of the stacking "added" modifiers (Game.SPELL_TWISTS, Spell._apply_add).
## Spell calls the hooks below; each card is a few functions named <hook>_<card id>. Everything here runs on the host
## (a puppet spell never reaches it); visuals go through WeaponFx.spawn and Sfx.play, which are mirrored to clients.
## Designs: docs/card_tiers/<card id>.md

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

## Runs every physics frame once landed.
static func tick(s, delta: float) -> void:
	match String(s.data.get("id", "")):
		"fireball":
			tick_fireball(s, tier_of(s), delta)

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

extends RefCounted
class_name WeaponTiers
## The tier ladder of the weapons (docs/weapon_tiers): ONE module per weapon in items/weapons/tiers/<id>.gd (no class_name, only statics),
## (entry points never await: a verb that waits starts a helper coroutine by a direct call), reached through run() from the hooks in Weapon and Tool (equip, pre_attack/attack, ability, release, dash, ultimate, on_hit, dash_hit, tick,
## aura). Every function takes the weapon first: attack(w), on_hit(w, e, dmg). A weapon without a module behaves as before.

const FRAC := {1: 0.0, 2: 0.20, 3: 0.35, 4: 0.55, 5: 0.78, 6: 1.0}
static var _mods := {}
static var _names := {}

static func mod(id: String):
	if id == "":
		return null
	if _mods.has(id):
		return _mods[id]
	var path := "res://items/weapons/tiers/%s.gd" % id
	var m = load(path) if ResourceLoader.exists(path) else null
	_mods[id] = m
	var names := {}
	if m != null:
		for d in m.get_script_method_list():
			names[d.name] = true
	_names[id] = names
	return m

static func has_fn(id: String, fn: String) -> bool:
	mod(id)
	return _names.get(id, {}).has(fn)

## Calls fn(w, args...) of the weapon's module if it has one. Returns what it returns (a coroutine is not awaited).
static func run(w, fn: String, args := []):
	if w == null or !is_instance_valid(w):
		return null
	var id: String = w.weapon_id
	if !has_fn(id, fn):
		return null
	return _mods[id].callv(fn, [w] + args)

static func rarity(w) -> int:
	return Game.weapon_rarity(w.weapon_id)

## The most of a rarity's fx / particle budget that tier t may use: ceil(total * frac).
static func budget(total: int, tier: int) -> int:
	return int(ceil(float(total) * float(FRAC.get(clampi(tier, 1, 6), 1.0))))

## Is the weapon still in the game and in hand (a rider that waited checks this when it resumes).
static func alive(w) -> bool:
	return w != null and is_instance_valid(w) and w.is_inside_tree()

## H: the weapon's basic hit before WeaponUtil.power (Sword and Pickaxe: 2.0).
static func H(w) -> float:
	return Game.basic_hit(w.weapon_id, 2.0)

## Wait, then say whether the weapon is still there; a rider that waited re-claims the shared WeaponUtil statics before it hits.
static func pause(w, secs: float) -> bool:
	if !alive(w):
		return false
	await w.get_tree().create_timer(secs).timeout
	if !alive(w):
		return false
	w._claim()
	return true

## Mark `e` for `secs` (a deadline in seconds, read with marked()).
static func mark(e: Node, name: String, secs: float) -> void:
	e.set_meta("wt_" + name, Time.get_ticks_msec() / 1000.0 + secs)

static func marked(e: Node, name: String) -> bool:
	return is_instance_valid(e) and e.has_meta("wt_" + name) and e.get_meta("wt_" + name) > Time.get_ticks_msec() / 1000.0

## A glowing weapon's light grows with its tier: add `bonus[tier - 1]` to its light radius and re-scale its GlowLight to match
## (the radius Game.player_light reads is `light_radius`). Call it from the module's equip().
static func light_bonus(w, bonus: Array) -> void:
	w.light_radius += float(bonus[clampi(w.tier - 1, 0, bonus.size() - 1)])
	for c in w.get_children():
		if c is GlowLight:
			c.texture_scale = maxf(0.1, w.light_radius * 2.0 / 128.0)
			w._st["glow"] = c
			w._st["glow_scale"] = c.texture_scale

extends RefCounted
## The signature attacks of the six sector bosses: three each, themed on their biome, none shared.
##   King Blobbert (grassland)  bounce, bramble, vine_sweep
##   Sand Colossus (desert)     sand_spiral, quicksand, scarab_fan
##   Frost Wyrm (tundra)        ice_lance, blizzard, frost_nova
##   Magma Titan (ember)        meteor_rain, lava_spokes, fire_wave
##   Bog Mother (swamp)         poison_pools, tongue_lash, mire_grasp
##   Crystal Warden (caverns)   prism_beams, shard_trail, facet_burst
## boss.gd calls run(boss, name) when the windup ends. Each attack finishes by calling boss._end_attack().
## Damages are base values: the boss scales them by its level and by enrage (boss._dmg).

const ZONE := preload("res://enemies/boss/boss_zone.gd")

const LABELS := {
	"bounce": "BOUNCE!", "bramble": "BRAMBLES", "vine_sweep": "VINE SWEEP",
	"sand_spiral": "SAND SPIRAL", "quicksand": "QUICKSAND", "scarab_fan": "SCARAB FAN",
	"ice_lance": "ICE LANCE", "blizzard": "BLIZZARD", "frost_nova": "FROST NOVA",
	"meteor_rain": "METEOR RAIN", "lava_spokes": "LAVA SPOKES", "fire_wave": "FIRE WAVE",
	"poison_pools": "POISON POOLS", "tongue_lash": "TONGUE LASH", "mire_grasp": "MIRE GRASP",
	"prism_beams": "PRISM BEAMS", "shard_trail": "SHARD TRAIL", "facet_burst": "FACET BURST",
}

## How many players beyond the first: attacks get bigger and spread over several players.
static func extra() -> int:
	return maxi(0, Game.player_count() - 1)

## A random player who can be hit (for attacks that should spread out), or the boss's usual target.
static func any_target(b):
	var pool := []
	for p in b.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.get("downed") and !p.get("is_in_tower"):
			pool.append(p)
	return pool.pick_random() if !pool.is_empty() else target(b)

static func has(name: String) -> bool:
	return LABELS.has(name)

static func label(name: String) -> String:
	return LABELS.get(name, "")

static func run(b, name: String) -> void:
	b._state = "recover"                     # stands still while the attack plays out
	match name:
		"bounce": await bounce(b)
		"bramble": await bramble(b)
		"vine_sweep": await vine_sweep(b)
		"sand_spiral": await sand_spiral(b)
		"quicksand": await quicksand(b)
		"scarab_fan": await scarab_fan(b)
		"ice_lance": await ice_lance(b)
		"blizzard": await blizzard(b)
		"frost_nova": await frost_nova(b)
		"meteor_rain": await meteor_rain(b)
		"lava_spokes": await lava_spokes(b)
		"fire_wave": await fire_wave(b)
		"poison_pools": await poison_pools(b)
		"tongue_lash": await tongue_lash(b)
		"mire_grasp": await mire_grasp(b)
		"prism_beams": await prism_beams(b)
		"shard_trail": await shard_trail(b)
		"facet_burst": await facet_burst(b)
	if is_instance_valid(b) and !b.dead and b._state == "recover":
		b._end_attack()

# ------------------------------------------------------------------ helpers

static func wait(b, t: float) -> bool:
	await b.get_tree().create_timer(t).timeout
	return is_instance_valid(b) and !b.dead

static func target(b):
	return b._player if is_instance_valid(b._player) and !b._player.get("downed") else null

static func ring_fx(b, pos: Vector2, radius: float, life: float, col: Color) -> void:
	WeaponFx.spawn(b.get_parent(), "ring", pos, col, {"radius": radius, "life": life})

## A telegraphed circle on the ground: it shows for `delay`, then hurts whoever is still inside.
static func circle(b, pos: Vector2, radius: float, delay: float, dmg: float, col: Color) -> bool:
	ring_fx(b, pos, radius, delay, col)
	if !await wait(b, delay):
		return false
	var p = target(b)
	ring_fx(b, pos, radius * 1.1, 0.25, col.lightened(0.4))
	if p != null and !p.is_in_tower and p.global_position.distance_to(pos) <= radius:
		p.take_damage(pos, b._dmg(dmg))
		return true
	return false

static func seg_dist(p: Vector2, a: Vector2, c: Vector2) -> float:
	var ab := c - a
	var t := clampf((p - a).dot(ab) / maxf(1.0, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## A telegraphed straight strike: a line shows for `delay`, then hurts anyone on it.
static func line(b, origin: Vector2, dir: Vector2, length: float, width: float, delay: float, dmg: float, col: Color) -> bool:
	WeaponFx.spawn(b.get_parent(), "line", origin, Color(col, 0.7), {"dir": dir, "length": length, "width": width * 0.4, "life": delay})
	if !await wait(b, delay):
		return false
	WeaponFx.spawn(b.get_parent(), "line", origin, col.lightened(0.5), {"dir": dir, "length": length, "width": width, "life": 0.22})
	var p = target(b)
	if p != null and !p.is_in_tower and seg_dist(p.global_position, origin, origin + dir * length) <= width * 0.5 + 6.0:
		p.take_damage(origin, b._dmg(dmg))
		return true
	return false

static func shot(b, dir: Vector2, speed: float, dmg: float, col: Color, rad := 7.0, life := 3.0, split := 0.0) -> void:
	EnemyProjectile.fire(b.get_parent(), b.global_position, dir, speed, b._dmg(dmg), col, rad, life, split)

static func zone(b, pos: Vector2, radius: float, life: float, dmg: float, factor: float, col: Color, warm := 0.8) -> void:
	var z = ZONE.new()
	z.position = pos
	z.radius = radius
	z.life = life
	z.warmup = warm
	z.dps_hit = b._dmg(dmg)
	z.factor = factor
	z.color = col
	b.get_parent().add_child.call_deferred(z)

static func aim(b) -> Vector2:
	var p = target(b)
	return (p.global_position - b.global_position).normalized() if p != null else Vector2.DOWN

# ------------------------------------------------------------------ King Blobbert (grassland)

## Leaps towards you (a hop of at most 85 units, not all the way onto you) and crashes down there.
static func bounce(b) -> void:
	var p = target(b)
	if p == null:
		return
	var to: Vector2 = p.global_position - b.global_position
	var land: Vector2 = b.global_position + to.limit_length(85.0)
	var col := Color(0.4, 0.9, 0.4)
	ring_fx(b, land, 38.0, 0.8, col)
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "global_position", land, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if !await wait(b, 0.75):
		return
	b._player.shake(5.0, 0.3)
	ring_fx(b, land, 46.0, 0.3, col.lightened(0.3))
	var p2 = target(b)
	if p2 != null and !p2.is_in_tower and p2.global_position.distance_to(land) <= 40.0:
		p2.take_damage(land, b._dmg(65.0))
	await wait(b, 0.4)

## Thorny roots burst out of the ground in three lines.
static func bramble(b) -> void:
	var base := aim(b)
	var col := Color(0.35, 0.75, 0.25)
	var fan := [-0.45, 0.0, 0.45]
	if extra() >= 1:
		fan = [-0.8, -0.4, 0.0, 0.4, 0.8]
	for k in fan:
		line(b, b.global_position, base.rotated(k), 170.0, 18.0, 0.8, 55.0, col)
		if !await wait(b, 0.3):
			return
	await wait(b, 0.9)

## A long vine whips across the field in a half-circle.
static func vine_sweep(b) -> void:
	var start := aim(b).rotated(-1.3)
	var col := Color(0.4, 0.8, 0.3)
	WeaponFx.spawn(b.get_parent(), "line", b.global_position, Color(col, 0.6), {"dir": start, "length": 105.0, "width": 3.0, "life": 0.6})
	if !await wait(b, 0.6):
		return
	var hit := false
	for i in 14:
		var d := start.rotated(i * 0.19)
		WeaponFx.spawn(b.get_parent(), "line", b.global_position, col.lightened(0.3), {"dir": d, "length": 105.0, "width": 7.0, "life": 0.12})
		var p = target(b)
		if !hit and p != null and !p.is_in_tower and seg_dist(p.global_position, b.global_position, b.global_position + d * 105.0) <= 9.0:
			hit = true
			p.take_damage(b.global_position, b._dmg(55.0))
		if !await wait(b, 0.07):
			return
	await wait(b, 0.3)

# ------------------------------------------------------------------ Sand Colossus (desert)

## Three arms of whirling sand spiral outward.
static func sand_spiral(b) -> void:
	var col := Color(0.9, 0.75, 0.4)
	var a := randf() * TAU
	var arms := 3 + (1 if extra() >= 2 else 0)
	for i in 24:
		for arm in arms:
			shot(b, Vector2.from_angle(a + arm * TAU / float(arms)), 85.0, 26.0, col, 6.0, 3.2)
		a += 0.38
		if !await wait(b, 0.07):
			return
	await wait(b, 0.5)

## Sinking sand opens under and around you: slow and hurt while inside.
static func quicksand(b) -> void:
	var p = target(b)
	if p == null:
		return
	var col := Color(0.75, 0.6, 0.3)
	zone(b, p.global_position, 44.0, 6.0, 10.0, 0.35, col)
	for i in 2 + extra():
		var at = any_target(b)
		zone(b, (at.global_position if at != null else p.global_position) + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0), 40.0, 6.0, 10.0, 0.35, col)
	await wait(b, 1.2)

## A fan of scarabs skitters out, twice.
static func scarab_fan(b) -> void:
	var col := Color(0.8, 0.55, 0.2)
	for round in 2:
		var base := aim(b)
		var n := 7 + 2 * extra()
		for i in n:
			shot(b, base.rotated((i - (n - 1) / 2.0) * 0.17), 125.0, 30.0, col, 7.0, 3.0)
		if !await wait(b, 0.55):
			return
	await wait(b, 0.4)

# ------------------------------------------------------------------ Frost Wyrm (tundra)

## A long lance of ice, telegraphed, straight at you.
static func ice_lance(b) -> void:
	var col := Color(0.6, 0.9, 1.0)
	await line(b, b.global_position, aim(b), 300.0, 18.0, 0.9, 70.0, col)
	await wait(b, 0.6)

## A snowstorm settles where you are: deep slow and frostbite.
static func blizzard(b) -> void:
	var p = target(b)
	if p == null:
		return
	zone(b, p.global_position, 72.0, 5.5, 14.0, 0.5, Color(0.75, 0.9, 1.0), 0.9)
	await wait(b, 1.5)

## Rings of ice shards with gaps to slip through.
static func frost_nova(b) -> void:
	var col := Color(0.7, 0.92, 1.0)
	for round in 2:
		var gap := randi() % 16
		for i in 16:
			if i == gap or i == (gap + 1) % 16:
				continue
			shot(b, Vector2.from_angle(i * TAU / 16.0 + round * 0.2), 92.0, 30.0, col, 6.0, 3.0)
		if !await wait(b, 0.7):
			return
	await wait(b, 0.4)

# ------------------------------------------------------------------ Magma Titan (ember)

## Meteors crash down around you one after another.
static func meteor_rain(b) -> void:
	var p = target(b)
	if p == null:
		return
	var col := Color(1.0, 0.45, 0.1)
	for i in 7 + 2 * extra():
		var pl = target(b) if i == 0 else any_target(b)         # later meteors pick a random player: they spread over the team
		if pl == null:
			break
		var at: Vector2 = pl.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(10.0, 70.0))
		_meteor(b, at, col)
		if !await wait(b, 0.3):
			return
	await wait(b, 1.0)

static func _meteor(b, at: Vector2, col: Color) -> void:
	await circle(b, at, 26.0, 0.85, 60.0, col)
	if is_instance_valid(b) and !b.dead:
		zone(b, at, 20.0, 3.0, 10.0, 1.0, Color(1.0, 0.35, 0.1), 0.1)

## Spokes of fire shoot out of the Titan like the rays of a sun.
static func lava_spokes(b) -> void:
	var col := Color(1.0, 0.4, 0.1)
	var off := randf() * TAU
	var spokes := 8 + 2 * mini(extra(), 3)
	for i in spokes:
		line(b, b.global_position, Vector2.from_angle(off + i * TAU / float(spokes)), 170.0, 14.0, 0.9, 62.0, col)
	if !await wait(b, 1.5):
		return
	for i in spokes:
		line(b, b.global_position, Vector2.from_angle(off + PI / float(spokes) + i * TAU / float(spokes)), 170.0, 14.0, 0.7, 62.0, col)
	await wait(b, 1.5)

## Three walls of flame roll toward you.
static func fire_wave(b) -> void:
	var col := Color(1.0, 0.55, 0.15)
	for w in 3 + (1 if extra() >= 2 else 0):
		var base := aim(b)
		var n := 6 + 2 * extra()
		for i in n:
			shot(b, base.rotated((i - (n - 1) / 2.0) * 0.17), 100.0 + w * 22.0, 34.0, col, 10.0, 3.6)
		if !await wait(b, 0.45):
			return
	await wait(b, 0.5)

# ------------------------------------------------------------------ Bog Mother (swamp)

## Pools of poison bubble up all around you.
static func poison_pools(b) -> void:
	var p = target(b)
	if p == null:
		return
	for i in 4 + 2 * extra():
		var at = any_target(b)
		zone(b, (at.global_position if at != null else p.global_position) + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 95.0), 36.0, 7.0, 10.0, 0.6, Color(0.4, 0.7, 0.2))
	await wait(b, 1.5)

## A sticky tongue lashes out and drags you in.
static func tongue_lash(b) -> void:
	var dir := aim(b)
	var origin: Vector2 = b.global_position
	var hit = await line(b, origin, dir, 210.0, 12.0, 0.8, 52.0, Color(0.9, 0.4, 0.5))
	var p = target(b)
	if hit and p != null:
		p.apply_knockback((origin - p.global_position).normalized() * 260.0)       # reeled in
	await wait(b, 0.6)

## Roots clamp around your feet: you cannot run for a moment.
static func mire_grasp(b) -> void:
	var p = target(b)
	if p == null:
		return
	var at: Vector2 = p.global_position
	var hit = await circle(b, at, 44.0, 0.9, 40.0, Color(0.5, 0.35, 0.15))
	var p2 = target(b)
	if hit and p2 != null:
		p2.speed_mult = 0.15
		await wait(b, 1.3)
		if is_instance_valid(p2) and p2.speed_mult < 0.2:
			p2.speed_mult = 1.0
	await wait(b, 0.3)

# ------------------------------------------------------------------ Crystal Warden (caverns)

## Three beams of light sweep around the cavern.
static func prism_beams(b) -> void:
	var col := Color(0.85, 0.6, 1.0)
	var off := randf() * TAU
	for k in 3:
		WeaponFx.spawn(b.get_parent(), "line", b.global_position, Color(col, 0.6), {"dir": Vector2.from_angle(off + k * TAU / 3.0), "length": 180.0, "width": 3.0, "life": 0.8})
	if !await wait(b, 0.8):
		return
	var hit_until := 0.0
	for i in 18:
		for k in 3:
			var d := Vector2.from_angle(off + k * TAU / 3.0 + i * 0.09)
			WeaponFx.spawn(b.get_parent(), "line", b.global_position, col.lightened(0.3), {"dir": d, "length": 180.0, "width": 7.0, "life": 0.12})
			var p = target(b)
			if p != null and !p.is_in_tower and seg_dist(p.global_position, b.global_position, b.global_position + d * 180.0) <= 9.0 and Time.get_ticks_msec() / 1000.0 > hit_until:
				hit_until = Time.get_ticks_msec() / 1000.0 + 0.7
				p.take_damage(b.global_position, b._dmg(55.0))
		if !await wait(b, 0.09):
			return
	await wait(b, 0.4)

## Crystal spikes erupt in a line toward you.
static func shard_trail(b) -> void:
	var dir := aim(b)
	var col := Color(0.8, 0.55, 1.0)
	for i in 8 + 2 * extra():
		circle(b, b.global_position + dir * (28.0 + i * 24.0), 19.0, 0.55, 55.0, col)
		if !await wait(b, 0.13):
			return
	await wait(b, 1.0)

## Big crystals fly out, then shatter into more shards.
static func facet_burst(b) -> void:
	var col := Color(0.75, 0.5, 1.0)
	var off := randf() * TAU
	var n := 6 + 2 * mini(extra(), 3)
	for i in n:
		shot(b, Vector2.from_angle(off + i * TAU / float(n)), 115.0, 34.0, col, 9.0, 3.0, 0.7)
	if !await wait(b, 1.0):
		return
	for i in n:
		shot(b, Vector2.from_angle(off + PI / float(n) + i * TAU / float(n)), 115.0, 34.0, col, 9.0, 3.0, 0.7)
	await wait(b, 1.4)

extends StaticBody2D
class_name Structure
## A built defence placed by a build card. Types (card "build" key):
##   barricade  solid wall; enemies chew on it (optional thorns hurt them back)
##   spike_trap hurts and slows enemies standing on it, limited uses
##   sentry     shoots the nearest enemy in range for a limited time
##   mender     heals players nearby for a limited time
##   totem      slows every enemy in range for a limited time
## Card level scales hp / damage / duration through Game.stats().

const MAX_STRUCTURES := 14

var data: Dictionary
var kind := "barricade"
var radius := 16.0
var hp := 24.0
var max_hp := 24.0
var life := 0.0             # (unused: buildings are permanent)
var _heal_budget := 0.0     # a healer can heal this much in total, then it is used up and goes away
var _healed := 0.0
var uses := 0
var _tick := 0.0
var flash := 0.0
var shot_to := Vector2.ZERO
var shot_t := 0.0
var _age := 0.0
var tier := 1               # 1-3: place the same build card on a structure to merge up
const MAX_TIER := 6

var twist := ""             # the newest thing it added (see Game.TWISTS)
var adds: Array = []        # everything it has added so far, stacked (Game.adds_for)
var light_radius := 0.0     # > 0: this building is a light source at night (torches, and glowing turrets); group "light"
var _glow: GlowLight
var _rearm := 0.0
# --- tier abilities (cards/structure_tiers.gd): host-only state is underscored, what a client must draw is public ---
var _timers := {}           # named clocks, see StructureTiers.pace
var _seen := {}             # enemies seen last tick, see StructureTiers.deaths
var _thr := {}              # hp thresholds, see StructureTiers.threshold
var _fx_t := 0.0
var _invuln := 0.0          # > 0: takes no damage
var _shots := 0             # sentry family: shots fired so far
var _triggers := 0          # spike trap: times it has been stepped on
var charge := 0.0           # 0..1, an ability about to fire (the building glows with it)
var aim := Vector2.ZERO     # direction of the last shot (turret barrels)
var lit := false            # a flame is burning
var fx_pulse := 1.0         # seconds since the last ability pulse, capped at 1 (the drawing flashes while it is small)
var vis := {}               # card-specific things a client must draw (plain numbers, vectors, arrays of them): stacks, fruit, a phoenix dive...
var _tdata := {}             # host-only per-card state of the second batch of tier abilities (cards/structure_tiers_c.gd)

func setup(card: Dictionary, pos: Vector2) -> void:
	data = card
	twist = str(card.get("twist", ""))
	adds = card.get("adds", [twist] if twist != "" else [])
	_apply_twist()
	kind = card.build
	tier = int(card.get("level", 1))              # a card drawn at a higher tier is placed at that tier
	points = 1 << (tier - 1)
	position = pos
	radius = card.radius
	max_hp = card.get("hp", 20.0)
	hp = max_hp
	life = 0.0                                   # buildings stay until enemies destroy them (only healers run out, below)
	_heal_budget = float(card.get("heal_per_sec", 0.0)) * float(card.get("duration", 0.0))
	uses = card.get("uses", 0)
	light_radius = float(card.get("light", 0.0))
	StructureTiers.on_setup(self)

const MERGE_RANGE := 26.0

## A structure holds POINTS: a tier 1 card is worth 1, tier 2 is 2, tier 3 is 4 (2^(tier-1)).
## Tier n covers 2^(n-1) up to 2^n - 1 points, so it needs a whole tier's worth more to move
## up: tier 1 + tier 1 = tier 2, tier 2 + tier 2 = tier 3, or a tier 3 gets tier 1 cards one at
## a time (1 of 4 ... 4 of 4) to reach tier 4. Placing a card next to a structure of the
## same kind feeds it. It cannot pass the tier you have unlocked for that card.
var points := 1

func tier_points(t: int) -> int:
	return 1 << (t - 1)

var tier_cap := 1            # synced: the highest tier the host's collection allows (a co-op client has no collection of its own)

func ceiling() -> int:
	if has_meta("net_puppet"):
		return tier_cap
	tier_cap = mini(MAX_TIER, Game.card_tier(str(data.get("id", ""))))
	return tier_cap

func points_cap() -> int:
	return (1 << ceiling()) - 1

## Points still needed for the next tier.
func needs() -> int:
	return tier_points(tier + 1) - points

func absorb(n: int) -> void:
	points += n
	while tier < MAX_TIER and points >= tier_points(tier + 1):
		promote()

## Feed freshly placed `st` into a neighbour of the same kind (the biggest one it fits into),
## then let that neighbour join any equal-tier neighbour of its own. `st` is freed if it was
## absorbed. Returns the structure that holds the points now.
static func settle(tree: SceneTree, st):
	var guard := 0
	while is_instance_valid(st) and guard < 8:
		guard += 1
		var best = null
		var blocked := false
		for o in tree.get_nodes_in_group("structure"):
			if o == st or !is_instance_valid(o) or o.is_queued_for_deletion() or o.data.get("id", "") != st.data.get("id", "?"):
				continue
			if o.global_position.distance_to(st.global_position) > MERGE_RANGE:
				continue
			if o.points + st.points > o.points_cap():
				blocked = true
				continue
			if best == null or o.points > best.points:
				best = o
		if best == null:
			if blocked and st.tier < MAX_TIER:
				Game.announce.emit("%s is at your unlocked tier (%d). Upgrade the card in the collection to grow it further." % [st.data.name, st.ceiling()])
			return st
		best.absorb(st.points)
		st.queue_free()
		st = best
	return st

## Twists that change numbers are applied to the data; the ones that change behaviour
## (regrow, rearm, venom, twin_shot) are checked while running.
func _apply_twist() -> void:
	for a in adds:
		_apply_add(String(a))

func _apply_add(a: String) -> void:
	match a:
		"thorned":
			data.thorns = maxf(data.get("thorns", 0.0), 2.0 * pow(1.5, tier - 1))
		"thorns_plus":
			data.thorns = data.get("thorns", 2.0 * pow(1.5, tier - 1)) * 2.0
		"tough":
			if data.has("hp"):
				data.hp = data.hp * 1.4
		"frost_shot":
			if !data.has("slow"):
				data.slow = 0.5
		"blast_shot":
			data.burst = maxf(data.get("burst", 0.0), data.get("damage", 1.0) * 0.8)
		"heavy":
			if data.has("damage"):
				data.damage = data.damage * 1.3
		"rapid":
			data.interval = data.get("interval", 0.7) * 0.6
		"barbed":
			if data.has("damage"):
				data.damage = data.damage * 1.5
		"more_uses":
			data.uses = int(data.get("uses", 0)) + 3
		"potent":
			for key in ["damage", "dps", "heal_per_sec", "burst"]:
				if data.has(key):
					data[key] = data[key] * 1.25
		"wide_field":
			data.radius = data.radius * 1.4
			if data.has("light"):
				data.light = data.light * 1.4
		"bright":
			if data.has("light"):
				data.light = data.light * 1.3
		"swift_heal":
			data.heal_per_sec = data.get("heal_per_sec", 0.0) * 1.6
		"deep_freeze":
			if data.has("slow"):
				data.slow = maxf(0.12, pow(data.slow, 1.8))

## One tier up. The new tier's numbers come from the same power curve as a card of that tier
## (a tier 3 is worth about 4.4 tier 1s), and it gains the twist that tier comes with.
func promote() -> void:
	tier += 1
	var id := str(data.id)
	data = Game.scaled(id, tier)
	twist = Game.twist_for(id, tier)
	adds = Game.adds_for(id, tier, twist)
	data.twist = twist
	data.adds = adds
	_apply_twist()
	if kind in ["spike_trap", "mender", "totem"]:
		radius = data.radius
	if data.has("light"):
		light_radius = float(data.light)
		if _glow != null:
			_glow.texture_scale = maxf(0.1, light_radius * 2.0 / 128.0)
	max_hp = data.get("hp", max_hp)
	hp = max_hp
	_heal_budget = float(data.get("heal_per_sec", 0.0)) * float(data.get("duration", 0.0))
	uses = int(data.get("uses", uses))
	flash = 0.4
	WeaponFx.spawn(get_parent(), "ring", global_position, Color(1.0, 0.85, 0.3), {"radius": radius + 10.0, "life": 0.4})
	StructureTiers.on_promote(self, tier)

func _ready() -> void:
	add_to_group("structure")
	add_to_group("net")
	z_index = 4
	if light_radius > 0.0 or float(data.get("light", 0.0)) > 0.0:
		light_radius = maxf(light_radius, float(data.get("light", 0.0)))
		add_to_group("light")
		_glow = GlowLight.attach(self, light_radius, _color().lerp(Color(1.0, 0.85, 0.5), 0.5), 0.6)
	if kind == "barricade":
		add_to_group("nav_obstacle")
		Game.nav_changed.emit()
		tree_exiting.connect(func(): Game.nav_changed.emit())
		collision_layer = 16       # enemies collide with layer 16, players do not
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		add_child(shape)
	# keep the number of placed structures bounded: the oldest one crumbles
	var all := get_tree().get_nodes_in_group("structure")
	if !Rep.is_puppet(self) and all.size() > MAX_STRUCTURES + int(Game.bonus("build_cap")):
		all[0].queue_free()

func _near_enemies(r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.global_position.distance_to(global_position) <= r:
			out.append(e)
	return out

func _physics_process(delta: float) -> void:
	_age += delta
	fx_pulse = minf(fx_pulse + delta, 1.0)
	_invuln = maxf(0.0, _invuln - delta)
	flash = max(0.0, flash - delta)
	shot_t = max(0.0, shot_t - delta)
	if "regrow" in adds and hp < max_hp:
		hp = minf(max_hp, hp + 1.5 * delta)
	if "rearm" in adds and kind == "spike_trap" and uses < int(data.get("uses", 0)):
		_rearm += delta
		if _rearm >= 3.0:
			_rearm = 0.0
			uses += 1
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			_expire()
			return
	_tick += delta
	match kind:
		"barricade":
			if _tick >= 0.5:
				_tick = 0.0
				var gnawing := _near_enemies(radius + 9.0)
				for e in gnawing:
					hp -= (1.0 if !(e is Boss) else 4.0) * StructureTiers.guard_mult(self)
					StructureTiers.on_gnaw(self, e)
					if data.get("thorns", 0.0) > 0.0:
						e.spell_damage(data.thorns, data.get("element", ""))
				if gnawing.size() > 0:
					flash = 0.15
				if hp <= 0.0:
					_expire()
					return
		"spike_trap":
			if _tick >= 0.45:
				_tick = 0.0
				var hit := _near_enemies(radius)
				if hit.size() > 0:
					for e in hit:
						e.spell_damage(data.damage, data.get("element", ""), true)
						StructureTiers.keep_slow(e, data.slow, 0.6)
						if "venom" in adds:
							WeaponUtil.bleed(get_tree(), e, 4, data.damage * 0.3)
					flash = 0.2
					_triggers += 1
					uses -= 1
					StructureTiers.on_trigger(self, hit)
					if uses <= 0:
						StructureTiers.on_last_use(self)
						_expire()
						return
		"sentry":
			if _tick >= data.get("interval", 0.7) * StructureTiers.interval_mult(self):
				var best = null
				for e in _near_enemies(data.range):
					if !Game.defence_sees(e, global_position):
						continue                      # in the dark it only sees what is lit (a torch next to it helps)
					if best == null or e.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
						best = e
				if best != null:
					_tick = 0.0
					shot_to = best.global_position
					shot_t = 0.12
					aim = (best.global_position - global_position).normalized()
					_shots += 1
					best.spell_damage(data.damage * StructureTiers.shot_mult(self, best), data.get("element", ""))
					if data.has("slow") and best.has_method("apply_slow"):
						best.apply_slow(data.slow, 1.2)
					if data.get("poison", 0.0) > 0.0:
						WeaponUtil.bleed(get_tree(), best, 4, data.poison * 0.25)
					if "twin_shot" in adds:
						var second = null
						for e2 in _near_enemies(data.range):
							if e2 != best and Game.defence_sees(e2, global_position) and (second == null or e2.global_position.distance_to(global_position) < second.global_position.distance_to(global_position)):
								second = e2
						if second != null:
							second.spell_damage(data.damage, data.get("element", ""))
							shot_to = second.global_position
					var blast: float = data.get("burst", 0.0)
					if blast > 0.0:
						for e in _near_enemies_at(best.global_position, 24.0):
							if e != best:
								e.spell_damage(blast * 0.5, data.get("element", ""), true)
						WeaponFx.spawn(get_parent(), "burst", best.global_position, _color(), {"radius": 16.0, "life": 0.2})
					StructureTiers.on_shot(self, best)
		"torch":
			if _tick >= 0.5:
				_tick = 0.0
				for e in _near_enemies(light_radius):
					if "blaze" in adds:
						e.spell_damage(1.0 + 0.5 * tier, "fire", true)
					if "sunfire" in adds:
						e.spell_damage(1.5 + 0.5 * tier, "fire", true)
					if "warding" in adds and e.has_method("apply_slow"):
						e.apply_slow(0.65, 0.7)
		"mender":
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and p.global_position.distance_to(global_position) <= radius and p.needs_health():
					p.heal(data.heal_per_sec * delta * StructureTiers.heal_mult(self, p))             # only a hurt player in range uses up its healing
					_healed += data.heal_per_sec * delta * StructureTiers.budget_mult(self)
			if _heal_budget > 0.0 and _healed >= _heal_budget:
				_expire()                                    # it has healed all it had
				return
		"totem":
			for e in _near_enemies(radius):
				StructureTiers.keep_slow(e, data.slow, 0.3)
	StructureTiers.tick(self, delta)
	ceiling()                 # keeps the synced tier_cap current for co-op clients
	queue_redraw()

func _near_enemies_at(pos: Vector2, r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.global_position.distance_to(pos) <= r:
			out.append(e)
	return out

func _expire() -> void:
	if "last_stand" in adds:
		for e in _near_enemies(radius + 24.0):
			e.spell_damage(3.0 * pow(1.6, tier - 1), "", true)
		WeaponFx.spawn(get_parent(), "ring", global_position, Color(1.0, 0.6, 0.3), {"radius": radius + 24.0, "life": 0.35})
	StructureTiers.on_expire(self)
	WeaponFx.spawn(get_parent(), "burst", global_position, _color(), {"radius": radius, "life": 0.25})
	queue_free()

func _color() -> Color:
	if data.has("color"):
		return data.color
	match kind:
		"barricade": return Color(0.65, 0.45, 0.25)
		"spike_trap": return Color(0.75, 0.75, 0.8)
		"sentry": return Color(0.9, 0.8, 0.4)
		"torch": return Color(1.0, 0.7, 0.25)
		"mender": return Color(0.4, 1.0, 0.5)
	return Color(0.7, 0.8, 1.0)

func _draw_progress() -> void:
	var w := maxf(16.0, radius * 1.6)
	var y := radius * 0.9 + 9.0
	if tier >= ceiling():
		var label := "MAX" if tier >= MAX_TIER else "LOCKED: unlock tier %d" % (tier + 1)
		draw_string(ThemeDB.fallback_font, Vector2(-w / 2.0 - 10.0, y + 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, w + 20.0, 6, Color(1, 0.85, 0.3, 0.8))
		return
	var span := float(tier_points(tier))
	var fill: float = clampf((points - tier_points(tier)) / span, 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, 3.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2.0 + 0.5, y + 0.5, (w - 1.0) * fill, 2.0), Color(0.55, 1.0, 0.6))
	var mouse := Pad.world_mouse(self)
	if mouse.distance_to(global_position) <= radius + 14.0 or (Game.card_aim_active and mouse.distance_to(global_position) <= MERGE_RANGE + radius):
		var n := needs()
		var tw: String = (" | Added: " + ", ".join(adds.filter(func(a): return Game.TWISTS.has(a)).map(func(a): return Game.TWISTS[a][0]))) if !adds.is_empty() else ""
		draw_string(ThemeDB.fallback_font, Vector2(-45, y + 12.0), "tier %d: %d/%d, needs %d more (tier 1 cards)%s" % [tier, points - tier_points(tier), tier_points(tier), n, tw], HORIZONTAL_ALIGNMENT_CENTER, 90.0, 6, Color(0.8, 1.0, 0.8))

func _draw_tier() -> void:
	_draw_progress()
	for i in tier - 1:
		draw_circle(Vector2((i - (tier - 2) * 0.5) * 7.0, -radius - 12.0), 2.6, Color.BLACK)
		draw_circle(Vector2((i - (tier - 2) * 0.5) * 7.0, -radius - 12.0), 1.8, Color(1.0, 0.85, 0.2))

func _draw() -> void:
	_draw_tier()
	var col := _color().lerp(Color(1.0, 0.92, 0.5), 0.08 * (tier - 1))          # a higher tier is tinted toward gold
	if tier >= 5:
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 28, Color(1.0, 0.85, 0.3, 0.5 + 0.2 * sin(_age * 3.0)), 1.5)     # and a ring of light round it
	if flash > 0.0:
		col = col.lerp(Color.WHITE, 0.6)
	draw_circle(Vector2(0, radius * 0.5), radius * 0.9, Color(0, 0, 0, 0.25))
	if StructureArt.draw(self, col):                   # a card with its own art draws it all; the rest use the plain look below
		return
	match kind:
		"barricade":
			draw_rect(Rect2(-radius, -radius * 0.8, radius * 2.0, radius * 1.6), Color.BLACK)
			draw_rect(Rect2(-radius + 1, -radius * 0.8 + 1, radius * 2.0 - 2, radius * 1.6 - 2), col)
			for i in 3:
				draw_line(Vector2(-radius + 2, -radius * 0.4 + i * radius * 0.4), Vector2(radius - 2, -radius * 0.4 + i * radius * 0.4), col.darkened(0.4), 1.5)
			if data.get("thorns", 0.0) > 0.0:
				for i in 5:
					var x := -radius + 3.0 + i * (radius * 2.0 - 6.0) / 4.0
					draw_colored_polygon(PackedVector2Array([Vector2(x - 2, -radius * 0.8), Vector2(x, -radius * 0.8 - 5), Vector2(x + 2, -radius * 0.8)]), Color(0.75, 0.9, 0.4))
			if hp < max_hp:
				var f: float = clamp(hp / max_hp, 0.0, 1.0)
				draw_rect(Rect2(-radius, radius * 0.8 + 3, radius * 2.0, 3), Color(0.2, 0, 0))
				draw_rect(Rect2(-radius, radius * 0.8 + 3, radius * 2.0 * f, 3), Color(0.3, 0.9, 0.3))
		"spike_trap":
			draw_circle(Vector2.ZERO, radius, Color(col, 0.18))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 28, Color(col, 0.6), 1.0)
			for i in 7:
				var a := i * TAU / 7.0
				var c := Vector2.from_angle(a) * radius * 0.55
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2.5, 2), c + Vector2(0, -5), c + Vector2(2.5, 2)]), col)
		"sentry":
			draw_rect(Rect2(-7, -3, 14, 10), Color.BLACK)
			draw_rect(Rect2(-6, -2, 12, 8), col.darkened(0.3))
			draw_circle(Vector2(0, -5), 5.5, Color.BLACK)
			draw_circle(Vector2(0, -5), 4.5, col)
			if shot_t > 0.0:
				draw_line(Vector2(0, -5), shot_to - global_position, Color(col.lightened(0.5), 0.9), 2.0)
		"torch":
			var flick := 0.8 + 0.2 * sin(_age * 11.0) + 0.1 * sin(_age * 17.0)
			draw_rect(Rect2(-1.5, -2, 3, 11), Color.BLACK)
			draw_rect(Rect2(-0.5, -1, 1, 9), Color(0.55, 0.38, 0.2))
			draw_circle(Vector2(0, -5), 5.0 * flick, Color(1.0, 0.45, 0.1, 0.9))
			draw_circle(Vector2(0, -6), 3.2 * flick, Color(1.0, 0.8, 0.3))
			draw_circle(Vector2(0, -6.5), 1.6 * flick, Color(1.0, 0.98, 0.8))
			if Game.is_dark():
				draw_arc(Vector2.ZERO, light_radius, 0, TAU, 40, Color(1.0, 0.8, 0.4, 0.15), 1.0)
		"mender", "totem":
			var pulse := 0.5 + 0.5 * sin(_age * 3.0)
			draw_circle(Vector2.ZERO, radius, Color(col, 0.07 + 0.05 * pulse))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(col, 0.35), 1.0)
			draw_rect(Rect2(-3, -9, 6, 16), Color.BLACK)
			draw_rect(Rect2(-2, -8, 4, 14), col.darkened(0.2))
			draw_circle(Vector2(0, -11), 4.0, col)

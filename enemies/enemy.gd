extends CharacterBody2D
class_name Enemy

@export var speed = 20
@export var knockback_strength: float = 300.0
@export var max_health = 6.0

var health = max_health
var level = 1
var ghost := false                   # underground (the Venom Burrower's dive): nothing can hurt it
var power := 1.0                     # how much tougher than the base type (health and damage): set by the wave plan before it enters the tree
var detection_distance = 200
var is_taking_damage = false
var has_crystal = false
var center = Vector2(0, 50)
var slow_mult = 1.0
var keep_dps = 1.2      # damage per second to the keep while standing at the crystal
var knock_vel = Vector2.ZERO
# counters: every enemy type is strong against some damage and weak to other
var armor := 0.0                  # flat damage removed from every hit (min 25% still lands); "pierce" ignores it
var resist := {}                  # element -> damage multiplier (0.2 resists, 1.8 is weak)
var shield := 0.0                 # absorbs this much damage; piercing goes straight through
var swarm := false                # comes in packs: area attacks hit it much harder
var slowed_bonus := 1.0           # damage multiplier while slowed (fast enemies fear control)
var _far := false
var _far_cd := 0.0
var knock_time = 0.0
var slow_time = 0.0
var charm_time = 0.0     # >0: fights for the defenders (Charm card)
var _charm_hit := 0.0
var charm_power := 1.0   # a charmed enemy's devotion: hits this much harder (Charm card tiers)
var charm_blast := 0.0   # > 0: when it dies charmed, it bursts and hurts the enemies that are not charmed (Heartbreak)
var _charm_scale := 1.0  # (the Favourite of a Royal Decree is bigger while charmed)
var _unstick := Unstick.new()

# --- fighting back: enemies notice you, turn on you when hit, and have a move of their own ---
const SWORD_HIT := 2.0
const AGGRO_TIME := 3.0           # how long an enemy stays on you once it has noticed or been hit by you
const AGGRO_RANGE := 90.0         # walk this close IN FRONT of it and it notices you (it does not notice you behind its back)
const FRONT_DOT := 0.3            # in front = within about 70 degrees of the way it is facing
const AGGRO_COOLDOWN := 2.5       # after losing interest it ignores you for this long (so nobody can be dragged around forever)
const TURN_RATE := 3.5            # how fast it turns to face something (radians per second, roughly): a slow turn is the flanking window
const BACKSTAB := 1.3             # damage multiplier for a hit from behind
var can_aggro := true             # runners and spitters keep to their own job
var aggro_target = null
var aggro_left := 0.0
var _aggro_cd := 0.0
var _aggro_scan := randf() * 0.25
var _edge_cd := randf() * 0.25
var _off_map := false
var _alert := 0.0                 # the "!" over its head
var facing := Vector2.DOWN
var hit_from := Vector2.INF       # where the hit that is being applied came from (set by WeaponUtil.hit), for the backstab bonus
var contact_damage := 10.0           # what touching a player does (per hit); the types below set their own
var haste := 1.0                  # speed multiplier (the Hasty elite, the runner's sprint)
var ability_cd := 2.0
var _wind := 0.0                  # >0: winding up an attack (stands still, flashes, shows where it will land)
var _wind_kind := ""
var _dash_left := 0.0
var _dash_dir := Vector2.ZERO
var _dash_speed := 280.0
var _recover := 0.0               # stands still after a dash or lunge: the window to hit it
var affix := ""                   # "shielded", "hasty" or "leeching": an elite with a modifier (see apply_affix)

@onready var audio_take_damage = $TakeDamage
@onready var nav_agent = $NavigationAgent2D as NavigationAgent2D
@onready var crystal = get_parent().get_parent().get_node("Well").get_node("Crystal")

const AFFIX_COLORS := {"shielded": Color(0.75, 0.6, 1.0), "hasty": Color(1.0, 0.9, 0.3), "leeching": Color(1.0, 0.35, 0.4)}

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.5, 0.15), "ice": Color(0.5, 0.9, 1.0), "poison": Color(0.55, 0.95, 0.3),
	"earth": Color(0.85, 0.7, 0.4), "pierce": Color(0.8, 0.5, 1.0),
}

## Small pips over the enemy: filled = weak to that element, ring = resists it, grey
## square = armored (piercing ignores it). Lets you pick the right weapon or spell.
func _draw() -> void:
	var pips := []
	for el in resist:
		if ELEMENT_COLORS.has(el) and resist[el] != 1.0:
			pips.append([ELEMENT_COLORS[el], resist[el] > 1.0])
	if armor > 0.0:
		pips.append([Color(0.75, 0.75, 0.8), null])
	if swarm:
		pips.append([Color(1.0, 0.95, 0.5), "swarm"])
	if shield > 0.0:
		draw_arc(Vector2(0, -2), 11.0, -PI * 0.85, -PI * 0.15, 12, Color(0.75, 0.6, 1.0, 0.8), 1.6)
	if affix != "":
		draw_arc(Vector2(0, 2), 13.0, 0, TAU, 24, AFFIX_COLORS.get(affix, Color.WHITE), 1.8)          # an elite: a coloured ring
	if _alert > 0.0:
		draw_string_outline(ThemeDB.fallback_font, Vector2(-4, -27), "!", HORIZONTAL_ALIGNMENT_CENTER, 10.0, 18, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -27), "!", HORIZONTAL_ALIGNMENT_CENTER, 10.0, 18, Color(1.0, 0.85, 0.2))
	if slowed_bonus > 1.0:
		pips.append([Color(0.5, 0.9, 1.0), "slow"])
	for i in pips.size():
		var c: Vector2 = Vector2(2.0 + (i - (pips.size() - 1) * 0.5) * 7.0, -21.5)
		var col: Color = pips[i][0]
		var kind = pips[i][1]
		if kind == null:
			draw_rect(Rect2(c - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), col)
		elif kind is String and kind == "swarm":
			for k in 3:
				draw_circle(c + Vector2((k - 1) * 2.4, 0.8 * (k % 2)), 1.1, col)       # a cluster: weak to area attacks
		elif kind is String:
			draw_line(c + Vector2(-3, 0), c + Vector2(3, 0), col, 1.6)      # a plus: fears slows
			draw_line(c + Vector2(0, -3), c + Vector2(0, 3), col, 1.6)
		elif kind:
			draw_circle(c, 2.6, col)
		else:
			draw_arc(c, 2.4, 0, TAU, 10, col.darkened(0.1), 1.3)

func _ready():
	var art = get_script().get_script_constant_map().get("ART")      # a kind with its own sheet (enemies/kinds/): same frames layout as its base
	if art != null and has_node("Sprite2D"):
		$Sprite2D.texture = load(art)
	queue_redraw()
	add_to_group("enemy")
	add_to_group("net")
	$AnimationPlayer.play("walking")
	nav_agent.path_desired_distance = 5.0       # the defaults (20 / 10) cut corners and bump into obstacles
	nav_agent.target_desired_distance = 7.0
	max_health *= Game.enemy_health_mult()          # (the bosses you have beaten make them tougher)
	max_health *= power                             # and the level this kind of enemy belongs to (see World.ROSTER)
	contact_damage *= power
	keep_dps *= sqrt(power)
	speed += level * 2
	
	health = max_health
	facing = (center - global_position).normalized() if global_position.distance_to(center) > 1.0 else Vector2.DOWN
	# slower, staggered path updates: with 100+ enemies, 10 path queries each per second is a lot
	$NavigationTimer.wait_time = randf_range(0.3, 0.45)

## Enemies far from the keep and every player skip collision checks and just walk
## (they are crossing empty ground). Full physics resumes as they get close.
func _is_far(delta: float) -> bool:
	_far_cd -= delta
	if _far_cd <= 0.0:
		_far_cd = randf_range(0.2, 0.35)
		_far = global_position.distance_to(center) > 420.0
		if _far:
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and p.global_position.distance_to(global_position) < 320.0:
					_far = false
					break
	return _far

func _physics_process(delta):
	if charm_time > 0.0:
		_charmed(delta)
		return
	if slow_time > 0:
		slow_time -= delta
		if !is_taking_damage:
			modulate = Color(0.6, 0.8, 1.5)
		if slow_time <= 0:
			slow_mult = 1.0
			if !is_taking_damage:
				modulate = Color(1, 1, 1)
	if knock_time > 0:
		knock_time -= delta
		Game.move_on_map(self, knock_vel, delta)
		return
	_edge_cd -= delta
	if _edge_cd <= 0.0:
		_edge_cd = randf_range(0.2, 0.3)
		_off_map = !Game.in_playable(global_position)
	if _off_map:
		global_position = global_position.move_toward(center, 160.0 * delta)        # a stray on the grey ground outside the map walks back in
	_update_aggro(delta)
	if affix == "leeching" and aggro_left > 0.0 and health < max_health and !dead:
		health = minf(max_health, health + max_health * 0.05 * delta)          # it feeds while it fights you
		$ColorRect/Health.size.x = ($ColorRect.size.x - 2) * clampf(health / max_health, 0.0, 1.0)
	if aggro_left > 0.0 and aggro_target != null and charm_time <= 0.0:
		var dist: float = global_position.distance_to(aggro_target.global_position)
		if _recover > 0.0:
			_recover -= delta                          # winded after its move: it just stands there
			velocity = Vector2.ZERO
		elif !_ability(delta, aggro_target, dist):
			_chase(delta)
		_update_facing(delta, aggro_target.global_position - global_position)
		_hit_guard(delta, aggro_target, dist)
		if !has_crystal and global_position.distance_to(center) <= 14.0:
			Game.damage_keep(keep_dps * delta)
		_flip_sprite()
		return
	_wind = 0.0
	_dash_left = 0.0
	if has_crystal or global_position.distance_to(center) > 5 or crystal.state != "home":
		if _is_far(delta):
			velocity = (nav_agent.target_position - global_position).normalized() * speed * slow_mult * haste
			global_position += velocity * delta
		else:
			var next_pos = nav_agent.get_next_path_position()
			if next_pos.distance_to(global_position) < 2.0:
				next_pos = nav_agent.target_position      # no path (outside the navmesh): go straight
			var dir = to_local(next_pos).normalized()
			var go: float = speed * slow_mult * haste * (0.8 if has_crystal else 1.0)
			Game.move_on_map(self, _unstick.steer(dir, go, delta), delta)
			_unstick.after_move(self, dir, go, delta)
	
	if !has_crystal and global_position.distance_to(center) <= 14.0:
		Game.damage_keep(keep_dps * delta)
	_update_facing(delta, velocity)
	_flip_sprite()

func _flip_sprite() -> void:
	if velocity.x < 0 and $Sprite2D.scale.x > 0:
		$Sprite2D.scale.x = -1
	elif velocity.x > 0 and $Sprite2D.scale.x < 0:
		$Sprite2D.scale.x = 1

## Turn towards `v` at a limited rate (so a hit from the side or behind lands before it has turned round).
func _update_facing(delta: float, v: Vector2) -> void:
	if v.length_squared() > 1.0:
		facing = facing.slerp(v.normalized(), minf(1.0, TURN_RATE * delta))

## True if `from` (an attacker's position) is behind this enemy.
func is_behind(from: Vector2) -> bool:
	var to := from - global_position
	return to.length() > 0.1 and facing.dot(to.normalized()) < -0.3

# ---------------- awareness ----------------

func _valid_target(p) -> bool:
	return p != null and is_instance_valid(p) and !p.get("downed") and !p.get("is_in_tower")

## Everything an enemy may turn on: the players, and the guards the Guards card summons (they draw enemies like a player does).
func _aggro_candidates() -> Array:
	return get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("guard") + get_tree().get_nodes_in_group("ally").filter(func(a): return a != self)

func _nearest_player(max_dist: float, front_only := false):
	var best = null
	var best_d := max_dist
	for p in _aggro_candidates():
		if _valid_target(p):
			var d: float = p.global_position.distance_to(global_position)
			if front_only and d > 1.0 and facing.dot((p.global_position - global_position) / d) < FRONT_DOT:
				continue
			if d <= best_d:
				best = p
				best_d = d
	return best

## Start (or refresh) fighting a player for a few seconds.
func start_aggro(p) -> void:
	if !can_aggro or has_crystal or charm_time > 0.0 or !_valid_target(p):
		return
	if aggro_left <= 0.0:
		_alert = 0.6
		queue_redraw()
	aggro_target = p
	aggro_left = AGGRO_TIME

## You hit it: it turns on the nearest player (whoever it was).
func provoke() -> void:
	if can_aggro and !has_crystal and !dead:
		var p = _nearest_player(240.0)
		if p != null:
			start_aggro(p)

func _update_aggro(delta: float) -> void:
	if _alert > 0.0:
		_alert -= delta
		if _alert <= 0.0:
			queue_redraw()
	_aggro_cd -= delta
	ability_cd -= delta
	if aggro_left > 0.0:
		aggro_left -= delta
		if !_valid_target(aggro_target) or has_crystal:
			aggro_left = 0.0
		if aggro_left <= 0.0:
			aggro_target = null
			_aggro_cd = AGGRO_COOLDOWN             # lost interest: back to the objective for a while
		return
	if !can_aggro or has_crystal or _aggro_cd > 0.0:
		return
	_aggro_scan -= delta
	if _aggro_scan <= 0.0:
		_aggro_scan = 0.25
		var p = _nearest_player(AGGRO_RANGE, true)
		if p == null:
			for g in get_tree().get_nodes_in_group("guard"):             # a Captain or better draws enemies from further off, front or back
				if is_instance_valid(g) and g.pull > 0.0 and g.global_position.distance_to(global_position) <= AGGRO_RANGE + g.pull:
					p = g
					break
		if p != null:
			start_aggro(p)

## Touching a guard or a converted enemy hurts it (they are not bodies, so the hitbox that hurts players never sees them).
func _hit_guard(delta: float, t, dist: float) -> void:
	_guard_cd -= delta
	if dist <= 14.0 and _guard_cd <= 0.0 and (t.is_in_group("guard") or t.is_in_group("ally")):
		_guard_cd = 0.9
		if t.is_in_group("guard"):
			t.take_damage(global_position, contact_damage * 0.4)
		else:
			t.spell_damage(contact_damage * 0.4)
		aggro_left = maxf(aggro_left, AGGRO_TIME * 0.5)          # it keeps at the guard while it is winning

var _guard_cd := 0.0

func _chase(delta: float) -> void:
	var dir: Vector2 = (aggro_target.global_position - global_position).normalized()
	var go: float = speed * slow_mult * haste * 1.1
	Game.move_on_map(self, _unstick.steer(dir, go, delta), delta)          # chasing you does not take it off the map
	_unstick.after_move(self, dir, go, delta)

## Called each frame while it is fighting you. Return true if it moved this frame itself (a wind-up or a dash).
## The default move is a lunge: a short telegraphed dash at you. Types override this with their own.
func _ability(delta: float, t, dist: float) -> bool:
	return _lunge(delta, t, dist)

## --- shared building blocks for the moves ---
func _winding(delta: float, col: Color) -> bool:
	if _wind <= 0.0:
		return false
	_wind -= delta
	velocity = Vector2.ZERO
	modulate = col if int(_wind * 14.0) % 2 == 0 else Color.WHITE
	if _wind <= 0.0:
		modulate = Color.WHITE
		_wind = 0.0
		return false
	return true

func _dashing(delta: float) -> bool:
	if _dash_left <= 0.0:
		return false
	_dash_left -= delta
	Game.move_on_map(self, _dash_dir * _dash_speed, delta)
	if _dash_left <= 0.0:
		_recover = 0.7                                 # and then it is open for a moment
	return true

func _lunge(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		if _winding(delta, Color(1.0, 0.85, 0.3)):
			return true
		_dash_left = 0.2                               # the wind-up is over: it launches (about 56 units)
		return _dashing(delta)
	if _dashing(delta):
		return true
	if ability_cd <= 0.0 and dist > 22.0 and dist < 80.0:
		_wind = 0.7                                    # a long, clearly visible wind-up
		ability_cd = 8.0                               # and a long pause before the next one
		_dash_dir = (t.global_position - global_position).normalized()
		_dash_speed = 280.0
		WeaponFx.spawn(Game.world, "line", global_position, Color(1.0, 0.85, 0.3, 0.7), {"dir": _dash_dir, "length": 56.0, "width": 5.0, "life": 0.7})
		return true
	return false

## An elite: a stronger version with one modifier. (Waves roll these; see world.gd.)
func apply_affix(a: String) -> void:
	affix = a
	match a:
		"shielded":
			shield += 6.0 + level
		"hasty":
			haste = 1.5
	scale *= 1.12
	queue_redraw()

## Charmed enemies hunt the nearest other enemy instead of the keep.
func charm(time: float, power := 1.0, blast := 0.0) -> void:
	if dead:
		return
	charm_time = max(charm_time, time)
	charm_power = maxf(charm_power, power)
	charm_blast = maxf(charm_blast, blast)
	$Sprite2D.modulate = Color(0.6, 1.0, 0.7)
	aggro_left = 0.0                      # whatever it was fighting, it is on your side now
	aggro_target = null
	if !is_in_group("ally"):
		add_to_group("ally")              # the other enemies see it as something to fight (_aggro_candidates)

func _charmed(delta: float) -> void:
	charm_time -= delta
	_charm_hit -= delta
	if charm_time <= 0.0:
		$Sprite2D.modulate = Color(1, 1, 1)
		remove_from_group("ally")
		charm_power = 1.0
		charm_blast = 0.0
		if _charm_scale != 1.0:
			scale /= _charm_scale
			_charm_scale = 1.0
		return
	var best = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or !is_instance_valid(e) or (e.get("charm_time") != null and e.charm_time > 0.0):
			continue
		if global_position.distance_to(e.global_position) < 220.0 and (best == null or e.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = e
	if best == null:
		velocity = Vector2.ZERO
		return
	var to: Vector2 = best.global_position - global_position
	if to.length() > 14.0:
		Game.move_on_map(self, to.normalized() * speed * 1.4 * minf(charm_power, 1.15), delta)
	elif _charm_hit <= 0.0:
		_charm_hit = 0.6
		best.spell_damage((2.0 + level) * power * charm_power)
	if velocity.x < 0 and $Sprite2D.scale.x > 0:
		$Sprite2D.scale.x = -1
	elif velocity.x > 0 and $Sprite2D.scale.x < 0:
		$Sprite2D.scale.x = 1

func take_damage(damage_origin: Vector2):
	if ghost:
		return
	provoke()
	if !is_taking_damage:
		is_taking_damage = true
		modulate = Color(1, 0, 0)
		var direction = (position - damage_origin).normalized()
		apply_knockback(direction * knockback_strength)
		audio_take_damage.play()
		health -= SWORD_HIT               # the sword and pickaxe swing: 2 damage (it was 1)
		if health <= 0:
			die()
		var maxSize = $ColorRect.size.x - 2
		var ratio = health / max_health
		$ColorRect/Health.size.x = maxSize * ratio
		$DamageTimer.start()
		await $DamageTimer.timeout
		modulate = Color(1, 1, 1)
		is_taking_damage = false

var dead = false

func die() -> void:
	if dead:
		return
	dead = true
	if charm_time > 0.0 and charm_blast > 0.0:        # heartbreak: a charmed enemy that falls hurts the ones that are not charmed
		WeaponFx.spawn(Game.world, "flash", global_position, Color(1.0, 0.5, 0.7), {"radius": 30.0, "life": 0.3})
		WeaponFx.spawn(Game.world, "burst", global_position, Color(1.0, 0.5, 0.7), {"radius": 30.0, "life": 0.3})
		Sfx.play("big_hit")
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and is_instance_valid(e) and e.global_position.distance_to(global_position) <= 40.0 and !(e.get("charm_time") != null and e.charm_time > 0.0):
				e.spell_damage(charm_blast, "", true)
	Game.record_kill()
	WeaponFx.spawn(Game.world, "burst", global_position, Color(1.0, 0.85, 0.6), {"radius": 14.0, "life": 0.3})
	GoldCoin.spawn(get_parent().get_parent(), global_position, randi_range(1, 2) + level - 1)
	queue_free()

func push(vel: Vector2, time: float) -> void:
	knock_vel = vel
	knock_time = time

func apply_slow(mult: float, time: float) -> void:
	slow_mult = mult
	slow_time = max(slow_time, time)

## Armor, element resistances and slow weaknesses applied to an incoming hit.
func apply_traits(amount: float, element: String, aoe := false) -> float:
	var a := amount
	if swarm and aoe:
		a *= 1.5
	if armor > 0.0 and element != "pierce":
		# crushing weapons (hammers) break armor: it counts half
		a = maxf(a - armor * (0.5 if element == "crush" else 1.0), amount * 0.25)
	if element != "" and resist.has(element):
		a *= resist[element]
	if slow_mult < 1.0 and slowed_bonus != 1.0:
		a *= slowed_bonus
	a *= Game.mark_mult(self)                 # toxin, brittleness (Poison Cloud, Stasis Field)
	if shield > 0.0 and element != "pierce":
		var absorbed := minf(shield, a)
		shield -= absorbed
		a -= absorbed
		queue_redraw()
	if Game.is_dark() and !Game.is_lit(self):
		a *= Game.SHROUD              # at night, an enemy in the dark takes less damage until it is lit
	return a

func spell_damage(amount: float, element := "", aoe := false) -> void:
	if ghost:
		return
	if element == "fire":
		Game.light_up(self, 2.5)          # fire is bright: it lights what it hits, so it is never shrouded
	provoke()
	var backstab := false
	if hit_from != Vector2.INF:
		backstab = is_behind(hit_from)
		hit_from = Vector2.INF
	var raw := amount
	amount = apply_traits(amount, element, aoe)
	if backstab:
		amount *= BACKSTAB
		raw *= BACKSTAB
	var tint := Color.WHITE
	if amount < raw * 0.6:
		tint = Color(0.6, 0.65, 0.8)          # resisted
	elif amount > raw * 1.3:
		tint = Color(1.0, 0.5, 0.15)          # weak to it
	if backstab:
		tint = Color(1.0, 0.9, 0.3)           # a hit from behind
	DamageNumber.spawn(Game.world, global_position + Vector2(0, -14), amount, amount >= 4.0 or tint.g < 0.6, tint)
	Sfx.play("big_hit" if amount >= 4.0 else "hit")
	health -= amount
	if health <= 0:
		die()
		return
	$ColorRect/Health.size.x = ($ColorRect.size.x - 2) * clamp(health / max_health, 0.0, 1.0)
	modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.25)

func attack():
	$AnimationPlayer.play("attacking")

func apply_knockback(knockback_velocity: Vector2):
	Game.move_on_map(self, knockback_velocity, get_physics_process_delta_time())


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "attacking"):
		$AnimationPlayer.play("walking")

## The closest player (host or co-op avatar).
func _target_player():
	var best = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.get("downed") and (best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = p
	return best

func make_path() -> void:
	# The objective is the crystal. Enemies only turn on a player when they have been hit by one or walk close to one
	# (see start_aggro / provoke); the old rule that sent them after any player standing between them and the keep
	# meant they were almost always chasing a player instead.
	if has_crystal:
		nav_agent.set_target_position(crystal.exit_point)
		if global_position.distance_to(crystal.exit_point) <= 26.0:
			Game.end_run("The crystal was stolen")
	elif crystal.state == "dropped" or crystal.state == "player":
		nav_agent.set_target_position(crystal.global_position)        # loose, or a player is carrying it: go and take it
	else:
		nav_agent.set_target_position(center)
	
func _on_navigation_timer_timeout() -> void:
	make_path()

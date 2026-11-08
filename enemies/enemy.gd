extends CharacterBody2D
class_name Enemy

@export var speed = 20
@export var knockback_strength: float = 300.0
@export var max_health = 8.0

var health = max_health
var level = 1
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
var _unstick := Unstick.new()

@onready var audio_take_damage = $TakeDamage
@onready var nav_agent = $NavigationAgent2D as NavigationAgent2D
@onready var crystal = get_parent().get_parent().get_node("Well").get_node("Crystal")

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
	queue_redraw()
	add_to_group("enemy")
	add_to_group("net")
	$AnimationPlayer.play("walking")
	nav_agent.path_desired_distance = 5.0       # the defaults (20 / 10) cut corners and bump into obstacles
	nav_agent.target_desired_distance = 7.0
	max_health += level * 2
	speed += level * 2
	
	health = max_health
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
		velocity = knock_vel
		move_and_slide()
		return
	if has_crystal or global_position.distance_to(center) > 5 or crystal.state != "home":
		if _is_far(delta):
			velocity = (nav_agent.target_position - global_position).normalized() * speed * slow_mult
			global_position += velocity * delta
		else:
			var next_pos = nav_agent.get_next_path_position()
			if next_pos.distance_to(global_position) < 2.0:
				next_pos = nav_agent.target_position      # no path (outside the navmesh): go straight
			var dir = to_local(next_pos).normalized()
			var go: float = speed * slow_mult * (0.8 if has_crystal else 1.0)
			velocity = _unstick.steer(dir, go, delta)
			move_and_slide()
			_unstick.after_move(self, dir, go, delta)
	
	if !has_crystal and global_position.distance_to(center) <= 14.0:
		Game.damage_keep(keep_dps * delta)

	if velocity.x < 0 and $Sprite2D.scale.x > 0:
		$Sprite2D.scale.x = -1
	elif velocity.x > 0 and $Sprite2D.scale.x < 0:
		$Sprite2D.scale.x = 1

## Charmed enemies hunt the nearest other enemy instead of the keep.
func charm(time: float) -> void:
	charm_time = max(charm_time, time)
	$Sprite2D.modulate = Color(0.6, 1.0, 0.7)

func _charmed(delta: float) -> void:
	charm_time -= delta
	_charm_hit -= delta
	if charm_time <= 0.0:
		$Sprite2D.modulate = Color(1, 1, 1)
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
		velocity = to.normalized() * speed * 1.4
		move_and_slide()
	elif _charm_hit <= 0.0:
		_charm_hit = 0.6
		best.spell_damage(2.0 + level)
	if velocity.x < 0 and $Sprite2D.scale.x > 0:
		$Sprite2D.scale.x = -1
	elif velocity.x > 0 and $Sprite2D.scale.x < 0:
		$Sprite2D.scale.x = 1

func take_damage(damage_origin: Vector2):
	if !is_taking_damage:
		is_taking_damage = true
		modulate = Color(1, 0, 0)
		var direction = (position - damage_origin).normalized()
		apply_knockback(direction * knockback_strength)
		audio_take_damage.play()
		health -= 1
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
	if shield > 0.0 and element != "pierce":
		var absorbed := minf(shield, a)
		shield -= absorbed
		a -= absorbed
		queue_redraw()
	return a

func spell_damage(amount: float, element := "", aoe := false) -> void:
	var raw := amount
	amount = apply_traits(amount, element, aoe)
	var tint := Color.WHITE
	if amount < raw * 0.6:
		tint = Color(0.6, 0.65, 0.8)          # resisted
	elif amount > raw * 1.3:
		tint = Color(1.0, 0.5, 0.15)          # weak to it
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
	velocity = knockback_velocity
	move_and_slide()


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "attacking"):
		$AnimationPlayer.play("walking")

## The closest player (host or co-op avatar).
func _target_player():
	var best = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and (best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = p
	return best

func make_path() -> void:
	var target = _target_player()
	if target == null:
		return
	var player_position = target.global_position
	if has_crystal:
		nav_agent.set_target_position(crystal.exit_point)
		if global_position.distance_to(crystal.exit_point) <= 26.0:
			Game.end_run("The crystal was stolen")
	elif crystal.state == "dropped":
		nav_agent.set_target_position(crystal.global_position)
	elif target.is_in_tower:
		nav_agent.set_target_position(center)
	elif player_position.distance_to(center) < global_position.distance_to(center) or crystal.state == "player":
		nav_agent.set_target_position(target.global_position)
	else:
		nav_agent.set_target_position(center)
	
func _on_navigation_timer_timeout() -> void:
	make_path()

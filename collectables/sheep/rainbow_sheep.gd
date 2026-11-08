extends CharacterBody2D
class_name RainbowSheep
## A rare rainbow sheep. It wanders, bolts when a player gets close (sprinting, then tiring
## for a moment so a fast hunter can catch it), and escapes after about a minute. Kill it
## and it drops gold, resources from the open sectors and sometimes a card chest.
## It is not an enemy: turrets and sentries ignore it (group "critter"), but every weapon,
## spell and the starting sword can hit it.

## Art: the same sheep as the one standing at the well (sheep.png, 3 x 3 frames of 12x12, same size and
## the same idle animation), so the sheep you chase is the sheep you already know.
const TEXTURE := "res://collectables/sheep/sheep.png"
const FLEE_RANGE := 150.0

var health := 14.0
var max_health := 14.0
var hit_radius := 7.0
var is_taking_damage := false      # the starting sword's hitbox asks for this
var slow_mult := 1.0
var dead := false
var life := 60.0                   # seconds before it runs off
var age := 0.0                     # drives the rainbow shimmer (also on co-op puppets)
var panic := 0.0
var _heading := Vector2.RIGHT
var _timer := 0.0
var _run := 0.0
var _tired := 0.0
var _iframes := 0.0
var _slow_t := 0.0
var _flash := 0.0
var _unstick := Unstick.new()
var _sprite: Sprite2D

func _ready() -> void:
	add_to_group("critter")
	add_to_group("net")
	collision_layer = 2            # the sword's hitbox looks for layer 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.texture = load(TEXTURE)
	_sprite.hframes = 3                   # 12x12 frames, 3 across and 3 down, like the sheep at the well
	_sprite.vframes = 3
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(1.0, 1.0)
	_sprite.position = Vector2.ZERO
	add_child(_sprite)
	z_index = 3
	_unstick.chip = false          # a sheep walks around trees instead of chewing them
	_heading = Vector2.from_angle(randf() * TAU)
	_update_visual()

func _update_visual() -> void:
	if _sprite == null:
		return
	_sprite.frame = int(age * 10.0) % 9       # the well sheep plays its 9 frames at 10 per second
	_sprite.modulate = Color(1.6, 1.6, 1.6) if _flash > 0.0 else Color.WHITE

func net_tick(_delta: float) -> void:
	_update_visual()

func _nearest_player():
	var best = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.get("is_in_tower") and !p.get("downed") and (best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = p
	return best

func _physics_process(delta: float) -> void:
	if dead or Rep.is_puppet(self):
		return
	age += delta
	life -= delta
	_flash = maxf(0.0, _flash - delta)
	panic = maxf(0.0, panic - delta)
	_iframes = maxf(0.0, _iframes - delta)
	is_taking_damage = _iframes > 0.0
	if _slow_t > 0.0:
		_slow_t -= delta
		if _slow_t <= 0.0:
			slow_mult = 1.0
	if life <= 0.0 or global_position.distance_to(Vector2(2, 4)) < 22.0:      # it hops into the well and is gone
		_escape()
		return
	var p = _nearest_player()
	var spd := 38.0
	_timer -= delta
	if p != null and p.global_position.distance_to(global_position) < FLEE_RANGE and _tired <= 0.0:
		_run += delta
		if _timer <= 0.0:
			_timer = 0.35
			_heading = (global_position - p.global_position).normalized().rotated(randf_range(-0.7, 0.7))
		spd = 92.0 + (28.0 if panic > 0.0 else 0.0)
		if _run > 4.0:                 # out of breath: a short rest
			_tired = 1.5
			_run = 0.0
	elif _tired > 0.0:
		_tired -= delta
		spd = 26.0
	else:
		_run = maxf(0.0, _run - delta)
		if _timer <= 0.0:
			_timer = randf_range(1.2, 2.6)
			_heading = Vector2.from_angle(randf() * TAU)
	# stay inside the open part of the map
	if global_position.length() > 1050.0 or !(Game.sector_at(global_position) in Game.sectors_unlocked):
		_heading = (-global_position).normalized()
	velocity = _unstick.steer(_heading, spd * slow_mult, delta)
	move_and_slide()
	_unstick.after_move(self, _heading, spd * slow_mult, delta)
	_update_visual()
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0, 5), 4.5, Color(0, 0, 0, 0.25))
	if health < max_health and !dead:
		draw_rect(Rect2(-8, -13, 16, 2), Color(0.2, 0, 0))
		draw_rect(Rect2(-8, -13, 16.0 * clampf(health / max_health, 0.0, 1.0), 2), Color(1.0, 0.4, 0.7))

# ---------- the hit API every weapon expects ----------

func take_damage(_origin: Vector2) -> void:         # the starting sword
	_hurt(2.0)

func spell_damage(amount: float, _element := "", _aoe := false) -> void:
	_hurt(amount)

func apply_slow(mult: float, time: float) -> void:
	slow_mult = maxf(0.4, mult)
	_slow_t = maxf(_slow_t, time)

func push(vel: Vector2, _time: float) -> void:
	velocity += vel * 0.3

func _hurt(amount: float) -> void:
	if dead:
		return
	health -= amount
	_flash = 0.15
	panic = 1.5
	_iframes = 0.2
	DamageNumber.spawn(Game.world, global_position + Vector2(0, -14), amount, false, Color(1.0, 0.6, 1.0))
	Sfx.play("hit")
	if health <= 0.0:
		_die()

func _die() -> void:
	dead = true
	var world := Game.world
	load("res://collectables/gold/gold_coin.gd").spawn(world, global_position, randi_range(8, 12))
	var types := ["stone", "stick"]
	var sm = load("res://world/sector_manager.gd")
	for id in Game.sectors_unlocked:
		if sm.SECTORS.has(id) and sm.SECTORS[id].get("resource", "") != "":
			types.append(sm.SECTORS[id].resource)
	for i in randi_range(5, 7):
		var pick = load("res://collectables/collectable.tscn").instantiate()
		pick.item_type = types.pick_random()
		pick.position = global_position + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		world.add_child.call_deferred(pick)
	# better than a chest: a weapon rolled one step above chest odds, and a better card chest more often
	var wpick = load("res://collectables/collectable.tscn").instantiate()
	wpick.item_type = Game.weapon_pool().pick_random()
	var rolled := Game.roll_weapon_entry(wpick.item_type, Game.chest_level(1))
	wpick.bonus = Game.weapon_bonus(rolled)
	wpick.twist = Game.entry_twist(rolled)
	wpick.fixed = true
	wpick.position = global_position + Vector2(randf_range(-12, 12), randf_range(-4, 12))
	world.add_child.call_deferred(wpick)
	if randf() < 0.6:
		var chest = load("res://collectables/chest/chest.gd").new()
		chest.kind = "card"
		chest.boost = 1
		chest.position = global_position + Vector2(0, 10)
		world.add_child.call_deferred(chest)
	for i in 6:
		WeaponFx.spawn(world, "ring", global_position, Color.from_hsv(i / 6.0, 0.8, 1.0), {"radius": 10.0 + 7.0 * i, "life": 0.45 + 0.05 * i})
	Sfx.play("big_hit")
	Game.announce.emit("The rainbow sheep dropped loot!")
	queue_free()

func _escape() -> void:
	dead = true
	collision_layer = 0
	remove_from_group("critter")
	WeaponFx.spawn(Game.world, "burst", global_position, Color(1, 1, 1), {"radius": 12.0, "life": 0.3})
	Game.announce.emit("The rainbow sheep got away...")
	queue_free()

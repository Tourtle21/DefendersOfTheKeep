extends CharacterBody2D

@export var controls: Resource
@export var item_info: Resource

var speed = 100.0
var knockback_strength = 600.0
var rotation_speed = 0.2
var swing_distance = PI / 2
var swinging = false
var initial_position = position

var is_using_item = false
var is_taking_damage = false
var is_in_tower = false
var shield_time = 0.0
var remote_controlled = false        # true for a co-op client's avatar on the host
var remote_input = {"move": Vector2.ZERO, "aim": Vector2.ZERO}
var remote_hp = 228.0
const RESPAWN_TIME := 30.0          # seconds out of the fight after you fall
var downed := false                 # fallen: out of the fight until respawn_left runs out
var respawn_left := 0.0
var _saved_layers := [0, 0]
var carried = {}                 # co-op avatars: resources they hold until they reach a tower
var has_crystal := false          # carrying the keep's crystal back to the Well
var weapon_slots: Array = []     # co-op avatars: weapon ids they carry (max 3)
var active_slot = 0
var base_zoom = 5.0      # camera zoom before the UI-scale compensation (5 = normal, 2 = wide view in a tower)
var dash_velocity = Vector2.ZERO
var dash_time = 0.0
var speed_mult = 1.0
var parry_time = 0.0
var on_parry = Callable()
var _saved_mask = 1

var pickaxe_initial_rotation = 0

var pickaxe_starting_position = 0
var pickaxe_starting_rotation = 0

var walking_playback_position = 0.0

const MAX_RADIUS = 120
const CENTER = Vector2(0, 0)

@onready var item: Node2D = null
@onready var item_animation_player: AnimationPlayer = null
@onready var right_hand: Node2D = $RightHand
@onready var audio_take_damage = $TakeDamage

func _ready():
	$AnimationPlayer.play("idle")
	initial_position = position
	speed = speed * (1.0 + Game.bonus("move_speed"))

## Where this player is aiming, in world coordinates (local mouse, or the client's aim).
func aim_point() -> Vector2:
	if remote_controlled:
		return remote_input.aim
	return Pad.world_mouse(self)

## You fell: out of the fight for RESPAWN_TIME seconds while the keep carries on, then back at the keep with full health.
func fall() -> void:
	if downed:
		return
	downed = true
	respawn_left = RESPAWN_TIME
	if is_in_tower:
		Game.exit_base(self)
		is_in_tower = false
	is_using_item = false
	velocity = Vector2.ZERO
	dash_time = 0.0
	_aim_start_ms.clear()
	_saved_layers = [collision_layer, collision_mask]
	collision_layer = 0                 # nothing can touch, target or pick up after a fallen player
	collision_mask = 0
	visible = false
	global_position = Vector2(0, 40)    # the camera watches the keep while you wait
	Sfx.play("hurt")
	Game.announce.emit("You fell! Back in %d seconds." % int(RESPAWN_TIME))

func respawn() -> void:
	downed = false
	respawn_left = 0.0
	collision_layer = _saved_layers[0]
	collision_mask = _saved_layers[1]
	visible = true
	modulate = Color(1, 1, 1)
	is_taking_damage = false
	global_position = Vector2(20, 0)
	shield_time = 2.5                   # a moment of safety
	if remote_controlled:
		remote_hp = 228.0
	else:
		get_parent().get_node("Hud/Control2/ColorRect/Health").size.x = 228.0
	WeaponFx.spawn(get_parent(), "ring", global_position, Color(1.0, 0.95, 0.6), {"radius": 22.0, "life": 0.5})
	Sfx.play("unlock", 0.0, 1.3)
	Game.announce.emit("You are back in the fight!")

func _physics_process(delta):
	if downed:
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn()
		return
	$Camera2D.zoom = Vector2.ONE * base_zoom / Game.ui_scale
	if is_in_tower and !is_taking_damage:
		heal(8.0 * delta)      # the keep slowly mends whoever is inside
	if parry_time > 0.0:
		parry_time -= delta
	if shield_time > 0:
		shield_time -= delta
		if !is_taking_damage:
			modulate = Color(0.6, 0.8, 1.6)
			if shield_time <= 0:
				modulate = Color(1, 1, 1)
	var mouse_position = to_local(aim_point())
	if mouse_position.x > 0:
		scale.x = 1
	else:
		scale.x = -1
		
	if is_using_item and item_animation_player != null:
		item_animation_player.play("use_item")
		
	process_movement(delta)
	
func dash(dir: Vector2, distance: float, time: float) -> void:
	dash_velocity = dir.normalized() * distance / time
	if dash_time <= 0.0:
		_saved_mask = collision_mask
	collision_mask = collision_mask & ~2      # slip through enemies (layer 2) while dashing
	dash_time = time
	shield_time = max(shield_time, time + 0.05)   # untouchable while dashing

func shake(amount: float, time := 0.2) -> void:
	var cam = get_node_or_null("Camera2D")
	if cam == null:
		return
	var tw = create_tween()
	for i in 5:
		tw.tween_property(cam, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount, time / 5.0)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)

func blink(offset: Vector2) -> void:
	move_and_collide(offset)

var _aim_start_ms := {}   # slot ("ability", "dash", "ultimate") -> ms when the key went down

## Seconds a cast key has been held (0 if not held). Weapons show their aim preview
## once this passes 1.0 and the slot has something to aim.
func aim_time(slot: String) -> float:
	if !_aim_start_ms.has(slot):
		return 0.0
	return (Time.get_ticks_msec() - _aim_start_ms[slot]) / 1000.0

func _can_cast() -> bool:
	return !downed and item != null and !Game.local_in_base() and !Game.draft_active and !has_crystal

var _crystal_note_ms := 0

## Carrying the crystal: both hands are full. Say so (not on every click).
func _crystal_busy_note() -> void:
	if Time.get_ticks_msec() - _crystal_note_ms > 2500:
		_crystal_note_ms = Time.get_ticks_msec()
		Game.announce.emit("You are carrying the crystal: no weapons or abilities. Get it to the Well!")

func _release_cast(slot: String) -> void:
	if !_aim_start_ms.has(slot):
		return
	_aim_start_ms.erase(slot)
	if !_can_cast():
		return
	match slot:
		"ability":
			if item.has_method("use_ability"):
				item.use_ability()
		"dash":
			if item.has_method("use_dash"):
				item.use_dash()
		"ultimate":
			if item.has_method("use_ultimate"):
				item.use_ultimate()

func _input(event):
	if downed:
		return
	if remote_controlled:
		return
	# Hold a key to aim, release to cast. A quick tap casts right away at the cursor.
	if has_crystal and (event.is_action_pressed("dash") or event.is_action_pressed("ultimate") or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])):
		_crystal_busy_note()
	if event.is_action_pressed("dash") and _can_cast():
		_aim_start_ms["dash"] = Time.get_ticks_msec()
	elif event.is_action_released("dash"):
		_release_cast("dash")
	if event.is_action_pressed("ultimate") and _can_cast():
		_aim_start_ms["ultimate"] = Time.get_ticks_msec()
	elif event.is_action_released("ultimate"):
		_release_cast("ultimate")
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_aim_start_ms.clear()      # cancel any aim
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and item != null:
		if item.get("hold_ability"):
			# charge-style abilities keep press = start, release = finish
			if event.pressed:
				if _can_cast() and item.has_method("use_ability"):
					item.use_ability()
			elif item.has_method("release_ability"):
				item.release_ability()
		elif event.pressed:
			if _can_cast():
				_aim_start_ms["ability"] = Time.get_ticks_msec()
		else:
			_release_cast("ability")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed and item != null and item.has_method("release_item"):
		item.release_item()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and item != null and !Game.local_in_base() and !Game.draft_active and !has_crystal:
		item.use_item()
		is_using_item = true
	
var _last_move := Vector2.ZERO
var _last_move_ms := -10000

## Which way a dash goes: the way you are moving (or were a moment ago). Standing still, it falls
## back to `fallback` (the cursor), so a dash always goes somewhere.
func dash_dir(fallback: Vector2) -> Vector2:
	var d: Vector2 = remote_input.move if remote_controlled else Input.get_vector(controls.left, controls.right, controls.up, controls.down)
	if d.length() > 0.1:
		return d.normalized()
	if _last_move.length() > 0.1 and Time.get_ticks_msec() - _last_move_ms < 400:
		return _last_move
	return fallback.normalized() if fallback.length() > 0.01 else Vector2.RIGHT

func process_movement(delta):
	var input_direction = remote_input.move if remote_controlled else Input.get_vector(controls.left, controls.right, controls.up, controls.down)
	if input_direction.length() > 0.1:
		_last_move = input_direction.normalized()
		_last_move_ms = Time.get_ticks_msec()
	if remote_controlled and is_in_tower:
		input_direction = Vector2.ZERO       # a co-op avatar stays put while it is in the keep
	if (input_direction.x != 0 or input_direction.y != 0):
		$AnimationPlayer.play("walking")
		if $Walking.playing == false:
			$Walking.play(walking_playback_position)
	else:
		$AnimationPlayer.play("idle")
		if $Walking.playing == true:
			walking_playback_position = $Walking.get_playback_position()
			$Walking.stop()
			
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_velocity
		if dash_time <= 0.0:
			collision_mask = _saved_mask      # solid to enemies again
	else:
		velocity = input_direction * speed * speed_mult * Hazard.slow_at(get_tree(), global_position)
	var new_position = position + velocity * delta
	# Stay inside the keep circle except through gates opened by defeating bosses.
	if CENTER.distance_to(new_position) > MAX_RADIUS:
		var direction_to_center = (new_position - CENTER).normalized()
		if !Game.gate_open(direction_to_center.angle()):
			# never snap a player who is already outside back to the keep (that read as a teleport to spawn): hold their current radius
			var hold_radius := maxf(float(MAX_RADIUS), minf(CENTER.distance_to(position), CENTER.distance_to(new_position)))
			if CENTER.distance_to(position) > MAX_RADIUS + 2.0:
				hold_radius = minf(CENTER.distance_to(position), CENTER.distance_to(new_position))
			var clamped_position = CENTER + direction_to_center * hold_radius
			velocity = (clamped_position - position) / delta  # Adjust velocity

	move_and_slide()

func equip_item(new_item) -> void:
	if (item != null):
		item.queue_free()
	var item_path = load(new_item.path)
	item = item_path.instantiate()
	if "bonus_tier" in item:                       # this copy's own tier bonus and twist
		item.bonus_tier = int(new_item.get("bonus", 0))
		item.twist = str(new_item.get("twist", ""))
	item_animation_player = null
	item.equip()
	right_hand.add_child(item)	
	if item.has_node("AnimationPlayer"):
		item_animation_player = item.get_node("AnimationPlayer")

func _remote_damage() -> void:
	if is_taking_damage:
		return
	is_taking_damage = true
	modulate = Color(1, 0, 0)
	remote_hp -= 30.0
	if remote_hp <= 0.0:
		fall()                         # co-op avatars fall too, and come back at the keep after the respawn time
		return
	await get_tree().create_timer(0.5).timeout
	modulate = Color(1, 1, 1)
	is_taking_damage = false

func heal(amount: float) -> void:
	if remote_controlled:
		remote_hp = min(remote_hp + amount, 228.0)
		return
	var health_rect = get_parent().get_node("Hud/Control2/ColorRect/Health")
	health_rect.size.x = min(health_rect.size.x + amount, 228.0)

func take_damage(damage_origin: Vector2):
	if downed:
		return
	if parry_time > 0.0 and on_parry.is_valid():
		parry_time = 0.0
		on_parry.call(damage_origin)
		return
	if shield_time > 0:
		return
	if remote_controlled:
		_remote_damage()
		return
	if !is_taking_damage:
		Game.player_hurt.emit()
		is_taking_damage = true
		modulate = Color(1, 0, 0)
		var direction = (position - damage_origin).normalized()
		apply_knockback(direction * knockback_strength)
		var x_size = get_parent().get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x
		get_parent().get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x = x_size - 30
		audio_take_damage.play()
		if x_size <= 18:
			fall()                      # no longer the end of the run: the keep fights on and you are back in 30 seconds
		$DamageTimer.start()
		await $DamageTimer.timeout
		modulate = Color(1, 1, 1)
		is_taking_damage = false
func apply_knockback(knockback_velocity: Vector2):
	velocity = knockback_velocity
	# Apply knockback while respecting collisions
	move_and_slide()

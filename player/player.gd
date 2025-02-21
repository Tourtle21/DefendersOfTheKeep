extends CharacterBody2D

@export var controls: Resource

var speed = 100.0
var knockback_strength = 600.0
var rotation_speed = 0.2
var swing_distance = PI / 2
var swinging = false
var initial_position = position

var is_using_item = false
var is_taking_damage = false

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

func _physics_process(delta):
	var mouse_position = get_local_mouse_position()
	if mouse_position.x > 0:
		scale.x = 1
	else:
		scale.x = -1
		
	if is_using_item and item_animation_player != null:
		item_animation_player.play("use_item")
		
	process_movement(delta)
	
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and item != null:
		item.use_item()
		is_using_item = true
	
func process_movement(delta):
	var input_direction = Input.get_vector(controls.left, controls.right, controls.up, controls.down)
	if (input_direction.x != 0 or input_direction.y != 0):
		$AnimationPlayer.play("walking")
		if $Walking.playing == false:
			$Walking.play(walking_playback_position)
	else:
		$AnimationPlayer.play("idle")
		if $Walking.playing == true:
			walking_playback_position = $Walking.get_playback_position()
			$Walking.stop()
			
	velocity = input_direction * speed
	var new_position = position + velocity * delta
	var min_angle = (2 * PI) / 3
	var max_angle = PI / 3
	# Check if the new position would go beyond the max radius
	if CENTER.distance_to(new_position) > MAX_RADIUS:
		var direction_to_center = (new_position - CENTER).normalized()
		if (direction_to_center.angle() > min_angle or direction_to_center.angle() < max_angle):
			if CENTER.distance_to(new_position) > MAX_RADIUS + 10:
				var angle = direction_to_center.angle()
				if angle < min_angle:
					angle = max_angle
				elif angle > max_angle:
					angle = min_angle
				var clamped_position = CENTER + Vector2(cos(angle), sin(angle)) * CENTER.distance_to(new_position)
				velocity = (clamped_position - position) / delta  # Adjust velocity
			else: 
				var clamped_position = CENTER + direction_to_center * MAX_RADIUS
				velocity = (clamped_position - position) / delta  # Adjust velocity

	move_and_slide()

func equip_item(new_item) -> void:
	if (item != null):
		item.queue_free()
	item = new_item
	item_animation_player = null
	item.equip()
	right_hand.add_child(item)	
	if item.has_node("AnimationPlayer"):
		item_animation_player = item.get_node("AnimationPlayer")

func take_damage(damage_origin: Vector2):
	if !is_taking_damage:
		is_taking_damage = true
		modulate = Color(1, 0, 0)
		var direction = (position - damage_origin).normalized()
		apply_knockback(direction * knockback_strength)
		var x_size = get_parent().get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x
		get_parent().get_node("Hud").get_node("Control2").get_node("ColorRect").get_node("Health").size.x = x_size - 30
		audio_take_damage.play()
		if x_size <= 18:
			get_tree().quit()
		$DamageTimer.start()
		await $DamageTimer.timeout
		modulate = Color(1, 1, 1)
		is_taking_damage = false
func apply_knockback(knockback_velocity: Vector2):
	velocity = knockback_velocity
	# Apply knockback while respecting collisions
	move_and_slide()

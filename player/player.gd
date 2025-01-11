extends CharacterBody2D

@export var controls: Resource

var speed = 300.0
var rotation_speed = 0.2
var swing_distance = PI / 2
var swinging = false
var initial_position = position

var pickaxe_initial_rotation = 0

var pickaxe_starting_position = 0
var pickaxe_starting_rotation = 0

func _ready():
	initial_position = position
	pickaxe_starting_rotation = $Pickaxe.rotation
	pickaxe_starting_position = $Pickaxe.position

func _physics_process(_delta):
	if (swinging):
		var offset = $Pickaxe.position # Get the offset (relative position)
		# Apply rotation around the parent’s center (in radians)
		var angle = $Pickaxe.rotation + rotation_speed  # Increment the angle
		var new_offset = offset.rotated(rotation_speed) # Rotate the offset
		$Pickaxe.rotation += rotation_speed
		# Update the object’s position
		$Pickaxe.position = new_offset
		
		if (abs($Pickaxe.rotation - pickaxe_initial_rotation)) >= swing_distance * 2:
			$Pickaxe.rotation = pickaxe_starting_rotation
			$Pickaxe.position = pickaxe_starting_position
			swinging = false
		
	
	process_movement()
	
func _input(event):
	# Detect mouse click event (left click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !swinging:
		# Trigger an action when the left mouse button is clicked
		var center = Vector2(get_viewport().size / 2)
		var mouse_position = center - event.position
		var direction = (mouse_position - $Pickaxe.position).normalized()
		var rotation = -swing_distance  # -45 degrees in radians
		direction = direction.rotated(rotation)
		# Move the pickaxe 1 unit in the new rotated direction
		$Pickaxe.rotation = direction.angle() + (5 * PI / 4)
		$Pickaxe.position -= direction * 15
		pickaxe_initial_rotation = $Pickaxe.rotation
		swinging = true
	
func process_movement():
	var input_direction = Input.get_vector(controls.left, controls.right, controls.up, controls.down)
	velocity = input_direction * speed
	$Pickaxe.z_index = position.y
	z_index = position.y
	move_and_slide()

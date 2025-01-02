extends CharacterBody2D

@export var controls: Resource

var speed = 300.0


func _physics_process(_delta):
	process_movement()
	
func process_movement():
	var input_direction = Input.get_vector(controls.left, controls.right, controls.up, controls.down)
	velocity = input_direction * speed
	
	move_and_slide()

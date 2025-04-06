extends Area2D

var y = 0
var moving = false
var direction = 1
var timer = 0
var speed = 15
var starting_position = 20
var ending_position = -20

var new_parent : Node2D
var being_held = false
var dropped = false

func activate():
	direction = 1
	moving = true
	if position.y >= starting_position:
		position.y = starting_position - 1

func deactive():
	direction = -1
	moving = true
	if position.y <= ending_position:
		position.y = ending_position + 1

func _ready():
	visible = false
	$AnimationPlayer.stop()  # Ensure the animation doesn't play yet

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !being_held and !dropped:
		if moving and position.y > ending_position and position.y < starting_position:
			position.y -= speed * delta * direction
			if position.y <= ending_position or position.y >= starting_position:
				moving = false
			
		if position.y < 15:
			visible = true
			$AnimationPlayer.play("spin")
		else:
			visible = false
			$AnimationPlayer.stop()
		if position.y <= ending_position and !being_held:
			if (len(get_overlapping_bodies())):
				new_parent = get_overlapping_bodies()[0]
				being_held = true
	elif being_held:
		if (new_parent):
			z_index = 1
			position = new_parent.position - Vector2(1, 30)
			new_parent.has_crystal = true
		else:
			z_index = 0
			being_held = false
			dropped = true
	else:
		if (get_overlapping_bodies()):
			new_parent = get_overlapping_bodies()[0]
			dropped = false
			being_held = true
		
		

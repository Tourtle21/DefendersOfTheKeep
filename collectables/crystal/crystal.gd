extends Node2D

var y = 0
var moving = false
var direction = 1
var timer = 0

func activate():
	direction = 1
	moving = true
	if position.y >= 145:
		position.y = 144

func deactive():
	direction = -1
	moving = true
	if position.y <= -150:
		position.y = -149

func _ready():
	visible = false
	$AnimationPlayer.stop()  # Ensure the animation doesn't play yet

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if moving and position.y > -150 and position.y < 145:
		position.y -= 100 * delta * direction
		if position.y <= -150 or position.y >= 145:
			moving = false
		
	if position.y < 80:
		visible = true
		$AnimationPlayer.play("spin")
	else:
		visible = false
		$AnimationPlayer.stop()

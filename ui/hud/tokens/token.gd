extends Control

var token
var upgrading = false
var times_flipped = 0
var level = 0
var amount = 0
var quadrent = 0

func _ready() -> void:
	$Sprite2D.texture = load("res://ui/hud/tokens/" + token.name + "_token.png")
	$Level.text = str(token.level)
	$Amount.text = str(token.amount)
	$Quadrent.text = str(token.quadrent)
	
func _on_mouse_entered() -> void:
	if (times_flipped == 0 and !get_parent().get_parent().get_parent().finished):
		modulate = Color(1.5, 1.5, 0.5)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	if (times_flipped == 0 and event.is_pressed() and !get_parent().get_parent().get_parent().finished):
		get_parent().get_parent().get_parent().pick_token(token.id)
		modulate = Color.WHITE
		$AnimationPlayer.play("flip")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (times_flipped < 3):
		$AnimationPlayer.play("flip")
	if (times_flipped == 3):
		$AnimationPlayer.play("half_flip")
	times_flipped += 1
	if (times_flipped == 5):
		$Level.visible = true
		$Amount.visible = true
		$Quadrent.visible = true
		
func display_upgrades() -> void:
	upgrading = true
	if token.type == "enemy":
		tooltip_text = "Summon " + str(token.amount) + " " + token.name + "(s)"
	else:
		tooltip_text = token.description
	$Level.upgrade()
	$Amount.upgrade()
	

func upgrade(type) -> void:
	upgrading = false
	get_parent().get_parent().get_parent().upgrade(type, token.id)
	$Level.stop_upgrade()
	$Amount.stop_upgrade()

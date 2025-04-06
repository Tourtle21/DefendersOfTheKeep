extends Label

@export var type = "level"

func _on_mouse_entered() -> void:
	if get_parent().upgrading:
		modulate = Color(1.5, 1.5, 0)

func _on_mouse_exited() -> void:
	if get_parent().upgrading:
		modulate = Color(3, 0, 0)
		
func _on_gui_input(event: InputEvent) -> void:
	if (event.is_pressed() and get_parent().upgrading):
		text = str(int(text) + 1)
		get_parent().upgrade(type)

func upgrade() -> void:
	get_parent().upgrading = true
	modulate = Color(3, 0, 0)
	
func stop_upgrade() -> void:
	modulate = Color.WHITE

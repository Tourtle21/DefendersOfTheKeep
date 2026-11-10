extends Enemy

func _ready() -> void:
	max_health = 3.0
	contact_damage = 6.0
	speed = 40
	keep_dps = 1.6
	super()

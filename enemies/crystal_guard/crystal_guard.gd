extends Enemy
## Crystal guard (caverns): armored and brittle against earth. A crystal shield soaks
## the first few points of damage and regrows after a pause; piercing damage ignores
## both the shield and the armor.

const SHIELD_MAX := 4.0
var _regrow := 0.0

func _ready() -> void:
	max_health = 22.0
	speed = 16
	keep_dps = 4.0
	armor = 2.5
	resist = {"earth": 1.8, "ice": 0.7}
	shield = SHIELD_MAX
	super()
	scale = Vector2(1.3, 1.3)

func _physics_process(delta: float) -> void:
	if shield <= 0.0:
		_regrow += delta
		if _regrow >= 8.0:
			_regrow = 0.0
			shield = SHIELD_MAX
			queue_redraw()
	super(delta)

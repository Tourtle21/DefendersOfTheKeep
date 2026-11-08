extends Enemy
## Brute: big, slow and very tanky. Shrugs off small hits, so burst it down or kite it.

func _ready() -> void:
	max_health = 24.0
	speed = 14
	keep_dps = 4.0
	armor = 2.0               # shrugs off weak hits: use heavy single hits or piercing damage
	knockback_strength = 120.0
	super()
	scale = Vector2(1.5, 1.5)
	$Sprite2D.modulate = Color(0.75, 0.5, 0.95)

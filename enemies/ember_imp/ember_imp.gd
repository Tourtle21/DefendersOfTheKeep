extends Enemy
## Ember imp (volcano): fast and fiery. Fire does almost nothing; ice shatters it.
## When it dies it leaves a patch of embers that burns whoever stands in it.

func _ready() -> void:
	max_health = 6.0
	speed = 56
	resist = {"fire": 0.2, "ice": 1.8}
	super()

func die() -> void:
	var was_dead: bool = dead
	var pos := global_position
	super()
	if !was_dead:
		WeaponUtil.patch(Game.world, pos, "burn", 22.0, Color(1.0, 0.4, 0.1, 0.5), 3.0)

## Fire trail: while it fights you it leaves burning ground behind it (it only burns players, not other enemies).
var _trail := 0.0

func _ability(delta: float, _t, _dist: float) -> bool:
	_trail -= delta
	if _trail <= 0.0:
		_trail = 0.45
		var h := Hazard.new()
		h.kind = "burn"
		h.radius = 13.0
		h.color = Color(1.0, 0.4, 0.1, 0.5)
		h.lifetime = 2.5
		h.hurts_enemies = false
		h.player_damage = 8.0
		h.position = global_position
		Game.world.add_child.call_deferred(h)
	return false

extends Enemy
## Frost imp (tundra): fast, fragile, immune-ish to ice but burns easily. Fire it down.
## When it dies it leaves a patch of freezing ground: kill it at range.

func _ready() -> void:
	max_health = 5.0
	contact_damage = 8.0
	speed = 60
	resist = {"ice": 0.2, "fire": 1.8}
	super()

func die() -> void:
	var was_dead: bool = dead
	var pos := global_position
	super()
	if !was_dead:
		WeaponUtil.patch(Game.world, pos, "slow", 26.0, Color(0.7, 0.9, 1.0, 0.5), 4.0, 0.45)

## Chill bolt: it stops, shivers, then throws a bolt that slows whoever it hits.
func _ability(delta: float, t, dist: float) -> bool:
	if _wind > 0.0:
		if _winding(delta, Color(0.6, 0.85, 1.0)):
			return true
		EnemyProjectile.fire(Game.world, global_position, _dash_dir, 120.0, 10.0, Color(0.6, 0.85, 1.0), 6.0, 2.0, 0.0, 0.5)
		return false
	if ability_cd <= 0.0 and dist >= 30.0 and dist <= 150.0:
		_wind = 0.45
		ability_cd = 4.5
		_dash_dir = (t.global_position - global_position).normalized()
		return true
	return false

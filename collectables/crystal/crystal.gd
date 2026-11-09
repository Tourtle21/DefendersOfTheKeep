extends Area2D
## The keep's crystal, in the Well. It is lowered (hidden) until the pressure plate raises it;
## once it is fully up, an enemy touching it steals it (the original behaviour). NEW: the thief
## carries it toward the map edge (reaching the edge loses the run), the base powers are offline
## while the crystal is away (no casting, mana, card draws, repairs, upgrades, turret fire), and
## killing the thief drops it for a player to pick up and carry back to the Well.
## States: "home" (raising / raised / lowered), "carried" (enemy thief), "dropped", "player".

const EXIT_RADIUS := 1250.0
const PICKUP_RANGE := 16.0

var state := "home"
var exit_point := Vector2.ZERO         # where the thief is heading
var age := 0.0
var y = 0
var moving = false
var direction = 1
var speed = 15
var starting_position = 20            # lowered (hidden)
var ending_position = -20             # raised (visible, can be stolen)
var being_held = false                # kept for the old code paths: true whenever it is away
var dropped = false
var _carrier: Node

func _ready():
	add_to_group("net")
	set_meta("net_own", true)          # replicated on its own even though it lives inside the Well scene
	visible = false
	$AnimationPlayer.stop()

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

func _set_state(s: String) -> void:
	state = s
	being_held = s != "home"
	dropped = s == "dropped"
	Game.crystal_state = s

func _enemy_here():
	for b in get_overlapping_bodies():
		if is_instance_valid(b) and b.is_in_group("enemy") and "has_crystal" in b and !b.is_queued_for_deletion() and !b.get("dead") and !b.get("has_crystal"):      # (bosses cannot carry it)
			return b
	return null

func _physics_process(delta: float) -> void:
	if Rep.is_puppet(self):
		return
	age += delta
	match state:
		"home":
			if moving and position.y > ending_position and position.y < starting_position:
				position.y -= speed * delta * direction
				if position.y <= ending_position or position.y >= starting_position:
					moving = false
			if position.y < 15:
				visible = true
				if !$AnimationPlayer.is_playing():
					$AnimationPlayer.play("spin")
			else:
				visible = false
				$AnimationPlayer.stop()
			if position.y <= ending_position:             # fully up: whoever touches it takes it
				var thief = _enemy_here()
				if thief != null:
					_take(thief)
		"carried":
			if !is_instance_valid(_carrier) or _carrier.is_queued_for_deletion() or _carrier.get("dead"):
				_drop()
			else:
				global_position = _carrier.global_position + Vector2(0, -14)
		"dropped":
			var taker = null
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and !p.get("is_in_tower") and !p.get("downed") and p.global_position.distance_to(global_position) <= PICKUP_RANGE:
					taker = p
					break
			if taker != null:
				_pickup(taker)
			else:
				var e = _enemy_here()
				if e != null:
					_take(e)
		"player":
			if !is_instance_valid(_carrier) or _carrier.get("downed"):
				_drop()                               # whoever carries it fell (they are sent back to the keep): it drops where they were
			else:
				global_position = _carrier.global_position + Vector2(0, -16)
				if _carrier.global_position.distance_to(get_parent().global_position) < 38.0:
					return_home()
	Game.crystal_pos = global_position
	Game.crystal_exit = exit_point
	if state == "carried" and is_instance_valid(_carrier):
		Game.crystal_eta = global_position.distance_to(exit_point) / maxf(1.0, _carrier.speed * 0.8)

func _take(thief: Node) -> void:
	_carrier = thief
	if "has_crystal" in thief:
		thief.has_crystal = true
	z_index = 4
	var home: Vector2 = get_parent().global_position
	exit_point = home + (thief.global_position - home).normalized() * EXIT_RADIUS
	visible = true
	$AnimationPlayer.play("spin")
	_set_state("carried")
	Sfx.play("boss_roar", 0.0)
	Game.announce.emit("THE CRYSTAL WAS STOLEN! The base is offline. Kill the thief before it escapes!")

## The carrying player fell: leave the crystal where they stood.
func drop_from(p: Node) -> void:
	if state == "player" and _carrier == p:
		global_position = p.global_position + Vector2(0, -16)
		_drop("The crystal carrier fell! Pick it up and carry it back to the Well.")

func _drop(msg := "The thief fell! Grab the crystal and carry it back to the Well.") -> void:
	if is_instance_valid(_carrier) and "has_crystal" in _carrier:
		_carrier.has_crystal = false
	_carrier = null
	_set_state("dropped")
	Game.announce.emit(msg)

func _pickup(p: Node) -> void:
	_carrier = p
	if "has_crystal" in p:
		p.has_crystal = true
	_set_state("player")
	Game.announce.emit("You have the crystal. Bring it back to the Well!")

## Back in the Well, lowered like at the start of a run.
func return_home() -> void:
	if is_instance_valid(_carrier) and "has_crystal" in _carrier:
		_carrier.has_crystal = false
	_carrier = null
	position = Vector2(0, starting_position)
	moving = false
	_set_state("home")
	exit_point = Vector2.ZERO
	Sfx.play("unlock", 0.0)
	Game.announce.emit("The crystal is home. Base powers restored.")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(age * 4.0)
	match state:
		"carried":
			draw_arc(Vector2.ZERO, 14.0 + 2.0 * pulse, 0, TAU, 24, Color(1.0, 0.3, 0.3, 0.8), 2.0)
		"dropped":
			draw_arc(Vector2.ZERO, 12.0 + 3.0 * pulse, 0, TAU, 24, Color(0.8, 0.5, 1.0, 0.9), 2.0)
			draw_circle(Vector2.ZERO, 22.0, Color(0.7, 0.4, 1.0, 0.12 + 0.1 * pulse))
		"player":
			draw_arc(Vector2.ZERO, 11.0, 0, TAU, 20, Color(0.6, 1.0, 0.7, 0.8), 1.5)

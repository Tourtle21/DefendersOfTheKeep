extends Node
## Local split-screen players 2 to 4. Each is a co-op avatar (the same kind a network client gets) driven by a
## controller instead of a network connection: controller N drives player N+1. Player 1 keeps the keyboard and
## mouse (or controller 0) and the normal player node, so everything else in the game is unchanged.

const FIRST_ID := 100            # fake peer ids for local players: 101, 102, 103
const DEAD := 0.25
const AIM_REACH := 70.0

var avatars := {}                # slot (1..3) -> player node
var keep_uis := {}               # slot -> LocalKeepUi (made by the split screen once the views exist)
var _aim_dir := {}
var _last_aim_ms := {}
var _prev_btn := {}

func setup(count: int) -> void:
	for slot in range(1, count):
		_spawn(slot)

func _spawn(slot: int) -> void:
	var id := FIRST_ID + slot
	var pl = preload("res://player/player.tscn").instantiate()
	pl.remote_controlled = true
	pl.set_meta("peer_id", id)
	pl.set_meta("local_slot", slot)
	pl.name = "LocalPlayer%d" % (slot + 1)
	pl.position = Vector2(20 + 14 * slot, 4 * slot)
	pl.get_node("Camera2D").enabled = false          # the split-screen camera follows it
	Game.world.add_child(pl)
	Net.give_weapon(pl, Game.start_weapon_id() if Game.start_weapon_id() in Game.start_weapon_options() else "sword")
	Net.remote_players[id] = pl
	Net._prev[id] = {}
	Net.names[id] = "Player %d" % (slot + 1)
	avatars[slot] = pl
	_aim_dir[slot] = Vector2.RIGHT
	_last_aim_ms[slot] = -100000
	_prev_btn[slot] = {}

func _exit_tree() -> void:
	for slot in avatars:
		Net.remote_players.erase(FIRST_ID + slot)
		Net._prev.erase(FIRST_ID + slot)
		Net.names.erase(FIRST_ID + slot)

func _stick(dev: int, ax: int, ay: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(dev, ax), Input.get_joy_axis(dev, ay))
	var m := v.length()
	if m < DEAD:
		return Vector2.ZERO
	return v.normalized() * ((m - DEAD) / (1.0 - DEAD))

func _held(dev: int, b: int) -> bool:
	return Input.is_joy_button_pressed(dev, b)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	for slot in avatars:
		var pl = avatars[slot]
		if !is_instance_valid(pl):
			continue
		var dev: int = int(Game._local_devices[slot]) if slot < Game._local_devices.size() else slot       # the controller this player claimed in the lobby
		if pl.is_in_tower:
			# inside a tower the controller drives the keep screen instead of the avatar
			Net.apply_input_state(FIRST_ID + slot, pl, {"move": Vector2.ZERO, "aim": pl.global_position, "attack": false, "ability": false, "dash": false, "ultimate": false})
			if keep_uis.has(slot):
				keep_uis[slot].poll(dev, delta)
			_prev_btn[slot] = {"a": true, "x": true}              # a press that was for the keep screen must not also be a walk-around press
			continue
		elif keep_uis.has(slot):
			keep_uis[slot].poll(dev, delta)                       # hides the keep screen again
		var left := _stick(dev, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		var right := _stick(dev, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		var now := Time.get_ticks_msec()
		if right != Vector2.ZERO:
			_aim_dir[slot] = right.normalized()
			_last_aim_ms[slot] = now
		elif left != Vector2.ZERO and now - _last_aim_ms[slot] > 1500:
			_aim_dir[slot] = left.normalized()            # hands-free: face where you walk
		var state := {
			"move": left, "aim": pl.global_position + _aim_dir[slot] * AIM_REACH,
			"attack": Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT) > 0.5, "ability": Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT) > 0.5,
			"dash": _held(dev, JOY_BUTTON_B), "ultimate": _held(dev, JOY_BUTTON_Y),
		}
		Net.apply_input_state(FIRST_ID + slot, pl, state)
		# A interacts (pick up, tower in / out, chests, forge) and X switches weapon: on the press only
		var prev: Dictionary = _prev_btn[slot]
		var a_now := _held(dev, JOY_BUTTON_A)
		var x_now := _held(dev, JOY_BUTTON_X)
		if a_now and !prev.get("a", false):
			Net._interact(pl)
		if x_now and !prev.get("x", false):
			Net.switch_weapon(pl)
		_prev_btn[slot] = {"a": a_now, "x": x_now}

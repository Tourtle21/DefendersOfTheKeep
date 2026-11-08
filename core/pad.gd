extends Node
## Controller support for moving around and fighting (autoload "Pad"). Menus, the keep and cards stay
## on the mouse.
##
## Left stick walks, right stick aims (the aim point floats out from the player; hands-free it follows
## where you walk), RT attacks, LT is the right-click ability, A interact, B dash, X switch weapon,
## Y ultimate, Start pause. RT / LT arrive as the same mouse-button events a mouse sends, so weapons,
## co-op clients and the rest need no changes. Touch the mouse, or open a menu or the keep, and the pad
## steps aside and the normal cursor returns.
## Anything that reads the pointer for gameplay asks Pad (world_mouse / screen_mouse).

signal device_changed(using_pad: bool)

const STICK_DEAD := 0.25
const AIM_REACH := 70.0               # world units from the player to the aim point
const TRIGGER_ON := 0.5
const TRIGGER_OFF := 0.3
const INJECTED := 4242                # device id on events we synthesise, so we never mistake them for a real mouse

var using_pad := false
var aim_dir := Vector2.RIGHT
var cursor := Vector2(640, 360)       # aim point in viewport pixels
var blocked := false                  # a menu, the keep or the token screen is up: mouse only

var _axes := {}                       # joypad axis -> value
var _lt := false
var _rt := false
var _pad_events := {}                 # action -> events we added to it
var _bound := true
var _last_aim_ms := -100000
var _scan_clock := 0.0
var _art: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register()
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.visible = false
	_art.draw.connect(_draw_cursor)
	layer.add_child(_art)

func _notification(what: int) -> void:
	# Never leave the OS mouse hidden or a trigger click held when the game closes.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_triggers()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Switching to another app (the terminal, the editor): hand the mouse back with the normal cursor,
	# and take the game cursor back when the window is focused again.
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_triggers()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.set_custom_mouse_cursor(null)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if !using_pad and Game.world != null:
			Input.set_custom_mouse_cursor(load("res://ui/cursors/aim_cursor.png"), 0, Vector2(16, 16))
		else:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if using_pad else Input.MOUSE_MODE_VISIBLE

# ---------- bindings ----------

func _bind(action: String, ev: InputEvent) -> void:
	if !InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_add_event(action, ev)
	if !_pad_events.has(action):
		_pad_events[action] = []
	_pad_events[action].append(ev)

func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _button_event(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	return e

func _register() -> void:
	_bind("move_left", _axis_event(JOY_AXIS_LEFT_X, -1.0))
	_bind("move_right", _axis_event(JOY_AXIS_LEFT_X, 1.0))
	_bind("move_up", _axis_event(JOY_AXIS_LEFT_Y, -1.0))
	_bind("move_down", _axis_event(JOY_AXIS_LEFT_Y, 1.0))
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(a, STICK_DEAD)
	_bind("interact", _button_event(JOY_BUTTON_A))
	_bind("dash", _button_event(JOY_BUTTON_B))
	_bind("switch_items", _button_event(JOY_BUTTON_X))
	_bind("ultimate", _button_event(JOY_BUTTON_Y))

## While a menu is up the pad's gameplay buttons are off, so a stray press can't act behind it.
func _set_bound(on: bool) -> void:
	if on == _bound:
		return
	_bound = on
	for action in _pad_events:
		for e in _pad_events[action]:
			if on:
				InputMap.action_add_event(action, e)
			else:
				InputMap.action_erase_event(action, e)
	if !on:
		for a in _pad_events:
			Input.action_release(a)

# ---------- who is using what ----------

func _set_using(on: bool) -> void:
	if on == using_pad:
		return
	using_pad = on
	_art.visible = on
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	if !on:
		_release_triggers()
	device_changed.emit(on)

func _release_triggers() -> void:
	if _rt:
		_rt = false
		_click(MOUSE_BUTTON_LEFT, false)
	if _lt:
		_lt = false
		_click(MOUSE_BUTTON_RIGHT, false)

## Pointer position in viewport pixels (the OS mouse, or the pad's aim point).
func screen_mouse(vp: Viewport) -> Vector2:
	return cursor if using_pad else vp.get_mouse_position()

## Pointer position in the world the node draws in.
func world_mouse(n: CanvasItem) -> Vector2:
	if !using_pad:
		return n.get_global_mouse_position()
	return n.get_canvas_transform().affine_inverse() * cursor

# ---------- raw input ----------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.device != INJECTED and using_pad and event.relative.length() > 1.5:
			_set_using(false)
		return
	if event is InputEventMouseButton:
		if event.device != INJECTED and using_pad and event.pressed:
			_set_using(false)
		return
	if event is InputEventJoypadMotion:
		_axes[event.axis] = event.axis_value
		if blocked:
			return
		if event.axis == JOY_AXIS_TRIGGER_RIGHT or event.axis == JOY_AXIS_TRIGGER_LEFT:
			_trigger(event.axis, event.axis_value)
		elif absf(event.axis_value) > 0.35:
			_set_using(true)
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			_key(KEY_P)
		elif !blocked:
			_set_using(true)

func _trigger(axis: int, value: float) -> void:
	if value > TRIGGER_ON:
		_set_using(true)
	var is_right := axis == JOY_AXIS_TRIGGER_RIGHT
	var held: bool = _rt if is_right else _lt
	var button := MOUSE_BUTTON_LEFT if is_right else MOUSE_BUTTON_RIGHT
	if !held and value > TRIGGER_ON:
		if is_right:
			_rt = true
		else:
			_lt = true
		_click(button, true)
	elif held and value < TRIGGER_OFF:
		if is_right:
			_rt = false
		else:
			_lt = false
		_click(button, false)

func _click(button: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = INJECTED
	e.button_index = button
	e.pressed = pressed
	e.position = cursor
	e.global_position = cursor
	e.button_mask = (1 << (button - 1)) if pressed else 0
	Input.parse_input_event(e)

func _key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.device = INJECTED
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)

# ---------- per frame ----------

func _stick(x_axis: int, y_axis: int) -> Vector2:
	var v := Vector2(_axes.get(x_axis, 0.0), _axes.get(y_axis, 0.0))
	var m := v.length()
	if m < STICK_DEAD:
		return Vector2.ZERO
	return v.normalized() * ((m - STICK_DEAD) / (1.0 - STICK_DEAD))

func _process(delta: float) -> void:
	_scan_clock -= delta
	if _scan_clock <= 0.0:
		_scan_clock = 0.1
		_scan_blocked()
	if !using_pad or blocked:
		return
	var right := _stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var left := _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var now := Time.get_ticks_msec()
	if right != Vector2.ZERO:
		aim_dir = right.normalized()
		_last_aim_ms = now
	elif left != Vector2.ZERO and now - _last_aim_ms > 1500:
		aim_dir = left.normalized()           # hands-free: face where you walk
	var vp := get_viewport()
	var xf := vp.get_canvas_transform()
	var origin := vp.get_visible_rect().size / 2.0
	var p := _local_player()
	if p != null:
		origin = xf * p.global_position
	cursor = origin + aim_dir * AIM_REACH * xf.get_scale().x
	_art.queue_redraw()

func _local_player() -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.get("remote_controlled") and !p.get("downed"):
			return p
	return null

## A menu is open (a full-screen mouse-catching panel on a high layer), the game is paused, or you are in the keep.
func _scan_blocked() -> void:
	var size := get_viewport().get_visible_rect().size
	var menu := false
	for holder in [get_tree().root, get_tree().current_scene]:
		if holder == null:
			continue
		for n in holder.get_children():
			if n is CanvasLayer and n.visible and n.layer >= 7 and n.layer < 100:
				for c in n.get_children():
					if c is Control and c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP \
							and c.size.x >= size.x * 0.8 and c.size.y >= size.y * 0.8:
						menu = true
	var now: bool = menu or get_tree().paused or Game.draft_active or Game.local_in_base()
	if now == blocked:
		return
	blocked = now
	_set_bound(!now)
	if now:
		_set_using(false)               # give the mouse back

func _draw_cursor() -> void:
	var col := Color(1.0, 0.92, 0.45)
	var edge := Color(0, 0, 0, 0.85)
	_art.draw_arc(cursor, 12.0, 0, TAU, 28, edge, 4.0)
	_art.draw_arc(cursor, 12.0, 0, TAU, 28, col, 2.0)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		_art.draw_line(cursor + d * 16.0, cursor + d * 22.0, col, 2.0)

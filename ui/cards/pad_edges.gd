extends RefCounted
## One controller's button presses for the split-screen menus of players 2-4 (Forge, Card Fuser, chest draft):
## read(dev) returns which buttons went down this frame. Menus move with the left stick or the d-pad
## (the right stick aims and LB / RB are for the hand's cards).

var _prev := {}

## {up, down, left, right, a, b, x, y}: true only on the frame the button is pressed.
func read(dev: int) -> Dictionary:
	var sx: float = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
	var now := {"up": Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP), "down": Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN),
		"left": sx < -0.6 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT), "right": sx > 0.6 or Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT),
		"a": Input.is_joy_button_pressed(dev, JOY_BUTTON_A), "b": Input.is_joy_button_pressed(dev, JOY_BUTTON_B),
		"x": Input.is_joy_button_pressed(dev, JOY_BUTTON_X), "y": Input.is_joy_button_pressed(dev, JOY_BUTTON_Y)}
	var out := {}
	for k in now:
		out[k] = now[k] and !_prev.get(k, false)
	_prev = now
	return out

## Treat a button as already held (the press that opened a menu must not also act in it).
func hold(key: String) -> void:
	_prev[key] = true

## Move a cursor over n items with left / right, wrapping.
func move(b: Dictionary, cur: int, n: int) -> int:
	if n <= 0:
		return 0
	if b.left:
		cur -= 1
	if b.right:
		cur += 1
	return wrapi(cur, 0, n)

extends CanvasLayer
## Connect screen for local split-screen play. Each player claims a slot with their own controller: press A to join,
## B to leave. The keyboard joins with Enter and is always player 1 (the mouse is its pointer). When two or more
## are in, Start (the button, or the Start button on any joined controller) begins the game with exactly these
## controllers in exactly these slots.

const UiKit = preload("res://ui/cards/ui_kit.gd")
signal started
signal closed

const COLORS := preload("res://ui/cards/ui_kit.gd").PLAYER_COLORS

var root_ctl: Control
var _cards: Array = []              # per slot: {title, device, state}
var _start: Button
var _members: Array = []            # joined devices in join order (-1 = keyboard)
var _prev := {}                     # device -> {a, b, start}
var _msg: Label
var fake_connected = null                   # tests: an Array of controller ids to treat as connected (null = ask the system)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 22
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.theme = UiKit.make_theme()
	root_ctl.visible = false
	root_ctl.add_to_group("menu_overlay")           # menus underneath stay quiet while this is up
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = UiKit.BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root_ctl.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)
	var head := UiKit.heading("Local co-op: connect your controllers", UiKit.FONT_TITLE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(head)
	var hint := Label.new()
	hint.text = "Press A on your controller to join.  B leaves.  Keyboard: press Enter (the keyboard is always player 1)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UiKit.FONT_BODY)
	hint.add_theme_color_override("font_color", UiKit.TEXT_HINT)
	outer.add_child(hint)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	outer.add_child(row)
	for i in 4:
		var panel := UiKit.panel(UiKit.RESULT_BG, COLORS[i].darkened(0.3), 14.0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 14)
		panel.add_child(v)
		var title := Label.new()
		title.text = "PLAYER %d" % (i + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", UiKit.FONT_TITLE)
		title.add_theme_color_override("font_color", COLORS[i])
		v.add_child(title)
		var dev := Label.new()
		dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dev.add_theme_font_size_override("font_size", UiKit.FONT_HEAD)
		v.add_child(dev)
		var state := Label.new()
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.add_theme_font_size_override("font_size", UiKit.FONT_BIG)
		v.add_child(state)
		_cards.append({"panel": panel, "dev": dev, "state": state})
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", UiKit.FONT_BODY)
	_msg.add_theme_color_override("font_color", UiKit.WARN)
	outer.add_child(_msg)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	outer.add_child(bottom)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 52)
	back.pressed.connect(close)
	bottom.add_child(back)
	_start = Button.new()
	_start.custom_minimum_size = Vector2(300, 52)
	_start.add_theme_font_size_override("font_size", UiKit.FONT_BIG)
	_start.pressed.connect(_begin)
	bottom.add_child(_start)
	_refresh()

func open() -> void:
	_members.clear()
	_prev.clear()
	var held = get_viewport().gui_get_focus_owner()
	if held != null:
		held.release_focus()               # the menu under this screen must not also react to A (it would press "Play game")
	root_ctl.visible = true
	_refresh()

func close() -> void:
	var held = get_viewport().gui_get_focus_owner()
	if held != null:
		held.release_focus()
	root_ctl.visible = false
	closed.emit()

## Joined controllers in slot order: the keyboard (if any) is slot 1, the rest follow in join order.
func devices() -> Array:
	var out := []
	if -1 in _members:
		out.append(-1)
	for d in _members:
		if d != -1:
			out.append(d)
	return out

func _name_of(d: int) -> String:
	if d == -1:
		return "Keyboard + mouse"
	var nm: String = Input.get_joy_name(d) if d in Input.get_connected_joypads() else ""         # (asking about a controller that is not there can crash)
	return ("%s (controller %d)" % [nm, d + 1]) if nm != "" else "Controller %d" % (d + 1)

func _refresh() -> void:
	var devs := devices()
	for i in 4:
		var c: Dictionary = _cards[i]
		if i < devs.size():
			c.dev.text = _name_of(devs[i])
			c.state.text = "READY"
			c.state.add_theme_color_override("font_color", UiKit.GOOD)
			c.panel.modulate = UiKit.WHITE
		else:
			c.dev.text = "Waiting for a player..."
			c.state.text = "Press A to join"
			c.state.add_theme_color_override("font_color", UiKit.TEXT_DIM)
			c.panel.modulate = UiKit.TEXT_DIM
	_start.disabled = devs.size() < 2
	_start.text = "Start  (%d players)" % devs.size() if devs.size() >= 2 else "Need 2 or more players"

func _process(_delta: float) -> void:
	if !root_ctl.visible:
		return
	var changed := false
	var connected: Array = fake_connected if fake_connected != null else Input.get_connected_joypads()
	for d in _members.duplicate():
		if d != -1 and !(d in connected):
			_members.erase(d)                 # unplugged
			changed = true
	for d in connected:
		var p: Dictionary = _prev.get(d, {})
		var a := Input.is_joy_button_pressed(d, JOY_BUTTON_A)
		var b := Input.is_joy_button_pressed(d, JOY_BUTTON_B)
		var st := Input.is_joy_button_pressed(d, JOY_BUTTON_START)
		if a and !p.get("a", false) and !(d in _members) and _members.size() < 4:
			_members.append(d)
			changed = true
		elif b and !p.get("b", false) and d in _members:
			_members.erase(d)
			changed = true
		elif st and !p.get("st", false) and d in _members and devices().size() >= 2:
			_begin()
			return
		_prev[d] = {"a": a, "b": b, "st": st}
	if changed:
		_msg.text = ""
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if !root_ctl.visible:
		return
	if event is InputEventKey and event.pressed and !event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if !(-1 in _members) and _members.size() < 4:
			_members.append(-1)
			_msg.text = ""
			_refresh()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and !event.echo and event.keycode == KEY_ESCAPE:
		if -1 in _members:
			_members.erase(-1)
			_refresh()
		else:
			close()
		get_viewport().set_input_as_handled()

func _begin() -> void:
	var devs := devices()
	if devs.size() < 2:
		_msg.text = "Join with at least two controllers (or the keyboard and one controller)."
		return
	Game._local_devices = devs
	root_ctl.visible = false
	started.emit()

extends CanvasLayer
## Pause menu (P): resume, restart the run, volume sliders (saved), quit.

const UiKit = preload("res://ui/cards/ui_kit.gd")
var root_ctl: Control
var _was_paused := false
var lan_box: VBoxContainer
var lan_label: Label
var _lan_key := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.visible = false
	root_ctl.theme = UiKit.make_theme()
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.BLACK, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(center)
	var frame := UiKit.panel(UiKit.PANEL_DEEP, UiKit.BORDER, 16.0)
	center.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360, 0)
	frame.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UiKit.FONT_TITLE)
	box.add_child(title)
	_button(box, "Resume (P)", close)
	box.add_child(UiKit.heading("Sound", UiKit.FONT_BODY))
	_slider(box, "Music volume", Game.meta.get("music_vol", 1.0), func(v):
		Game.meta["music_vol"] = v
		Music.apply_volume())
	_slider(box, "Effects volume", Game.meta.get("sfx_vol", 1.0), func(v):
		Game.meta["sfx_vol"] = v
		Sfx.play("coin", 0.0))
	box.add_child(UiKit.heading("Co-op on this network", UiKit.FONT_BODY))
	_button(box, "Host a game", func():
		var err := Net.host_game()
		var addr := ", ".join(Net.lan_addresses())
		Game.announce.emit(("Hosting on your LAN: friends join %s (port %d)" % [addr if addr != "" else "this computer's address", Net.PORT]) if err == OK else "Could not host (error %d)" % err)
		close())
	lan_label = Label.new()
	lan_label.text = "Looking for games..."
	box.add_child(lan_label)
	lan_box = VBoxContainer.new()
	box.add_child(lan_box)
	var ip := LineEdit.new()
	ip.text = "127.0.0.1"
	ip.placeholder_text = "host address"
	box.add_child(ip)
	_button(box, "Join this address", func():
		Net.joined.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://net/client_view.tscn"), CONNECT_ONE_SHOT)
		Net.join_failed.connect(func(): Game.announce.emit("Could not connect to %s" % ip.text), CONNECT_ONE_SHOT)
		Net.join_game(ip.text))
	var tips := CheckBox.new()
	tips.text = "Show tips"
	tips.button_pressed = Game.meta.get("hints_enabled", true)
	tips.toggled.connect(func(on): Game.meta["hints_enabled"] = on)
	box.add_child(tips)
	box.add_child(UiKit.heading("Run", UiKit.FONT_BODY))
	_button(box, "Restart run", func():
		close()
		Game.restart_run())
	_button(box, "Quit game", func():
		Game.save_meta()
		get_tree().quit())
	_attach_pad()

func _attach_pad() -> void:
	preload("res://ui/cards/menu_pad.gd").attach(root_ctl, close)               # controller: d-pad + A, B closes the menu

func _button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	parent.add_child(b)

func _slider(parent: Node, text: String, value: float, cb: Callable) -> void:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.value_changed.connect(cb)
	parent.add_child(s)

func _process(_delta: float) -> void:
	if !root_ctl.visible or Net.is_host:
		return
	# list hosts announcing themselves on the local network
	var key := str(Net.lan_hosts.keys())
	if key == _lan_key:
		return
	_lan_key = key
	for c in lan_box.get_children():
		lan_box.remove_child(c)
		c.queue_free()
	lan_label.text = "Games found:" if Net.lan_hosts.size() > 0 else "No games found"
	for addr in Net.lan_hosts:
		var h: Dictionary = Net.lan_hosts[addr]
		_button(lan_box, "Join %s  (%s, %d player%s)" % [h.name, addr, h.players, "" if h.players == 1 else "s"], func():
			Net.joined.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://net/client_view.tscn"), CONNECT_ONE_SHOT)
			Net.join_failed.connect(func(): Game.announce.emit("Could not connect to %s" % addr), CONNECT_ONE_SHOT)
			Net.join_game(addr, h.port))

## Is the main menu, the connect screen or another full-screen menu up? Then Start / P must not pause behind it.
func _menu_up() -> bool:
	for m in get_tree().get_nodes_in_group("menu_pad"):
		if is_instance_valid(m.root) and m.root != root_ctl and m.root.is_visible_in_tree() and m.root.get_parent() is CanvasLayer and m.root.get_parent().layer >= 20:
			return true
	for n in get_tree().get_nodes_in_group("menu_overlay"):
		if n is Control and n.is_visible_in_tree():
			return true
	return false

func open() -> void:
	if Game.run_over or _menu_up():
		return
	Net.start_lan_scan()
	_was_paused = get_tree().paused
	get_tree().paused = !Net.active          # in co-op the menu does not freeze your friends
	root_ctl.visible = true

func close() -> void:
	Net.stop_lan_scan()
	root_ctl.visible = false
	get_tree().paused = _was_paused
	Game.save_meta()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo and event.physical_keycode == KEY_P:
		if root_ctl.visible:
			close()
		else:
			open()

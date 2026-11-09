extends Node
## Controller navigation for a full-screen menu (attached by UiKit.screen, and by hand to the other menus).
## D-pad / left stick move between the controls (Godot's own focus navigation), A presses, B goes back,
## LB / RB switch between the Cards / Weapons / Drawn / Skills tabs. When the menu opens, the first control
## is focused so the d-pad has somewhere to start.

var root: Control
var on_back := Callable()
var tab_id := ""
var focus_root: Control          # where to look for the first control to focus (default: the whole menu)
var first_focus: Control         # focus this one first if given

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visibility_changed.connect(func():
		if root.visible:
			_grab.call_deferred())
	if root.visible:
		_grab.call_deferred()            # a menu that starts open (the main menu)

func _grab() -> void:
	await get_tree().create_timer(0.1, true, false, true).timeout       # let the screen build its cards first
	if !is_inside_tree() or !root.is_visible_in_tree():
		return
	var owner = root.get_viewport().gui_get_focus_owner()
	if owner != null and is_instance_valid(owner) and root.is_ancestor_of(owner) and owner.is_visible_in_tree():
		return
	var target: Control = first_focus if first_focus != null and is_instance_valid(first_focus) and first_focus.is_visible_in_tree() else null
	if target == null:
		target = _first_focusable(focus_root if focus_root != null else root)
	if target == null:
		target = _first_focusable(root)
	if target != null:
		target.grab_focus()

func _first_focusable(n: Node) -> Control:
	if n is Control and n.is_visible_in_tree() and n.focus_mode == Control.FOCUS_ALL and !(n is BaseButton and n.disabled):
		return n
	for c in n.get_children():
		var f := _first_focusable(c)
		if f != null:
			return f
	return null

func _unhandled_input(event: InputEvent) -> void:
	if root == null or !root.is_visible_in_tree():
		return
	if root.get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") \
			or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_grab()                                  # nothing focused (a screen above just closed): start from the first control
		return
	if event.is_action_pressed("ui_cancel") and on_back.is_valid():
		get_viewport().set_input_as_handled()
		on_back.call()
		return
	if tab_id != "" and event is InputEventJoypadButton and event.pressed \
			and (event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		var ids := []
		for t in preload("res://ui/cards/ui_kit.gd").TABS:
			ids.append(t[0])
		var i := ids.find(tab_id)
		var step := 1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
		get_viewport().set_input_as_handled()
		preload("res://ui/cards/ui_kit.gd").switch_tab(root, ids[wrapi(i + step, 0, ids.size())])

## Attach to any full-screen menu root.
static func attach(menu_root: Control, back := Callable(), tab := "", search_in: Control = null, first: Control = null) -> Node:
	var mp: Node = load("res://ui/cards/menu_pad.gd").new()
	mp.root = menu_root
	mp.on_back = back
	mp.tab_id = tab
	mp.focus_root = search_in
	mp.first_focus = first
	menu_root.add_child(mp)
	return mp

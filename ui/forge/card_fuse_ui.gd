extends CanvasLayer
## Player 1's Card Fuser: the shared screen (ui/forge/fuser_view.gd) with the mouse and d-pad focus.
## The rules are Game.fuse_preview / Game.fuse_hand.

const FuserView = preload("res://ui/forge/fuser_view.gd")

var view: FuserView
var selected: Array = []        # hand indexes
var is_open := false
var root_ctl: Control:
	get: return view
var fuse_button: Button:
	get: return view.fuse_btn
var result_box: HBoxContainer:
	get: return view.result_box

func _ready() -> void:
	add_to_group("card_fuse_ui")
	layer = 8
	view = FuserView.new()
	view.visible = false
	add_child(view)
	view.card_pressed.connect(_toggle)
	view.fuse_pressed.connect(fuse)
	view.back_pressed.connect(close)
	preload("res://ui/cards/menu_pad.gd").attach(view, close, "", view.hand_box)
	Game.hand_changed.connect(func(): if is_open: _refresh())
	get_viewport().size_changed.connect(func(): if is_open: fit_view(_area()))

func _area() -> Vector2:
	if custom_viewport != null and is_instance_valid(custom_viewport) and custom_viewport is SubViewport:
		return Vector2(custom_viewport.size)
	return get_viewport().get_visible_rect().size

## Split screen calls this with player 1's view size (world/split_screen.gd).
func fit_view(area: Vector2) -> void:
	view.fit(area)

func open() -> void:
	selected = []
	is_open = true
	view.fit(_area())
	view.visible = true
	_refresh()

func close() -> void:
	is_open = false
	view.visible = false

func _toggle(i: int) -> void:
	selected = FuserView.toggle(selected, i)
	_refresh()

func _refresh() -> void:
	selected = selected.filter(func(i): return i < Game.hand.size())
	view.render({"hand": Game.hand, "picks": selected, "cur": -1, "gold": int(Game.resources.get("gold", 0))})

func fuse() -> void:
	if selected.size() == 2 and Game.fuse_hand(selected[0], selected[1]):
		selected = []
		_refresh()

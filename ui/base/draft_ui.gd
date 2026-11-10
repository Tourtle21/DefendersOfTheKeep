extends CanvasLayer
## Player 1's chest draft: the shared screen (ui/base/draft_view.gd) with mouse and d-pad focus. Pick 1 of 3 cards;
## picking a card you already own upgrades it.

const DraftView = preload("res://ui/base/draft_view.gd")

var view: DraftView
var root_ctl: Control:
	get: return view

func _ready() -> void:
	layer = 7
	view = DraftView.new()
	view.visible = false
	add_child(view)
	view.take.connect(func(entry): Game.take_draft_card(entry))
	view.combine.connect(func(i, j): Game.merge_hand(i, j))
	Game.hand_changed.connect(func(): if view.visible: view.render())
	preload("res://ui/cards/menu_pad.gd").attach(view, Callable(), "", view.row)     # any controller: d-pad / left stick to move, A to take
	Game.draft_started.connect(_show)
	Game.deck_changed.connect(func(): view.visible = Game.draft_active and Game.draft_owner_slot == 0)
	get_viewport().size_changed.connect(func(): if view.visible: fit_view(_area()); view.render())

func _area() -> Vector2:
	if custom_viewport != null and is_instance_valid(custom_viewport) and custom_viewport is SubViewport:
		return Vector2(custom_viewport.size)
	return get_viewport().get_visible_rect().size

## Split screen calls this with player 1's view size (world/split_screen.gd).
func fit_view(area: Vector2) -> void:
	view.fit(area)

func _show(_options: Array) -> void:
	if Game.draft_owner_slot > 0:
		return                       # a local player 2 to 4 opened it: their own view shows it (ui/base/local_draft_ui.gd)
	view.fit(_area())
	view.render()
	view.visible = true

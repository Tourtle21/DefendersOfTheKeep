extends CanvasLayer
## The chest card choice for a local split-screen player (players 2 to 4) who opened the chest: the shared screen
## (ui/base/draft_view.gd) in their own view. Left stick / d-pad move, A takes the card, X combines the first pair in the hand.

const DraftView = preload("res://ui/base/draft_view.gd")
const PadEdges = preload("res://ui/cards/pad_edges.gd")

var pl: Node
var slot := 1
var vp: SubViewport
var is_open := false
var cur := 0
var view: DraftView
var _pad := PadEdges.new()
var _root: Control:
	get: return view

func setup(player: Node, viewport: SubViewport, slot_index: int) -> void:
	pl = player
	vp = viewport
	slot = slot_index
	layer = 9
	custom_viewport = viewport
	view = DraftView.new({"take": "A", "combine": "X"})
	view.visible = false
	add_child(view)
	fit(Vector2(viewport.size))

func fit(area: Vector2) -> void:
	view.fit(area)

## True while this player's chest choice is up (their controller belongs to it).
func wants() -> bool:
	return Game.draft_active and Game.draft_owner_slot == slot

func poll(dev: int) -> void:
	var b := _pad.read(dev)
	if !wants():
		if is_open:
			is_open = false
			view.visible = false
		return
	if !is_open:
		is_open = true
		cur = 0
		view.visible = true
		_pad.hold("a")             # the press that opened the chest must not also take a card
		b.a = false
	if b.x:
		var pair := DraftView.first_pair()
		if !pair.is_empty():
			Game.merge_hand(pair[0], pair[1])
	cur = _pad.move(b, cur, Game.draft_options.size())
	if b.a and !Game.draft_options.is_empty():
		Game.take_draft_card(Game.draft_options[cur])
		return
	view.render(cur)

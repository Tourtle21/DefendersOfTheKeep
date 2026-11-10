extends CanvasLayer
## The Card Fuser for a local split-screen player (players 2 to 4): the shared screen (ui/forge/fuser_view.gd) in their own
## view. Stand at the table and press d-pad up. Left stick / d-pad move, A picks a card (two of them), X fuses, B closes.
## Rules: Game.fuse_preview / Net.card_fuse.

const FuserView = preload("res://ui/forge/fuser_view.gd")
const PadEdges = preload("res://ui/cards/pad_edges.gd")

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var view: FuserView
var _pad := PadEdges.new()
var _root: Control:
	get: return view

func setup(player: Node, viewport: SubViewport) -> void:
	pl = player
	vp = viewport
	layer = 8
	custom_viewport = viewport
	view = FuserView.new({"pick": "A", "fuse": "X", "back": "B"})
	view.visible = false
	add_child(view)
	fit(Vector2(viewport.size))

func fit(area: Vector2) -> void:
	view.fit(area)

func close() -> void:
	is_open = false
	view.visible = false
	picks.clear()

func open() -> void:
	is_open = true
	cur = 0
	picks.clear()
	view.visible = true
	_pad.hold("a")            # the press that is held now must not also pick a card
	_refresh()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var b := _pad.read(dev)
	var near: bool = Net.near_station(pl, Net.CARD_FUSER_POS)
	if !is_open:
		if b.up and near and !pl.is_in_tower and !pl.downed:
			open()
		return
	if !near or pl.downed or pl.is_in_tower:
		close()
		return
	var n := Game.hand.size()
	cur = _pad.move(b, cur, n)
	picks = picks.filter(func(i): return i < n)
	if b.a and n > 0:
		picks = FuserView.toggle(picks, cur)
	if b.x and picks.size() == 2 and Game.fuse_preview(picks[0], picks[1]).ok:
		Net.card_fuse(pl, picks[0], picks[1])
		picks.clear()
		cur = 0
	if b.b:
		close()
		return
	_refresh()

func _refresh() -> void:
	view.render({"hand": Game.hand, "picks": picks, "cur": cur, "gold": int(Game.resources.get("gold", 0))})

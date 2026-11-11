extends CanvasLayer
## The Forge for a local split-screen player (players 2 to 4): the shared screen (ui/forge/forge_view.gd) in their own view,
## driven by their controller. Stand at the anvil and press d-pad up (or A). Left stick / d-pad move, A picks a weapon (two of
## them), X forges, Y drops the weapon under the cursor into the forge or takes it out, B closes. Rules: Net.forge_*.

const ForgeView = preload("res://ui/forge/forge_view.gd")
const ForgeLayout = preload("res://ui/forge/forge_layout.gd")
const PadEdges = preload("res://ui/cards/pad_edges.gd")

var pl: Node
var vp: SubViewport
var is_open := false
var cur := 0
var picks: Array = []
var view: ForgeView
var _pad := PadEdges.new()
var _root: Control:
	get: return view

func setup(player: Node, viewport: SubViewport) -> void:
	pl = player
	vp = viewport
	layer = 8
	custom_viewport = viewport
	view = ForgeView.new({"pick": "A", "forge": "X", "store": "Y", "back": "B"})
	view.visible = false
	add_child(view)
	fit(Vector2(viewport.size))

func fit(area: Vector2) -> void:
	view.fit(area)

func _items() -> Array:
	return ForgeLayout.items(pl.weapon_slots, Game._forge_store)

func preview() -> Dictionary:
	return ForgeLayout.preview(_items(), picks)

func close() -> void:
	is_open = false
	view.visible = false
	picks.clear()

func open() -> void:
	if pl.is_in_tower or pl.downed:
		return
	is_open = true
	cur = 0
	picks.clear()
	view.visible = true
	_pad.hold("a")             # the press that is held now must not also pick a weapon
	_refresh()

## Called every physics frame with this player's controller.
func poll(dev: int) -> void:
	var b := _pad.read(dev)
	if !is_open:
		if b.up and Net.can_use_station(pl, Net.FORGE_POS):
			open()
		return
	if !Net.can_use_station(pl, Net.FORGE_POS):
		close()
		return
	var items := _items()
	var n := items.size()
	cur = _pad.move(b, cur, n)
	if b.a and n > 0:
		if cur in picks:
			picks.erase(cur)
		elif picks.size() < 2:
			picks.append(cur)
	if b.y and cur < n:
		Net.forge_toggle_store(pl, items[cur].src, items[cur].idx)
		picks.clear()
		cur = clampi(cur, 0, maxi(0, _items().size() - 1))
	if b.x and picks.size() == 2 and preview().ok:
		Net.forge_craft(pl, items[picks[0]].src, items[picks[0]].idx, items[picks[1]].src, items[picks[1]].idx)
		picks.clear()
		cur = 0
	if b.b:
		close()
		return
	_refresh()

func _refresh() -> void:
	view.render({"list": _items(), "picks": picks, "cur": cur, "store_full": Game._forge_store.size() >= Game.FORGE_STORE_MAX, "hands_full": pl.weapon_slots.size() >= 3})

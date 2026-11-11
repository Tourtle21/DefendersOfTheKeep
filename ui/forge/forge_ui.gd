extends CanvasLayer
## Player 1's Forge: the shared screen (ui/forge/forge_view.gd) over player 1's HUD weapon slots, mouse and d-pad focus.
## The rules are Game.forge_preview (what a pair makes and costs), the same ones Net.forge_* use for everyone else.
## Also the merge-on-the-spot hint and F key (two held weapons that fuse or combine, no forge needed).

const ForgeView = preload("res://ui/forge/forge_view.gd")
const ForgeLayout = preload("res://ui/forge/forge_layout.gd")

var view: ForgeView
var root_ctl: Control:
	get: return view
var selected: Array = []        # keys: a HUD slot (0-2) for a held weapon, 100 + index for a stored one
# (tests and older code read these)
var info_label: Label:
	get: return view.info
var numbers: RichTextLabel:
	get: return view.numbers
var fuse_button: Button:
	get: return view.forge_btn
var awaken_button: Button:
	get: return view.forge_btn
var held_title: Label:
	get: return view.held_title
var store_title: Label:
	get: return view.store_title
var list_box: Container:
	get: return view.held_box
var store_box: Container:
	get: return view.store_box

func _ready() -> void:
	add_to_group("forge_ui")
	layer = 8
	view = ForgeView.new({}, true)
	view.visible = false
	add_child(view)
	view.card_pressed.connect(func(pos): _toggle(_key_at(pos)))
	view.recipe_pressed.connect(func(a, b):
		selected = [_key_at(a), _key_at(b)]
		_refresh()
		if view.forge_btn.disabled == false:
			forge())
	view.forge_pressed.connect(forge)
	view.store_pressed.connect(_store_or_take)
	view.back_pressed.connect(close)
	preload("res://ui/cards/menu_pad.gd").attach(view, close, "", view.held_box)       # d-pad focus, B = back
	get_viewport().size_changed.connect(func(): if view.visible: fit_view(_area()))

func _hud():
	return get_parent().get_node("Hud")

## The size of the view this screen is drawn in (player 1's split view, or the window).
func _area() -> Vector2:
	if custom_viewport != null and is_instance_valid(custom_viewport) and custom_viewport is SubViewport:
		return Vector2(custom_viewport.size)
	return get_viewport().get_visible_rect().size

## Split screen calls this with player 1's view size (world/split_screen.gd).
func fit_view(area: Vector2) -> void:
	view.fit(area)

func open() -> void:
	selected = []
	view.fit(_area())
	_refresh()
	view.visible = true

func close() -> void:
	view.visible = false

## ---- Merge on the spot ----
var _merge_clock := 0.0

## The weapons in your hands as entries, in slot order: [{slot, entry}]
func _held_entries() -> Array:
	return _hud().held_entries()

func _merge_options() -> Dictionary:
	var held := _held_entries()
	var m := Game.held_merge(held.map(func(h): return h.entry))
	if !m.is_empty():
		m["slot_a"] = held[m.a].slot
		m["slot_b"] = held[m.b].slot
	return m

func _process(delta: float) -> void:
	_merge_clock -= delta
	if _merge_clock > 0.0:
		return
	_merge_clock = 0.2
	var widget = _hud().slots_widget
	if widget == null:
		return
	var p = get_tree().get_first_node_in_group("player")
	var busy: bool = p == null or view.visible or Game.menu_open() or Game.local_in_base() or p.get("is_in_tower") or (Game.draft_active and Game.draft_owner_slot == 0)
	widget.set_merge(Game.held_merge(_held_entries().map(func(h): return h.entry)) if !busy else {}, "D-pad down" if Pad.using_pad else "F")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("merge_weapons") and !view.visible and !Game.menu_open():
		quick_merge()

## Merge the two held weapons the hint shows. Returns true if it happened.
func quick_merge() -> bool:
	var p = get_tree().get_first_node_in_group("player")
	if p == null or Game.local_in_base() or p.get("is_in_tower"):
		return false
	var done: bool = Net.merge_held(p)               # the same function every other player uses
	_merge_clock = 0.0
	return done

func _entry_of(info: Dictionary) -> String:
	if info.has("entry"):
		return info.entry
	return info.id if info.has("id") else _hud().item_slots.get_child(0).item_info.items.find_key(info)

## Everything the forge can use in the shared display order, each with its key.
func _list() -> Array:
	var held := _held_entries()
	var list := ForgeLayout.items(held.map(func(h): return h.entry), Game._forge_store)
	for it in list:
		it["key"] = held[it.idx].slot if it.src == "held" else 100 + it.idx
	return list

func _key_at(pos: int) -> int:
	var list := _list()
	return list[pos].key if pos >= 0 and pos < list.size() else -1

func _item_for(key: int) -> Dictionary:
	for it in _list():
		if it.key == key:
			return it
	return {}

func _refresh() -> void:
	var list := _list()
	var picks := []
	for k in selected:
		for n in list.size():
			if list[n].key == k:
				picks.append(n)
	view.render({"list": list, "picks": picks, "cur": -1, "store_full": Game._forge_store.size() >= Game.FORGE_STORE_MAX, "hands_full": _held_entries().size() >= 3})
	if picks.size() == 2:
		var p: Dictionary = Game.forge_preview(list[picks[0]].entry, list[picks[1]].entry)
		if p.has("key"):
			Game.note_recipe(p.key)          # the recipe journal: a previewed fusion counts as discovered

func _toggle(key: int) -> void:
	if key < 0:
		return
	if key in selected:
		selected.erase(key)
	elif selected.size() < 2:
		selected.append(key)
	else:
		selected = [selected[1], key]
	_refresh()

## A picked key as the forge rules see it: ["held", position among the weapons you hold] or ["store", index in the forge].
func _src_of(key: int) -> Array:
	if key >= 100:
		return ["store", key - 100]
	var held: Array = _held_entries()
	for n in held.size():
		if held[n].slot == key:
			return ["held", n]
	return ["held", -1]

## Fuse or combine the two picked weapons: Net.craft, the same function every other player's forge uses. Returns true if it happened.
func _craft() -> bool:
	if selected.size() != 2:
		return false
	var a := _src_of(selected[0])
	var b := _src_of(selected[1])
	var p = get_tree().get_first_node_in_group("player")
	if !Net.craft(p, a[0], a[1], b[0], b[1]):
		return false
	Sfx.play("unlock", 0.0)
	return true

## The Forge button: fuse two different weapons (closes the screen) or combine two copies.
func forge() -> void:
	var fusing: bool = selected.size() == 2 and _item_for(selected[0]).get("id") != _item_for(selected[1]).get("id")
	if !_craft():
		return
	selected = []
	if fusing:
		view.visible = false
	else:
		_refresh()

func fuse() -> void:
	forge()

func awaken() -> void:
	forge()

## Drop the picked held weapon into the forge, or take the picked stored one out (Net.toggle_store, shared with the other players).
func _store_or_take() -> void:
	if selected.size() != 1:
		return
	var src := _src_of(selected[0])
	var p = get_tree().get_first_node_in_group("player")
	if !Net.toggle_store(p, src[0], src[1]):
		return
	Sfx.play("unlock", 0.0)
	selected = []
	_refresh()

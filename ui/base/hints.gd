extends CanvasLayer
## One-time contextual tips for new players. Each tip appears once, when it becomes relevant,
## and is remembered in Game.meta["hints_seen"]. Turn them off in the pause menu.
const UiKit = preload("res://ui/cards/ui_kit.gd")

const TIPS := {
	"pickup": "Walk onto the sword or pickaxe on the grass and press E to pick it up.",
	"attack": "Left click attacks and Shift is a dash attack. The right-click ability unlocks at weapon tier 2 and Space (ultimate) at tier 3: raise tiers at the Forge. Tap to cast at the cursor, hold a second to aim.",
	"gather": "Chop trees and mine rocks (left click) for sticks and stone, and kill enemies for gold.",
	"tower": "You are carrying resources. Walk into a tower (E) to deposit them and use the keep.",
	"cards": "In the keep: drag a card onto the map. It flies from the crystal, so aim ahead of moving enemies.",
	"chest": "A chest appeared! Gold chests give a card draft, blue chests drop a weapon. Walk to it and press E.",
	"gold": "Enemies drop gold. Walk over the coins before they vanish, then deposit it in the keep.",
	"wave": "A wave is coming. Defend the crystal: fight outside, and from the keep reload turrets (click a tower) and repair the keep.",
	"forge": "Two weapons? Take them to the Forge (the anvil in the yard) to fuse a stronger one for gold.",
	"build": "Build cards (walls, traps, sentries) cost materials, not mana, and stay on the map. Two of the same kind and tier next to each other merge into the next tier (tier 3 takes four).",
	"generator": "A resource generator! Press E to activate it with carried gold. It fills with this biome's resource: come back to collect, or upgrade it.",
	"biome": "A new biome opened. Its enemies have weaknesses: look for the pips above them (filled dot = weak to that element, grey square = armored).",
	"crystal": "The crystal was stolen! The base is offline until you kill the thief, pick the crystal up and carry it back to the Well. If the thief reaches the edge you lose.",
	"sheep": "A rainbow sheep! It runs when you come close and tires after a sprint. Catch it for gold and resources (it is the rainbow dot on the radar).",
	"night": "Night: enemies outside every light are shrouded (they take 40% less damage) and your towers and sentries only see them up close. Torches, flares, fire spells and fire or Torch weapons light them up. Night cards come up more often in your hand.",
	"keep_low": "The keep is badly damaged! From inside a tower you can repair it (3 stone) and reload the turrets.",
}

var panel: PanelContainer
var label: Label
var _queue: Array = []
var _showing := 0.0
var _check := 0.0
var _t := 0.0
var _weapon_since := -1.0

func _ready() -> void:
	layer = 12
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiKit.STORE_BG, 0.88)
	style.border_color = UiKit.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -250
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	label = Label.new()
	label.custom_minimum_size = Vector2(560, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UiKit.FONT_BODY)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

func enabled() -> bool:
	return Game.meta.get("hints_enabled", true)

func seen() -> Array:
	if !Game.meta.has("hints_seen"):
		Game.meta["hints_seen"] = []
	return Game.meta.hints_seen

## Queue a tip once (ignored if already seen or tips are off).
func hint(id: String) -> void:
	if !enabled() or id in seen() or id in _queue or !TIPS.has(id):
		return
	_queue.append(id)

func _local_player():
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and !p.remote_controlled:
			return p
	return null

func _process(delta: float) -> void:
	_t += delta
	if _showing > 0.0:
		_showing -= delta
		if _showing <= 0.0:
			panel.visible = false
	elif !_queue.is_empty() and !get_tree().paused:
		var id: String = _queue.pop_front()
		seen().append(id)
		Game.save_meta()
		label.text = "TIP   " + TIPS[id]
		panel.visible = true
		_showing = 8.0
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var p = _local_player()
	if p == null or !enabled():
		return
	if p.item == null and _t > 12.0:
		hint("pickup")
	if p.item != null:
		if _weapon_since < 0.0:
			_weapon_since = _t
			hint("attack")
		if _t - _weapon_since > 18.0 and Game.carried.get("stone", 0) + Game.carried.get("stick", 0) + Game.resources.get("stone", 0) + Game.resources.get("stick", 0) == 0:
			hint("gather")
	var carried := 0
	for k in Game.carried:
		carried += Game.carried[k]
	if carried >= 3 and !Game.local_in_base():
		hint("tower")
	if Game.local_in_base():
		hint("cards")
		for id in Game.hand:
			if Game.is_build(id):
				hint("build")
				break
	for g in get_tree().get_nodes_in_group("generator"):
		if is_instance_valid(g) and g.hovering:
			hint("generator")
	if Game.sectors_unlocked.size() > 1:
		hint("biome")
	if get_tree().get_nodes_in_group("chest").size() > 0:
		hint("chest")
	if get_tree().get_nodes_in_group("gold").size() > 0:
		hint("gold")
	if Game.run_stats.waves >= 1:
		hint("wave")
	var hud = get_parent().get_node_or_null("Hud")
	if hud and hud.equipped_items_count >= 2:
		hint("forge")
	if Game.crystal_away():
		hint("crystal")
	if !get_tree().get_nodes_in_group("critter").is_empty():
		hint("sheep")
	if Game.keep_hp < Game.keep_max() * 0.5:
		hint("keep_low")
	if Game.is_dark():
		hint("night")

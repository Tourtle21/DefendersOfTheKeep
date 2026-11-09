extends Node
## Local split screen for 2 to 4 players. Each player gets a SubViewport that shares the game's world with its own
## camera (the same technique dodger-madness uses). Player 1's HUD layers are pointed at player 1's viewport
## (CanvasLayer.custom_viewport) so nothing else in the game has to move; players 2 to 4 get a small HUD each.
## The cursor of player 1 (mouse or pad) is mapped into player 1's viewport by Pad.

const SPLIT_LAYER := 3                     # above the world, below the HUD layers (5 and up) and the menus
const HUD_SCRIPTS := ["ability_hud.gd", "base_ui.gd", "crystal_alert.gd", "respawn_ui.gd", "wave_banner.gd", "forge_ui.gd"]

var containers: Array = []
var viewports: Array = []
var cameras: Array = []
var rects: Array = []
var _players: Array = []                   # slot -> player node
var _corner: Array = []                    # slot -> {hp, name, weapon, down}
var _scale: Array = []
var _bg: ColorRect
var _count := 0

static func layout(count: int, size: Vector2) -> Array:
	var w := size.x
	var h := size.y
	match count:
		2:
			return [Rect2(0, 0, w / 2.0, h), Rect2(w / 2.0, 0, w / 2.0, h)]
		3:
			return [Rect2(0, 0, w / 2.0, h / 2.0), Rect2(w / 2.0, 0, w / 2.0, h / 2.0), Rect2(0, h / 2.0, w, h / 2.0)]
		_:
			return [Rect2(0, 0, w / 2.0, h / 2.0), Rect2(w / 2.0, 0, w / 2.0, h / 2.0), Rect2(0, h / 2.0, w / 2.0, h / 2.0), Rect2(w / 2.0, h / 2.0, w / 2.0, h / 2.0)]

func setup(count: int, local: Node) -> void:
	var screen := get_viewport().get_visible_rect().size
	rects = layout(count, screen)
	var layer := CanvasLayer.new()
	layer.layer = SPLIT_LAYER
	add_child(layer)
	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg)
	_count = count
	var world: Node = Game.world
	for slot in count:
		var r: Rect2 = rects[slot]
		var c := SubViewportContainer.new()
		c.stretch = true
		c.position = r.position + Vector2(1, 1)         # a thin black gap between the views
		c.size = r.size - Vector2(2, 2)
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		layer.add_child(c)
		var vp := SubViewport.new()
		vp.world_2d = get_viewport().world_2d
		vp.handle_input_locally = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		c.add_child(vp)
		var cam := Camera2D.new()
		vp.add_child(cam)
		cam.make_current()
		containers.append(c)
		viewports.append(vp)
		cameras.append(cam)
		_scale.append(minf(r.size.x / screen.x, r.size.y / screen.y))
		if slot == 0:
			_players.append(world.get_node("Player"))
		else:
			_players.append(local.avatars[slot])
	# player 1's HUD lives in player 1's view
	for n in world.get_children():
		if n is CanvasLayer and n.get_script() != null and str(n.get_script().resource_path).get_file() in HUD_SCRIPTS:
			n.custom_viewport = viewports[0]
	var hud = world.get_node_or_null("Hud")
	if hud != null:
		hud.custom_viewport = viewports[0]
	# players 2 to 4: a small HUD in their own view
	for slot in range(1, count):
		_make_corner(slot)
	Pad.enter_split(containers[0], viewports[0], int(Game._local_devices[0]) if !Game._local_devices.is_empty() else -1)
	get_viewport().size_changed.connect(_relayout)         # the window maximizes right after the game starts, and can be resized
	_relayout.call_deferred()
	_nudge.call_deferred()

## HUD layers were built for the full window: poke player 1's view once so they re-anchor to it.
func _nudge() -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	if !is_inside_tree() or viewports.is_empty():
		return
	var c: Control = containers[0]
	var keep: Vector2 = c.size
	c.size = keep + Vector2(2, 0)
	await get_tree().process_frame
	c.size = keep

## Fit the views to the window.
func _relayout() -> void:
	var screen := get_viewport().get_visible_rect().size
	rects = layout(_count, screen)
	_scale.clear()
	for slot in _count:
		var r: Rect2 = rects[slot]
		var c: Control = containers[slot]
		c.position = r.position + Vector2(1, 1)
		c.size = r.size - Vector2(2, 2)
		_scale.append(minf(r.size.x / screen.x, r.size.y / screen.y))

func _make_corner(slot: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.custom_viewport = viewports[slot]
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(10, 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	var name_l := Label.new()
	name_l.text = "PLAYER %d" % (slot + 1)
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(0.6, 1.0, 0.5), Color(1.0, 0.6, 0.9)][slot])
	name_l.add_theme_color_override("font_outline_color", Color.BLACK)
	name_l.add_theme_constant_override("outline_size", 5)
	box.add_child(name_l)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(170, 14)
	hp.max_value = 228.0
	hp.show_percentage = false
	hp.modulate = Color(1.0, 0.35, 0.3)
	box.add_child(hp)
	var weapon := Label.new()
	weapon.add_theme_font_size_override("font_size", 14)
	weapon.add_theme_color_override("font_outline_color", Color.BLACK)
	weapon.add_theme_constant_override("outline_size", 4)
	box.add_child(weapon)
	var down := Label.new()
	down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	down.add_theme_font_size_override("font_size", 28)
	down.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	down.add_theme_color_override("font_outline_color", Color.BLACK)
	down.add_theme_constant_override("outline_size", 7)
	down.visible = false
	layer.add_child(down)
	_corner.resize(maxi(_corner.size(), slot + 1))
	_corner[slot] = {"hp": hp, "weapon": weapon, "down": down}

func _process(_delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	for slot in cameras.size():
		var pl = _players[slot]
		if !is_instance_valid(pl):
			continue
		var pcam: Camera2D = pl.get_node("Camera2D")      # the player keeps its own camera node up to date (position, shake, zoom)
		var cam: Camera2D = cameras[slot]
		cam.global_position = pcam.global_position
		cam.offset = pcam.offset
		cam.zoom = pcam.zoom * _scale[slot]
		if slot > 0:
			var c: Dictionary = _corner[slot]
			c.hp.value = pl.remote_hp
			var item = pl.item
			c.weapon.text = "%s  T%d" % [Fusion.display_name(str(item.get("weapon_id")) if item != null and item.get("weapon_id") != null and str(item.get("weapon_id")) != "" else (item._id() if item != null and item.has_method("_id") else "")), Game.weapon_tier_of(str(pl.weapon_slots[pl.active_slot]))] if item != null and !pl.weapon_slots.is_empty() else "no weapon"
			c.down.visible = pl.downed
			c.down.text = "You fell!  Back in %d" % ceili(pl.respawn_left)
			var light = pl.get_node_or_null("PointLight2D")
			if light != null:
				light.energy = Game.night_level * 0.55        # the same gentle night light player 1 has

func _exit_tree() -> void:
	Pad.leave_split()

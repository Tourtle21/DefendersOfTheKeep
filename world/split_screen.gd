extends Node
## Local split screen for 2 to 4 players. Each player gets a SubViewport that shares the game's world with its own
## camera (the same technique dodger-madness uses). Player 1's HUD layers are pointed at player 1's viewport
## (CanvasLayer.custom_viewport) so nothing else in the game has to move; players 2 to 4 get a small HUD each.
## The cursor of player 1 (mouse or pad) is mapped into player 1's viewport by Pad.
const UiKit = preload("res://ui/cards/ui_kit.gd")

const SPLIT_LAYER := 3                     # above the world, below the HUD layers (5 and up) and the menus
const BIG_SCREENS := ["help_ui.gd"]
const HUD_SCRIPTS := ["ability_hud.gd", "base_ui.gd", "crystal_alert.gd", "respawn_ui.gd", "wave_banner.gd", "forge_ui.gd", "card_fuse_ui.gd", "draft_ui.gd", "help_ui.gd", "hints.gd"]

var containers: Array = []
var viewports: Array = []
var cameras: Array = []
var rects: Array = []
var _players: Array = []                   # slot -> player node
var _corner: Array = []                    # slot -> {hp, name, weapon, down}
var _scale: Array = []
var _bg: ColorRect
var _p1_layers: Array = []                 # player 1's HUD layers (their controls are pinned to player 1's view)
var _local_huds: Array = []                # players 2 to 4: their always-on HUD (ui/base/local_hud.gd)
var _slot_roots: Array = []                # slot -> the Control the small HUDs of players 2 to 4 are built in
var _count := 0
var _local: Node

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
	_bg.color = UiKit.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg)
	_count = count
	_local = local
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
			_p1_layers.append(n)
	var hud = world.get_node_or_null("Hud")
	if hud != null:
		hud.custom_viewport = viewports[0]
		_p1_layers.append(hud)
	# players 2 to 4: a small HUD in their own view
	for slot in range(1, count):
		_make_corner(slot)
		var kui := preload("res://ui/base/local_keep_ui.gd").new()
		add_child(kui)
		kui.setup(local.avatars[slot], viewports[slot], slot)
		local.keep_uis[slot] = kui
		var fui := preload("res://ui/base/local_forge_ui.gd").new()
		add_child(fui)
		fui.setup(local.avatars[slot], viewports[slot])
		local.forge_uis[slot] = fui
		var zui := preload("res://ui/base/local_fuser_ui.gd").new()
		add_child(zui)
		zui.setup(local.avatars[slot], viewports[slot])
		local.fuser_uis[slot] = zui
		var dui := preload("res://ui/base/local_draft_ui.gd").new()
		add_child(dui)
		dui.setup(local.avatars[slot], viewports[slot], slot)
		local.draft_uis[slot] = dui
	Pad.enter_split(containers[0], viewports[0], int(Game._local_devices[0]) if !Game._local_devices.is_empty() else -1)
	get_viewport().size_changed.connect(_relayout)         # the window maximizes right after the game starts, and can be resized
	_relayout.call_deferred()
	_pin_all.call_deferred()

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

## HUD controls anchored to the window's edges are laid out for the whole window, not for a view: re-place each one
## (keeping its anchors and offsets as designed) against the size of the view it is shown in.
func _pin_all() -> void:
	if viewports.is_empty() or !is_inside_tree():
		return
	var s0 := Vector2(viewports[0].size)
	for layer in _p1_layers:
		if layer.has_method("fit_view"):
			layer.fit_view(s0)                     # a shared screen sizes itself exactly like players 2-4's (ui/forge/forge_view.gd)
			continue
		var big: bool = str(layer.get_script().resource_path).get_file() in BIG_SCREENS
		var design := Vector2(1060, 1260) if str(layer.get_script().resource_path).get_file() == "help_ui.gd" else Vector2(1100, 760)       # (about how big each screen is drawn)
		var f: float = clampf(minf(s0.x / design.x, s0.y / design.y), 0.35, 1.0) if big else 1.0
		for c in layer.get_children():
			if c is Control:
				c.pivot_offset = Vector2.ZERO
				c.scale = Vector2(f, f)                  # a big screen (forge, card fuser, chest draft) is shrunk to fit a half-width view
				_pin(c, s0 / f)
	for slot in range(1, _count):
		if slot < _slot_roots.size() and _slot_roots[slot] != null:
			_slot_roots[slot].size = Vector2(viewports[slot].size)
		var kui = _keep_ui(slot)
		if kui != null:
			kui.fit(Vector2(viewports[slot].size))
		if _local != null and _local.forge_uis.has(slot):
			_local.forge_uis[slot].fit(Vector2(viewports[slot].size))
		if slot - 1 < _local_huds.size():
			_local_huds[slot - 1].fit(Vector2(viewports[slot].size))
		if _local != null and _local.fuser_uis.has(slot):
			_local.fuser_uis[slot].fit(Vector2(viewports[slot].size))
		if _local != null and _local.draft_uis.has(slot):
			_local.draft_uis[slot].fit(Vector2(viewports[slot].size))

func _keep_ui(slot: int):
	return _local.keep_uis.get(slot) if _local != null else null

func _pin(c: Control, area: Vector2) -> void:
	if !c.has_meta("_pin"):
		c.set_meta("_pin", [c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom, c.offset_left, c.offset_top, c.offset_right, c.offset_bottom])
	var o: Array = c.get_meta("_pin")
	var left: float = o[0] * area.x + o[4]
	var top: float = o[1] * area.y + o[5]
	var right: float = o[2] * area.x + o[6]
	var bottom: float = o[3] * area.y + o[7]
	for side in 4:
		c.set_anchor(side, 0.0, false, false)
	c.set_offset(SIDE_LEFT, left)
	c.set_offset(SIDE_TOP, top)
	c.set_offset(SIDE_RIGHT, right)
	c.set_offset(SIDE_BOTTOM, bottom)

## Fit the views to the window.
func _relayout() -> void:
	if !is_inside_tree() or get_viewport() == null:
		return                                   # (a window resize, or a deferred call, arriving after "Restart run" removed this screen)
	var screen := get_viewport().get_visible_rect().size
	rects = layout(_count, screen)
	_scale.clear()
	for slot in _count:
		var r: Rect2 = rects[slot]
		var c: Control = containers[slot]
		c.position = r.position + Vector2(1, 1)
		c.size = r.size - Vector2(2, 2)
		_scale.append(minf(r.size.x / screen.x, r.size.y / screen.y))
	_pin_all.call_deferred()

func _make_corner(slot: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.custom_viewport = viewports[slot]
	add_child(layer)
	var holder := Control.new()                         # sized to this player's view, so centred things really are centred
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(viewports[slot].size)
	layer.add_child(holder)
	_slot_roots.resize(maxi(_slot_roots.size(), slot + 1))
	_slot_roots[slot] = holder
	var hud := preload("res://ui/base/local_hud.gd").new()      # resources, keep bar, health bar, announcements, hurt flash: like player 1's
	add_child(hud)
	hud.setup(_players[slot], viewports[slot], slot)
	_local_huds.append(hud)
	var alert := CrystalAlert.new()                          # "the crystal was stolen": banner and an arrow in this player's view
	alert.view = viewports[slot]
	add_child(alert)
	alert.custom_viewport = viewports[slot]
	var wave := preload("res://ui/hud/wave_banner.gd").new()
	wave.title_font = 30
	wave.body_font = 14
	wave.half_width = 300.0
	add_child(wave)
	wave.custom_viewport = viewports[slot]
	var down := Label.new()
	down.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	down.add_theme_font_size_override("font_size", UiKit.FONT_TITLE)
	down.add_theme_color_override("font_color", UiKit.WARN)
	down.add_theme_color_override("font_outline_color", UiKit.BLACK)
	down.add_theme_constant_override("outline_size", 7)
	down.visible = false
	holder.add_child(down)
	_corner.resize(maxi(_corner.size(), slot + 1))
	var abilities := AbilityHud.new()                   # the same attack / ability / dash / ultimate panel player 1 has, for this avatar
	abilities.target = _players[slot]
	abilities.key_labels = ["RT", "X", "LT", "Y"]
	add_child(abilities)
	abilities.custom_viewport = viewports[slot]
	var slots_ctl := Control.new()                      # the weapon slots: what you carry, the one in hand tinted (ui/hud/weapon_slots.gd)
	slots_ctl.set_script(preload("res://ui/hud/weapon_slots.gd"))
	holder.add_child(slots_ctl)
	var aimer := Control.new()                          # the yellow aimer of this player, drawn in their view only (like player 1's cursor)
	aimer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aimer.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(aimer)
	aimer.draw.connect(func():
		var pl = _players[slot]
		if _local == null or !is_instance_valid(pl) or pl.downed or pl.is_in_tower or !_local.avatars.has(slot):
			return
		var at: Vector2 = viewports[slot].get_canvas_transform() * _local.aim_world_point(slot)
		var col := UiKit.WARM
		aimer.draw_arc(at, 12.0, 0, TAU, 28, Color(UiKit.BLACK, 0.85), 4.0)
		aimer.draw_arc(at, 12.0, 0, TAU, 28, col, 2.0)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			aimer.draw_line(at + d * 16.0, at + d * 22.0, col, 2.0))
	_corner[slot] = {"down": down, "aimer": aimer, "slots": slots_ctl}

func _process(_delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	for slot in cameras.size():
		var pl = _players[slot]
		if !is_instance_valid(pl):
			continue
		var pcam: Camera2D = pl.get_node("Camera2D")      # the player keeps its own camera node up to date (position, shake, zoom)
		var cam: Camera2D = cameras[slot]
		if slot > 0:
			pl.base_zoom = 2.0 if pl.is_in_tower else 5.0               # inside a tower the view pulls back and sits lower, like player 1's
		cam.global_position = pcam.global_position + (Vector2(0, 100) if slot > 0 and pl.is_in_tower else Vector2.ZERO)
		cam.offset = pcam.offset
		cam.zoom = pcam.zoom          # the same magnification as single player: a split view is a narrower window onto the same picture
		if slot > 0:
			var c: Dictionary = _corner[slot]
			c.aimer.queue_redraw()
			c.slots.slots = pl.weapon_slots
			c.slots.active = pl.active_slot
			var busy: bool = (Game.draft_active and Game.draft_owner_slot == slot) or (_local != null and _local.forge_uis.has(slot) and _local.forge_uis[slot].is_open)
			var mg: Dictionary = Game.held_merge(pl.weapon_slots) if !pl.is_in_tower and !pl.downed and !busy else {}
			c.slots.set_merge(mg, "D-pad down")
			c.down.visible = pl.downed
			c.down.text = "You fell!  Back in %d" % ceili(pl.respawn_left)
			var light = pl.get_node_or_null("PointLight2D")
			if light != null:
				light.energy = Game.night_level * 0.55        # the same gentle night light player 1 has

func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_relayout):
		vp.size_changed.disconnect(_relayout)
	Pad.leave_split()

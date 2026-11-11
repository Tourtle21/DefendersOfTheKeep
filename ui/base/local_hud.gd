extends CanvasLayer
## The always-on HUD of a local split-screen player (players 2 to 4): the shared HUD pieces (ui/hud/hud_kit.gd) in their
## view, like player 1's: resources top-left, the keep bar and wave countdown top-centre, the health bar top-right with
## their name tag, the announcement banner and a red flash when you are hit.

const HudKit = preload("res://ui/hud/hud_kit.gd")
const UiKit = preload("res://ui/cards/ui_kit.gd")

var pl: Node
var slot := 1
var root: Control
var top: Dictionary
var info: RichTextLabel:
	get: return top.info
var keep_bar: ProgressBar:
	get: return top.keep_bar
var keep_lbl: Label:
	get: return top.keep_lbl
var banner: Label:
	get: return top.banner
var wave_label: Label:
	get: return top.wave
var hp_fill: ColorRect
var flash: ColorRect

func setup(player: Node, viewport: SubViewport, slot_index: int) -> void:
	pl = player
	slot = slot_index
	layer = 5
	custom_viewport = viewport
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(viewport.size)
	root.theme = UiKit.make_theme(true)
	add_child(root)
	flash = HudKit.hurt_flash(root)
	if pl.has_signal("hurt"):
		pl.hurt.connect(func(): HudKit.flash(flash))
	top = HudKit.top(root)
	hp_fill = HudKit.health_bar(root)
	var tag := HudKit.outlined("PLAYER %d" % (slot + 1), UiKit.FONT_SMALL + 1, UiKit.PLAYER_COLORS[slot])
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tag.offset_left = -250
	tag.offset_right = -16
	tag.offset_top = 44
	root.add_child(tag)
	Game.announce.connect(func(text): HudKit.announce(top.banner, text))

func fit(area: Vector2) -> void:
	root.size = area
	HudKit.fit_top(top, area)

func _process(_delta: float) -> void:
	if !is_instance_valid(pl):
		return
	HudKit.set_top(top, pl.carried, Game.resources, Game.keep_hp, Game.keep_max())
	hp_fill.size.x = clampf(pl.remote_hp, 0.0, 228.0)

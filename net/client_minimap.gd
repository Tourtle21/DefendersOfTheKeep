extends Control
## Radar for the co-op client, drawn from the host's snapshots (same look as ui/base/minimap.gd).
const UiKit = preload("res://ui/cards/ui_kit.gd")

const SM := preload("res://world/sector_manager.gd")
const RANGE := 1150.0
var view            # the client view that owns the smoothed positions

func _init() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	visible = view != null and view._in_base
	if visible:
		queue_redraw()

func _map(p: Vector2) -> Vector2:
	return size / 2.0 + p / RANGE * (size.x / 2.0)

func _draw() -> void:
	var snap: Dictionary = Net.last_snapshot
	if !snap.has("players"):
		return
	var half := size.x / 2.0
	draw_circle(size / 2.0, half + 2.0, UiKit.SHADE)
	var open: Array = snap.sectors
	for id in Game.SECTOR_ANGLES:
		var c: float = Game.SECTOR_ANGLES[id]
		var col: Color = Color(UiKit.GRASS, 0.55) if id == "s" else SM.SECTORS[id].ground
		if id != "s":
			col.a = 0.7
		if !(id in open):
			col = Color(UiKit.MUTED_DARK, 0.35)
		var pts := PackedVector2Array([size / 2.0])
		for i in 13:
			pts.append(size / 2.0 + Vector2.from_angle(deg_to_rad(c - 30.0 + 60.0 * i / 12.0)) * half)
		draw_colored_polygon(pts, col)
	draw_arc(size / 2.0, half, 0, TAU, 48, Color(UiKit.WHITE, 0.6), 1.5)
	draw_circle(size / 2.0, 4.0, UiKit.MAGIC)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"):
			draw_circle(_map(e.global_position), 1.6, UiKit.BAD)
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b):
			draw_circle(_map(b.global_position), 4.5, UiKit.MAGIC if b.awake else UiKit.MAGIC.darkened(0.35))
	for c in get_tree().get_nodes_in_group("chest"):
		if is_instance_valid(c):
			draw_rect(Rect2(_map(c.global_position) - Vector2(2.5, 2.5), Vector2(5, 5)), UiKit.SKY if c.kind == "weapon" else UiKit.GOLD)
	for g in get_tree().get_nodes_in_group("generator"):
		if is_instance_valid(g) and g.visible:
			draw_circle(_map(g.global_position), 2.5, g.color if g.level > 0 else UiKit.MUTED)
	for p in snap.players:
		draw_circle(_map(p.pos), 3.0, UiKit.WHITE if p.id == multiplayer.get_unique_id() else UiKit.SKY)

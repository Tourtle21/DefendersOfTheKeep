extends Control
## Radar for the keep: the whole hex of sectors around the keep, with enemies,
## bosses, chests and the player as dots. Shown while someone is in the keep.
const UiKit = preload("res://ui/cards/ui_kit.gd")

const SM := preload("res://world/sector_manager.gd")
const RANGE := 1150.0           # world units from the keep to the edge of the map

func _init() -> void:
	custom_minimum_size = Vector2(220, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _map(p: Vector2) -> Vector2:
	return size / 2.0 + p / RANGE * (size.x / 2.0)

func _draw() -> void:
	var half := size.x / 2.0
	draw_circle(size / 2.0, half + 2.0, UiKit.SHADE)
	# the six sectors as wedges; locked ones are grey
	for id in Game.SECTOR_ANGLES:
		var c: float = Game.SECTOR_ANGLES[id]
		var unlocked: bool = id in Game.sectors_unlocked
		var col := Color(UiKit.GRASS, 0.55)
		if id != "s":
			col = SM.SECTORS[id].ground
			col.a = 0.7
		if !unlocked:
			col = Color(UiKit.MUTED_DARK, 0.35)
		var pts := PackedVector2Array([size / 2.0])
		for i in 13:
			var a := deg_to_rad(c - 30.0 + 60.0 * i / 12.0)
			pts.append(size / 2.0 + Vector2.from_angle(a) * half)
		draw_colored_polygon(pts, col)
		var label_pos := size / 2.0 + Vector2.from_angle(deg_to_rad(c)) * half * 0.62
		draw_circle(label_pos, 2.0, Color(UiKit.WHITE, 0.5) if unlocked else Color(UiKit.BLACK, 0.5))
	draw_arc(size / 2.0, half, 0, TAU, 48, Color(UiKit.WHITE, 0.6), 1.5)
	draw_circle(size / 2.0, 4.0, UiKit.MAGIC)                  # the keep
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss") and !(e.has_method("is_queued_for_deletion") and e.is_queued_for_deletion()):
			draw_circle(_map(e.global_position), 1.6, UiKit.BAD)
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b):
			var bp := _map(b.global_position)
			draw_circle(bp, 5.0, UiKit.BLACK)
			draw_circle(bp, 3.8, UiKit.MAGIC if b.awake else UiKit.MAGIC.darkened(0.35))
	for c in get_tree().get_nodes_in_group("chest"):
		var cp := _map(c.global_position)
		var col2 := UiKit.SKY if c.kind == "weapon" else UiKit.GOLD
		draw_rect(Rect2(cp - Vector2(2.5, 2.5), Vector2(5, 5)), col2)
	# resource generators in open sectors (ringed when there is something to collect), and structures
	for g in get_tree().get_nodes_in_group("generator"):
		if !is_instance_valid(g) or !g.is_visible_in_tree():
			continue
		var gp := _map(g.global_position)
		var gc: Color = g.color if g.level > 0 else UiKit.MUTED
		draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -3.5), gp + Vector2(3.5, 0), gp + Vector2(0, 3.5), gp + Vector2(-3.5, 0)]), gc)
		if g.stored > 0:
			draw_arc(gp, 5.5, 0, TAU, 12, Color(UiKit.WARM, 0.9), 1.2)
	for st in get_tree().get_nodes_in_group("structure"):
		if is_instance_valid(st):
			draw_circle(_map(st.global_position), 1.3, UiKit.GOOD)
	for c in get_tree().get_nodes_in_group("critter"):      # the rainbow sheep
		if is_instance_valid(c):
			draw_circle(_map(c.global_position), 3.2, Color.from_hsv(fmod(Time.get_ticks_msec() / 800.0, 1.0), 0.8, 1.0))
	if Game.crystal_away():             # the crystal (and where the thief is heading)
		var cp := _map(Game.crystal_pos)
		var cc := UiKit.BAD if Game.crystal_state == "carried" else UiKit.MAGIC
		draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -5), cp + Vector2(4, 0), cp + Vector2(0, 5), cp + Vector2(-4, 0)]), cc)
		if Game.crystal_state == "carried":
			var xp := _map(Game.crystal_exit)
			draw_line(xp + Vector2(-3, -3), xp + Vector2(3, 3), cc, 1.5)
			draw_line(xp + Vector2(-3, 3), xp + Vector2(3, -3), cc, 1.5)
	for p in get_tree().get_nodes_in_group("player"):
		draw_circle(_map(p.global_position), 3.0, UiKit.WHITE)

extends CanvasLayer
class_name AbilityHud
## Bottom-right: the four weapon moves (LMB attack, RMB ability, Shift dash, Space
## ultimate) with a radial cooldown sweep. When a move comes off cooldown the slot
## pops, flashes a ring and sparkles, so you notice without looking for it.
const UiKit = preload("res://ui/cards/ui_kit.gd")

const SLOTS := [
	{"id": "attack", "key": "LMB", "color": UiKit.WARN},
	{"id": "ability", "key": "RMB", "color": UiKit.SKY},
	{"id": "dash", "key": "SHIFT", "color": UiKit.GOOD},
	{"id": "ultimate", "key": "SPACE", "color": UiKit.MAGIC},
]
const BOX := 64.0
const GAP := 8.0

var canvas: Control
var target: Node = null             # split screen: show this co-op avatar's moves instead of player 1's
var key_labels: Array = []          # split screen: the controller buttons to print under the slots (attack, ability, dash, ultimate)
var remote_cd: Dictionary = {}       # client: cooldown info sent by the host (slot -> [left, total, name, locked, tier])
var _was_ready := {}
var _pop := {}               # slot id -> seconds since it became ready
var _time := 0.0

func _ready() -> void:
	layer = 5
	canvas = Control.new()
	if target == null:
		canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_slots)
	add_child(canvas)

func _process(delta: float) -> void:
	_time += delta
	if target != null and custom_viewport != null:
		canvas.size = Vector2(custom_viewport.size)          # fitted to the view this avatar is shown in
	for k in _pop.keys():
		_pop[k] += delta
		if _pop[k] > 0.7:
			_pop.erase(k)
	canvas.queue_redraw()

func _weapon():
	if !remote_cd.is_empty():
		return self          # cd_info() below answers from the host's data
	if target != null:
		if !is_instance_valid(target) or target.downed or target.is_in_tower:
			return null
		var tw = target.get("item")
		return tw if (tw is Weapon or tw is Tool) else null
	var pl = get_tree().get_first_node_in_group("player")
	if pl == null or !is_instance_valid(pl) or Game.local_in_base():
		return null
	var w = pl.get("item")
	return w if (w is Weapon or w is Tool) else null

func cd_info(slot: String) -> Array:
	return remote_cd.get(slot, [0.0, 1.0, ""])

func _draw_slots() -> void:
	var w = _weapon()
	if w == null:
		_was_ready.clear()
		return
	var font := ThemeDB.fallback_font
	var vp: Vector2 = canvas.size
	var total_w := SLOTS.size() * BOX + (SLOTS.size() - 1) * GAP
	var origin := Vector2(vp.x - total_w - 16.0, vp.y - BOX - 18.0)
	for i in SLOTS.size():
		var spec: Dictionary = SLOTS[i]
		var info: Array = w.cd_info(spec.id)
		var name: String = info[2]
		if name == "":
			continue
		var locked: bool = info.size() > 3 and info[3]
		var left: float = info[0]
		var total: float = max(info[1], 0.01)
		var ready: bool = left <= 0.0 and !locked
		var id: String = spec.id
		if _was_ready.get(id, true) == false and ready:
			_pop[id] = 0.0
		_was_ready[id] = ready
		var col: Color = spec.color
		var pos := origin + Vector2(i * (BOX + GAP), 0)
		var center := pos + Vector2(BOX, BOX) / 2.0
		var pop: float = _pop.get(id, 1.0)
		var scale := 1.0 + (0.28 * sin(pop / 0.7 * PI) if pop < 0.7 else 0.0)
		var half := BOX / 2.0 * scale
		var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
		canvas.draw_rect(rect.grow(2.0), UiKit.BLACK)
		canvas.draw_rect(rect, Color(UiKit.PANEL, 0.92))
		# icon: the weapon sprite for attack, a glyph for the rest
		var base_col := col if ready else col.darkened(0.55)
		_icon(id, center, half * 0.6, base_col)
		if locked:
			canvas.draw_rect(rect, UiKit.SHADE)
			# padlock + the tier that opens it
			var lc := center + Vector2(0, 4)
			canvas.draw_rect(Rect2(lc + Vector2(-8, -3), Vector2(16, 12)), UiKit.TEXT_DIM)
			canvas.draw_arc(lc + Vector2(0, -3), 6.0, PI, TAU, 12, UiKit.TEXT_DIM, 2.5)
			canvas.draw_string(font, center + Vector2(-half, -half + 14), "TIER %d" % info[4], HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, 11, UiKit.GOLD)
		elif !ready:
			# radial sweep: the dark wedge shrinks as the cooldown runs out
			var frac: float = clamp(left / total, 0.0, 1.0)
			var pts := PackedVector2Array([center])
			var steps := 28
			for s in steps + 1:
				var a := -PI / 2.0 + TAU * frac * (float(s) / steps)
				pts.append(center + Vector2.from_angle(a) * half * 1.45)
			var clip := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
			var poly := PackedVector2Array()
			for p in pts:
				poly.append(Vector2(clamp(p.x, clip.position.x, clip.end.x), clamp(p.y, clip.position.y, clip.end.y)))
			if poly.size() >= 3:
				canvas.draw_colored_polygon(poly, Color(UiKit.BLACK, 0.62))
			canvas.draw_string(font, center + Vector2(-half, 6.0), "%.1f" % left if left < 10.0 else "%d" % ceil(left), HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, 16, UiKit.WHITE)
		else:
			var glow := 0.5 + 0.5 * sin(_time * 4.0 + i)
			canvas.draw_rect(rect.grow(1.0), Color(col, 0.35 + 0.25 * glow), false, 2.0)
		# ready pop: expanding ring and sparkles
		if pop < 0.7:
			var t := pop / 0.7
			canvas.draw_arc(center, half * (1.0 + t * 0.9), 0, TAU, 32, Color(col, 1.0 - t), 3.0)
			for s in 6:
				var a := s * TAU / 6.0 + t
				canvas.draw_circle(center + Vector2.from_angle(a) * half * (1.1 + t * 0.8), 2.5 * (1.0 - t), Color(UiKit.WHITE, 1.0 - t))
		canvas.draw_string(font, pos + Vector2(0, BOX + 12.0), (key_labels[i] if i < key_labels.size() else spec.key), HORIZONTAL_ALIGNMENT_CENTER, BOX, 10, UiKit.STORE_TEXT)
		var short: String = name if name.length() <= 11 else name.substr(0, 10) + "."
		canvas.draw_string(font, pos + Vector2(-4.0, -4.0), short, HORIZONTAL_ALIGNMENT_CENTER, BOX + 8.0, 11, Color(UiKit.WHITE, 0.85) if ready else Color(UiKit.WHITE, 0.45))

func _star(center: Vector2, outer: float, inner: float, points: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2.from_angle(-PI / 2.0 + i * PI / points) * r)
	canvas.draw_colored_polygon(pts, col)

func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	match id:
		"attack":
			canvas.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 4.0)
			canvas.draw_line(c + Vector2(-r * 0.5, 0), c + Vector2(0, r * 0.5), col, 3.0)
		"ability":
			_star(c, r, r * 0.35, 4, col)
		"dash":
			for k in 2:
				var o := Vector2(k * r * 0.9 - r * 0.5, 0)
				canvas.draw_polyline(PackedVector2Array([c + o + Vector2(-r * 0.4, -r), c + o + Vector2(r * 0.4, 0), c + o + Vector2(-r * 0.4, r)]), col, 3.5)
		"ultimate":
			_star(c, r * 1.15, r * 0.5, 5, col)

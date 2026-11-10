extends Control
## The three stacked weapon frames, the same look as player 1's inventory (ui/hud/inventory): the weapon's icon, a tier badge,
## and the one in hand tinted blue. Used for players 2 to 4 in split screen and for a LAN client's own HUD.

var slots: Array = []          # weapon entries, e.g. "spear" or "hammer:1:twin"
var active := 0                # which of them is in hand
var hint := ""                 # e.g. "D-pad down: merge Spear + Hammer" when two held weapons can merge
var hint_ok := true
var _icons := {}
const FRAME_TEX := preload("res://ui/hud/inventory.png")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var k := clampf(size.y / 1000.0 * 1.1, 0.4, 0.6)
	var step := 133.0 * k
	var frame := 128.0 * k
	for i in 3:
		var top := size.y - 12.0 - frame - i * step
		var rect := Rect2(Vector2(10.0, top), Vector2(frame, frame))
		var is_active: bool = i == active and i < slots.size()
		draw_texture_rect(FRAME_TEX, rect, false, Color(0.3, 0.3, 1.0) if is_active else Color.WHITE)
		if i >= slots.size():
			continue
		var entry: String = slots[i]
		var info: Dictionary = Game.weapon_info(entry)
		var path: String = info.get("texture", "")
		if path != "":
			if !_icons.has(path):
				_icons[path] = load(path)
			var isz := 112.0 * k
			draw_texture_rect_region(_icons[path], Rect2(rect.position + (rect.size - Vector2(isz, isz)) / 2.0, Vector2(isz, isz)), Rect2(0, 0, 32, 32))
		var fs := int(20.0 * k * 1.6)
		var label := "T%d" % Game.weapon_tier_of(entry)
		var at := rect.position + Vector2(6.0 * k, frame - 6.0 * k)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.9, 0.3))
	if hint != "":
		var hs := int(20.0 * k * 1.3)
		var at2 := Vector2(frame + 22.0, size.y - 12.0 - frame - 6.0)
		var col := Color(0.6, 1.0, 0.65) if hint_ok else Color(1.0, 0.8, 0.45)
		draw_string_outline(font, at2, hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - at2.x - 8.0, hs, 5, Color.BLACK)
		draw_string(font, at2, hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - at2.x - 8.0, hs, col)

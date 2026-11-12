extends Control
## The three stacked weapon frames, the same look as player 1's inventory (ui/hud/inventory): the weapon's icon, a tier badge,
## and the one in hand tinted blue. Used for players 2 to 4 in split screen and for a LAN client's own HUD.
const UiKit = preload("res://ui/cards/ui_kit.gd")
const ResIcons = preload("res://ui/cards/res_icons.gd")

var slots: Array = []          # weapon entries, e.g. "spear" or "hammer:1:twin"
var active := 0                # which of them is in hand
var hint := ""                 # e.g. "D-pad down: merge Spear + Hammer" when two held weapons can merge
var hint_ok := true
var hint_cost := {}            # the merge cost, drawn as resource icons after the hint text
var hint_tail := ""            # e.g. "(not enough in the keep)"
const FRAME_TEX := preload("res://ui/hud/inventory.png")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Show the merge hint for Game.held_merge's result (empty: no hint). `key` is the button that merges ("F", "D-pad down").
func set_merge(m: Dictionary, key: String) -> void:
	hint = "" if m.is_empty() else "%s: merge  %s" % [key, m.text]
	hint_cost = {} if m.is_empty() else m.cost
	hint_tail = "" if m.is_empty() or m.ok else "(not enough in the keep)"
	hint_ok = m.get("ok", true)

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
		draw_texture_rect(FRAME_TEX, rect, false, UiKit.SLOT_ACTIVE if is_active else UiKit.WHITE)
		if i >= slots.size():
			continue
		var entry: String = slots[i]
		var info: Dictionary = Game.weapon_info(entry)
		var path: String = info.get("texture", "")
		if path != "":
			var tex: Texture2D = WeaponArt.hud_icon(str(info.id), Game.weapon_tier_of(entry), path)      # the tier's own drawing
			var isz := 112.0 * k
			draw_texture_rect(tex, Rect2(rect.position + (rect.size - Vector2(isz, isz)) / 2.0, Vector2(isz, isz)), false)
		var fs := int(20.0 * k * 1.6)
		var label := "T%d" % Game.weapon_tier_of(entry)
		var at := rect.position + Vector2(6.0 * k, frame - 6.0 * k)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, UiKit.BLACK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.GOLD)
	if hint != "":
		var hs := int(20.0 * k * 1.3)
		var at2 := Vector2(frame + 22.0, size.y - 12.0 - frame - 6.0)
		var col := UiKit.GOOD if hint_ok else UiKit.WARN
		draw_string_outline(font, at2, hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - at2.x - 8.0, hs, 5, UiKit.BLACK)
		draw_string(font, at2, hint, HORIZONTAL_ALIGNMENT_LEFT, size.x - at2.x - 8.0, hs, col)
		var hx := at2.x + font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x + 8.0
		hx = ResIcons.draw(self, Vector2(hx, at2.y), hint_cost, float(hs), hs, col)
		if hint_tail != "":
			draw_string(font, Vector2(hx, at2.y), hint_tail, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, col)

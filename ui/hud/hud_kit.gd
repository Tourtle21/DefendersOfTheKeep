extends RefCounted
## The HUD and keep-screen pieces, built ONE way for player 1 (ui/base/base_ui.gd), split-screen players 2-4
## (ui/base/local_hud.gd, ui/base/local_keep_ui.gd) and LAN clients (net/client_view.gd). Each builder makes the nodes;
## each setter fills them from plain data, so every front-end shows exactly the same thing.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const TierCard = preload("res://ui/cards/tier_card.gd")
const UPGRADE_CARD := Vector2(92, 128)
const UPGRADE_GLYPHS := {"max_mana": "M", "regen": "R", "draw": "D"}

## Text over the world: a font size, a colour and the black outline every HUD label has.
static func outlined(text: String, size: int, color := UiKit.TEXT, outline := 4) -> Label:
	var l := UiKit.label(text, size, color)
	l.add_theme_color_override("font_outline_color", UiKit.OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## The top of every HUD: the resource line (top-left), the keep bar and the wave countdown (top-centre) and the
## announcement banner. Returns {info, keep_bar, keep_lbl, wave, banner}.
static func top(parent: Control) -> Dictionary:
	var info := outlined("", UiKit.FONT_HEAD)
	info.position = Vector2(12, 10)
	parent.add_child(info)
	var keep_bar := ProgressBar.new()
	keep_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	keep_bar.offset_left = -170
	keep_bar.offset_right = 170
	keep_bar.offset_top = 38
	keep_bar.offset_bottom = 58
	keep_bar.show_percentage = false
	UiKit.style_bar(keep_bar, UiKit.KEEP_FILL)
	keep_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keep_lbl := outlined("", UiKit.FONT_SMALL, UiKit.TEXT, 3)
	keep_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	keep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keep_bar.add_child(keep_lbl)
	parent.add_child(keep_bar)
	var wave := outlined("", UiKit.FONT_BODY + 1, UiKit.WARM, 5)        # the countdown to the next wave, so there is time to prepare
	wave.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wave.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wave.position.y = 62
	parent.add_child(wave)
	var banner := outlined("", UiKit.FONT_TITLE, UiKit.WARM, 6)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 70
	banner.offset_left = -400
	banner.offset_right = 400
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.modulate.a = 0.0
	parent.add_child(banner)
	return {"info": info, "keep_bar": keep_bar, "keep_lbl": keep_lbl, "wave": wave, "banner": banner}

## Lay the top out for a view: a narrow view (a half or quarter window) wraps the resource line left of the health bar
## and moves the keep bar, wave countdown and banner down under it.
static func fit_top(t: Dictionary, area: Vector2) -> void:
	var narrow: bool = area.x < 900.0
	var info: Label = t.info
	info.add_theme_font_size_override("font_size", UiKit.FONT_SMALL + 1 if narrow else UiKit.FONT_HEAD)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if narrow else TextServer.AUTOWRAP_OFF
	info.custom_minimum_size.x = (area.x - 280.0) if narrow else 0.0
	info.reset_size()
	t.keep_bar.offset_top = 52.0 if narrow else 38.0
	t.keep_bar.offset_bottom = 70.0 if narrow else 58.0
	t.wave.position.y = 74.0 if narrow else 62.0
	t.banner.offset_top = 80.0 if narrow else 70.0
	t.banner.add_theme_font_size_override("font_size", UiKit.FONT_BIG if narrow else UiKit.FONT_TITLE)
	t.banner.offset_left = -300.0 if narrow else -400.0
	t.banner.offset_right = 300.0 if narrow else 400.0

## Fill the top from plain numbers (the same for every player: the keep and the wave are shared).
static func set_top(t: Dictionary, carried: Dictionary, keep_res: Dictionary, keep_hp: float, keep_max: float) -> void:
	var line := Game.resource_line(carried, keep_res)
	if line != t.info.text:
		t.info.text = line
		t.info.reset_size()
	t.keep_bar.max_value = keep_max
	t.keep_bar.value = keep_hp
	t.keep_lbl.text = "Keep %d / %d" % [keep_hp, keep_max]
	t.wave.text = Game.wave_timer_text()

## Show an announcement in the banner for a few seconds.
static func announce(banner: Label, text: String) -> void:
	banner.text = text
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)

## The health bar top-right, as in the original HUD (ui/hud/hud.tscn): a 3 px black frame and a red fill. Returns the fill.
static func health_bar(parent: Control) -> ColorRect:
	var frame := ColorRect.new()
	frame.color = UiKit.HP_FRAME
	frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	frame.offset_left = -250
	frame.offset_right = -16
	frame.offset_top = 16
	frame.offset_bottom = 43
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var fill := ColorRect.new()
	fill.color = UiKit.HP_RED
	fill.position = Vector2(3, 3)
	fill.size = Vector2(228, 21)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(fill)
	return fill

## A red flash over the whole view when you are hit.
static func hurt_flash(parent: Control) -> ColorRect:
	var flash := ColorRect.new()
	flash.color = Color(UiKit.HP_RED, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(flash)
	return flash

static func flash(f: ColorRect) -> void:
	f.color.a = 0.35
	f.create_tween().tween_property(f, "color:a", 0.0, 0.4)

## The mana bar with "Mana x / y" and the thin card-draw bar under it. Returns {mana, label, draw, box}.
static func mana_block(parent: Control, width := 420.0) -> Dictionary:
	var mana := ProgressBar.new()
	mana.custom_minimum_size = Vector2(width, 22)
	mana.show_percentage = false
	UiKit.style_bar(mana, UiKit.MANA_FILL)
	mana.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mana)
	var label := outlined("", UiKit.FONT_BODY, UiKit.TEXT, 3)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana.add_child(label)
	var draw := ProgressBar.new()
	draw.custom_minimum_size = Vector2(width, 6)
	draw.show_percentage = false
	draw.max_value = 1.0
	UiKit.style_bar(draw, UiKit.DRAW_FILL, 1)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(draw)
	return {"mana": mana, "label": label, "draw": draw}

static func set_mana(m: Dictionary, mana: float, max_mana: float, draw: float) -> void:
	m.mana.max_value = max_mana
	m.mana.value = mana
	m.label.text = "Mana %d / %d" % [mana, max_mana]
	m.draw.value = draw

static func size_mana(m: Dictionary, width: float) -> void:
	m.mana.custom_minimum_size.x = width
	m.draw.custom_minimum_size.x = width

## Repair and the keep upgrades as small cards (green frame: you can buy it now; the gems are the level).
## `pick` is a controller's highlight (-1 none). `on_repair` / `on_buy(id)` make them clickable (invalid: not clickable).
## `have` is the keep's resources, `keep_hp` / `keep_max` its health (a LAN client passes the snapshot's).
static func upgrade_cards(box: Container, card_size: Vector2, pick: int, have: Dictionary, keep_hp: float, keep_max: float,
		on_repair := Callable(), on_buy := Callable()) -> void:
	UiKit.clear(box)
	var can_repair := Game.can_repair(have, keep_hp, keep_max)
	var rc := TierCard.new()
	rc.setup({"size": card_size, "title": "Repair", "glyph": "+", "lines": ["+%d keep" % Game.REPAIR_AMOUNT], "footer": Game.cost_line(Game.REPAIR_COST),
		"accent": UiKit.KEEP_FILL, "locked": !can_repair, "tooltip": "Repair the keep +%d (%s)" % [Game.REPAIR_AMOUNT, Game.cost_line(Game.REPAIR_COST)], "blink": pick == 0})
	rc.set_selected(can_repair)
	_clickable(rc, on_repair, [])
	box.add_child(rc)
	var n := 0
	for id in Game.UPGRADES:
		n += 1
		var u: Dictionary = Game.UPGRADES[id]
		var cost := Game.upgrade_cost(id)
		var lvl: int = Game.upgrade_levels.get(id, 0)
		var can := true
		for t in cost:
			if int(have.get(t, 0)) < int(cost[t]):
				can = false
		var c := TierCard.new()
		c.setup({"size": card_size, "title": u.name, "glyph": UPGRADE_GLYPHS.get(id, "+"), "tier": mini(lvl, 6), "max_tier": 6, "badge": "Lv %d" % lvl,
			"lines": [u.desc], "footer": Game.cost_line(cost).replace(",", ""), "accent": UiKit.SKY, "locked": !can,
			"tooltip": "%s: %s" % [u.name, u.desc], "blink": pick == n})
		c.set_selected(can)
		_clickable(c, on_buy, [id])
		box.add_child(c)
	box.reset_size()                 # (a box keeps its old size when the cards get smaller: shrink it to them)

static func _clickable(card: Control, action: Callable, args: Array) -> void:
	if action.is_valid():
		card.pressed.connect(func(_c): action.callv(args))
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Repair / upgrade card size in a view `view_w` wide: full size from 1100 px, smaller in a split view (same rule for all).
static func upgrade_size(view_w: float) -> Vector2:
	return UPGRADE_CARD * clampf(view_w / 1100.0, 0.5, 1.0)

## Lay the keep screen out for a view (the same for every player): mana bar width, a radar as large as the view allows
## (top-right), the upgrade cards under the keep bar and the hint under the wave timer (both lower in a narrow view).
static func fit_keep(area: Vector2, mana: Dictionary, radar: Control, upgrade_box: Control, hint: Label) -> void:
	var narrow: bool = area.x < 900.0
	size_mana(mana, minf(420.0, area.x * 0.86))
	var r: float = clampf(minf(area.x * 0.32, area.y * 0.4), 90.0, 220.0)
	radar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -(r + 16.0)
	radar.offset_right = -16.0
	radar.offset_top = 66.0
	radar.offset_bottom = 66.0 + r
	radar.custom_minimum_size = Vector2(r, r)          # (the radar asks for 220 by itself, more than a small view has)
	upgrade_box.position = Vector2(12.0, 124.0 if narrow else 100.0)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = 98.0 if narrow else 84.0
	hint.custom_minimum_size.x = area.x - 24.0
	hint.offset_left = -(area.x - 24.0) / 2.0
	hint.offset_right = (area.x - 24.0) / 2.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## The hand as cards in a row, scaled by `cs`; `sel` is lifted. `on_down(i)` makes them clickable. Returns the CardViews.
static func hand_cards(row: Container, hand: Array, cs: float, sel: int, on_down := Callable()) -> Array:
	UiKit.clear(row)
	var views := []
	for i in hand.size():
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE * cs
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE if !on_down.is_valid() else Control.MOUSE_FILTER_PASS
		var v := CardView.new()
		v.setup(Game.entry_id(hand[i]), Game.entry_tier(hand[i]), "", Game.entry_twist(hand[i]))
		v.scale = Vector2(cs, cs)
		if on_down.is_valid():
			var idx := i
			v.pressed_down.connect(func(_v): on_down.call(idx))
		else:
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(v)
		row.add_child(holder)
		v.set_state(i == sel, Game.can_cast(hand[i]) if Game.in_base else true)
		views.append(v)
	return views

## The biggest hand-card scale (up to full size) that fits n cards across `width`.
static func hand_scale(n: int, width: float) -> float:
	var k := maxi(1, n)
	return clampf((width * 0.96 - 8.0 * (k - 1)) / (k * CardView.SIZE.x), 0.45, 1.0)

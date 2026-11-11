extends RefCounted
## The buttons under a reward / drawn card, built ONCE for the end-of-run screen and the Drawn tab: one highlighted main button (Unlock,
## Upgrade or Merge) and the other choices side by side under it (Convert, or Combine and Sell). `opt` is the entry
## {kind, id, tier, realm, result: "offer" | "upgrade" | "spare", cost?}; `changed` is called after any action so the screen can refresh.

const UiKit = preload("res://ui/cards/ui_kit.gd")

static func build(opt: Dictionary, width: float, changed: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size.x = width
	var main_btn: Button = null
	var side: Array = []
	if opt.result == "upgrade":
		var cid := str(opt.id)
		var is_weapon: bool = str(opt.get("kind", "card")) == "weapon"
		var owned_next: bool = (Game.weapon_tier_unlocked(cid) if is_weapon else Game.card_tier(cid)) >= int(opt.tier)
		var price: int = Game.weapon_tier_price(cid) if is_weapon else Game.card_upgrade_cost(cid)
		main_btn = _button("Upgraded" if owned_next else "Upgrade  (%d)" % price, true, !owned_next and Game.meta.shards >= price, width, func():
			if (Game.buy_weapon_tier(cid) if is_weapon else Game.upgrade_card(cid)):
				Sfx.play_ui("reveal_3")
				changed.call())
	elif opt.result == "spare":
		var can_up: bool = int(opt.tier) < Game.MAX_LEVEL
		main_btn = _button(("Merge  -> T%d" % (int(opt.tier) + 1)) if can_up else "Max tier", true, Game.spare_can_merge(opt), width, func():
			if Game.spare_merge(opt):
				Sfx.play_ui("reveal_3")
				changed.call())
		main_btn.tooltip_text = "Merges this copy into your card: that draws its next tier, and you pay Shards to upgrade to it."
		if !Game.spare_pair(opt).is_empty() and can_up:
			var comb := _button("Combine", false, true, width, func():
				if Game.spare_combine(opt):
					Sfx.play_ui("reveal_2")
					changed.call())
			comb.tooltip_text = "Two spare copies of the same card and tier make one spare a tier higher."
			side.append(comb)
		side.append(_button("Sell  +%d" % Game.spare_sell_value(opt), false, true, width, func():
			Game.spare_sell(opt)
			changed.call()))
	elif opt.result == "offer":
		main_btn = _button("Unlock  (%d)" % opt.cost, true, Game.meta.shards >= opt.cost, width, func():
			if Game.unlock_offer(opt):
				changed.call())
		side.append(_button("Convert  +%d" % Game.offer_convert_value(opt), false, true, width, func():
			Game.convert_offer(opt)
			changed.call()))
	if main_btn != null:
		box.add_child(main_btn)
	if !side.is_empty():
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		srow.custom_minimum_size.x = width
		var th := UiKit.make_theme()
		for b in side:
			b.custom_minimum_size.x = 0.0                        # share the row equally; the width never depends on the text
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			if width < 160.0:
				b.add_theme_font_size_override("font_size", UiKit.FONT_TINY)      # a narrow column: smaller text so "Combine" fits its half
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb: StyleBoxFlat = th.get_stylebox(st, "Button").duplicate()
				sb.content_margin_left = 4.0
				sb.content_margin_right = 4.0
				b.add_theme_stylebox_override(st, sb)
			srow.add_child(b)
		box.add_child(srow)
	return box

## One button, always the same width: the main one is highlighted, the others plain and smaller.
static func _button(text: String, main: bool, enabled: bool, width: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = !enabled
	b.custom_minimum_size = Vector2(width, 34.0 if main else 28.0)
	b.add_theme_font_size_override("font_size", UiKit.FONT_BODY if main else UiKit.FONT_SMALL)
	if main and enabled:
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UiKit.style(UiKit.GOLD_FILL, UiKit.GOLD, 6.0))
	b.pressed.connect(cb)
	return b

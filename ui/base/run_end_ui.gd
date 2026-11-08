extends CanvasLayer
## Shown when a run ends (you fall, or the crystal is stolen): what you earned,
## the Shard shop that permanently unlocks cards, and Play again.

var root_ctl: Control
var title: Label
var summary: Label
var shop_row: HBoxContainer
var extras_row: HBoxContainer
var skills: SkillTreeUi
var codex: CodexUi
var reward_head: Label
var recipe_label: Label
var collection: CollectionUi
var _rewards: Array = []
var shards_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # keeps working while the game is paused
	layer = 20
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.visible = false
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	root_ctl.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	summary = Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 18)
	box.add_child(summary)
	shards_label = Label.new()
	shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shards_label.add_theme_font_size_override("font_size", 22)
	shards_label.add_theme_color_override("font_color", Color("8fd8ff"))
	box.add_child(shards_label)
	reward_head = Label.new()
	reward_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_head.add_theme_font_size_override("font_size", 14)
	box.add_child(reward_head)
	shop_row = HBoxContainer.new()
	shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_row.add_theme_constant_override("separation", 14)
	recipe_label = Label.new()
	recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_label.add_theme_color_override("font_color", Color("6df08a"))
	recipe_label.add_theme_font_size_override("font_size", 15)
	box.add_child(recipe_label)
	var scroll := ScrollContainer.new()          # kept offers can be many: scroll sideways
	scroll.custom_minimum_size = Vector2(900, 270)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(shop_row)
	box.add_child(scroll)
	extras_row = HBoxContainer.new()
	extras_row.alignment = BoxContainer.ALIGNMENT_CENTER
	extras_row.add_theme_constant_override("separation", 10)
	box.add_child(extras_row)
	collection = CollectionUi.new()
	add_child(collection)
	collection.closed.connect(func(): _refresh())
	skills = SkillTreeUi.new()
	add_child(skills)
	skills.closed.connect(func(): _refresh())
	codex = CodexUi.new()
	add_child(codex)
	var codex_btn := Button.new()
	codex_btn.text = "Weapon codex"
	codex_btn.custom_minimum_size = Vector2(320, 40)
	codex_btn.pressed.connect(func(): codex.open())
	box.add_child(codex_btn)
	var skill_btn := Button.new()
	skill_btn.text = "Skill tree (permanent upgrades)"
	skill_btn.custom_minimum_size = Vector2(320, 40)
	skill_btn.pressed.connect(func(): skills.open())
	box.add_child(skill_btn)
	var coll_btn := Button.new()
	coll_btn.text = "Card collection (upgrade with Shards)"
	coll_btn.custom_minimum_size = Vector2(320, 40)
	coll_btn.pressed.connect(func(): collection.open())
	box.add_child(coll_btn)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(200, 48)
	again.pressed.connect(func(): Game.restart_run())
	box.add_child(again)
	Game.run_ended.connect(_show)

func _show(info: Dictionary) -> void:
	get_tree().paused = true
	title.text = info.reason
	var st: Dictionary = info.stats
	summary.text = "Waves survived: %d    Enemies slain: %d    Gold collected: %d    Best wave: %d" % [st.waves, st.kills, st.gold, Game.meta.best_wave]
	_rewards = info.get("rewards", [])
	_refresh(info.shards)
	root_ctl.visible = true

func _refresh(earned: int = -1) -> void:
	shards_label.text = ("+%d Shards earned   " % earned if earned >= 0 else "") + "Shards: %d" % Game.meta.shards
	_refresh_extras()
	for c in shop_row.get_children():
		shop_row.remove_child(c)
		c.queue_free()
	var total_conv := 0
	for opt in _rewards:
		total_conv += int(opt.shards)
	# offers from earlier runs that you have not unlocked or converted yet are still yours
	var kept := []
	for pe in Game.meta.pending:
		var is_new := false
		for e in _rewards:
			if e.kind == pe.kind and e.id == pe.id:
				is_new = true
		if !is_new:
			kept.append(pe)
	var shown: Array = _rewards + kept
	reward_head.text = "Reached level %d of 6: %d reward cards%s. New cards and weapons cost Shards to unlock, or convert them to save up. Offers you leave here are kept for next time; tier-ups apply; duplicates became +%d Shards" % [
		Game.level_reached(), _rewards.size(), (" and %d kept from before" % kept.size()) if kept.size() > 0 else "", total_conv]
	recipe_label.text = "\n".join(Game.recipe_log)
	for opt in shown:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE
		if opt.kind == "card":
			var view := CardView.new()
			view.setup(opt.id, opt.tier, "T%d" % opt.tier)
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(view)
		else:
			var wl := Label.new()
			wl.text = "WEAPON\n\n%s" % String(opt.id).capitalize()
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			wl.clip_text = true
			wl.position = Vector2(0, 40)
			wl.custom_minimum_size = Vector2(CardView.SIZE.x, 60)
			wl.size = Vector2(CardView.SIZE.x, 60)
			holder.add_child(wl)
		if opt.result == "converted" or opt.result == "offer":
			holder.modulate = Color(0.85, 0.85, 0.9) if opt.result == "offer" else holder.modulate
		if opt.result == "converted":
			holder.modulate = Color(0.6, 0.6, 0.65)
		col.add_child(holder)
		var tag := Label.new()
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		match opt.result:
			"offer":
				tag.text = "KEPT" if opt in kept else "NEW"
				tag.add_theme_color_override("font_color", Color("6df08a"))
			"unlocked":
				tag.text = "UNLOCKED"
				tag.add_theme_color_override("font_color", Color("6df08a"))
			"upgrade":
				tag.text = "TIER UP -> T%d" % opt.tier
				tag.add_theme_color_override("font_color", Color("ffd23a"))
			_:
				tag.text = "Owned: +%d Shards" % opt.shards
				tag.add_theme_color_override("font_color", Color("8fd8ff"))
		col.add_child(tag)
		if opt.result == "offer":
			var unlock := Button.new()
			unlock.text = "Unlock (%d)" % opt.cost
			unlock.disabled = Game.meta.shards < opt.cost
			unlock.pressed.connect(func():
				if Game.unlock_offer(opt):
					_refresh())
			col.add_child(unlock)
			var conv := Button.new()
			conv.text = "Convert (+%d)" % Game.convert_value(int(opt.tier), int(opt.get("realm", 1)))
			conv.pressed.connect(func():
				Game.convert_offer(opt)
				_refresh())
			col.add_child(conv)
		shop_row.add_child(col)

## Weapon unlocks, fusion tiers and the starting weapon, as compact buttons.
func _refresh_extras() -> void:
	Game.fix_meta()

	for c in extras_row.get_children():
		extras_row.remove_child(c)
		c.queue_free()
	for id in Game.WEAPON_UNLOCK_COSTS:
		if id in Game.SECTOR_WEAPONS.values():
			continue                      # sector weapons are unlocked in the weapon codex or from reward draws
		var owned: bool = id in Game.meta.weapons
		var b := Button.new()
		b.text = "%s (owned)" % id.capitalize() if owned else "Weapon: %s - %d" % [id.capitalize(), Game.WEAPON_UNLOCK_COSTS[id]]
		b.disabled = owned or Game.meta.shards < Game.WEAPON_UNLOCK_COSTS[id]
		b.tooltip_text = "Adds this weapon to the chest pool for every run."
		b.pressed.connect(func():
			if Game.buy_weapon(id):
				_refresh())
		extras_row.add_child(b)
	for t in Game.FUSION_TIER_COSTS:
		var have: bool = Game.fusion_tier_unlocked(t)
		var b := Button.new()
		b.text = "Tier %d fusions (owned)" % t if have else "Tier %d fusions - %d" % [t, Game.FUSION_TIER_COSTS[t]]
		b.disabled = have or Game.meta.shards < Game.FUSION_TIER_COSTS[t] or (t > 3 and !Game.fusion_tier_unlocked(t - 1))
		b.pressed.connect(func():
			if Game.buy_fusion_tier(t):
				_refresh())
		extras_row.add_child(b)
	var l := Label.new()
	l.text = "Start with:"
	extras_row.add_child(l)
	var opt := OptionButton.new()
	var options: Array = Game.start_weapon_options()
	for o in options:
		opt.add_item(Fusion.display_name(String(o)))
	opt.selected = max(0, options.find(Game.meta.start_weapon))
	opt.item_selected.connect(func(i: int): Game.set_start_weapon(options[i]))
	extras_row.add_child(opt)

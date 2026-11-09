extends CanvasLayer
## Shown when a run ends (you fall, or the crystal is stolen): what you earned,
## the Shard shop that permanently unlocks cards, and Play again.

const UiKit = preload("res://ui/cards/ui_kit.gd")
const DrawsUi = preload("res://ui/base/draws_ui.gd")
const TierCard = preload("res://ui/cards/tier_card.gd")
var root_ctl: Control
var title: Label
var summary: Label
var shop_row: Container
var extras_row: Container
var skills: SkillTreeUi
var codex: CodexUi
var reward_head: Label
var recipe_label: Label
var collection: CollectionUi
var _rewards: Array = []
var _flippers: Array = []            # one callable per face-down reward
var flip_all: Button
var pull_label: Label
var _box: VBoxContainer
var _box_origin := Vector2.ZERO
var _box_origin_set := false
var _shake_tw: Tween
var shards_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # keeps working while the game is paused
	layer = 20
	root_ctl = Control.new()
	root_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctl.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctl.visible = false
	root_ctl.theme = UiKit.make_theme()
	add_child(root_ctl)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(dim)
	var frame := UiKit.panel(Color(0.07, 0.07, 0.13), UiKit.BORDER, 16.0)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	root_ctl.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)
	_box = box
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
	reward_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_head.custom_minimum_size = Vector2(1000, 0)
	reward_head.add_theme_font_size_override("font_size", 14)
	box.add_child(reward_head)
	flip_all = Button.new()
	flip_all.text = "Flip all"
	flip_all.custom_minimum_size = Vector2(200, 36)
	flip_all.pressed.connect(func(): _flip_all())
	box.add_child(flip_all)
	pull_label = Label.new()
	pull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_label.add_theme_font_size_override("font_size", 20)
	pull_label.visible = false
	box.add_child(pull_label)
	shop_row = HFlowContainer.new()
	shop_row.alignment = FlowContainer.ALIGNMENT_CENTER
	shop_row.add_theme_constant_override("h_separation", 14)
	shop_row.add_theme_constant_override("v_separation", 10)
	shop_row.custom_minimum_size = Vector2(1000, 0)
	recipe_label = Label.new()
	recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_label.add_theme_color_override("font_color", Color("6df08a"))
	recipe_label.add_theme_font_size_override("font_size", 15)
	box.add_child(recipe_label)
	box.add_child(shop_row)                      # wraps onto more rows: no scrolling
	extras_row = HFlowContainer.new()                  # wraps onto more lines instead of running off the screen
	extras_row.alignment = FlowContainer.ALIGNMENT_CENTER
	extras_row.custom_minimum_size = Vector2(1000, 0)
	extras_row.add_theme_constant_override("h_separation", 10)
	extras_row.add_theme_constant_override("v_separation", 6)
	var again := Button.new()
	again.text = "Continue"
	again.custom_minimum_size = Vector2(240, 52)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func():                   # back to the main menu (cards, weapons, skills and unlocks live there)
		Game._menu_done = false
		Game.restart_run())
	box.add_child(again)
	preload("res://ui/cards/menu_pad.gd").attach(root_ctl, Callable(), "", null, flip_all)       # controller: Flip all first, then Continue
	Game.run_ended.connect(_show)

func _show(info: Dictionary) -> void:
	get_tree().paused = true
	title.text = info.reason
	var st: Dictionary = info.stats
	summary.text = "Waves survived: %d    Enemies slain: %d    Gold collected: %d    Best wave: %d" % [st.waves, st.kills, st.gold, Game.meta.best_wave]
	_rewards = info.get("rewards", [])
	_box_origin_set = false
	_refresh(info.shards)
	root_ctl.visible = true

func _refresh(earned: int = -1) -> void:
	shards_label.text = ("+%d Shards earned   " % earned if earned >= 0 else "") + "Shards: %d" % Game.meta.shards
	_refresh_extras()
	for c in shop_row.get_children():
		shop_row.remove_child(c)
		c.queue_free()
	_flippers.clear()
	pull_label.visible = false
	var total_conv := 0
	for opt in _rewards:
		total_conv += int(opt.shards)
	# offers from earlier runs that you have not unlocked or converted yet are still yours
	var kept := []
	for pe in Game.meta.pending:
		var is_new := false
		for e in _rewards:
			if is_same(e, pe):
				is_new = true
		if !is_new:
			kept.append(pe)
	var shown: Array = _rewards                 # only what this run earned; older unclaimed ones wait in Drawn Cards
	kept = []
	var waiting: int = Game.waiting_draws().size()
	reward_head.text = "Flip your reward cards  (level %d)%s" % [Game.level_reached(), ("   -   %d more waiting in Drawn Cards" % maxi(0, waiting - _rewards.size())) if waiting > _rewards.size() else ""]
	if _rewards.is_empty():
		reward_head.text = "No rewards this time. Survive wave 1 to earn cards."
	recipe_label.text = "\n".join(Game.recipe_log)
	var unrevealed := 0
	for opt in shown:
		var is_kept: bool = opt in kept
		var hidden: bool = !is_kept and !opt.get("revealed", false)
		if hidden:
			unrevealed += 1
		var rarity: int = Game.rarity_of(opt.kind, str(opt.id))             # from where the card is found, never from its tier
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var holder := Control.new()
		holder.custom_minimum_size = CardView.SIZE
		holder.pivot_offset = CardView.SIZE / 2.0
		var face := _make_face(opt)
		holder.add_child(face)
		var back := TextureRect.new()
		back.texture = load("res://ui/cards/card_back.png")
		back.size = CardView.SIZE
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.add_child(back)
		var fx = preload("res://ui/cards/rarity_fx.gd").new()
		fx.setup(rarity, CardView.SIZE)
		holder.add_child(fx)
		col.add_child(holder)
		var footer := VBoxContainer.new()
		footer.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(footer)
		shop_row.add_child(col)
		if hidden:
			face.visible = false
			fx.visible = false
			var hint := Label.new()
			hint.text = "click to flip"
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
			footer.add_child(hint)
			var flip := func(): _reveal(opt, holder, face, back, fx, footer, rarity)
			back.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					flip.call())
			back.mouse_entered.connect(func():
				if !opt.get("revealed", false):
					Sfx.play_ui("deal", 1.5)
					create_tween().tween_property(holder, "scale", Vector2(1.07, 1.07), 0.08))
			back.mouse_exited.connect(func():
				if !opt.get("revealed", false):
					create_tween().tween_property(holder, "scale", Vector2.ONE, 0.1))
			_flippers.append(flip)
			_deal(holder, unrevealed - 1)
		else:
			back.visible = false
			fx.play_burst()
			_fill_footer(footer, opt, holder, is_kept, rarity)
	flip_all.visible = unrevealed > 0
	flip_all.text = "Flip all (%d)" % unrevealed

## What a reward looks like face up: a card, or a weapon panel with its icon and rarity colour.
func _make_face(opt: Dictionary) -> Control:
	if opt.kind == "card":
		var view := CardView.new()
		view.setup(opt.id, opt.tier)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return view
	var r: int = Game.weapon_rarity(str(opt.id))
	var panel := Panel.new()
	panel.custom_minimum_size = CardView.SIZE
	panel.size = CardView.SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("252c52")
	sb.border_color = Game.rarity_color(r)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	var info = load("res://world/item_info.tres").items.get(str(opt.id), {})
	if info.has("texture"):
		icon.texture = load(info.texture)
	icon.position = Vector2(24, 22)
	icon.size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(icon)
	var name_l := Label.new()
	name_l.text = Fusion.display_name(str(opt.id))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(4, 78)
	name_l.size = Vector2(88, 22)
	name_l.add_theme_font_size_override("font_size", 12)
	panel.add_child(name_l)
	var kind_l := Label.new()
	kind_l.text = ("TIER %d" % int(opt.tier)) if opt.get("result", "") == "tierup" else "WEAPON"
	kind_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_l.position = Vector2(4, 108)
	kind_l.size = Vector2(88, 20)
	kind_l.add_theme_font_size_override("font_size", 11)
	kind_l.add_theme_color_override("font_color", Color("c9d3f2"))
	panel.add_child(kind_l)
	return panel

## Cards fly in one after another, each with a whoosh that climbs in pitch, then wobble gently while face down.
func _deal(holder: Control, index: int) -> void:
	holder.modulate.a = 0.0
	holder.scale = Vector2(0.2, 0.2)
	holder.rotation_degrees = -25.0
	var delay := 0.12 + 0.09 * index
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): Sfx.play_ui("deal", 0.9 + 0.06 * index))
	tw.set_parallel(true)
	tw.tween_property(holder, "modulate:a", 1.0, 0.15)
	tw.tween_property(holder, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "rotation_degrees", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if is_instance_valid(holder) and !holder.has_meta("revealed"):
			var wob := create_tween().set_loops()
			wob.tween_property(holder, "rotation_degrees", 1.6, 0.9 + 0.07 * index).set_trans(Tween.TRANS_SINE)
			wob.tween_property(holder, "rotation_degrees", -1.6, 0.9 + 0.07 * index).set_trans(Tween.TRANS_SINE)
			holder.set_meta("wobble", wob))

## Flip one reward: a rumble that builds (a rare card's edge starts to glow in its colour before it turns), an
## overshooting flip, then the rarity bursts out with sound, sparks, a screen shake and a banner that grow with it.
func _reveal(opt: Dictionary, holder: Control, face: Control, back: Control, fx: Control, footer: VBoxContainer, rarity: int) -> void:
	if opt.get("revealed", false):
		return
	opt["revealed"] = true
	holder.set_meta("revealed", true)
	if holder.has_meta("wobble"):
		(holder.get_meta("wobble") as Tween).kill()
	for c in footer.get_children():
		c.queue_free()
	holder.rotation_degrees = 0.0
	Sfx.play_ui("flip_rumble")
	var grow := create_tween()
	grow.tween_property(holder, "scale", Vector2(1.14, 1.14), 0.4).set_trans(Tween.TRANS_QUAD)
	var shake := create_tween()
	for i in 8:
		shake.tween_property(holder, "rotation_degrees", (7.0 if i % 2 == 0 else -7.0) * (0.4 + i * 0.1), 0.05)
	shake.tween_property(holder, "rotation_degrees", 0.0, 0.04)
	await get_tree().create_timer(0.22, true).timeout
	if rarity >= 1 and is_instance_valid(fx):
		fx.visible = true                                    # the tell: the edge lights up in the card's colour
	await get_tree().create_timer(0.2, true).timeout
	if !is_instance_valid(holder):
		return
	Sfx.play_ui("flip_pop")
	var t := create_tween()
	t.tween_property(holder, "scale:x", 0.0, 0.1)
	t.tween_callback(func():
		back.visible = false
		face.visible = true
		fx.visible = true
		fx.play_burst()
		Sfx.play_ui("reveal_%d" % rarity)
		if rarity >= 3:
			Sfx.play_ui("thump", 1.0 - 0.05 * (rarity - 3))
		_celebrate(rarity, holder, opt))
	t.tween_property(holder, "scale", Vector2(1.0, 1.0), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _fill_footer(footer, opt, holder, false, rarity, true))
	_update_flip_all()

## What a reveal feels like, by rarity: Common is a quiet chime; Rare adds a coloured ring; Epic shakes the screen and
## throws sparks; Mythic and Ancient add a flash and a banner; Legendary is a rainbow fireworks moment.
func _celebrate(rarity: int, holder: Control, opt: Dictionary) -> void:
	var col: Color = Game.rarity_color(rarity)
	var centre: Vector2 = holder.get_global_rect().get_center()
	if rarity >= 3:
		_shake_ui(3.0 + 3.0 * (rarity - 3))
		_confetti(centre, col, 30 + 25 * (rarity - 3), rarity >= 6)
	if rarity >= 4:
		_flash(col, 0.18 + 0.12 * (rarity - 4))
		_banner("%s!" % Game.rarity_name(rarity).to_upper(), col, rarity)
	if rarity >= 6:
		_shake_ui(14.0)
		for i in 3:
			await get_tree().create_timer(0.25, true).timeout
			_confetti(centre + Vector2(randf_range(-250, 250), randf_range(-120, 80)), Color.from_hsv(randf(), 0.6, 1.0), 60, true)
			Sfx.play_ui("reveal_6", 1.0 + 0.12 * i)

func _shake_ui(strength: float) -> void:
	if !_box_origin_set:
		_box_origin = _box.position                  # the panel is centred, so its resting position is not (0, 0)
		_box_origin_set = true
	if _shake_tw != null:
		_shake_tw.kill()
	_box.position = _box_origin
	var tw := create_tween()
	_shake_tw = tw
	for i in 8:
		tw.tween_property(_box, "position", _box_origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 8.0), 0.04)
	tw.tween_property(_box, "position", _box_origin, 0.04)

## A burst of coloured sparks that fly out and fall. `rainbow` makes every spark a different colour.
func _confetti(at: Vector2, col: Color, amount: int, rainbow := false) -> void:
	var pr := CPUParticles2D.new()
	pr.position = at
	pr.amount = amount
	pr.one_shot = true
	pr.explosiveness = 0.95
	pr.lifetime = 1.3
	pr.direction = Vector2(0, -1)
	pr.spread = 150.0
	pr.initial_velocity_min = 130.0
	pr.initial_velocity_max = 380.0
	pr.gravity = Vector2(0, 520.0)
	pr.scale_amount_min = 2.0
	pr.scale_amount_max = 4.5
	pr.color = col
	if rainbow:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		g.colors = PackedColorArray([Color("ff5a5a"), Color("ffb040"), Color("ffe14a"), Color("5fe07a"), Color("5aa8ff"), Color("b066ff")])
		pr.color_ramp = g
		pr.color = Color.WHITE
	pr.z_index = 5
	root_ctl.add_child(pr)
	pr.emitting = true
	get_tree().create_timer(2.0, true).timeout.connect(func():
		if is_instance_valid(pr):
			pr.queue_free())

## A big word that pops in over the screen and fades: "EPIC!", "LEGENDARY!".
func _banner(text: String, col: Color, rarity: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 56 + 8 * (rarity - 4))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position.y = 70
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 6
	root_ctl.add_child(l)
	l.pivot_offset = Vector2(l.size.x / 2.0, 30)
	l.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.9 + 0.2 * (rarity - 4))
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	if rarity >= 6:
		var hue := l.create_tween().set_loops(8)                 # bound to the banner, so it ends when the banner does
		hue.tween_method(func(h): if is_instance_valid(l): l.add_theme_color_override("font_color", Color.from_hsv(h, 0.55, 1.0)), 0.0, 1.0, 0.7)

func _flash(col: Color, strength := 0.55) -> void:
	var f := ColorRect.new()
	f.color = Color(col, strength)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctl.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.6)
	tw.tween_callback(f.queue_free)

func _update_flip_all() -> void:
	var left := 0
	for opt in _rewards:
		if !opt.get("revealed", false):
			left += 1
	flip_all.visible = left > 0
	flip_all.text = "Flip all (%d)" % left
	if left == 0 and !_rewards.is_empty():
		var best: Dictionary = _rewards[0]
		for opt in _rewards:
			if Game.rarity_of(opt.kind, str(opt.id)) > Game.rarity_of(best.kind, str(best.id)):
				best = opt
		var br: int = Game.rarity_of(best.kind, str(best.id))
		var nm: String = Game.CARDS[best.id].name if best.kind == "card" else Fusion.display_name(str(best.id))
		pull_label.text = "Best pull: %s %s" % [Game.rarity_name(br), nm]
		pull_label.add_theme_color_override("font_color", Game.rarity_color(br))
		pull_label.visible = true

## The rarity line and the Unlock / Convert buttons under a face-up reward.
func _fill_footer(footer: VBoxContainer, opt: Dictionary, holder: Control, is_kept: bool, rarity: int, animate := false) -> void:
	for c in footer.get_children():
		c.queue_free()
	if opt.result == "converted":
		holder.modulate = Color(0.6, 0.6, 0.65)
	elif opt.result == "offer":
		holder.modulate = Color(0.9, 0.9, 0.95)
	var rl := Label.new()
	rl.text = Game.rarity_name(rarity).to_upper()
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.add_theme_font_size_override("font_size", 13)
	rl.add_theme_color_override("font_color", Game.rarity_color(rarity))
	footer.add_child(rl)
	if animate:                                              # the rarity word pops in
		rl.pivot_offset = Vector2(40, 8)
		rl.scale = Vector2(0.1, 0.1)
		create_tween().tween_property(rl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match opt.result:
		"offer":
			tag.text = "KEPT" if is_kept else ("LEGENDARY! UNLOCK IT" if opt.get("legendary", false) else "NEW")
			tag.add_theme_color_override("font_color", Color("ffd23a") if opt.get("legendary", false) else Color("6df08a"))
		"unlocked":
			tag.text = "LEGENDARY UNLOCKED!" if opt.get("legendary", false) else "UNLOCKED"
			tag.add_theme_color_override("font_color", Color("ffd23a") if opt.get("legendary", false) else Color("6df08a"))
		"tierup":
			tag.text = "TIER %d UNLOCKED" % opt.tier
			tag.add_theme_color_override("font_color", Color("ffd23a"))
		"upgrade":
			tag.text = "TIER %d DRAWN" % opt.tier
			tag.add_theme_color_override("font_color", Color("ffd23a"))
		"spare":
			tag.text = "SPARE COPY (T%d)" % opt.tier
			tag.add_theme_color_override("font_color", Color("8fd8ff"))
		"merged":
			tag.text = "MERGED -> T%d" % (int(opt.tier) + 1)
			tag.add_theme_color_override("font_color", Color("ffd23a"))
		_:
			tag.text = "Owned: +%d Shards" % opt.shards
			tag.add_theme_color_override("font_color", Color("8fd8ff"))
	footer.add_child(tag)
	if opt.result == "upgrade":
		var upb := Button.new()
		var cid := str(opt.id)
		var owned_next: bool = Game.card_tier(cid) >= int(opt.tier)
		upb.text = "Upgraded" if owned_next else "Upgrade (%d)" % Game.card_upgrade_cost(cid)
		upb.disabled = owned_next or Game.meta.shards < Game.card_upgrade_cost(cid)
		upb.pressed.connect(func():
			if Game.upgrade_card(cid):
				Sfx.play_ui("reveal_3")
				_refresh())
		footer.add_child(upb)
	if opt.result == "spare":
		var merge := Button.new()
		merge.text = "Merge -> T%d" % (int(opt.tier) + 1) if int(opt.tier) < Game.MAX_LEVEL else "Max tier"
		merge.disabled = !Game.spare_can_merge(opt)
		merge.tooltip_text = "Adds this copy to your card: a copy of the same tier raises it one tier (up to the deepest level you have reached)."
		merge.pressed.connect(func():
			if Game.spare_merge(opt):
				Sfx.play_ui("reveal_3")
				_refresh())
		footer.add_child(merge)
		if !Game.spare_pair(opt).is_empty() and int(opt.tier) < Game.MAX_LEVEL:
			var comb := Button.new()
			comb.text = "Combine pair -> T%d" % (int(opt.tier) + 1)
			comb.tooltip_text = "Two spare copies of the same card and tier make one spare a tier higher."
			comb.pressed.connect(func():
				if Game.spare_combine(opt):
					Sfx.play_ui("reveal_2")
					_refresh())
			footer.add_child(comb)
		var sell := Button.new()
		sell.text = "Sell (+%d)" % Game.spare_sell_value(opt)
		sell.pressed.connect(func():
			Game.spare_sell(opt)
			_refresh())
		footer.add_child(sell)
	if opt.result == "offer":
		var unlock := Button.new()
		unlock.text = "Unlock (%d)" % opt.cost
		unlock.disabled = Game.meta.shards < opt.cost
		unlock.pressed.connect(func():
			if Game.unlock_offer(opt):
				_refresh())
		footer.add_child(unlock)
		var conv := Button.new()
		conv.text = "Convert (+%d)" % Game.offer_convert_value(opt)
		conv.pressed.connect(func():
			Game.convert_offer(opt)
			_refresh())
		footer.add_child(conv)

func _flip_all() -> void:
	var todo: Array = _flippers.duplicate()
	_flippers.clear()
	for f in todo:
		f.call()
		await get_tree().create_timer(0.8, true).timeout

## Weapon unlocks, fusion tiers and the starting weapon, as compact buttons.
func _refresh_extras() -> void:
	return                      # the unlock shop moved to the main menu
	Game.fix_meta()

	for c in extras_row.get_children():
		extras_row.remove_child(c)
		c.queue_free()
	var items: Dictionary = load("res://world/item_info.tres").items
	for id in Game.WEAPON_UNLOCK_COSTS:
		if id in Game.SECTOR_WEAPONS.values():
			continue                      # sector weapons are unlocked in the weapon codex or from reward draws
		var owned: bool = id in Game.meta.weapons
		var price: int = Game.WEAPON_UNLOCK_COSTS[id]
		var seen: bool = Game.is_seen(id)
		var can: bool = !owned and seen and Game.meta.shards >= price
		var c := TierCard.new()
		if !seen:
			c.setup({"size": Vector2(92, 130), "title": "???", "glyph": "?", "accent": Color(0.4, 0.4, 0.5), "locked": true, "footer": "not found", "footer_color": Color(0.6, 0.6, 0.65)})
			extras_row.add_child(c)
			continue
		c.setup({"size": Vector2(92, 130), "title": Fusion.display_name(id), "icon": load(items[id].texture), "tier": 1 if owned else 0, "max_tier": 6,
			"accent": Game.rarity_color(Game.weapon_rarity(id)), "locked": !owned and !can,
			"footer": "OWNED" if owned else "%d shards" % price, "footer_color": Color(0.5, 1, 0.55) if owned else (Color(1, 0.9, 0.5) if can else Color(1, 0.55, 0.45)),
			"tooltip": "Adds this weapon to the chest pool for every run."})
		c.set_selected(can)
		if can:
			c.pressed.connect(func(_c):
				if Game.buy_weapon(id):
					_refresh())
		extras_row.add_child(c)
	for t in Game.FUSION_TIER_COSTS:
		var have: bool = Game.fusion_tier_unlocked(t)
		var price: int = Game.FUSION_TIER_COSTS[t]
		var gated: bool = t > 3 and !Game.fusion_tier_unlocked(t - 1)
		var can: bool = !have and !gated and Game.meta.shards >= price
		var c := TierCard.new()
		c.setup({"size": Vector2(92, 130), "title": "Fusions T%d" % t, "glyph": "T%d" % t, "tier": t if have else t - 1, "max_tier": 4,
			"lines": ["Forge tier %d" % t], "accent": Color(1.0, 0.6, 0.25), "locked": !have and !can,
			"footer": "OWNED" if have else ("needs T%d" % (t - 1) if gated else "%d shards" % price),
			"footer_color": Color(0.5, 1, 0.55) if have else (Color(1, 0.9, 0.5) if can else Color(1, 0.55, 0.45))})
		c.set_selected(can)
		if can:
			c.pressed.connect(func(_c):
				if Game.buy_fusion_tier(t):
					_refresh())
		extras_row.add_child(c)
	var l := Label.new()
	l.text = "Start with:"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	extras_row.add_child(l)
	var opt := OptionButton.new()
	opt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var options: Array = Game.start_weapon_options()
	for o in options:
		opt.add_item(Fusion.display_name(String(o)))
	opt.selected = max(0, options.find(Game.meta.start_weapon))
	opt.item_selected.connect(func(i: int): Game.set_start_weapon(options[i]))
	extras_row.add_child(opt)

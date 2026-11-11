extends RefCounted
## The forge's data for every Forge screen (player 1, split-screen players 2-4, LAN clients): the list of weapons in your
## hands and in the forge's storage, the preview text of a picked pair and the weapon numbers. The rules themselves are
## Game.forge_preview (what a pair makes and costs) and Net.forge_* (doing it); the screen is ui/forge/forge_view.gd.

const UiKit = preload("res://ui/cards/ui_kit.gd")

## held / stored are arrays of weapon entries. Returns [{src: "held"|"store", idx, entry, id}] in display order:
## your hands first, then the forge's storage, each common first, then by name, then highest tier first.
static func items(held: Array, stored: Array) -> Array:
	var out := []
	for i in held.size():
		out.append({"src": "held", "idx": i, "entry": held[i], "id": Game.entry_id(held[i])})
	for j in stored.size():
		out.append({"src": "store", "idx": j, "entry": stored[j], "id": Game.entry_id(stored[j])})
	out.sort_custom(func(a, b):
		if a.src != b.src:
			return a.src == "held"
		var ra: int = Game.weapon_rarity(a.id)
		var rb: int = Game.weapon_rarity(b.id)
		if ra != rb:
			return ra < rb
		if a.id != b.id:
			return Fusion.display_name(a.id) < Fusion.display_name(b.id)
		return Game.weapon_tier_of(a.entry) > Game.weapon_tier_of(b.entry))
	return out

## What the picked pair would make: Game.forge_preview plus the text every Forge screen shows; p.cost is shown by the screen as resource icons.
static func preview(list: Array, picks: Array) -> Dictionary:
	var none := {"ok": false, "kind": "", "result": ""}
	if picks.size() == 1:
		none["text"] = "Now pick a second weapon."
		return none
	if picks.size() < 2 or picks[0] >= list.size() or picks[1] >= list.size():
		none["text"] = "Pick two weapons."
		return none
	var p: Dictionary = Game.forge_preview(list[picks[0]].entry, list[picks[1]].entry)
	if p.get("note", "") != "":
		p.text += "  " + p.note
	return p                                   # (the cost is drawn as icons by the screen from p.cost)

## Real numbers for the weapon now and one tier up (green). Each tier of bonus gives +20% damage and -8% cooldowns.
static func numbers_text(info: Dictionary, bonus: int) -> String:
	var inst = load(info["path"]).instantiate()
	var cds := [["Attack", inst.attack_cooldown, inst.attack_name], ["Ability (T2)", inst.ability_cooldown, inst.ability_name],
		["Dash", inst.dash_cooldown, inst.dash_name], ["Ultimate (T3)", inst.ultimate_cooldown, inst.ultimate_name]]
	inst.free()
	var r: int = Game.weapon_rarity(str(info.id))
	var fz: float = pow(0.95, Fusion.tier_of(str(info.id)) - 1)
	var lines := ["[color=#%s][b]%s[/b][/color] weapon" % [Game.rarity_color(r).to_html(false), Game.rarity_name(r)], "Damage  [color=#ffd23a][b]x%.1f[/b][/color]  ->  [color=#6df08a][b]x%.1f[/b][/color]" % [Game.weapon_power(str(info.id), bonus), Game.weapon_power(str(info.id), bonus + 1)]]
	var now: Dictionary = Game.basic_numbers(str(info.id), bonus)
	var nxt: Dictionary = Game.basic_numbers(str(info.id), bonus + 1)
	if !now.is_empty():
		lines.append("Damage per second  [color=#ffd23a][b]%.1f[/b][/color]  ->  [color=#6df08a][b]%.1f[/b][/color]   (%.1f per hit)" % [now.dps, nxt.dps, now.hit])
	for c in cds:
		if c[2] == "":
			continue
		lines.append("%s: %s  [color=#ffd23a][b]%.2fs[/b][/color]  ->  [color=#6df08a][b]%.2fs[/b][/color]" % [c[0], c[2], c[1] * fz * pow(0.92, bonus), c[1] * fz * pow(0.92, bonus + 1)])
	return "\n".join(lines)

## The recipes you know over the weapons in `list`: [{a: [id, text], b: [id, text], c: [id, text], state (0 grey, 1 yellow, 2 green),
## pick: [a_pos, b_pos] or []}]. Matching pairs that combine into the next tier first, then every known fusion. Anything locked (a tier you have not unlocked) is left out.
static func recipes(list: Array) -> Array:
	var out := []
	var tier_of_id := func(id: String) -> int:
		var best := 0
		for it in list:
			if it.id == id:
				best = maxi(best, Game.weapon_tier_of(it.entry))
		return best
	var seen := {}
	for n in list.size():
		var it: Dictionary = list[n]
		var k := "%s:%d" % [it.id, Game.weapon_bonus(it.entry)]
		if seen.has(k):
			continue
		seen[k] = true
		var j := -1
		for m in list.size():
			if m != n and list[m].id == it.id and Game.weapon_bonus(list[m].entry) == Game.weapon_bonus(it.entry):
				j = m
				break
		var t := Game.weapon_tier_of(it.entry)
		var res := Game.combine_weapons(it.entry, it.entry)
		if res == "":
			continue                       # the next tier is not unlocked yet (or this is the top tier): nothing to show
		var ok: bool = j >= 0 and Game.can_afford(Game.combine_cost(it.entry))
		out.append({"a": [it.id, "Tier %d" % t], "b": [it.id, "Tier %d%s" % [t, "" if j >= 0 else " (need a 2nd)"]],
			"c": [it.id, "Tier %d" % (t + 1)],
			"state": 2 if ok else (1 if j >= 0 else 0), "pick": [n, j] if j >= 0 else []})
	for key in Fusion.RECIPES:
		var r: Dictionary = Fusion.RECIPES[key]
		if !Game.weapon_known(r.id) or !Game.fusion_tier_unlocked(r.tier):
			continue                       # only recipes you can actually make: known result, unlocked tier
		var pr: PackedStringArray = key.split("+")
		var a := -1
		var b := -1
		for n in list.size():
			if a < 0 and list[n].id == pr[0]:
				a = n
		for n in list.size():
			if b < 0 and n != a and list[n].id == pr[1]:
				b = n
		var carry: bool = a >= 0 and b >= 0
		var ok2: bool = carry and Game.fusion_tier_unlocked(r.tier) and Game.can_afford(Fusion.cost(r.tier))
		var ta: int = tier_of_id.call(pr[0])
		var tb: int = tier_of_id.call(pr[1])
		out.append({"a": [pr[0], ("T%d carried" % ta) if ta > 0 else "not carried"], "b": [pr[1], ("T%d carried" % tb) if tb > 0 else "not carried"],
			"c": [r.id, "Tier %d" % r.tier],
			"state": 2 if ok2 else (1 if carry else 0), "pick": [a, b] if carry else []})
	return out

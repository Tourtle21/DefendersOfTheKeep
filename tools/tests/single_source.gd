extends SceneTree
## Single-source guard (no game needed, runs in a second). Rules and shared behaviour live in ONE helper; this fails
## when a known helper is written again somewhere else, and when UI code adds raw colours / font sizes instead of
## taking them from the shared kit (ui/cards/ui_kit.gd, ui/hud/hud_kit.gd). See CLAUDE.md.
var fails := 0
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if !c:
		fails += 1

## [pattern (regex), the only files allowed to contain it, what to use instead]
const ONE_HOME := [
	["distance_to\\((Net\\.)?(FORGE_POS|CARD_FUSER_POS)\\)", ["core/net.gd"], "Net.near_station(pl, station)"],
	["STATION_REACH|<= 50\\.0\\b.*(FORGE|FUSER)", ["core/net.gd"], "Net.near_station"],
	["func _edge\\(", ["ui/base/local_keep_ui.gd", "world/local_players.gd", "ui/base/local_lobby.gd"], "ui/cards/pad_edges.gd"],
	[": merge  %s", ["ui/hud/weapon_slots.gd"], "weapon_slots.set_merge(Game.held_merge(...), key)"],
	["in \\[\"stone\", \"stick\", \"gold\"\\]", ["core/game.gd"], "Game.resource_line / Game.resource_text"],
	["\\{\"stone\": 3\\}", ["core/game.gd"], "Game.REPAIR_COST / Game.can_repair"],
	["\"Keep %d / %d\"", ["ui/hud/hud_kit.gd"], "HudKit.top / HudKit.set_top"],
	["\"Mana %d / %d\"", ["ui/hud/hud_kit.gd"], "HudKit.mana_block / HudKit.set_mana"],
	["\"title\": \"Repair\"", ["ui/hud/hud_kit.gd"], "HudKit.upgrade_cards"],
	["Fusion\\.RECIPES", ["core/game.gd", "items/fusion.gd", "ui/forge/forge_layout.gd", "ui/base/codex_ui.gd", "ui/base/collection_ui.gd", "ui/base/run_end_ui.gd", "core/net.gd"], "ForgeLayout.recipes"],
	["func _chip\\(|func _recipe_card\\(", ["ui/forge/forge_view.gd"], "ForgeView"],
	["(?m)^\\s*move_and_slide\\(\\)", ["core/game.gd", "player/player.gd", "enemies/blobbert/blobbert.gd"], "Game.move_on_map(body, velocity, delta)"],
]

## UI files may only keep (at most) the raw Color( / font-size literals they had when this guard was added; new files none.
## Shrink these numbers when you move a file onto the kit; never raise them.
const STYLE_BUDGET := {
	"ui/hud/ability_hud.gd": [16, 0], "ui/base/base_ui.gd": [9, 2], "ui/cards/card_view.gd": [8, 0], "net/client_minimap.gd": [12, 0],
	"net/client_view.gd": [14, 3], "ui/base/codex_ui.gd": [2, 2], "ui/base/collection_ui.gd": [6, 4], "ui/base/crystal_alert.gd": [8, 0],
	"ui/fx/damage_number.gd": [4, 0], "ui/base/draws_ui.gd": [2, 2], "ui/base/help_ui.gd": [1, 1], "ui/base/hints.gd": [2, 1],
	"ui/hud/inventory/inventory.gd": [1, 1], "ui/base/lobby_ui.gd": [2, 2], "ui/base/local_keep_ui.gd": [3, 1], "ui/base/local_lobby.gd": [10, 6],
	"ui/base/main_menu.gd": [2, 4], "ui/base/minimap.gd": [17, 0], "ui/base/pause_ui.gd": [2, 1], "ui/cards/rarity_fx.gd": [5, 0],
	"ui/hud/respawn_ui.gd": [3, 1], "ui/base/run_end_ui.gd": [34, 11], "ui/base/skill_tree_ui.gd": [10, 2], "ui/cards/tier_card.gd": [35, 0],
	"ui/hud/tokens/token.gd": [1, 0], "ui/hud/tokens/upgrade.gd": [3, 0], "ui/hud/upgrades/upgrades.gd": [1, 1], "ui/hud/wave_banner.gd": [2, 2],
	"ui/hud/weapon_slots.gd": [4, 0],
}
const KIT := ["ui/cards/ui_kit.gd", "ui/hud/hud_kit.gd"]

func _scripts(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at("res://" + dir):
		if f.ends_with(".gd"):
			out.append((dir + "/" + f).trim_prefix("/"))
	for d in DirAccess.get_directories_at("res://" + dir):
		if !d.begins_with(".") and d != "tools" and d != "addons":
			_scripts((dir + "/" + d).trim_prefix("/"), out)

func _count(text: String, re: RegEx) -> int:
	return re.search_all(text).size()

func _initialize() -> void:
	var files := []
	_scripts("", files)
	var text := {}
	for f in files:
		text[f] = FileAccess.get_file_as_string("res://" + f)
	for rule in ONE_HOME:
		var re := RegEx.create_from_string(rule[0])
		var bad := []
		for f in files:
			if !(f in rule[1]) and re.search(text[f]) != null:
				bad.append(f)
		ok("one home for /%s/ (use %s)%s" % [rule[0], rule[2], "" if bad.is_empty() else ": also in " + ", ".join(bad)], bad.is_empty())
	var color_re := RegEx.create_from_string("Color\\(")
	var size_re := RegEx.create_from_string("font_size\", [0-9]|font_size\"\\), [0-9]|outlined\\(\"[^\"\\n]*\", [0-9]|label\\([^,\\n]*, [0-9]")
	var over := []
	for f in files:
		if !(f.begins_with("ui/") or f.begins_with("net/client")) or f in KIT:
			continue
		var budget: Array = STYLE_BUDGET.get(f, [0, 0])
		var c := _count(text[f], color_re)
		var s := _count(text[f], size_re)
		if c > budget[0] or s > budget[1]:
			over.append("%s (%d colours, %d font sizes; budget %s)" % [f, c, s, budget])
	ok("UI style comes from the kit (raw Color( / font sizes within budget)%s" % ("" if over.is_empty() else ": " + "; ".join(over)), over.is_empty())
	print("single_source: %s" % ("ok" if fails == 0 else "%d FAIL" % fails))
	quit()

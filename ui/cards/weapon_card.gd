extends RefCounted
## ONE weapon card: a CardView in weapon mode, so it is laid out exactly like spell and building cards (frame, art window, name
## banner, text box, tier badge top-right), in the weapon frame with a thin rarity-coloured line inside it. Every screen that
## shows a weapon as a card (the end-of-run rewards, the Drawn tab, the weapon codex, the Forge) builds it here. A screen passes only
## what is special about it (lines, a footer, a locked look) in `extra`, which overrides the defaults.

const UiKit = preload("res://ui/cards/ui_kit.gd")

## The weapon's icon (the sword and pickaxe are sprite sheets: UiKit.weapon_icon shows their first frame), or null.
## From tier 2 the icon is the tier's art (WeaponArt: polished, a glow ring, sparkles...), the same picture the weapon has in the hand.
static func icon(id: String, tier := 1) -> Texture2D:
	var info: Dictionary = load("res://world/item_info.tres").items.get(id, {})
	if !info.has("texture"):
		return null
	if tier >= 2 and !UiKit.WEAPON_SHEETS.has(str(info.texture)):
		return WeaponArt.hud_icon(id, tier, str(info.texture))
	return UiKit.weapon_icon(str(info.texture))

static func make(id: String, tier: int, size: Vector2, extra := {}) -> CardView:
	var data := {"title": Fusion.display_name(id), "icon": icon(id, tier), "accent": Game.rarity_color(Game.weapon_rarity(id))}
	data.merge(extra, true)
	var card := CardView.new()
	card.setup_weapon(id, tier, data, size)
	return card

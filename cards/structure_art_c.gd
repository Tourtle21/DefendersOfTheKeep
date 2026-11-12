extends RefCounted
## The drawing of the sentry towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower, Sunspire, the Magma Wall and the menders
## Healing Grove and Phoenix Shrine, per tier (designs: docs/card_tiers/<card id>.md). StructureArt.draw delegates here for the
## ids in StructureTiersC.OWN. Motion comes from the structure's `_age` and SpellArt.jit only, so a LAN client draws the same.

static func draw(st, col: Color) -> bool:
	match String(st.data.get("id", "")):
		_:
			return false

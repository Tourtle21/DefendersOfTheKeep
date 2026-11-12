extends RefCounted
## Per-tier art of the FUSED weapons (see weapon_tier_art.gd). Each weapon is its own picture drawn from scratch with the Paint kit,
## `func draw_<id>(p: Paint, t: int) -> void` (t = 1..6); it never composes its parents' icons.
const Paint = preload("res://items/weapons/art/weapon_paint.gd")

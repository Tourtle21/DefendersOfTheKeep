extends Node2D
## A brand-new content type made only to prove the rule: it joins the group "net", has public
## variables, and nothing else multiplayer-related. Replication must just work.
var label := "thing"
var count := 1
var palette := [Color.RED, Color.GREEN]
var secret_note := "stays on the host"      # not private by name, so it syncs too
var _hidden := 42                            # private: never sent

func _ready() -> void:
	add_to_group("net")

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0 + count, palette[0])

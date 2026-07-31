extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var overlay = get_parent()
	if overlay and overlay.has_method("_draw_arrows"):
		overlay._draw_arrows()

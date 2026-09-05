class_name TouchButton
extends Button

## A touch-sized button used by TouchControls. Emits no mouse emulation and
## keeps a pressed visual state while the finger is down.

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	# Touch presses arrive as emulated mouse events; keep the default handling
	# but silence focus outlines for a cleaner look on small screens.
	focus_mode = Control.FOCUS_NONE
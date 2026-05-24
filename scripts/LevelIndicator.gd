# =============================================================================
# LevelIndicator.gd — Control
# Small label injected into BoardPanel by TabNavigator.
# Shows: "Lv.3 — The Funnel"
# =============================================================================
extends Control

@onready var _label: Label = $Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(200.0, 32.0)
	offset_top    = 4.0
	offset_left   = 8.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	LevelManager.level_changed.connect(_on_level_changed)
	_refresh()

func _refresh() -> void:
	var lbl: Label = get_node_or_null("Label")
	if lbl:
		lbl.text = "Lv.%d — %s" % [LevelManager.current_level, LevelManager.get_layout_name()]

func _on_level_changed(_new_level: int) -> void:
	_refresh()

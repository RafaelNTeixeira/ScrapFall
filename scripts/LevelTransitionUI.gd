# =============================================================================
# LevelTransitionUI.gd — Control (NOT CanvasLayer)
#
# Extends Control so anchors work correctly when injected into UILayer.
# Uses z_index=100 to render above all other UI.
# Injected by TabNavigator via call_deferred so layout is fully computed first.
# =============================================================================
extends Control

signal transition_complete()

var _confirm_panel:  Control
var _buff_panel:     Control
var _buff_ids:       Array = []

# Stored refs — avoids fragile tree-walk in _refresh_confirm_text / _show_buff_picker
var _confirm_title: Label
var _confirm_body:  Label
var _cards_box:     VBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index      = 100
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_confirm_panel()
	_build_buff_panel()

	LevelManager.show_advance_ui_requested.connect(show_confirmation)

# -----------------------------------------------------------------------------
# Public
# -----------------------------------------------------------------------------
func show_confirmation() -> void:
	visible                = true
	_confirm_panel.visible = true
	_buff_panel.visible    = false
	_refresh_confirm_text()

# -----------------------------------------------------------------------------
# Dark semi-transparent overlay that blocks clicks
# -----------------------------------------------------------------------------
func _make_overlay() -> ColorRect:
	var overlay          := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.80)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	return overlay

# -----------------------------------------------------------------------------
# Create a card that auto-sizes to its content and is centred on screen.
# Uses CenterContainer so the PanelContainer size is driven by its children,
# not by a hard-coded offset — this eliminates blank space at the bottom.
# Returns the inner PanelContainer. The CenterContainer is added to `parent`.
# -----------------------------------------------------------------------------
func _make_center_card(parent: Control, width: float) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0.0)   # height driven by content
	card.mouse_filter        = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	return card

# -----------------------------------------------------------------------------
# Confirmation panel
# -----------------------------------------------------------------------------
func _build_confirm_panel() -> void:
	_confirm_panel         = _make_overlay()
	_confirm_panel.visible = false
	add_child(_confirm_panel)

	var card := _make_center_card(_confirm_panel, 320.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_confirm_title = Label.new()
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_title.add_theme_font_size_override("font_size", 20)
	_confirm_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(_confirm_title)

	_confirm_body = Label.new()
	_confirm_body.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_body.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_confirm_body)

	var warn := Label.new()
	warn.text               = "⚠  Resources reset to 0.\nGold, upgrades and buffs are kept."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.add_theme_font_size_override("font_size", 12)
	warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(warn)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text             = "Not Yet"
	cancel_btn.custom_minimum_size = Vector2(120.0, 44.0)
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text               = "Let's Go! →"
	confirm_btn.custom_minimum_size = Vector2(140.0, 44.0)
	confirm_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	confirm_btn.modulate           = Color(1.0, 0.85, 0.2)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)

func _refresh_confirm_text() -> void:
	var next_level:  int    = LevelManager.current_level + 1
	var layout_idx:  int    = mini(next_level - 1, LevelManager.LAYOUTS.size() - 1)
	var layout_name: String = LevelManager.LAYOUTS[layout_idx].get("name", "Unknown")
	_confirm_title.text = "Advance to Level %d?" % next_level
	_confirm_body.text  = "Next board: \"%s\"\n\nComplete this level and you will\nchoose a permanent buff." \
						  % [layout_name]

# -----------------------------------------------------------------------------
# Buff picker panel
# -----------------------------------------------------------------------------
func _build_buff_panel() -> void:
	_buff_panel         = _make_overlay()
	_buff_panel.visible = false
	add_child(_buff_panel)

	var card := _make_center_card(_buff_panel, 350.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text                 = "Choose a Permanent Buff"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text                 = "This bonus carries into every future level."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(sub)

	_cards_box = VBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_cards_box)

func _show_buff_picker() -> void:
	_buff_ids = BuffManager.get_random_picks()
	_confirm_panel.visible = false
	_buff_panel.visible    = true

	for child in _cards_box.get_children():
		child.queue_free()
	for buff_id in _buff_ids:
		_cards_box.add_child(_make_buff_card(buff_id))

func _make_buff_card(buff_id: String) -> Control:
	var def: Dictionary = BuffManager.BUFFS[buff_id]
	var card            := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 90.0)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)

	var icon := Label.new()
	icon.text                = def.get("icon", "✦")
	icon.add_theme_font_size_override("font_size", 28)
	icon.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	icon.custom_minimum_size = Vector2(40.0, 0.0)
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = def["label"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text          = def["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_lbl)

	var count: int   = BuffManager.stack_count(buff_id)
	var stat_lbl     := Label.new()
	if count > 0:
		var cur: float = BuffManager.stacked_value(buff_id)
		stat_lbl.text  = "Now: +%.0f%s  →  After: +%.0f%s" % [
			cur, def["stat_unit"],
			cur + def["stat_per_stack"], def["stat_unit"]
		]
		stat_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	else:
		stat_lbl.text = "New!  +%.0f%s" % [def["stat_per_stack"], def["stat_unit"]]
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	stat_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(stat_lbl)

	var pick_btn := Button.new()
	pick_btn.text              = "Pick"
	pick_btn.custom_minimum_size = Vector2(70.0, 0.0)
	pick_btn.pressed.connect(func(): _on_buff_picked(buff_id))
	hbox.add_child(pick_btn)

	return card

# -----------------------------------------------------------------------------
# Signal handlers
# -----------------------------------------------------------------------------
func _on_cancel() -> void:
	visible = false

func _on_confirm() -> void:
	_show_buff_picker()

func _on_buff_picked(buff_id: String) -> void:
	visible = false
	LevelManager.advance(buff_id)
	emit_signal("transition_complete")

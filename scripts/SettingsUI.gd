# =============================================================================
# SettingsUI.gd
# Injected into SettingsPanel by TabNavigator — all children built in code.
#
# Sections:
#   Audio  — SFX / Music toggle + volume sliders
#   Game   — Reset Save (with confirmation overlay)
#   About  — version / engine info
# =============================================================================
extends Control

# ---- Node refs --------------------------------------------------------------
var _sfx_toggle:    CheckButton
var _music_toggle:  CheckButton
var _sfx_slider:    HSlider
var _music_slider:  HSlider
var _sfx_vol_lbl:   Label
var _music_vol_lbl: Label
var _confirm_overlay: Control = null

# =============================================================================
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_build_page_header(vbox)
	_build_section_label(vbox, "Audio")
	_build_audio_section(vbox)
	_build_section_label(vbox, "Game")
	_build_game_section(vbox)
	_build_section_label(vbox, "About")
	_build_about_section(vbox)

	_refresh_all()

# =============================================================================
# Layout helpers
# =============================================================================
func _build_page_header(parent: Control) -> void:
	var lbl := Label.new()
	lbl.text = "Settings"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	parent.add_child(lbl)

func _build_section_label(parent: Control, text: String) -> void:
	parent.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	parent.add_child(lbl)

# =============================================================================
# Audio section
# =============================================================================
func _build_audio_section(parent: Control) -> void:
	var card := PanelContainer.new()
	parent.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left",   12)
	card_margin.add_theme_constant_override("margin_right",  12)
	card_margin.add_theme_constant_override("margin_top",    10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	card_margin.add_child(inner)

	# SFX row
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 10)
	inner.add_child(sfx_row)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "Sound Effects"
	sfx_lbl.add_theme_font_size_override("font_size", 13)
	sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	sfx_row.add_child(sfx_lbl)

	_sfx_toggle = CheckButton.new()
	_sfx_toggle.button_pressed = AudioManager.sfx_enabled
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	sfx_row.add_child(_sfx_toggle)

	# SFX volume row
	var sfx_vol_row := HBoxContainer.new()
	sfx_vol_row.add_theme_constant_override("separation", 8)
	inner.add_child(sfx_vol_row)

	var sfx_vol_lbl_title := Label.new()
	sfx_vol_lbl_title.text = "Volume"
	sfx_vol_lbl_title.add_theme_font_size_override("font_size", 11)
	sfx_vol_lbl_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	sfx_vol_lbl_title.custom_minimum_size = Vector2(52.0, 0.0)
	sfx_vol_lbl_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx_vol_row.add_child(sfx_vol_lbl_title)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 100
	_sfx_slider.step      = 1
	_sfx_slider.value     = _db_to_slider(AudioManager.sfx_volume_db)
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	sfx_vol_row.add_child(_sfx_slider)

	_sfx_vol_lbl = Label.new()
	_sfx_vol_lbl.add_theme_font_size_override("font_size", 11)
	_sfx_vol_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	_sfx_vol_lbl.custom_minimum_size = Vector2(32.0, 0.0)
	_sfx_vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sfx_vol_lbl.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	sfx_vol_row.add_child(_sfx_vol_lbl)

	# Separator
	inner.add_child(HSeparator.new())

	# Music row
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 10)
	inner.add_child(music_row)

	var music_lbl := Label.new()
	music_lbl.text = "Music"
	music_lbl.add_theme_font_size_override("font_size", 13)
	music_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	music_row.add_child(music_lbl)

	_music_toggle = CheckButton.new()
	_music_toggle.button_pressed = AudioManager.music_enabled
	_music_toggle.toggled.connect(_on_music_toggled)
	music_row.add_child(_music_toggle)

	# Music volume row
	var music_vol_row := HBoxContainer.new()
	music_vol_row.add_theme_constant_override("separation", 8)
	inner.add_child(music_vol_row)

	var music_vol_lbl_title := Label.new()
	music_vol_lbl_title.text = "Volume"
	music_vol_lbl_title.add_theme_font_size_override("font_size", 11)
	music_vol_lbl_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	music_vol_lbl_title.custom_minimum_size = Vector2(52.0, 0.0)
	music_vol_lbl_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_vol_row.add_child(music_vol_lbl_title)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0
	_music_slider.max_value = 100
	_music_slider.step      = 1
	_music_slider.value     = _db_to_slider(AudioManager.music_volume_db)
	_music_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_slider.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_music_slider.value_changed.connect(_on_music_volume_changed)
	music_vol_row.add_child(_music_slider)

	_music_vol_lbl = Label.new()
	_music_vol_lbl.add_theme_font_size_override("font_size", 11)
	_music_vol_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	_music_vol_lbl.custom_minimum_size = Vector2(32.0, 0.0)
	_music_vol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_music_vol_lbl.size_flags_vertical  = Control.SIZE_SHRINK_CENTER
	music_vol_row.add_child(_music_vol_lbl)

# =============================================================================
# Game section
# =============================================================================
func _build_game_section(parent: Control) -> void:
	var card := PanelContainer.new()
	parent.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left",   12)
	card_margin.add_theme_constant_override("margin_right",  12)
	card_margin.add_theme_constant_override("margin_top",    10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card_margin.add_child(inner)

	var reset_title := Label.new()
	reset_title.text = "Reset Game"
	reset_title.add_theme_font_size_override("font_size", 13)
	inner.add_child(reset_title)

	var reset_desc := Label.new()
	reset_desc.text = "Permanently deletes all progress — resources, gold, upgrades, buffs, and level. Cannot be undone."
	reset_desc.add_theme_font_size_override("font_size", 11)
	reset_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	reset_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(reset_desc)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Save Data"
	reset_btn.custom_minimum_size = Vector2(0.0, 44.0)
	reset_btn.modulate = Color(1.0, 0.35, 0.35)
	reset_btn.pressed.connect(_on_reset_pressed)
	inner.add_child(reset_btn)

# =============================================================================
# About section
# =============================================================================
func _build_about_section(parent: Control) -> void:
	var card := PanelContainer.new()
	parent.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left",   12)
	card_margin.add_theme_constant_override("margin_right",  12)
	card_margin.add_theme_constant_override("margin_top",    10)
	card_margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(card_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card_margin.add_child(vbox)

	var lines: Array = [
		["The Resource Factory",   16, Color(0.9, 0.75, 0.2)],
		["Version 0.1.0-alpha",    12, Color(0.75, 0.75, 0.75)],
		["Built with Godot 4.6.3", 11, Color(0.5, 0.5, 0.5)],
	]
	for entry in lines:
		var lbl := Label.new()
		lbl.text = entry[0] as String
		lbl.add_theme_font_size_override("font_size", entry[1] as int)
		lbl.add_theme_color_override("font_color", entry[2] as Color)
		vbox.add_child(lbl)

# =============================================================================
# Refresh
# =============================================================================
func _refresh_all() -> void:
	if _sfx_toggle:
		_sfx_toggle.button_pressed  = AudioManager.sfx_enabled
	if _music_toggle:
		_music_toggle.button_pressed = AudioManager.music_enabled
	if _sfx_slider:
		_sfx_slider.value  = _db_to_slider(AudioManager.sfx_volume_db)
	if _music_slider:
		_music_slider.value = _db_to_slider(AudioManager.music_volume_db)
	_update_vol_labels()
	_update_slider_states()

func _update_vol_labels() -> void:
	if _sfx_vol_lbl:
		_sfx_vol_lbl.text   = "%d" % int(_sfx_slider.value if _sfx_slider else 0)
	if _music_vol_lbl:
		_music_vol_lbl.text = "%d" % int(_music_slider.value if _music_slider else 0)

func _update_slider_states() -> void:
	var sfx_on:   bool = AudioManager.sfx_enabled
	var music_on: bool = AudioManager.music_enabled
	if _sfx_slider:
		_sfx_slider.editable   = sfx_on
		_sfx_slider.modulate   = Color.WHITE if sfx_on else Color(0.45, 0.45, 0.45)
	if _music_slider:
		_music_slider.editable  = music_on
		_music_slider.modulate  = Color.WHITE if music_on else Color(0.45, 0.45, 0.45)

# =============================================================================
# Audio handlers
# =============================================================================
func _on_sfx_toggled(pressed: bool) -> void:
	AudioManager.set_sfx_enabled(pressed)
	_update_slider_states()
	SaveManager.save()

func _on_music_toggled(pressed: bool) -> void:
	AudioManager.set_music_enabled(pressed)
	_update_slider_states()
	SaveManager.save()

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_sfx_volume_db(_slider_to_db(value))
	_update_vol_labels()
	SaveManager.save()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_music_volume_db(_slider_to_db(value))
	_update_vol_labels()
	SaveManager.save()

# =============================================================================
# Reset Save — two-step confirmation overlay
# =============================================================================
func _on_reset_pressed() -> void:
	if _confirm_overlay and is_instance_valid(_confirm_overlay):
		return   # already showing

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.0, 0.0, 0.0, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300.0, 0.0)
	card.mouse_filter        = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left",   16)
	card_margin.add_theme_constant_override("margin_right",  16)
	card_margin.add_theme_constant_override("margin_top",    16)
	card_margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(card_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card_margin.add_child(vbox)

	var title := Label.new()
	title.text                 = "Reset All Progress?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	vbox.add_child(title)

	var body := Label.new()
	body.text                 = "This will delete everything:\nresources, gold, upgrades, buffs,\nlevel progress, and shop purchases.\n\nThe game will restart immediately.\nThis cannot be undone."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text               = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(110.0, 44.0)
	cancel_btn.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	)
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text               = "Reset"
	confirm_btn.custom_minimum_size = Vector2(110.0, 44.0)
	confirm_btn.modulate           = Color(1.0, 0.35, 0.35)
	confirm_btn.pressed.connect(_do_reset)
	btn_row.add_child(confirm_btn)

	# Add to our parent (SettingsPanel) so it sits above the scroll container
	get_parent().add_child(_confirm_overlay)

func _do_reset() -> void:
	# hard_reset resets every autoload's in-memory state first, THEN reloads
	# the scene. Calling only delete_save + reload_current_scene is not enough
	# because autoloads persist across reloads and keep stale level/buff data.
	SaveManager.hard_reset()

# =============================================================================
# Volume conversion helpers
# =============================================================================
# Slider range 0–100 → dB.  Slider 0 = silent (−80 dB), 100 = full (0 dB).
func _slider_to_db(value: float) -> float:
	if value <= 0.0:
		return -80.0
	return linear_to_db(value / 100.0)

# dB → slider range 0–100
func _db_to_slider(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)

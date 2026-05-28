# =============================================================================
# WarehouseUI.gd
# Attach to: Control node — the Warehouse tab panel
#
# Scene tree — names must match exactly:
#   WarehouseUI (Control)
#   ├── TitleLabel      (Label)        — "Warehouse"
#   ├── CopperBar       (Control)      ← ResourceBar.gd attached
#   ├── SteelBar        (Control)      ← ResourceBar.gd attached
#   ├── GlassBar        (Control)      ← ResourceBar.gd attached
#   └── WoodBar         (Control)      ← ResourceBar.gd attached
#
# Each *Bar node must have ResourceBar.gd attached and its @export
# resource_type set correctly in the Inspector.
# =============================================================================
extends Control

@onready var _copper_bar: Control = $CopperBar
@onready var _steel_bar:  Control = $SteelBar
@onready var _glass_bar:  Control = $GlassBar
@onready var _wood_bar:   Control = $WoodBar

# Gold display (no storage cap — shown as a flat number)
@onready var _gold_label: Label = $GoldLabel

func _ready() -> void:
	# Set resource types in case they weren't set in the Inspector
	_copper_bar.resource_type = "Copper"
	_steel_bar.resource_type  = "Steel"
	_glass_bar.resource_type  = "Glass"
	_wood_bar.resource_type   = "Wood"

	GameManager.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(GameManager.gold)

	_build_buff_section()
	BuffManager.buffs_changed.connect(_refresh_buffs)
	_refresh_buffs()

func _on_gold_changed(new_total: float) -> void:
	if _gold_label:
		_gold_label.text = "Gold: %d" % int(new_total)

# -----------------------------------------------------------------------------
# Active buffs section — anchored below the resource bars.
# Adjust the SIDE_TOP anchor (0.62) if your bars occupy more/less space.
# -----------------------------------------------------------------------------
var _buff_list: VBoxContainer

func _build_buff_section() -> void:
	var section := Control.new()
	section.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	section.set_anchor_and_offset(SIDE_RIGHT,  1.0, -8.0)
	section.set_anchor_and_offset(SIDE_TOP,    0.62, 4.0)
	section.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -8.0)
	add_child(section)

	# Thin separator at the top edge
	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.35, 0.35, 0.8)
	sep.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	sep.set_anchor_and_offset(SIDE_RIGHT,  1.0, 0.0)
	sep.set_anchor_and_offset(SIDE_TOP,    0.0, 0.0)
	sep.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 1.0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	scroll.set_anchor_and_offset(SIDE_RIGHT,  1.0, 0.0)
	scroll.set_anchor_and_offset(SIDE_TOP,    0.0, 6.0)
	scroll.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)
	section.add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(outer_vbox)

	var header := Label.new()
	header.text = "Active Buffs"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	outer_vbox.add_child(header)

	_buff_list = VBoxContainer.new()
	_buff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buff_list.add_theme_constant_override("separation", 3)
	outer_vbox.add_child(_buff_list)

func _refresh_buffs() -> void:
	if not _buff_list:
		return
	for child in _buff_list.get_children():
		child.queue_free()

	var any_active: bool = false
	for buff_id in BuffManager.BUFFS:
		var count: int = BuffManager.stack_count(buff_id)
		if count <= 0:
			continue
		any_active = true
		var def: Dictionary = BuffManager.BUFFS[buff_id]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_buff_list.add_child(row)

		# Icon
		var icon_lbl := Label.new()
		icon_lbl.text = def.get("icon", "✦")
		icon_lbl.add_theme_font_size_override("font_size", 12)
		icon_lbl.custom_minimum_size = Vector2(22.0, 0.0)
		row.add_child(icon_lbl)

		# Name (expands to fill available width)
		var name_lbl := Label.new()
		name_lbl.text = def["label"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Stack badge — only when count > 1
		if count > 1:
			var badge := Label.new()
			badge.text = "×%d" % count
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			row.add_child(badge)

		# Accumulated stat value
		var val: float   = BuffManager.stacked_value(buff_id)
		var unit: String = def.get("stat_unit", "")
		var stat_lbl     := Label.new()
		# Boolean-style buffs (empty unit, 1.0 per stack) → show "Active" / "Active ×N"
		if unit == "" and def.get("stat_per_stack", 1.0) == 1.0:
			stat_lbl.text = "Active" if count == 1 else "Active ×%d" % count
		else:
			stat_lbl.text = "+%.0f%s" % [val, unit]
		stat_lbl.add_theme_font_size_override("font_size", 11)
		stat_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
		stat_lbl.custom_minimum_size  = Vector2(72.0, 0.0)
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(stat_lbl)

	if not any_active:
		var none_lbl := Label.new()
		none_lbl.text = "No buffs yet — complete a level to earn one."
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buff_list.add_child(none_lbl)

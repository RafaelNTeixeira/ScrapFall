# =============================================================================
# WarehouseUI.gd  — fully code-driven, zero scene dependencies
#
# Attach to any Control node (the warehouse panel root).
# _ready() frees all pre-existing scene children, then builds the full UI.
# No .tscn children are needed — the scene node can be a bare Control.
#
# Inlines the ResourceBar behaviour (fill bar + cap blink) so ResourceBar.tscn
# is not required.
# =============================================================================
extends Control

# ---- Resource bar colours (matches ResourceBar.gd COLORS) ------------------
const BAR_COLORS: Dictionary = {
	"Copper": Color(0.72, 0.35, 0.10),
	"Steel":  Color(0.50, 0.55, 0.65),
	"Glass":  Color(0.45, 0.75, 0.90),
	"Wood":   Color(0.45, 0.28, 0.10),
}

const RESOURCE_ORDER: Array = ["Wood", "Steel", "Glass", "Copper"]

# ---- Node references --------------------------------------------------------
var _gold_lbl:    Label
var _bar_fills:   Dictionary = {}   # res → ProgressBar
var _bar_amounts: Dictionary = {}   # res → Label  ("247 / 500")
var _bar_full:    Dictionary = {}   # res → Label  ("FULL!")
var _is_blinking: Dictionary = {}   # res → bool
var _buff_list:   VBoxContainer

# =============================================================================
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Purge any legacy scene-designed children so this script owns everything
	for child in get_children():
		child.free()

	# ---- Scroll wrapper ----
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ---- Header ----
	var header := Label.new()
	header.text = "Warehouse"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	vbox.add_child(header)

	# ---- Gold display ----
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 16)
	_gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	vbox.add_child(_gold_lbl)

	# ---- Resources section ----
	var res_sep := HSeparator.new()
	vbox.add_child(res_sep)

	var res_hdr := Label.new()
	res_hdr.text = "Resources"
	res_hdr.add_theme_font_size_override("font_size", 13)
	res_hdr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(res_hdr)

	for res in RESOURCE_ORDER:
		_build_resource_bar(res, vbox)

	# ---- Active Buffs section ----
	vbox.add_child(HSeparator.new())

	var buffs_hdr := Label.new()
	buffs_hdr.text = "Active Buffs"
	buffs_hdr.add_theme_font_size_override("font_size", 13)
	buffs_hdr.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(buffs_hdr)

	_buff_list = VBoxContainer.new()
	_buff_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buff_list.add_theme_constant_override("separation", 3)
	vbox.add_child(_buff_list)

	# ---- Signals ----
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.resource_collected.connect(_on_resource_collected)
	GameManager.storage_full.connect(_on_storage_full)
	BuffManager.buffs_changed.connect(_refresh_buffs)

	# ---- Initial state ----
	_on_gold_changed(GameManager.gold)
	for res in RESOURCE_ORDER:
		_refresh_bar(res)
	_refresh_buffs()

# =============================================================================
# Resource bar builder — replicates ResourceBar.gd behaviour inline
# =============================================================================
func _build_resource_bar(res: String, parent: Control) -> void:
	var col: Color = BAR_COLORS.get(res, Color.WHITE)

	var card := PanelContainer.new()
	card.custom_minimum_size    = Vector2(0.0, 56.0)
	card.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	# Tinted background matching resource colour
	var bg := ColorRect.new()
	bg.color       = Color(col.r, col.g, col.b, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bg)

	# Explicit inner padding — sits in PanelContainer's content rect, on top of bg
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	card.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	margin.add_child(inner)

	# Label row: name  ·  amount  ·  "FULL!"
	var label_row := HBoxContainer.new()
	label_row.add_theme_constant_override("separation", 6)
	inner.add_child(label_row)

	var name_lbl := Label.new()
	name_lbl.text = res
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(name_lbl)

	var amount_lbl := Label.new()
	amount_lbl.add_theme_font_size_override("font_size", 11)
	amount_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	label_row.add_child(amount_lbl)

	var full_lbl := Label.new()
	full_lbl.text    = "FULL!"
	full_lbl.visible = false
	full_lbl.add_theme_font_size_override("font_size", 11)
	full_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label_row.add_child(full_lbl)

	# Progress bar
	var fill_bar := ProgressBar.new()
	fill_bar.min_value           = 0
	fill_bar.max_value           = GameManager.storage_caps.get(res, 500)
	fill_bar.value               = GameManager.resources.get(res, 0)
	fill_bar.show_percentage     = false
	fill_bar.custom_minimum_size = Vector2(0.0, 14.0)
	fill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill_bar.modulate            = col
	inner.add_child(fill_bar)

	_bar_fills[res]   = fill_bar
	_bar_amounts[res] = amount_lbl
	_bar_full[res]    = full_lbl
	_is_blinking[res] = false

# =============================================================================
# Bar refresh helpers
# =============================================================================
func _refresh_bar(res: String) -> void:
	if not _bar_fills.has(res):
		return
	var cap:     int = GameManager.storage_caps.get(res, 500)
	var current: int = GameManager.resources.get(res, 0)
	var fill:    ProgressBar = _bar_fills[res]
	fill.max_value = cap
	fill.value     = current
	_bar_amounts[res].text = "%d / %d" % [current, cap]
	var is_full: bool = (current >= cap)
	_bar_full[res].visible = is_full
	if is_full and not _is_blinking[res]:
		_blink_bar(res)

func _blink_bar(res: String) -> void:
	_is_blinking[res] = true
	var base_col: Color = BAR_COLORS.get(res, Color.WHITE)
	var fill: ProgressBar = _bar_fills[res]
	var tween: Tween = create_tween().set_loops(6)
	tween.tween_property(fill, "modulate", Color.RED,  0.18)
	tween.tween_property(fill, "modulate", base_col,   0.18)
	tween.finished.connect(func(): _is_blinking[res] = false, CONNECT_ONE_SHOT)

# =============================================================================
# Signal handlers
# =============================================================================
func _on_gold_changed(new_total: float) -> void:
	if _gold_lbl:
		_gold_lbl.text = "Gold:  %d" % int(new_total)

func _on_resource_collected(res_type: String, _new_total: int) -> void:
	_refresh_bar(res_type)

func _on_storage_full(res_type: String) -> void:
	if not _is_blinking.get(res_type, false):
		_blink_bar(res_type)

# =============================================================================
# Active buffs list
# =============================================================================
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

		var icon_lbl := Label.new()
		icon_lbl.text = def.get("icon", "✦")
		icon_lbl.add_theme_font_size_override("font_size", 12)
		icon_lbl.custom_minimum_size = Vector2(22.0, 0.0)
		row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = def["label"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		if count > 1:
			var badge := Label.new()
			badge.text = "×%d" % count
			badge.add_theme_font_size_override("font_size", 11)
			badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			row.add_child(badge)

		var val: float   = BuffManager.stacked_value(buff_id)
		var unit: String = def.get("stat_unit", "")
		var stat_lbl     := Label.new()
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

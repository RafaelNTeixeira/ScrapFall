# =============================================================================
# ShippingUI.gd
# Attach to: ShippingPanel (Control) inside TabNavigator/Panels
# Everything built in code — no manual children needed.
# =============================================================================
extends Control

const RES_TYPES: Array[String] = ["Copper", "Steel", "Glass", "Wood"]

# Contract card nodes — indexed 0-2
var _cards:       Array = []   # Array of Dictionary per card slot

# Liquidation section
var _sliders:     Dictionary = {}   # res → HSlider
var _slider_lbls: Dictionary = {}   # res → Label (shows amount + gold preview)
var _total_lbl:          Label
var _sell_btn:           Button
# Level progress section
var _level_progress_lbl: Label
var _level_bar:          ProgressBar
var _advance_btn:        Button

# -----------------------------------------------------------------------------
# _ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	# MarginContainer gives breathing room on all four edges
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

	_build_header(vbox)
	_build_contract_cards(vbox)
	_build_divider(vbox)
	_build_liquidation(vbox)
	_build_divider(vbox)
	_build_level_progress(vbox)

	# Connect signals
	ContractManager.contract_updated.connect(_on_contract_updated)
	LevelManager.progress_changed.connect(_on_level_progress_changed)
	LevelManager.advance_available.connect(_on_advance_available)
	ContractManager.contract_fulfilled.connect(_on_contract_fulfilled)
	ContractManager.contract_expired.connect(_on_contract_expired)
	GameManager.resource_collected.connect(func(_r, _n): _refresh_sliders())
	GameManager.resource_collected.connect(func(_r, _n): _refresh_fulfill_buttons())

	_refresh_all()

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------
func _build_header(parent: Control) -> void:
	var lbl := Label.new()
	lbl.text = "Shipping"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	parent.add_child(lbl)

# -----------------------------------------------------------------------------
# Contract cards
# -----------------------------------------------------------------------------
func _build_contract_cards(parent: Control) -> void:
	var contracts_lbl := Label.new()
	contracts_lbl.text = "Active Contracts  (2× Gold Bonus)"
	contracts_lbl.add_theme_font_size_override("font_size", 13)
	contracts_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	parent.add_child(contracts_lbl)

	for i in ContractManager.SLOT_COUNT:
		var card := _make_contract_card(i)
		_cards.append(card)
		parent.add_child(card["root"])

func _make_contract_card(slot: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 130.0)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Row 1: Faction name + 2× badge
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var faction_lbl := Label.new()
	faction_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_lbl.add_theme_font_size_override("font_size", 14)
	top_row.add_child(faction_lbl)

	var badge := Label.new()
	badge.text = "  2× BONUS!  "
	badge.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	badge.add_theme_font_size_override("font_size", 11)
	# Gold background via modulate
	var badge_bg := PanelContainer.new()
	badge_bg.modulate = Color(1.0, 0.82, 0.1)
	badge_bg.add_child(badge)
	top_row.add_child(badge_bg)

	# Row 2: Resources needed
	var res_lbl := Label.new()
	res_lbl.add_theme_font_size_override("font_size", 12)
	res_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(res_lbl)

	# Row 3: Gold reward
	var gold_lbl := Label.new()
	gold_lbl.add_theme_font_size_override("font_size", 13)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	vbox.add_child(gold_lbl)

	# Row 4: Timer bar
	var timer_bar := ProgressBar.new()
	timer_bar.min_value       = 0
	timer_bar.max_value       = 1
	timer_bar.value           = 1
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0.0, 8.0)
	timer_bar.modulate        = Color(0.3, 0.8, 1.0)
	vbox.add_child(timer_bar)

	# Row 5: Fulfill button
	var fulfill_btn := Button.new()
	fulfill_btn.text = "Fulfill Contract"
	fulfill_btn.pressed.connect(func(): _on_fulfill_pressed(slot))
	vbox.add_child(fulfill_btn)

	var card := {
		"root":        panel,
		"faction_lbl": faction_lbl,
		"res_lbl":     res_lbl,
		"gold_lbl":    gold_lbl,
		"timer_bar":   timer_bar,
		"fulfill_btn": fulfill_btn,
	}
	return card

# -----------------------------------------------------------------------------
# Divider
# -----------------------------------------------------------------------------
func _build_divider(parent: Control) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

	var lbl := Label.new()
	lbl.text = "Raw Sales  (1× Rate)"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	parent.add_child(lbl)

# -----------------------------------------------------------------------------
# Liquidation sliders
# -----------------------------------------------------------------------------
func _build_liquidation(parent: Control) -> void:
	for res in RES_TYPES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text                   = res
		name_lbl.custom_minimum_size    = Vector2(55.0, 0.0)
		name_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(name_lbl)

		var slider := HSlider.new()
		slider.min_value              = 0
		slider.max_value              = GameManager.storage_caps.get(res, 500)
		slider.value                  = 0
		slider.step                   = 1
		slider.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(_v): _refresh_slider_label(res))
		_sliders[res] = slider
		row.add_child(slider)

		var amt_lbl := Label.new()
		amt_lbl.custom_minimum_size   = Vector2(90.0, 0.0)
		amt_lbl.add_theme_font_size_override("font_size", 11)
		amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
		_slider_lbls[res] = amt_lbl
		row.add_child(amt_lbl)

	# Total + sell button
	var bottom_row := HBoxContainer.new()
	parent.add_child(bottom_row)

	_total_lbl = Label.new()
	_total_lbl.text                  = "Total: 0 Gold"
	_total_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_lbl.add_theme_font_size_override("font_size", 13)
	_total_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	bottom_row.add_child(_total_lbl)

	_sell_btn = Button.new()
	_sell_btn.text    = "Sell Raw"
	_sell_btn.pressed.connect(_on_sell_raw_pressed)
	bottom_row.add_child(_sell_btn)

# -----------------------------------------------------------------------------
# Level progress section
# -----------------------------------------------------------------------------
func _build_level_progress(parent: Control) -> void:
	var lbl := Label.new()
	lbl.text = "Level Progress"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	parent.add_child(lbl)

	_level_progress_lbl = Label.new()
	_level_progress_lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(_level_progress_lbl)

	_level_bar = ProgressBar.new()
	_level_bar.min_value       = 0
	_level_bar.show_percentage = false
	_level_bar.custom_minimum_size = Vector2(0.0, 10.0)
	_level_bar.modulate        = Color(0.5, 1.0, 0.5)
	parent.add_child(_level_bar)

	_advance_btn = Button.new()
	_advance_btn.text    = "Advance to Next Level →"
	_advance_btn.visible = false
	_advance_btn.modulate = Color(1.0, 0.85, 0.2)
	_advance_btn.pressed.connect(_on_advance_pressed)
	parent.add_child(_advance_btn)

	_refresh_level_progress()

func _refresh_level_progress() -> void:
	if not _level_progress_lbl:
		return
	var done:     int = LevelManager.contracts_this_level
	var needed:   int = LevelManager.contracts_required()
	var gold_req: int = LevelManager.gold_required()
	_level_progress_lbl.text = "Contracts: %d / %d   |   Gold needed: %d (have %d)" % [
		done, needed, gold_req, int(GameManager.gold)
	]
	_level_bar.max_value = needed
	_level_bar.value     = done
	var can_go: bool = LevelManager.can_advance()
	_advance_btn.visible  = can_go
	_level_bar.modulate   = Color(1.0, 0.85, 0.2) if can_go else Color(0.5, 1.0, 0.5)

# -----------------------------------------------------------------------------
# _process — tick timer bars every frame
# -----------------------------------------------------------------------------
func _process(_delta: float) -> void:
	_refresh_level_progress()
	for i in ContractManager.SLOT_COUNT:
		if i >= _cards.size():
			break
		var c: Dictionary    = ContractManager.contracts[i]
		var bar: ProgressBar = _cards[i]["timer_bar"]
		var frac: float      = c["time_remaining"] / c["duration"]
		bar.value            = clampf(frac, 0.0, 1.0)
		# Colour shifts red as time runs low
		bar.modulate = Color(0.3, 0.8, 1.0).lerp(Color(1.0, 0.2, 0.2), 1.0 - frac)

# -----------------------------------------------------------------------------
# Refresh helpers
# -----------------------------------------------------------------------------
func _refresh_all() -> void:
	for i in ContractManager.SLOT_COUNT:
		_refresh_card(i)
	_refresh_sliders()

func _refresh_card(slot: int) -> void:
	if slot >= _cards.size():
		return
	var c:    Dictionary = ContractManager.contracts[slot]
	var card: Dictionary = _cards[slot]

	card["faction_lbl"].text = c["faction"]
	card["res_lbl"].text     = _resources_string(c["resources"])
	card["gold_lbl"].text    = "Reward: %d Gold" % int(c["gold_reward"])
	card["timer_bar"].max_value = c["duration"]
	_refresh_fulfill_buttons()

func _refresh_fulfill_buttons() -> void:
	for i in ContractManager.SLOT_COUNT:
		if i >= _cards.size():
			continue
		var can: bool = ContractManager.can_fulfill(i)
		_cards[i]["fulfill_btn"].disabled = not can
		_cards[i]["fulfill_btn"].modulate = Color.WHITE if can else Color(0.5, 0.5, 0.5)

func _refresh_sliders() -> void:
	for res in RES_TYPES:
		if not _sliders.has(res):
			continue
		var slider: HSlider = _sliders[res]
		var max_val: int    = GameManager.resources.get(res, 0)
		slider.max_value    = max_val
		# Clamp current value if stored amount dropped
		slider.value        = minf(slider.value, max_val)
		_refresh_slider_label(res)
	_refresh_total_label()

func _refresh_slider_label(res: String) -> void:
	if not _slider_lbls.has(res):
		return
	var amt:  int   = int(_sliders[res].value)
	var gold: float = ContractManager.raw_gold_for(res, amt)
	_slider_lbls[res].text = "%d units  (+%.0f G)" % [amt, gold]
	_refresh_total_label()

func _refresh_total_label() -> void:
	var total: float = 0.0
	for res in RES_TYPES:
		if _sliders.has(res):
			total += ContractManager.raw_gold_for(res, int(_sliders[res].value))
	_total_lbl.text = "Total: %.0f Gold" % total
	_sell_btn.disabled = (total <= 0.0)

func _resources_string(res_dict: Dictionary) -> String:
	var parts: Array = []
	for res in res_dict:
		parts.append("%d %s" % [res_dict[res], res])
	return "Needs: " + "  •  ".join(parts)

# -----------------------------------------------------------------------------
# Button handlers
# -----------------------------------------------------------------------------
func _on_fulfill_pressed(slot: int) -> void:
	if ContractManager.fulfill_contract(slot):
		_refresh_all()

func _on_sell_raw_pressed() -> void:
	var amounts: Dictionary = {}
	for res in RES_TYPES:
		if _sliders.has(res):
			var amt: int = int(_sliders[res].value)
			if amt > 0:
				amounts[res] = amt
	if amounts.is_empty():
		return
	ContractManager.sell_raw(amounts)
	# Reset sliders to 0 after selling
	for res in RES_TYPES:
		if _sliders.has(res):
			_sliders[res].value = 0
	_refresh_sliders()

# -----------------------------------------------------------------------------
# Level signal handlers
# -----------------------------------------------------------------------------
func _on_level_progress_changed(_done: int, _needed: int) -> void:
	_refresh_level_progress()

func _on_advance_available(_available: bool) -> void:
	_refresh_level_progress()

func _on_advance_pressed() -> void:
	LevelManager.show_advance_ui_requested.emit()

# ContractManager signal handlers
# -----------------------------------------------------------------------------
func _on_contract_updated(slot: int) -> void:
	_refresh_card(slot)

func _on_contract_fulfilled(_slot: int, gold: float) -> void:
	# Brief flash on the panel
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.3, 1.3, 0.6), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_contract_expired(_slot: int) -> void:
	pass  # card auto-refreshed via contract_updated

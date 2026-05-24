# =============================================================================
# UpgradeUI.gd — Control node on BoardPanel
# All children built in code. Anchor to Full Rect, mouse_filter = Pass.
# =============================================================================
extends Control

const PANEL_WIDTH:  float = 300.0
const PANEL_HEIGHT: float = 440.0
const CARD_HEIGHT:  float = 110.0

var _panel:           Control
var _scroll:          ScrollContainer
var _card_list:       VBoxContainer
var _toggle_btn:      Button
var _is_open:         bool = false
var _placement_banner: Control
var _banner_label:    Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_toggle_button()
	_build_panel()
	_build_placement_banner()

	UpgradeManager.upgrade_purchased.connect(_on_any_change)
	UpgradeManager.upgrade_failed.connect(_on_upgrade_failed)
	UpgradeManager.placement_mode_started.connect(_on_placement_started)
	UpgradeManager.placement_mode_cancelled.connect(_on_placement_done)
	UpgradeManager.placement_confirmed.connect(_on_placement_done)
	GameManager.resource_collected.connect(func(_r, _n): _refresh_cards())
	GameManager.gold_changed.connect(func(_g): _refresh_cards())

# -----------------------------------------------------------------------------
# Toggle button
# -----------------------------------------------------------------------------
func _build_toggle_button() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text                = "Upgrades"
	_toggle_btn.custom_minimum_size = Vector2(100.0, 40.0)
	_toggle_btn.set_anchor_and_offset(SIDE_RIGHT,  1.0, -12.0)
	_toggle_btn.set_anchor_and_offset(SIDE_LEFT,   1.0, -112.0)
	_toggle_btn.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -84.0)
	_toggle_btn.set_anchor_and_offset(SIDE_TOP,    1.0, -124.0)
	_toggle_btn.pressed.connect(_toggle_panel)
	add_child(_toggle_btn)

# -----------------------------------------------------------------------------
# Upgrade panel
# -----------------------------------------------------------------------------
func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -8.0)
	_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -(PANEL_WIDTH + 8.0))
	_panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -132.0)
	_panel.set_anchor_and_offset(SIDE_TOP,    1.0, -(PANEL_HEIGHT + 132.0))
	_panel.visible      = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Upgrades"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, PANEL_HEIGHT - 60.0)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_card_list)

	_build_all_cards()

# -----------------------------------------------------------------------------
# Placement banner
# -----------------------------------------------------------------------------
func _build_placement_banner() -> void:
	_placement_banner = PanelContainer.new()
	_placement_banner.set_anchor_and_offset(SIDE_LEFT,   0.0,  16.0)
	_placement_banner.set_anchor_and_offset(SIDE_RIGHT,  1.0, -16.0)
	_placement_banner.set_anchor_and_offset(SIDE_TOP,    0.0,  70.0)
	_placement_banner.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 124.0)
	_placement_banner.visible      = false
	_placement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placement_banner)

	var hbox := HBoxContainer.new()
	_placement_banner.add_child(hbox)

	_banner_label = Label.new()
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(_banner_label)

	var cancel_btn := Button.new()
	cancel_btn.text    = "Cancel"
	cancel_btn.pressed.connect(func(): UpgradeManager.cancel_placement())
	hbox.add_child(cancel_btn)

# -----------------------------------------------------------------------------
# Cards
# -----------------------------------------------------------------------------
func _build_all_cards() -> void:
	for child in _card_list.get_children():
		child.queue_free()
	for upgrade_id in UpgradeManager.UPGRADES:
		# Skip hidden relocation entries — they appear as Relocate buttons on parent cards
		if UpgradeManager.UPGRADES[upgrade_id].get("hidden", false):
			continue
		_card_list.add_child(_make_card(upgrade_id))

func _make_card(upgrade_id: String) -> Control:
	var upg: Dictionary = UpgradeManager.UPGRADES[upgrade_id]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	card.name                = "Card_" + upgrade_id

	var vbox := VBoxContainer.new()
	vbox.name     = "VBoxContainer"
	card.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = upg["label"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text          = upg["description"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = _cost_string(upg)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.name = "CostLabel"
	vbox.add_child(cost_lbl)

	# Button row: Buy + optional Relocate
	var btn_row := HBoxContainer.new()
	btn_row.name = "HBoxContainer"
	vbox.add_child(btn_row)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.pressed.connect(func(): _on_card_button_pressed(upgrade_id))
	btn_row.add_child(buy_btn)

	# Relocate button — for droppers, gates, and special pegs
	if upgrade_id in ["auto_dropper_1", "auto_dropper_2", "gate_1", "gate_2", "splitter_peg", "energy_peg", "bouncy_peg"]:
		var rel_btn := Button.new()
		rel_btn.name = "RelocateButton"
		rel_btn.text = "Relocate"
		rel_btn.visible = false
		rel_btn.pressed.connect(func(): _on_relocate_pressed(upgrade_id))
		btn_row.add_child(rel_btn)

	_update_card_state(card, upgrade_id)
	return card

func _cost_string(upg: Dictionary) -> String:
	var parts: Array = []
	for res in upg["cost_res"]:
		parts.append("%d %s" % [upg["cost_res"][res], res])
	if upg["cost_gold"] > 0.0:
		parts.append("%d Gold" % int(upg["cost_gold"]))
	return "Cost: " + ", ".join(parts) if not parts.is_empty() else "Free"

func _update_card_state(card: Control, upgrade_id: String) -> void:
	var upg: Dictionary      = UpgradeManager.UPGRADES[upgrade_id]
	var btn_row: HBoxContainer = card.get_node("VBoxContainer/HBoxContainer")
	var buy_btn: Button       = btn_row.get_node("BuyButton")
	var purchased: bool       = upg.get("purchased", false)
	var placed:    bool       = upg.get("placed",    false)
	var affordable: bool      = UpgradeManager.can_afford(upgrade_id)

	# Relocate button visibility
	var rel_btn: Button = btn_row.get_node_or_null("RelocateButton")
	if rel_btn:
		rel_btn.visible = purchased and placed

	var needs_placement: bool = upg.get("placement") == true

	if purchased and (not needs_placement or placed):
		# Instant upgrades (no placement) and fully-placed upgrades both show Purchased
		buy_btn.text     = "Purchased ✓"
		buy_btn.disabled = true
		buy_btn.modulate = Color(0.6, 0.9, 0.6)
	elif purchased and needs_placement and not placed:
		# Paid but still needs a board tap to place
		buy_btn.text     = "Tap board to place"
		buy_btn.disabled = false
		buy_btn.modulate = Color(1.0, 0.85, 0.2)
	elif not affordable:
		buy_btn.text     = "Buy"
		buy_btn.disabled = true
		buy_btn.modulate = Color(0.5, 0.5, 0.5)
	else:
		buy_btn.text     = "Buy"
		buy_btn.disabled = false
		buy_btn.modulate = Color.WHITE

func _refresh_cards() -> void:
	for card in _card_list.get_children():
		var id: String = card.name.trim_prefix("Card_")
		if UpgradeManager.UPGRADES.has(id):
			_update_card_state(card, id)

# -----------------------------------------------------------------------------
# Button handlers
# -----------------------------------------------------------------------------
func _on_card_button_pressed(upgrade_id: String) -> void:
	var upg: Dictionary = UpgradeManager.UPGRADES[upgrade_id]
	if upg.get("purchased", false) and not upg.get("placed", false):
		UpgradeManager.reenter_placement(upgrade_id)
	else:
		UpgradeManager.purchase(upgrade_id)

func _on_relocate_pressed(upgrade_id: String) -> void:
	var mode: String = ""
	match upgrade_id:
		"auto_dropper_1": mode = "relocate_dropper_1"
		"auto_dropper_2": mode = "relocate_dropper_2"
		"gate_1":         mode = "relocate_gate_1"
		"gate_2":         mode = "relocate_gate_2"
		"splitter_peg":   mode = "relocate_splitter"
		"energy_peg":     mode = "relocate_energy"
		"bouncy_peg":     mode = "relocate_bouncy"
	if not mode.is_empty():
		UpgradeManager.enter_relocate_mode(mode)

# -----------------------------------------------------------------------------
# Signal handlers
# -----------------------------------------------------------------------------
func _on_any_change(_id: String = "") -> void:
	_refresh_cards()

func _on_upgrade_failed(_id: String, _reason: String) -> void:
	pass  # Phase 9: toast notification

func _on_placement_started(upgrade_id: String) -> void:
	_panel.visible            = false
	_is_open                  = false
	_toggle_btn.text          = "Upgrades"
	_placement_banner.visible = true

	# Set contextual banner text
	match upgrade_id:
		"splitter_peg":
			_banner_label.text = "Tap a peg in the middle rows to place the Splitter"
		"energy_peg":
			_banner_label.text = "Tap any peg to make it an Energy Peg"
		"gate_1", "gate_2":
			_banner_label.text = "Click on two consecutive pegs to insert a gate"
		"bouncy_peg":
			_banner_label.text = "Tap any peg to make it a Bouncy Peg"
		"relocate_splitter":
			_banner_label.text = "Tap a middle-row peg to move the Splitter"
		"relocate_energy":
			_banner_label.text = "Tap any peg to move the Energy Peg"
		"relocate_bouncy":
			_banner_label.text = "Tap any peg to move the Bouncy Peg"
		"auto_dropper_1", "auto_dropper_2":
			_banner_label.text = "Tap the top of the board to place the Auto-Dropper"
		"relocate_dropper_1", "relocate_dropper_2":
			_banner_label.text = "Tap a new position to move the Auto-Dropper"
		"relocate_gate_1", "relocate_gate_2":
			_banner_label.text = "Click on two consecutive pegs to place the Gate"
		_:
			_banner_label.text = "Tap the board to place"

func _on_placement_done(_id: String = "") -> void:
	_placement_banner.visible = false
	_refresh_cards()

# -----------------------------------------------------------------------------
# Toggle
# -----------------------------------------------------------------------------
func _toggle_panel() -> void:
	_is_open       = not _is_open
	_panel.visible = _is_open
	_toggle_btn.text = "Close" if _is_open else "Upgrades"

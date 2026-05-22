# =============================================================================
# UpgradeUI.gd
# Attach to: Control node — a floating panel on the Board tab
#
# Scene tree — all built in code, no manual children needed:
#   UpgradeUI (Control)   ← this script
#
# A toggle button sits in the corner of the board view. Tapping it opens
# a scrollable list of upgrade cards. Each card shows:
#   • Name + description
#   • Cost (resources or gold)
#   • Status (Buy / Purchased / Needs placement / Can't afford)
# =============================================================================
extends Control

const PANEL_WIDTH:  float = 280.0
const PANEL_HEIGHT: float = 420.0
const CARD_HEIGHT:  float = 90.0

var _panel:      Control
var _scroll:     ScrollContainer
var _card_list:  VBoxContainer
var _toggle_btn: Button
var _is_open:    bool = false

# Placement mode banner shown while waiting for board tap
var _placement_banner: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_toggle_button()
	_build_panel()
	_build_placement_banner()

	UpgradeManager.upgrade_purchased.connect(_on_upgrade_changed)
	UpgradeManager.upgrade_failed.connect(_on_upgrade_failed)
	UpgradeManager.placement_mode_started.connect(_on_placement_started)
	UpgradeManager.placement_mode_cancelled.connect(_on_placement_cancelled)
	GameManager.resource_collected.connect(func(_r, _n): _refresh_cards())
	GameManager.gold_changed.connect(func(_g): _refresh_cards())

# -----------------------------------------------------------------------------
# Toggle button (bottom-right corner, above tab bar)
# -----------------------------------------------------------------------------
func _build_toggle_button() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text                  = "Upgrades"
	_toggle_btn.custom_minimum_size   = Vector2(100.0, 40.0)
	_toggle_btn.set_anchor_and_offset(SIDE_RIGHT,  1.0, -12.0)
	_toggle_btn.set_anchor_and_offset(SIDE_LEFT,   1.0, -112.0)
	_toggle_btn.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -84.0)   # above tab bar
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
	_scroll.custom_minimum_size        = Vector2(0.0, PANEL_HEIGHT - 60.0)
	_scroll.size_flags_vertical        = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_card_list)

	_build_all_cards()

# -----------------------------------------------------------------------------
# Placement banner
# -----------------------------------------------------------------------------
func _build_placement_banner() -> void:
	_placement_banner = PanelContainer.new()
	_placement_banner.set_anchor_and_offset(SIDE_LEFT,   0.0, 20.0)
	_placement_banner.set_anchor_and_offset(SIDE_RIGHT,  1.0, -20.0)
	_placement_banner.set_anchor_and_offset(SIDE_TOP,    0.0, 70.0)
	_placement_banner.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 120.0)
	_placement_banner.visible      = false
	_placement_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_placement_banner)

	var hbox := HBoxContainer.new()
	_placement_banner.add_child(hbox)

	var lbl := Label.new()
	lbl.text                       = "Tap a peg on the board to place"
	lbl.size_flags_horizontal      = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)

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
		_card_list.add_child(_make_card(upgrade_id))

func _make_card(upgrade_id: String) -> Control:
	var upg:      Dictionary = UpgradeManager.UPGRADES[upgrade_id]
	var card      := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, CARD_HEIGHT)
	card.name                = "Card_" + upgrade_id

	var vbox      := VBoxContainer.new()
	vbox.name     = "VBoxContainer"
	card.add_child(vbox)

	# Title row
	var title_lbl := Label.new()
	title_lbl.text = upg["label"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.name = "TitleLabel"
	vbox.add_child(title_lbl)

	# Description
	var desc_lbl  := Label.new()
	desc_lbl.text           = upg["description"]
	desc_lbl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_lbl)

	# Cost row
	var cost_lbl  := Label.new()
	cost_lbl.text = _cost_string(upg)
	cost_lbl.add_theme_font_size_override("font_size", 11)
	cost_lbl.name = "CostLabel"
	vbox.add_child(cost_lbl)

	# Buy button
	var btn       := Button.new()
	btn.name       = "BuyButton"
	btn.pressed.connect(func(): UpgradeManager.purchase(upgrade_id))
	vbox.add_child(btn)

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
	var upg: Dictionary = UpgradeManager.UPGRADES[upgrade_id]
	var btn: Button     = card.get_node("VBoxContainer/BuyButton")
	var purchased:  bool = upg.get("purchased", false)
	var placed:     bool = upg.get("placed",    false)
	var affordable: bool = UpgradeManager.can_afford(upgrade_id)

	if purchased and (not upg.get("placement", false) or placed):
		btn.text     = "Purchased"
		btn.disabled = true
	elif purchased and not placed:
		btn.text     = "Tap board to place"
		btn.disabled = true
		btn.modulate = Color(1.0, 0.85, 0.2)
	elif not affordable:
		btn.text     = "Buy"
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
	else:
		btn.text     = "Buy"
		btn.disabled = false
		btn.modulate = Color.WHITE

func _refresh_cards() -> void:
	for card in _card_list.get_children():
		var upgrade_id: String = card.name.trim_prefix("Card_")
		if UpgradeManager.UPGRADES.has(upgrade_id):
			_update_card_state(card, upgrade_id)

# -----------------------------------------------------------------------------
# Toggle
# -----------------------------------------------------------------------------
func _toggle_panel() -> void:
	_is_open   = not _is_open
	_panel.visible = _is_open
	_toggle_btn.text = "Close" if _is_open else "Upgrades"

# -----------------------------------------------------------------------------
# Signal handlers
# -----------------------------------------------------------------------------
func _on_upgrade_changed(_id: String) -> void:
	_refresh_cards()

func _on_upgrade_failed(_id: String, reason: String) -> void:
	# TODO: show a brief toast notification (Phase 9 polish)
	print("Upgrade failed: ", reason)

func _on_placement_started(_id: String) -> void:
	_panel.visible          = false
	_is_open                = false
	_toggle_btn.text        = "Upgrades"
	_placement_banner.visible = true

func _on_placement_cancelled() -> void:
	_placement_banner.visible = false
	_refresh_cards()

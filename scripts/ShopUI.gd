# =============================================================================
# ShopUI.gd
# Injected into ShopPanel by TabNavigator — all children built in code.
#
# Sections:
#   1. Sphere Skins  — weighted random unbox (CSGO-style scroll animation)
#   2. Factory Themes — 4 colour themes applied to panel backgrounds
#   3. QoL Upgrades  — Offline Overdrive tiers, Contract Refresh Tokens
#   4. Premium       — Golden Shipping Drone, Expanded Storage Silos, Supporter stub
# =============================================================================
extends Control

# ---- Skin catalogue ---------------------------------------------------------
# Each entry: { name, rarity, color, weight }
# Weights sum to 121; roughly: Common≈60%, Rare≈28%, Epic≈10%, Legendary≈3%
const SKINS: Dictionary = {
	"default":     { "name": "Factory Gray",  "rarity": "Common",    "color": Color(0.72, 0.72, 0.72), "weight": 25 },
	"copper_ball": { "name": "Copper Shell",  "rarity": "Common",    "color": Color(0.72, 0.45, 0.20), "weight": 20 },
	"steel_ball":  { "name": "Steel Chrome",  "rarity": "Common",    "color": Color(0.75, 0.78, 0.88), "weight": 20 },
	"timber":      { "name": "Timber",        "rarity": "Common",    "color": Color(0.60, 0.40, 0.20), "weight": 15 },
	"crystal":     { "name": "Crystal",       "rarity": "Rare",      "color": Color(0.50, 0.88, 1.00), "weight": 10 },
	"neon_blue":   { "name": "Neon Blue",     "rarity": "Rare",      "color": Color(0.15, 0.45, 1.00), "weight": 10 },
	"toxic":       { "name": "Toxic",         "rarity": "Rare",      "color": Color(0.20, 1.00, 0.30), "weight": 8  },
	"lava":        { "name": "Lava",          "rarity": "Epic",      "color": Color(1.00, 0.22, 0.05), "weight": 4  },
	"void":        { "name": "Void",          "rarity": "Epic",      "color": Color(0.50, 0.00, 1.00), "weight": 3  },
	"arctic":      { "name": "Arctic Ice",    "rarity": "Epic",      "color": Color(0.75, 0.95, 1.00), "weight": 3  },
	"solar_gold":  { "name": "Solar Gold",    "rarity": "Legendary", "color": Color(1.00, 0.85, 0.00), "weight": 1  },
	"obsidian":    { "name": "Obsidian",      "rarity": "Legendary", "color": Color(0.15, 0.05, 0.25), "weight": 1  },
	"prism":       { "name": "Prism",         "rarity": "Legendary", "color": Color(1.00, 0.45, 0.85), "weight": 1  },
}

const RARITY_COLORS: Dictionary = {
	"Common":    Color(0.70, 0.70, 0.70),
	"Rare":      Color(0.20, 0.55, 1.00),
	"Epic":      Color(0.70, 0.20, 1.00),
	"Legendary": Color(1.00, 0.70, 0.00),
}

# ---- Theme catalogue --------------------------------------------------------
const THEMES: Dictionary = {
	"factory":   { "name": "Factory"   },
	"cyberpunk": { "name": "Cyberpunk" },
	"steampunk": { "name": "Steampunk" },
	"zen":       { "name": "Zen"       },
}

# ---- Shop costs -------------------------------------------------------------
const CRATE_COST:           float = 75.0
const TOKEN_COST:           float = 100.0
const OFFLINE_TIER_COSTS:   Array = [200.0, 500.0]
const OFFLINE_TIER_VALUES:  Array = [0.5,   1.0]      # fraction of normal production
const GOLDEN_DRONE_COST:    float = 500.0
const EXPANDED_SILOS_COST:  float = 300.0
const DUPLICATE_BONUS_GOLD: float = 15.0

# ---- Unbox animation --------------------------------------------------------
const STRIP_CARD_W:  float = 86.0
const STRIP_CARD_H:  float = 86.0
const STRIP_GAP:     float = 6.0
const STRIP_STEP:    float = STRIP_CARD_W + STRIP_GAP  # 92 px per slot
const STRIP_COUNT:   int   = 42
const WINNER_INDEX:  int   = 34   # card index that holds the winner
const ANIM_DURATION: float = 3.4

# ---- Node references --------------------------------------------------------
var _crate_btn:      Button
var _skin_grid:      GridContainer
var _theme_btns:     Dictionary = {}
var _offline_btns:   Array      = []
var _offline_desc:   Label
var _token_buy_btn:  Button
var _token_count_lbl: Label
var _drone_btn:      Button
var _silos_btn:      Button
var _unbox_overlay:  Control = null   # lives as child of ShopPanel during animation

# =============================================================================
# _ready
# =============================================================================
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_build_header(vbox)
	_build_section_label(vbox, "Sphere Skins")
	_build_skins_section(vbox)
	_build_section_label(vbox, "Factory Themes")
	_build_themes_section(vbox)
	_build_section_label(vbox, "QoL Upgrades")
	_build_upgrades_section(vbox)
	_build_section_label(vbox, "Premium")
	_build_premium_section(vbox)

	GameManager.gold_changed.connect(func(_g): _refresh_affordability())
	GameManager.skin_changed.connect(func(_s): _refresh_skins())
	GameManager.theme_changed.connect(func(_t): _refresh_themes())

	_refresh_skins()
	_refresh_themes()
	_refresh_upgrades()
	_refresh_affordability()

# =============================================================================
# Section builders
# =============================================================================
func _build_header(parent: Control) -> void:
	var lbl := Label.new()
	lbl.text = "Shop"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	parent.add_child(lbl)

func _build_section_label(parent: Control, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	parent.add_child(lbl)

# ---- Skins ------------------------------------------------------------------
func _build_skins_section(parent: Control) -> void:
	# Open crate row
	var crate_row := HBoxContainer.new()
	crate_row.add_theme_constant_override("separation", 10)
	parent.add_child(crate_row)

	_crate_btn = Button.new()
	_crate_btn.text = "Open Crate"
	_crate_btn.custom_minimum_size = Vector2(130.0, 44.0)
	_crate_btn.pressed.connect(_on_open_crate)
	crate_row.add_child(_crate_btn)

	var cost_lbl := Label.new()
	cost_lbl.text = "%.0f Gold each" % CRATE_COST
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	cost_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crate_row.add_child(cost_lbl)

	# Odds hint
	var odds_lbl := Label.new()
	odds_lbl.text = "Common 60%  •  Rare 28%  •  Epic 9%  •  Legendary 3%"
	odds_lbl.add_theme_font_size_override("font_size", 10)
	odds_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	odds_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(odds_lbl)

	# Owned skins header
	var owned_hdr := Label.new()
	owned_hdr.text = "Owned — tap to equip:"
	owned_hdr.add_theme_font_size_override("font_size", 12)
	owned_hdr.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	parent.add_child(owned_hdr)

	# Skin grid (rebuilt on skin_changed)
	_skin_grid = GridContainer.new()
	_skin_grid.columns = 4
	_skin_grid.add_theme_constant_override("h_separation", 8)
	_skin_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(_skin_grid)

# ---- Themes -----------------------------------------------------------------
func _build_themes_section(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	for theme_id in THEMES:
		var btn := Button.new()
		btn.text = THEMES[theme_id]["name"]
		btn.custom_minimum_size = Vector2(0.0, 44.0)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Capture loop variable
		var tid: String = theme_id
		btn.pressed.connect(func(): _on_theme_selected(tid))
		_theme_btns[theme_id] = btn
		grid.add_child(btn)

# ---- QoL Upgrades -----------------------------------------------------------
func _build_upgrades_section(parent: Control) -> void:
	# Offline Overdrive
	var od_title := Label.new()
	od_title.text = "Offline Overdrive"
	od_title.add_theme_font_size_override("font_size", 13)
	parent.add_child(od_title)

	_offline_desc = Label.new()
	_offline_desc.add_theme_font_size_override("font_size", 11)
	_offline_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_offline_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_offline_desc)

	var od_row := HBoxContainer.new()
	od_row.add_theme_constant_override("separation", 8)
	parent.add_child(od_row)

	for i in 2:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i   # capture
		btn.pressed.connect(func(): _on_offline_upgrade(idx))
		_offline_btns.append(btn)
		od_row.add_child(btn)

	# Contract Refresh Tokens
	parent.add_child(HSeparator.new())

	var token_panel := PanelContainer.new()
	token_panel.custom_minimum_size = Vector2(0.0, 72.0)
	parent.add_child(token_panel)

	var token_vbox := VBoxContainer.new()
	token_panel.add_child(token_vbox)

	var token_title := Label.new()
	token_title.text = "Contract Refresh Token"
	token_title.add_theme_font_size_override("font_size", 13)
	token_vbox.add_child(token_title)

	var token_desc := Label.new()
	token_desc.text = "Reroll any active contract instantly. Max 10 held. Use the 🔄 button in Shipping."
	token_desc.add_theme_font_size_override("font_size", 10)
	token_desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	token_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	token_vbox.add_child(token_desc)

	var token_row := HBoxContainer.new()
	token_row.add_theme_constant_override("separation", 8)
	token_vbox.add_child(token_row)

	_token_count_lbl = Label.new()
	_token_count_lbl.add_theme_font_size_override("font_size", 12)
	_token_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	_token_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_count_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	token_row.add_child(_token_count_lbl)

	_token_buy_btn = Button.new()
	_token_buy_btn.text = "Buy  %.0f G" % TOKEN_COST
	_token_buy_btn.custom_minimum_size = Vector2(110.0, 0.0)
	_token_buy_btn.pressed.connect(_on_buy_token)
	token_row.add_child(_token_buy_btn)

# ---- Premium ----------------------------------------------------------------
func _build_premium_section(parent: Control) -> void:
	# Golden Shipping Drone
	var drone_panel := PanelContainer.new()
	drone_panel.custom_minimum_size = Vector2(0.0, 88.0)
	parent.add_child(drone_panel)

	var drone_vbox := VBoxContainer.new()
	drone_panel.add_child(drone_vbox)

	var drone_title := Label.new()
	drone_title.text = "Golden Shipping Drone"
	drone_title.add_theme_font_size_override("font_size", 13)
	drone_vbox.add_child(drone_title)

	var drone_desc := Label.new()
	drone_desc.text = "All shipping contracts pay +20%% gold. One-time permanent upgrade."
	drone_desc.add_theme_font_size_override("font_size", 11)
	drone_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	drone_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drone_vbox.add_child(drone_desc)

	_drone_btn = Button.new()
	_drone_btn.text = "Buy  %.0f Gold" % GOLDEN_DRONE_COST
	_drone_btn.pressed.connect(_on_buy_drone)
	drone_vbox.add_child(_drone_btn)

	# Expanded Storage Silos
	var silos_panel := PanelContainer.new()
	silos_panel.custom_minimum_size = Vector2(0.0, 88.0)
	parent.add_child(silos_panel)

	var silos_vbox := VBoxContainer.new()
	silos_panel.add_child(silos_vbox)

	var silos_title := Label.new()
	silos_title.text = "Expanded Storage Silos"
	silos_title.add_theme_font_size_override("font_size", 13)
	silos_vbox.add_child(silos_title)

	var silos_desc := Label.new()
	silos_desc.text = "+25%% capacity for all resource types. One-time permanent upgrade."
	silos_desc.add_theme_font_size_override("font_size", 11)
	silos_desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	silos_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	silos_vbox.add_child(silos_desc)

	_silos_btn = Button.new()
	_silos_btn.text = "Buy  %.0f Gold" % EXPANDED_SILOS_COST
	_silos_btn.pressed.connect(_on_buy_silos)
	silos_vbox.add_child(_silos_btn)

	# Supporter Pack stub
	var support_lbl := Label.new()
	support_lbl.text = "Supporter Pack — coming soon!"
	support_lbl.add_theme_font_size_override("font_size", 12)
	support_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	parent.add_child(support_lbl)

# =============================================================================
# Refresh helpers
# =============================================================================
func _refresh_skins() -> void:
	for child in _skin_grid.get_children():
		child.queue_free()
	for skin_id in SKINS:
		var is_owned:  bool = skin_id in GameManager.owned_skins
		var is_active: bool = (skin_id == GameManager.active_skin)
		_skin_grid.add_child(_make_skin_card(skin_id, is_owned, is_active))

func _make_skin_card(skin_id: String, owned: bool, active: bool) -> Control:
	var skin: Dictionary  = SKINS[skin_id]
	var rarity_col: Color = RARITY_COLORS.get(skin["rarity"], Color.WHITE)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(72.0, 100.0)
	if active:
		card.modulate = Color(1.2, 1.2, 0.65)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Ball colour swatch
	var swatch := ColorRect.new()
	swatch.color = skin["color"] if owned else Color(0.18, 0.18, 0.22)
	swatch.custom_minimum_size   = Vector2(0.0, 46.0)
	swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(swatch)

	# Rarity accent bar
	var accent := ColorRect.new()
	accent.color                = rarity_col if owned else Color(0.3, 0.3, 0.3)
	accent.custom_minimum_size  = Vector2(0.0, 3.0)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(accent)

	# Skin name
	var name_lbl := Label.new()
	name_lbl.text = skin["name"]
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color",
		rarity_col if owned else Color(0.35, 0.35, 0.35))
	vbox.add_child(name_lbl)

	# Status line
	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if active:
		status_lbl.text = "Active ✓"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4))
	elif owned:
		status_lbl.text = "Equip"
		status_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	else:
		status_lbl.text = "Locked"
		status_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	vbox.add_child(status_lbl)

	# Make owned (non-active) cards tappable
	if owned and not active:
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index == MOUSE_BUTTON_LEFT:
				_equip_skin(skin_id)
		)

	return card

func _refresh_themes() -> void:
	for theme_id in _theme_btns:
		var btn: Button  = _theme_btns[theme_id]
		var is_active: bool = (theme_id == GameManager.active_theme)
		btn.text    = THEMES[theme_id]["name"] + ("  ✓" if is_active else "")
		btn.modulate = Color(1.0, 0.85, 0.2) if is_active else Color.WHITE

func _refresh_upgrades() -> void:
	var tier: int   = GameManager.offline_overdrive_tier
	var pcts: Array = [10, 50, 100]
	_offline_desc.text = "Idle production: %d%% of normal.  Current tier: %d / 2." % [
		pcts[tier], tier
	]
	for i in 2:
		var btn: Button = _offline_btns[i]
		if tier > i:
			btn.text     = "Tier %d  ✓" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.55, 0.90, 0.55)
		else:
			var locked: bool = tier != i   # must buy in order
			btn.text     = "Tier %d  →  %d%%   (%.0f G)" % [
				i + 1, int(OFFLINE_TIER_VALUES[i] * 100), OFFLINE_TIER_COSTS[i]
			]
			btn.disabled = locked
			btn.modulate = Color(0.45, 0.45, 0.45) if locked else Color.WHITE

	_token_count_lbl.text = "Held: %d / 10" % GameManager.contract_refresh_tokens

func _refresh_affordability() -> void:
	var gold: float = GameManager.gold

	# Crate
	var can_crate: bool = gold >= CRATE_COST
	_crate_btn.disabled = not can_crate
	_crate_btn.modulate = Color.WHITE if can_crate else Color(0.5, 0.5, 0.5)

	# Token
	var can_token: bool = gold >= TOKEN_COST and GameManager.contract_refresh_tokens < 10
	_token_buy_btn.disabled = not can_token
	_token_buy_btn.modulate = Color.WHITE if can_token else Color(0.5, 0.5, 0.5)
	_token_count_lbl.text   = "Held: %d / 10" % GameManager.contract_refresh_tokens

	# Offline tiers (affordability only; unlock gate handled by _refresh_upgrades)
	var tier: int = GameManager.offline_overdrive_tier
	for i in 2:
		if tier == i:   # only the next purchasable tier matters
			var btn: Button    = _offline_btns[i]
			var affordable: bool = gold >= OFFLINE_TIER_COSTS[i]
			btn.modulate = Color.WHITE if affordable else Color(0.5, 0.5, 0.5)

	# Golden Drone
	if _drone_btn:
		if GameManager.has_golden_drone:
			_drone_btn.text     = "Purchased ✓"
			_drone_btn.disabled = true
			_drone_btn.modulate = Color(0.55, 0.90, 0.55)
		else:
			var can: bool = gold >= GOLDEN_DRONE_COST
			_drone_btn.disabled = not can
			_drone_btn.modulate = Color(1.0, 0.85, 0.2) if can else Color(0.5, 0.5, 0.5)

	# Expanded Silos
	if _silos_btn:
		if GameManager.has_expanded_silos:
			_silos_btn.text     = "Purchased ✓"
			_silos_btn.disabled = true
			_silos_btn.modulate = Color(0.55, 0.90, 0.55)
		else:
			var can: bool = gold >= EXPANDED_SILOS_COST
			_silos_btn.disabled = not can
			_silos_btn.modulate = Color(1.0, 0.85, 0.2) if can else Color(0.5, 0.5, 0.5)

# =============================================================================
# Button handlers
# =============================================================================
func _equip_skin(skin_id: String) -> void:
	GameManager.active_skin = skin_id
	GameManager.emit_signal("skin_changed", skin_id)

func _on_theme_selected(theme_id: String) -> void:
	GameManager.active_theme = theme_id
	GameManager.emit_signal("theme_changed", theme_id)

func _on_buy_token() -> void:
	if GameManager.contract_refresh_tokens >= 10:
		return
	if not GameManager.spend_gold(TOKEN_COST):
		return
	GameManager.contract_refresh_tokens += 1
	_refresh_upgrades()
	_refresh_affordability()

func _on_offline_upgrade(tier_idx: int) -> void:
	# Must buy in order; only the current tier is purchasable
	if GameManager.offline_overdrive_tier != tier_idx:
		return
	if not GameManager.spend_gold(OFFLINE_TIER_COSTS[tier_idx]):
		return
	GameManager.offline_overdrive_tier = tier_idx + 1
	GameManager.offline_multiplier     = OFFLINE_TIER_VALUES[tier_idx]
	_refresh_upgrades()
	_refresh_affordability()

func _on_buy_drone() -> void:
	if GameManager.has_golden_drone:
		return
	if not GameManager.spend_gold(GOLDEN_DRONE_COST):
		return
	GameManager.contract_gold_multiplier *= 1.2
	GameManager.has_golden_drone = true
	# Notify ShippingUI so contract gold labels redraw with the new multiplier
	for i in ContractManager.SLOT_COUNT:
		ContractManager.emit_signal("contract_updated", i)
	_refresh_affordability()

func _on_buy_silos() -> void:
	if GameManager.has_expanded_silos:
		return
	if not GameManager.spend_gold(EXPANDED_SILOS_COST):
		return
	for res in GameManager.storage_caps:
		GameManager.storage_caps[res] = int(GameManager.storage_caps[res] * 1.25)
	GameManager.has_expanded_silos = true
	# ResourceBar.gd re-reads storage_caps on every resource_collected signal,
	# so emit one for each resource to force the cap display to update.
	for res in GameManager.resources:
		GameManager.resource_collected.emit(res, GameManager.resources.get(res, 0))
	_refresh_affordability()

func _on_open_crate() -> void:
	if not GameManager.spend_gold(CRATE_COST):
		return
	_show_unbox_overlay(_weighted_random_skin())

# =============================================================================
# Weighted random skin roll
# =============================================================================
func _weighted_random_skin() -> String:
	var total: int = 0
	for sid in SKINS:
		total += SKINS[sid]["weight"]
	var roll: int = randi() % total
	var acc:  int = 0
	for sid in SKINS:
		acc += SKINS[sid]["weight"]
		if roll < acc:
			return sid
	return "default"

# =============================================================================
# Unbox overlay — CSGO-style scrolling strip
# =============================================================================
# Added to get_parent() (ShopPanel) so it sits above the ScrollContainer and
# is never offset by scroll position.
func _show_unbox_overlay(winner_id: String) -> void:
	if _unbox_overlay and is_instance_valid(_unbox_overlay):
		_unbox_overlay.queue_free()

	# Use ShopPanel's live width so the clip is exactly as wide as the panel
	# minus small margins.  Fall back to viewport width if the panel isn't
	# laid out yet (shouldn't happen on user interaction, but be safe).
	var panel_w: float = get_parent().size.x
	if panel_w <= 0:
		panel_w = get_viewport_rect().size.x
	var clip_w: float = panel_w - 28.0
	var clip_h: float = STRIP_CARD_H + 12.0

	# ---- Root overlay (fills ShopPanel) ------------------------------------
	_unbox_overlay = Control.new()
	_unbox_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unbox_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.0, 0.0, 0.0, 0.90)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unbox_overlay.add_child(bg)

	# ---- VBoxContainer — anchored to the middle band of the overlay --------
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	vbox.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	vbox.set_anchor_and_offset(SIDE_TOP,    0.12, 0.0)
	vbox.set_anchor_and_offset(SIDE_BOTTOM, 0.88, 0.0)
	_unbox_overlay.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Opening Crate..."
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(title)

	# ---- Clip container — masks the scrolling strip ------------------------
	var clip := Control.new()
	clip.clip_contents           = true
	clip.custom_minimum_size     = Vector2(clip_w, clip_h)
	clip.size_flags_horizontal   = Control.SIZE_SHRINK_CENTER
	vbox.add_child(clip)

	# ---- Card strip (absolute child positions, no Container layout) --------
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(STRIP_COUNT * STRIP_STEP, STRIP_CARD_H)
	strip.position            = Vector2(0.0, 4.0)
	strip.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	clip.add_child(strip)

	# Populate: random skins throughout, winner placed at WINNER_INDEX
	for i in STRIP_COUNT:
		var sid: String  = winner_id if i == WINNER_INDEX else _weighted_random_skin()
		var card: Control = _make_strip_card(sid)
		card.position = Vector2(i * STRIP_STEP, 0.0)
		card.size     = Vector2(STRIP_CARD_W, STRIP_CARD_H)
		strip.add_child(card)

	# Centre-line marker — added AFTER strip so it draws on top of cards
	var marker := ColorRect.new()
	marker.color       = Color(1.0, 0.85, 0.2, 0.92)
	marker.position    = Vector2(clip_w * 0.5 - 2.0, 0.0)
	marker.size        = Vector2(4.0, clip_h)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(marker)

	# ---- Result label (hidden until animation ends) ------------------------
	var result_lbl := Label.new()
	result_lbl.visible              = false
	result_lbl.add_theme_font_size_override("font_size", 14)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	result_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(result_lbl)

	# ---- Collect button — fixed size, centred in an alignment row ----------
	var btn_row := HBoxContainer.new()
	btn_row.alignment            = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)

	var collect_btn := Button.new()
	collect_btn.text                = "Collect!"
	collect_btn.visible             = false
	collect_btn.custom_minimum_size = Vector2(140.0, 44.0)
	btn_row.add_child(collect_btn)

	# ---- Determine outcome before the animation plays ----------------------
	var is_duplicate: bool = (winner_id in GameManager.owned_skins) and (winner_id != "default")
	if is_duplicate:
		GameManager.award_gold(DUPLICATE_BONUS_GOLD)
	else:
		if winner_id not in GameManager.owned_skins:
			GameManager.owned_skins.append(winner_id)
		GameManager.active_skin = winner_id
		GameManager.emit_signal("skin_changed", winner_id)

	# ---- Scroll animation --------------------------------------------------
	# Move strip so winner card centre ends up at clip's horizontal centre.
	var winner_center_in_strip: float = WINNER_INDEX * STRIP_STEP + STRIP_CARD_W * 0.5
	var final_x: float = clip_w * 0.5 - winner_center_in_strip   # negative value

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(strip, "position:x", final_x, ANIM_DURATION)
	tween.tween_callback(func():
		title.text = ""
		var skin_name:  String = SKINS[winner_id]["name"]
		var rarity:     String = SKINS[winner_id]["rarity"]
		var rarity_col: Color  = RARITY_COLORS.get(rarity, Color.WHITE)
		if is_duplicate:
			result_lbl.text = "%s  [%s]\nAlready owned — +%.0f Gold bonus!" % [
				skin_name, rarity, DUPLICATE_BONUS_GOLD
			]
		else:
			result_lbl.text = "You got:  %s  [%s]!" % [skin_name, rarity]
		result_lbl.add_theme_color_override("font_color", rarity_col)
		result_lbl.visible  = true
		collect_btn.visible = true

		# Pulse the winning card
		var winner_card: Node = strip.get_child(WINNER_INDEX)
		if is_instance_valid(winner_card):
			var pulse := create_tween()
			pulse.set_loops(4)
			pulse.tween_property(winner_card, "modulate", Color(1.6, 1.6, 0.5), 0.18)
			pulse.tween_property(winner_card, "modulate", Color.WHITE,          0.18)
	)

	collect_btn.pressed.connect(func():
		if is_instance_valid(_unbox_overlay):
			_unbox_overlay.queue_free()
		_unbox_overlay = null
		_refresh_skins()
		_refresh_affordability()
	)

	get_parent().add_child(_unbox_overlay)

# Single card for the scrolling strip — uses explicit position/size set by caller
func _make_strip_card(skin_id: String) -> Control:
	var skin: Dictionary  = SKINS[skin_id]
	var rarity_col: Color = RARITY_COLORS.get(skin["rarity"], Color.WHITE)

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Panel background
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.14, 0.15, 0.19)
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel_bg)

	# Skin colour swatch (top ~60%)
	var swatch := ColorRect.new()
	swatch.color       = skin["color"]
	swatch.position    = Vector2(5.0, 5.0)
	swatch.size        = Vector2(STRIP_CARD_W - 10.0, STRIP_CARD_H * 0.58)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(swatch)

	# Rarity colour bar at bottom edge
	var rarity_bar := ColorRect.new()
	rarity_bar.color       = rarity_col
	rarity_bar.position    = Vector2(0.0, STRIP_CARD_H - 5.0)
	rarity_bar.size        = Vector2(STRIP_CARD_W, 5.0)
	rarity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rarity_bar)

	# Name label
	var name_lbl := Label.new()
	name_lbl.text = skin["name"]
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.position    = Vector2(2.0, STRIP_CARD_H * 0.63)
	name_lbl.size        = Vector2(STRIP_CARD_W - 4.0, 18.0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	return card

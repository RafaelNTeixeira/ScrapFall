# =============================================================================
# TabNavigator.gd
# Attach to: Control node inside UILayer (CanvasLayer).
# No manual anchor setup needed — _ready() positions everything in code.
#
# Scene tree — names must match exactly:
#   TabNavigator (Control)        ← this script
#   ├── TabBar (HBoxContainer)
#   │   ├── BtnWarehouse (Button)
#   │   ├── BtnBoard     (Button)
#   │   ├── BtnShipping  (Button)
#   │   ├── BtnShop      (Button)
#   │   └── BtnSettings  (Button)
#   └── Panels (Control)
#       ├── WarehousePanel (Control) ← WarehouseUI.gd
#       ├── BoardPanel     (Control) ← empty
#       ├── ShippingPanel  (Control) ← placeholder
#       ├── ShopPanel      (Control) ← placeholder
#       └── SettingsPanel  (Control) ← placeholder
# =============================================================================
extends Control

const TAB_BAR_HEIGHT:    float = 64.0
const POWER_METER_HEIGHT: float = 60.0   # leave room at top for PowerMeterUI

enum Tab { WAREHOUSE, BOARD, SHIPPING, SHOP, SETTINGS }

@onready var _tab_bar:  HBoxContainer = $TabBar
@onready var _panels:   Control       = $Panels

@onready var _btn_warehouse: Button = $TabBar/BtnWarehouse
@onready var _btn_board:     Button = $TabBar/BtnBoard
@onready var _btn_shipping:  Button = $TabBar/BtnShipping
@onready var _btn_shop:      Button = $TabBar/BtnShop
@onready var _btn_settings:  Button = $TabBar/BtnSettings

@onready var _panel_warehouse: Control = $Panels/WarehousePanel
@onready var _panel_board:     Control = $Panels/BoardPanel
@onready var _panel_shipping:  Control = $Panels/ShippingPanel
@onready var _panel_shop:      Control = $Panels/ShopPanel
@onready var _panel_settings:  Control = $Panels/SettingsPanel

var _tabs: Dictionary = {}
var _panel_bgs: Array  = []   # ColorRect refs for each non-board panel bg

func _ready() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# --- Size this Control to fill the entire screen ---
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Tab bar: anchored to the bottom ---
	_tab_bar.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	_tab_bar.set_anchor_and_offset(SIDE_RIGHT,  1.0, 0.0)
	_tab_bar.set_anchor_and_offset(SIDE_BOTTOM, 1.0, 0.0)
	_tab_bar.set_anchor_and_offset(SIDE_TOP,    1.0, -TAB_BAR_HEIGHT)
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	# --- Panels: fill the space between PowerMeterUI and the tab bar ---
	_panels.set_anchor_and_offset(SIDE_LEFT,   0.0, 0.0)
	_panels.set_anchor_and_offset(SIDE_RIGHT,  1.0, 0.0)
	_panels.set_anchor_and_offset(SIDE_TOP,    0.0, POWER_METER_HEIGHT)
	_panels.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -TAB_BAR_HEIGHT)
	_panels.mouse_filter  = Control.MOUSE_FILTER_PASS
	# TabNavigator root must also pass input through
	mouse_filter          = Control.MOUSE_FILTER_PASS

	# --- Size each panel to fill Panels container ---
	for panel in [_panel_warehouse, _panel_board, _panel_shipping,
				  _panel_shop, _panel_settings]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# BoardPanel must never block board touches
	_panel_board.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add a solid background to every non-board panel so the board
	# is not visible behind them.
	for panel in [_panel_warehouse, _panel_shipping, _panel_shop, _panel_settings]:
		var bg := ColorRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0.10, 0.11, 0.14, 1.0)   # dark opaque background
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let panel handle input
		panel.add_child(bg)
		panel.move_child(bg, 0)  # push behind any existing children
		_panel_bgs.append(bg)    # store ref for theme updates

	# --- Button labels ---
	_btn_warehouse.text = "Warehouse"
	_btn_board.text     = "Board"
	_btn_shipping.text  = "Shipping"
	_btn_shop.text      = "Shop"
	_btn_settings.text  = "Settings"

	# Expand buttons evenly
	for btn in [_btn_warehouse, _btn_board, _btn_shipping, _btn_shop, _btn_settings]:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size   = Vector2(0.0, TAB_BAR_HEIGHT)

	# --- Map tabs ---
	_tabs = {
		Tab.WAREHOUSE: {&"btn": _btn_warehouse, &"panel": _panel_warehouse},
		Tab.BOARD:     {&"btn": _btn_board,     &"panel": _panel_board    },
		Tab.SHIPPING:  {&"btn": _btn_shipping,  &"panel": _panel_shipping },
		Tab.SHOP:      {&"btn": _btn_shop,      &"panel": _panel_shop     },
		Tab.SETTINGS:  {&"btn": _btn_settings,  &"panel": _panel_settings },
	}

	# --- Connect buttons ---
	_btn_warehouse.pressed.connect(func(): _switch_to(Tab.WAREHOUSE))
	_btn_board.pressed.connect(func():     _switch_to(Tab.BOARD))
	_btn_shipping.pressed.connect(func():  _switch_to(Tab.SHIPPING))
	_btn_shop.pressed.connect(func():      _switch_to(Tab.SHOP))
	_btn_settings.pressed.connect(func():  _switch_to(Tab.SETTINGS))

	# Attach ShippingUI to ShippingPanel
	var shipping_ui: Node = load("res://scripts/ShippingUI.gd").new()
	_panel_shipping.add_child(shipping_ui)

	# Attach ShopUI to ShopPanel
	var shop_ui: Node = load("res://scripts/ShopUI.gd").new()
	_panel_shop.add_child(shop_ui)

	# Attach SettingsUI to SettingsPanel
	var settings_ui: Node = load("res://scripts/SettingsUI.gd").new()
	_panel_settings.add_child(settings_ui)

	# Inject LevelIndicator into BoardPanel
	var level_ind: Node = load("res://scripts/LevelIndicator.gd").new()
	_panel_board.add_child(level_ind)

	# Inject LevelTransitionUI after the current frame so the viewport
	# is fully laid out — this is critical for anchor calculations to work.
	call_deferred("_inject_level_transition_ui")

	# Apply saved theme to panel backgrounds immediately
	GameManager.theme_changed.connect(_on_theme_changed)
	_on_theme_changed(GameManager.active_theme)

	_switch_to(Tab.BOARD)

func _switch_to(tab: Tab) -> void:
	for t in _tabs:
		var entry: Dictionary = _tabs[t]
		var is_active: bool   = (t == tab)
		(entry[&"panel"] as Control).visible = is_active
		(entry[&"btn"]   as Button).modulate = Color.WHITE if is_active else Color(0.55, 0.55, 0.55)

	# Board.gd uses _unhandled_input for ball drops. Control mouse-filters
	# don't block _unhandled_input, so we must disable it directly when the
	# board tab is not visible. This also prevents the PowerMeterUI area from
	# spawning balls while on other tabs.
	var board_active: bool = (tab == Tab.BOARD)
	for board in get_tree().get_nodes_in_group("board"):
		board.set_process_unhandled_input(board_active)

func _inject_level_transition_ui() -> void:
	# LevelTransitionUI now extends Control — add it directly to UILayer
	# (our parent) so it inherits the correct viewport rect for anchors.
	var trans_ui: Node = load("res://scripts/LevelTransitionUI.gd").new()
	get_parent().add_child(trans_ui)

# ---- Theme support ----------------------------------------------------------
const THEME_BG_COLORS: Dictionary = {
	"factory":   Color(0.10, 0.11, 0.14),
	"cyberpunk": Color(0.04, 0.02, 0.12),
	"steampunk": Color(0.14, 0.09, 0.04),
	"zen":       Color(0.04, 0.08, 0.06),
}

func _on_theme_changed(theme_id: String) -> void:
	var col: Color = THEME_BG_COLORS.get(theme_id, THEME_BG_COLORS["factory"])
	for bg in _panel_bgs:
		if is_instance_valid(bg):
			bg.color = col

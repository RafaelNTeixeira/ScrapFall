# =============================================================================
# PowerMeterUI.gd
# Attach to: Control (or PanelContainer) node in a CanvasLayer above the board.
#
# Scene tree expected:
#   PowerMeterUI (Control)
#   ├── FillBar (ProgressBar)       ← main energy fill
#   ├── EnergyLabel (Label)         ← "74 / 100"
#   ├── RegenLabel (Label)          ← "+1/s" or upgraded rate
#   └── NoEnergyFlash (ColorRect)   ← full-screen red flash on failed drop
#
# Colour states (match GDD intent):
#   > 50%  → green    (healthy)
#   20-50% → orange   (warning)
#   < 20%  → red      (critical / flashing)
# =============================================================================
extends Control

# Node references — all optional so the script doesn't crash in partial scenes
@onready var _fill_bar:      ProgressBar = $FillBar      if has_node("FillBar")      else null
@onready var _energy_label:  Label       = $EnergyLabel  if has_node("EnergyLabel")  else null
@onready var _regen_label:   Label       = $RegenLabel   if has_node("RegenLabel")   else null
@onready var _no_energy_fx:  ColorRect   = $NoEnergyFlash if has_node("NoEnergyFlash") else null

# Colour constants
const COLOR_FULL:     Color = Color(0.25, 0.90, 0.45)   # green
const COLOR_MID:      Color = Color(1.00, 0.70, 0.10)   # orange
const COLOR_LOW:      Color = Color(0.95, 0.20, 0.20)   # red

# Threshold fractions
const THRESH_FULL: float = 0.50
const THRESH_LOW:  float = 0.20

var _is_flashing: bool = false

# -----------------------------------------------------------------------------
# _ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	if _fill_bar:
		_fill_bar.max_value = GameManager.POWER_METER_MAX
		_fill_bar.value     = GameManager.power_meter

	if _no_energy_fx:
		_no_energy_fx.color   = Color(1.0, 0.0, 0.0, 0.0)   # transparent by default
		_no_energy_fx.visible = true

	# Signals from GameManager
	GameManager.power_meter_changed.connect(_on_power_changed)
	GameManager.ball_drop_failed.connect(_on_drop_failed)

	_refresh(GameManager.power_meter)

# -----------------------------------------------------------------------------
# Signal handlers
# -----------------------------------------------------------------------------
func _on_power_changed(new_value: float) -> void:
	_refresh(new_value)

func _on_drop_failed() -> void:
	## Red screen-edge flash — tells the player the meter is empty.
	if _is_flashing:
		return
	_is_flashing = true
	if _no_energy_fx:
		var tween: Tween = create_tween()
		tween.tween_property(_no_energy_fx, "color", Color(1.0, 0.0, 0.0, 0.30), 0.08)
		tween.tween_property(_no_energy_fx, "color", Color(1.0, 0.0, 0.0, 0.00), 0.25)
		tween.tween_callback(func(): _is_flashing = false)

# -----------------------------------------------------------------------------
# Visual update
# -----------------------------------------------------------------------------
func _refresh(value: float) -> void:
	var fraction: float = value / GameManager.POWER_METER_MAX

	if _fill_bar:
		_fill_bar.value    = value
		_fill_bar.modulate = _bar_color(fraction)

	if _energy_label:
		_energy_label.text = "%d / %d" % [int(value), int(GameManager.POWER_METER_MAX)]

	if _regen_label:
		_regen_label.text = "+%.1f/s" % GameManager.passive_regen_rate

	## Critical pulsing at low energy — draws attention without being annoying
	if fraction < THRESH_LOW and not _is_flashing:
		_pulse_bar()

func _bar_color(fraction: float) -> Color:
	if fraction > THRESH_FULL:
		return COLOR_FULL
	elif fraction > THRESH_LOW:
		## Lerp orange → green smoothly in the mid range
		var t: float = (fraction - THRESH_LOW) / (THRESH_FULL - THRESH_LOW)
		return COLOR_MID.lerp(COLOR_FULL, t)
	else:
		return COLOR_LOW

func _pulse_bar() -> void:
	if not _fill_bar:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fill_bar, "modulate", Color(1.2, 0.3, 0.3), 0.20)
	tween.tween_property(_fill_bar, "modulate", COLOR_LOW, 0.20)

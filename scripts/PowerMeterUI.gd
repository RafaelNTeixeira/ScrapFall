# =============================================================================
# PowerMeterUI.gd
# Attach to: Control node inside a CanvasLayer (layer = 10)
#
# Scene tree — node names must match exactly:
#   Control                 ← this script
#   ├── FillBar             (ProgressBar)
#   ├── EnergyLabel         (Label)
#   └── RegenLabel          (Label)
# =============================================================================
extends Control

@onready var _fill_bar:     ProgressBar = $FillBar
@onready var _energy_label: Label       = $EnergyLabel
@onready var _regen_label:  Label       = $RegenLabel

const COLOR_FULL: Color = Color(0.25, 0.90, 0.45)
const COLOR_MID:  Color = Color(1.00, 0.70, 0.10)
const COLOR_LOW:  Color = Color(0.95, 0.20, 0.20)

func _ready() -> void:
	_fill_bar.min_value = 0.0
	# max_value uses effective_power_max() so buffs are reflected immediately
	_fill_bar.max_value = GameManager.effective_power_max()

	GameManager.power_meter_changed.connect(_on_power_changed)
	GameManager.ball_drop_failed.connect(_on_drop_failed)

	# Refresh whenever a buff changes the max energy or regen rate
	BuffManager.buffs_changed.connect(_on_buffs_changed)

	_refresh(GameManager.power_meter)

func _process(_delta: float) -> void:
	_fill_bar.value = GameManager.power_meter

func _on_power_changed(new_value: float) -> void:
	_refresh(new_value)

func _on_buffs_changed() -> void:
	# Buff may have changed effective max — update bar range and redraw
	_fill_bar.max_value = GameManager.effective_power_max()
	_refresh(GameManager.power_meter)

func _on_drop_failed() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fill_bar, "modulate", Color(1.5, 0.2, 0.2), 0.07)
	tween.tween_property(_fill_bar, "modulate",
		_bar_color(GameManager.power_meter / GameManager.effective_power_max()), 0.25)

func _refresh(value: float) -> void:
	var max_val: float  = GameManager.effective_power_max()
	var fraction: float = value / max_val

	_fill_bar.max_value  = max_val
	_fill_bar.value      = value
	_fill_bar.modulate   = _bar_color(fraction)

	_energy_label.text = "%d / %d" % [int(value), int(max_val)]
	_regen_label.text  = "+%.1f / sec" % GameManager.passive_regen_rate

func _bar_color(fraction: float) -> Color:
	if fraction > 0.5:
		return COLOR_FULL
	elif fraction > 0.2:
		return COLOR_MID.lerp(COLOR_FULL, (fraction - 0.2) / 0.3)
	else:
		return COLOR_LOW

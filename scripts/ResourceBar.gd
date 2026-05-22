# =============================================================================
# ResourceBar.gd
# Attach to: Control node — one instance per resource (Copper/Steel/Glass/Wood)
#
# Scene tree — names must match exactly:
#   ResourceBar (Control)
#   ├── Background   (ColorRect)
#   ├── FillBar      (ProgressBar)
#   ├── ResourceLabel (Label)   — "Copper"
#   ├── AmountLabel  (Label)    — "247 / 500"
#   └── FullLabel    (Label)    — "FULL!" hidden unless at cap
# =============================================================================
extends Control

@export var resource_type: String = "Copper"

@onready var _fill_bar:       ProgressBar = $FillBar
@onready var _resource_label: Label       = $ResourceLabel
@onready var _amount_label:   Label       = $AmountLabel
@onready var _full_label:     Label       = $FullLabel
@onready var _background:     ColorRect   = $Background

const COLORS: Dictionary = {
	"Copper": Color(0.72, 0.35, 0.10),
	"Steel":  Color(0.50, 0.55, 0.65),
	"Glass":  Color(0.45, 0.75, 0.90),
	"Wood":   Color(0.45, 0.28, 0.10),
}

var _is_blinking: bool = false

func _ready() -> void:
	_resource_label.text = resource_type
	_full_label.visible  = false

	var col: Color = COLORS.get(resource_type, Color.WHITE)
	_fill_bar.modulate = col
	_background.color  = Color(col.r, col.g, col.b, 0.15)

	_fill_bar.min_value = 0
	_fill_bar.max_value = GameManager.storage_caps.get(resource_type, 500)
	_fill_bar.value     = GameManager.resources.get(resource_type, 0)
	_update_amount_label()

	GameManager.resource_collected.connect(_on_resource_collected)
	GameManager.storage_full.connect(_on_storage_full)

func _on_resource_collected(res_type: String, new_total: int) -> void:
	if res_type != resource_type:
		return
	_fill_bar.max_value = GameManager.storage_caps.get(resource_type, 500)
	_fill_bar.value     = new_total
	_update_amount_label()
	_full_label.visible = (new_total >= int(_fill_bar.max_value))
	if _full_label.visible and not _is_blinking:
		_start_blink()

func _on_storage_full(res_type: String) -> void:
	if res_type == resource_type and not _is_blinking:
		_start_blink()

func _update_amount_label() -> void:
	var current: int = GameManager.resources.get(resource_type, 0)
	var cap:     int = GameManager.storage_caps.get(resource_type, 500)
	_amount_label.text = "%d / %d" % [current, cap]

func _start_blink() -> void:
	_is_blinking = true
	var tween: Tween = create_tween().set_loops(6)
	tween.tween_property(_fill_bar, "modulate", Color.RED, 0.18)
	tween.tween_property(_fill_bar, "modulate", COLORS.get(resource_type, Color.WHITE), 0.18)
	tween.finished.connect(func(): _is_blinking = false, CONNECT_ONE_SHOT)

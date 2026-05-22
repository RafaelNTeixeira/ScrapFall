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

func _on_gold_changed(new_total: float) -> void:
	if _gold_label:
		_gold_label.text = "Gold: %d" % int(new_total)

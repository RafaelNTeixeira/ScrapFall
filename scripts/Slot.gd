# =============================================================================
# Slot.gd
# Attach to: Area2D
#
# Scene tree expected:
#   Slot (Area2D)              ← this script
#   ├── CollisionShape2D       ← RectangleShape2D (sized dynamically)
#   ├── Background             ← ColorRect or Sprite2D (slot trough visual)
#   ├── ResourceIcon           ← Sprite2D (icon for the resource type)
#   └── CountLabel             ← Label (shows current stored amount)
#
# There are 5 Slot instances created by Board.gd:
#   [Wood]  [Steel]  [Gold]  [Glass]  [Copper]
#
# Slots detect RigidBody2D balls entering their area and call
# ball.enter_slot(resource_type), which triggers the GameManager.
# =============================================================================
extends Area2D

# -----------------------------------------------------------------------------
# Properties — set by Board.gd after instantiation
# -----------------------------------------------------------------------------
@export var resource_type: String = "Copper"
@export var slot_width:    float  = 60.0
@export var slot_height:   float  = 80.0

# -----------------------------------------------------------------------------
# Node references
# -----------------------------------------------------------------------------
@onready var _col:        CollisionShape2D = $CollisionShape2D
@onready var _background: ColorRect        = $Background   if has_node("Background")   else null
@onready var _icon:       Sprite2D         = $ResourceIcon if has_node("ResourceIcon") else null
@onready var _label:      Label            = $CountLabel   if has_node("CountLabel")   else null

# -----------------------------------------------------------------------------
# Slot colour palette — shown in the slot background trough
# -----------------------------------------------------------------------------
const SLOT_COLORS: Dictionary = {
	"Wood":   Color(0.45, 0.28, 0.10),
	"Steel":  Color(0.50, 0.55, 0.65),
	"Gold":   Color(0.90, 0.72, 0.05),
	"Glass":  Color(0.45, 0.75, 0.90),
	"Copper": Color(0.72, 0.35, 0.10),
}

# -----------------------------------------------------------------------------
# _ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Slots detect balls (layer 2) but live on layer 0 (no physics interaction)
	collision_layer = 0
	collision_mask  = 2

	_apply_size()
	_apply_colour()
	_update_label()

	body_entered.connect(_on_body_entered)

	# Update count label whenever a resource changes
	GameManager.resource_collected.connect(_on_resource_collected)

# -----------------------------------------------------------------------------
# Size the collision shape and background to match slot dimensions
# -----------------------------------------------------------------------------
func _apply_size() -> void:
	if _col:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(slot_width - 4.0, slot_height)   # 2px gap each side
		_col.shape  = shape

	if _background:
		_background.size            = Vector2(slot_width, slot_height)
		_background.position        = Vector2(-slot_width * 0.5, -slot_height * 0.5)
		_background.color           = SLOT_COLORS.get(resource_type, Color.GRAY)
		_background.color.a         = 0.35   # semi-transparent trough

# -----------------------------------------------------------------------------
# Colour helpers
# -----------------------------------------------------------------------------
func _apply_colour() -> void:
	## Tint the whole node so labels and icons inherit the theme colour.
	modulate = SLOT_COLORS.get(resource_type, Color.WHITE)

# -----------------------------------------------------------------------------
# Label
# -----------------------------------------------------------------------------
func _update_label() -> void:
	if not _label:
		return
	_label.text = resource_type   # initial — replaced by count once balls land

func _on_resource_collected(res_type: String, new_total: int) -> void:
	if res_type != resource_type:
		return
	if _label:
		_label.text = "%s\n%d" % [resource_type, new_total]
	_check_storage_full(new_total)

func _check_storage_full(current: int) -> void:
	var cap: int = GameManager.storage_caps.get(resource_type, 500)
	if current >= cap:
		_flash_full_warning()

func _flash_full_warning() -> void:
	## Blink red to signal wasted drops, as specified in the GDD.
	var tween: Tween = create_tween().set_loops(4)
	tween.tween_property(self, "modulate", Color.RED, 0.15)
	tween.tween_property(self, "modulate", SLOT_COLORS.get(resource_type, Color.WHITE), 0.15)

# -----------------------------------------------------------------------------
# Ball detection
# -----------------------------------------------------------------------------
func _on_body_entered(body: Node) -> void:
	if body.has_method("enter_slot"):
		body.enter_slot(resource_type)
		_play_collect_fx()

func _play_collect_fx() -> void:
	## Quick upward pulse to give tactile feedback on collection.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.07)\
		 .set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)\
		 .set_ease(Tween.EASE_IN_OUT)

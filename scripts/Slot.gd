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

# Slot multiplier — rotates every 30 s, staggered so not all slots sync
var _multiplier:       int   = 1
var _mult_timer:       float = 0.0
var _mult_label:       Label = null
const MULT_INTERVAL:   float = 30.0
# Weighted roll: 60 % ×1, 30 % ×2, 10 % ×3
const MULT_WEIGHTS:    Array = [6, 3, 1]

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
	GameManager.resource_collected.connect(_on_resource_collected)

	# Multiplier label — sits above the slot, built in code
	_mult_label = Label.new()
	_mult_label.add_theme_font_size_override("font_size", 14)
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mult_label.size = Vector2(slot_width, 22.0)
	_mult_label.position = Vector2(-slot_width * 0.5, -slot_height * 0.5 - 24.0)
	add_child(_mult_label)

	# Stagger first rotation so slots don't all switch at the same time
	_mult_timer = randf_range(5.0, MULT_INTERVAL)
	_update_mult_label()

# -----------------------------------------------------------------------------
# Size the collision shape and background to match slot dimensions
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_mult_timer -= delta
	if _mult_timer <= 0.0:
		_rotate_multiplier()
		_mult_timer = MULT_INTERVAL

func _rotate_multiplier() -> void:
	var roll: int = randi() % 10
	var acc:  int = 0
	var new_mult: int = 1
	for i in MULT_WEIGHTS.size():
		acc += MULT_WEIGHTS[i]
		if roll < acc:
			new_mult = i + 1
			break
	_multiplier = new_mult
	_update_mult_label()
	if _multiplier > 1:
		_flash_mult_label()

func _update_mult_label() -> void:
	if not _mult_label:
		return
	if _multiplier == 1:
		_mult_label.text = ""
	else:
		_mult_label.text = "×%d" % _multiplier
		_mult_label.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.1) if _multiplier == 2 else Color(1.0, 0.45, 0.1))

func _flash_mult_label() -> void:
	if not _mult_label:
		return
	var tween := create_tween()
	tween.tween_property(_mult_label, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(_mult_label, "scale", Vector2(1.0, 1.0), 0.15)

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
		# Bonus collections for ×2 / ×3 multiplier
		for _i in (_multiplier - 1):
			GameManager.collect_resource(resource_type, 1)
		_play_collect_fx()
		if _multiplier > 1:
			_flash_mult_label()

func _play_collect_fx() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.07)\
		 .set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)\
		 .set_ease(Tween.EASE_IN_OUT)
	AudioManager.play(AudioManager.sfx_slot_collect)

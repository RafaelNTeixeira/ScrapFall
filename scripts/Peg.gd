# =============================================================================
# Peg.gd  — StaticBody2D
# =============================================================================
extends StaticBody2D
class_name Peg

signal energy_peg_hit()
signal split_ball_requested(origin_pos: Vector2, original_velocity: Vector2)

enum PegType { NORMAL, ENERGY, SPLITTER }

@export var peg_type: PegType = PegType.NORMAL
var peg_index: Vector2i = Vector2i.ZERO

const HIT_COOLDOWN: float = 0.18
var _hit_cooldown_timer: float = 0.0
var _balls_hit: Array = []

var _highlight_tween: Tween = null
var _is_highlighted:  bool  = false

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 1
	collision_mask  = 0
	_apply_visuals()
	var hit_area: Area2D = $HitArea if has_node("HitArea") else _create_hit_area()
	hit_area.body_entered.connect(_on_ball_entered)

func _create_hit_area() -> Area2D:
	var area  := Area2D.new()
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius         = 13.0
	col.shape            = shape
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask  = 2
	area.name            = "HitArea"
	add_child(area)
	return area

func _process(delta: float) -> void:
	if _hit_cooldown_timer > 0.0:
		_hit_cooldown_timer -= delta
		if _hit_cooldown_timer <= 0.0:
			_hit_cooldown_timer = 0.0
			_balls_hit.clear()

func _on_ball_entered(body: Node) -> void:
	if not body.has_method("enter_slot"):
		return
	if body in _balls_hit:
		return
	_balls_hit.append(body)
	_hit_cooldown_timer = HIT_COOLDOWN
	_trigger_hit_effect()
	_trigger_type_effect(body)

func _trigger_hit_effect() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.06).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0,  1.0),  0.12).set_ease(Tween.EASE_IN_OUT)

func _trigger_type_effect(ball: RigidBody2D) -> void:
	match peg_type:
		PegType.ENERGY:
			emit_signal("energy_peg_hit")
			_flash_color(Color(1.0, 0.95, 0.3))
		PegType.SPLITTER:
			emit_signal("split_ball_requested", position, ball.linear_velocity)
			ball.on_split_event()
			_flash_color(Color(0.4, 0.85, 1.0))
		PegType.NORMAL:
			_flash_color(Color(1.1, 1.1, 1.1))

func _flash_color(target: Color) -> void:
	if _is_highlighted:
		return  # don't interrupt highlight animation with a hit flash
	var original: Color = _sprite.modulate
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", target,   0.05)
	tween.tween_property(_sprite, "modulate", original, 0.15)

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func set_peg_type(new_type: PegType) -> void:
	peg_type = new_type
	set_highlight(false)
	_apply_visuals()

func _apply_visuals() -> void:
	if not is_node_ready() or not has_node("Sprite2D"):
		return
	_sprite.modulate = _base_color()

func _base_color() -> Color:
	match peg_type:
		PegType.NORMAL:   return Color(0.85, 0.85, 0.85)
		PegType.ENERGY:   return Color(1.0,  0.82, 0.1)
		PegType.SPLITTER: return Color(0.35, 0.80, 1.0)
	return Color.WHITE

# -----------------------------------------------------------------------------
# Highlight — pulsing glow used during upgrade placement mode
# -----------------------------------------------------------------------------
func set_highlight(active: bool) -> void:
	if active == _is_highlighted:
		return
	_is_highlighted = active
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	if active:
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 0.5), 0.35)
		_highlight_tween.tween_property(_sprite, "modulate", _base_color(),          0.35)
	else:
		_sprite.modulate = _base_color()

# -----------------------------------------------------------------------------
# Eligibility helpers
# -----------------------------------------------------------------------------
func is_gate_eligible() -> bool:
	return peg_type == PegType.NORMAL

## Only middle rows are valid for the Splitter so balls have room to diverge.
## Row range 3–8 (inclusive) out of 0–11.
func is_splitter_eligible() -> bool:
	return peg_type == PegType.NORMAL and peg_index.y >= 3 and peg_index.y <= 8

func mark_as_gate_anchor(active: bool) -> void:
	if active:
		set_highlight(false)
		if _highlight_tween:
			_highlight_tween.kill()
			_highlight_tween = null
		_sprite.modulate = Color(1.0, 0.5, 0.0)
	else:
		_apply_visuals()

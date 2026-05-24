# =============================================================================
# MovingPeg.gd — StaticBody2D
# Oscillates horizontally. Setting position in _physics_process lets Godot
# calculate an implied velocity so balls deflect correctly off the moving surface.
# =============================================================================
extends StaticBody2D

var move_range: float = 80.0   # total side-to-side distance
var move_speed: float = 45.0   # oscillation speed (higher = faster)
var _origin:    Vector2
var _time:      float = randf_range(0.0, TAU)   # random phase so not all sync

func _ready() -> void:
	_origin        = global_position
	collision_layer = 1
	collision_mask  = 0
	_build_visual()
	# Wire hit detection same as normal pegs
	var area  := Area2D.new()
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius         = 13.0
	col.shape            = shape
	area.collision_layer = 0
	area.collision_mask  = 2
	area.monitoring      = true
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_ball_hit)

func _build_visual() -> void:
	var rect := ColorRect.new()
	rect.size     = Vector2(22.0, 22.0)
	rect.position = Vector2(-11.0, -11.0)
	rect.color    = Color(1.0, 0.6, 0.1)   # orange — visually distinct
	add_child(rect)
	var col_shape := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius  = 10.0
	col_shape.shape = circle
	add_child(col_shape)

func _physics_process(delta: float) -> void:
	_time          += delta * (move_speed / 50.0)
	global_position = Vector2(
		_origin.x + sin(_time) * move_range * 0.5,
		_origin.y
	)

func _on_ball_hit(_body: Node) -> void:
	# Scale pulse on hit
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.06)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)

# =============================================================================
# BlackHole.gd — Area2D
# Destroys any ball that enters its area. Uses Ball.enter_slot("void") so
# Ball._remove() fires cleanly and Board.active_balls is updated via signal.
# =============================================================================
extends Area2D

var _time: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2
	monitoring      = true
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Layered circles for a "void" look
	for i in 3:
		var ring     := ColorRect.new()
		var size_val := 32.0 - i * 8.0
		ring.size     = Vector2(size_val, size_val)
		ring.position = Vector2(-size_val * 0.5, -size_val * 0.5)
		ring.color    = Color(0.0, 0.0, 0.0, 1.0 - i * 0.2)
		add_child(ring)
	# Red glow rim
	var glow     := ColorRect.new()
	glow.size     = Vector2(36.0, 36.0)
	glow.position = Vector2(-18.0, -18.0)
	glow.color    = Color(0.6, 0.0, 0.0, 0.5)
	move_child(glow, 0)
	# Collision
	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape    = shape
	add_child(col)

func _process(delta: float) -> void:
	_time  += delta
	# Pulsing red glow
	var pulse: float = (sin(_time * 4.0) + 1.0) * 0.5
	modulate = Color(1.0 + pulse * 0.3, 0.5 + pulse * 0.2, 0.5 + pulse * 0.2)

func _on_body_entered(body: Node) -> void:
	if not body.has_method("enter_slot"):
		return
	# "void" is not a real resource — GameManager.collect_resource ignores it,
	# ball simply gets removed. This keeps Board.active_balls consistent.
	body.enter_slot("void")
	# Flash absorption effect
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

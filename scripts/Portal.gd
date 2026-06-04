# =============================================================================
# Portal.gd — Area2D
# Spawned in pairs by Board.gd. Ball enters one, exits from the other.
# Board sets `partner` after spawning both.
# Uses PhysicsServer2D to teleport RigidBody2D reliably mid-physics-step.
# =============================================================================
extends Area2D

const IS_PORTAL: bool = true   # used by Board to identify portals reliably

var partner: Node  = null
var pair_id: int   = 0
var _time:   float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2   # detects balls (layer 2)
	monitoring      = true

	var col   := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape    = shape
	add_child(col)

	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	var outer := ColorRect.new()
	outer.size     = Vector2(32.0, 32.0)
	outer.position = Vector2(-16.0, -16.0)
	outer.color    = _pick_color().darkened(0.4)
	add_child(outer)

	var inner := ColorRect.new()
	inner.size     = Vector2(18.0, 18.0)
	inner.position = Vector2(-9.0, -9.0)
	inner.color    = _pick_color()
	add_child(inner)

func _pick_color() -> Color:
	match pair_id % 4:
		0: return Color(0.4, 0.2, 1.0)
		1: return Color(0.2, 0.9, 0.5)
		2: return Color(1.0, 0.5, 0.1)
		_: return Color(1.0, 0.2, 0.5)

func _process(delta: float) -> void:
	_time += delta
	var pulse: float = (sin(_time * 3.0) + 1.0) * 0.5
	modulate = Color(1.0 + pulse * 0.4, 1.0 + pulse * 0.4, 1.0 + pulse * 0.4)

func _on_body_entered(body: Node) -> void:
	if partner == null:
		return
	if not body.has_method("enter_slot"):
		return
	if body.get_meta("portal_cooldown", false):
		return

	body.set_meta("portal_cooldown", true)

	AudioManager.play(AudioManager.sfx_portal)

	# PhysicsServer2D is the ONLY reliable way to teleport a RigidBody2D.
	# Setting global_position directly or via set_deferred gets overridden
	# by the physics engine in the same step.
	var target: Vector2 = partner.global_position + Vector2(0.0, 20.0)
	PhysicsServer2D.body_set_state(
		body.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		Transform2D(0.0, target)
	)

	if GameManager.portal_energy_bonus > 0.0:
		GameManager._add_power(GameManager.portal_energy_bonus)

	# Release cooldown after 0.4 s so the ball can use portals again
	get_tree().create_timer(0.4).timeout.connect(
		func():
			if is_instance_valid(body):
				body.set_meta("portal_cooldown", false),
		CONNECT_ONE_SHOT
	)

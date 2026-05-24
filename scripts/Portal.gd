# =============================================================================
# Portal.gd — Area2D
# Spawned in pairs by Board.gd. Ball enters one, exits from the other.
# Board sets `partner` after spawning both.
# =============================================================================
extends Area2D

var partner:  Node  = null
var pair_id:  int   = 0
var _color_a: Color = Color(0.4, 0.2, 1.0)   # purple
var _color_b: Color = Color(0.2, 0.8, 1.0)   # cyan
var _time:    float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask  = 2
	monitoring      = true
	body_entered.connect(_on_body_entered)
	_build_visual()

func _build_visual() -> void:
	# Outer ring
	var outer := ColorRect.new()
	outer.size     = Vector2(28.0, 28.0)
	outer.position = Vector2(-14.0, -14.0)
	outer.color    = _pick_color().darkened(0.3)
	add_child(outer)
	# Inner core
	var inner := ColorRect.new()
	inner.size     = Vector2(16.0, 16.0)
	inner.position = Vector2(-8.0, -8.0)
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
	if partner == null or not body.has_method("enter_slot"):
		return
	# Cooldown prevents infinite bounce between portals
	if body.get_meta("portal_cooldown", false):
		return
	body.set_meta("portal_cooldown", true)
	body.global_position = partner.global_position + Vector2(0.0, 8.0)
	# Award portal energy bonus if buff is active
	if GameManager.portal_energy_bonus > 0.0:
		GameManager._add_power(GameManager.portal_energy_bonus)
	# Clear cooldown after a short delay
	get_tree().create_timer(0.4).timeout.connect(
		func():
			if is_instance_valid(body):
				body.set_meta("portal_cooldown", false),
		CONNECT_ONE_SHOT
	)

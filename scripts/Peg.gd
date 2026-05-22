class_name Peg
# =============================================================================
# Peg.gd
# Attach to: StaticBody2D
#
# Scene tree expected:
#   Peg (StaticBody2D)           ← this script
#   ├── Sprite2D                 ← visual (colour tinted by type)
#   ├── CollisionShape2D         ← CircleShape2D, radius ≈ 10
#   ├── HitParticles (optional)  ← GPUParticles2D, one-shot on hit
#   └── GlowLight (optional)     ← PointLight2D for Energy/Splitter pegs
#
# Peg Types:
#   NORMAL   — just bounces balls, no side-effect
#   ENERGY   — awards +8 energy to the power meter on hit
#   SPLITTER — requests a second ball from Board on first hit per ball
#
# The Splitter and Energy pegs are ONE-OF upgrades purchased with resources.
# Board.gd sets peg_type via set_peg_type() after the player buys the upgrade
# and taps the peg they want to upgrade.
# =============================================================================
extends StaticBody2D

# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
## Emitted when this ENERGY peg is struck by a ball.
signal energy_peg_hit()

## Emitted when this SPLITTER peg is struck — Board spawns the second ball.
signal split_ball_requested(origin_pos: Vector2, original_velocity: Vector2)

# -----------------------------------------------------------------------------
# Peg type
# -----------------------------------------------------------------------------
enum PegType { NORMAL, ENERGY, SPLITTER }

@export var peg_type: PegType = PegType.NORMAL

## Grid coordinate set by Board during generation — useful for Gate logic (Ph4)
var peg_index: Vector2i = Vector2i.ZERO

# -----------------------------------------------------------------------------
# Hit cooldown — prevents one ball triggering the peg 20 times in one bounce
# -----------------------------------------------------------------------------
const HIT_COOLDOWN: float = 0.18   # seconds
var _hit_cooldown_timer: float = 0.0

# Tracks which balls have already triggered this peg's special effect
# so a single ball can't farm the same Energy peg repeatedly.
var _balls_hit: Array = []

# -----------------------------------------------------------------------------
# Node references
# -----------------------------------------------------------------------------
@onready var _sprite: Sprite2D = $Sprite2D

# -----------------------------------------------------------------------------
# _ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Pegs live on layer 1; balls are on layer 2 and mask layer 1
	collision_layer = 1
	collision_mask  = 0

	_apply_visuals()

	# Connect our own body_entered to detect ball hits
	# Requires "Monitoring" on any Area2D child — OR we use the Area2D
	# approach below: add a slightly larger Area2D child to detect balls.
	# If you prefer pure collision signals, use a child Area2D named HitArea.
	var hit_area: Area2D = $HitArea if has_node("HitArea") else _create_hit_area()
	hit_area.body_entered.connect(_on_ball_entered)

func _create_hit_area() -> Area2D:
	## Fallback: programmatically create a hit-detection Area2D
	## if the scene doesn't have one pre-placed.
	var area:  Area2D         = Area2D.new()
	var col:   CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D  = CircleShape2D.new()
	shape.radius    = 13.0     # slightly larger than the visual peg
	col.shape       = shape
	area.add_child(col)
	area.collision_layer = 0
	area.collision_mask  = 2   # detect balls (layer 2)
	area.name = "HitArea"
	add_child(area)
	return area

# -----------------------------------------------------------------------------
# _process
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _hit_cooldown_timer > 0.0:
		_hit_cooldown_timer -= delta
		if _hit_cooldown_timer <= 0.0:
			_hit_cooldown_timer = 0.0
			_balls_hit.clear()    # reset per-ball tracking after cooldown

# -----------------------------------------------------------------------------
# Ball hit detection
# -----------------------------------------------------------------------------
func _on_ball_entered(body: Node) -> void:
	# Only react to Ball nodes
	if not body.has_method("enter_slot"):
		return
	# Per-ball cooldown check
	if body in _balls_hit:
		return
	_balls_hit.append(body)
	_hit_cooldown_timer = HIT_COOLDOWN

	_trigger_hit_effect()
	_trigger_type_effect(body)

func _trigger_hit_effect() -> void:
	## Satisfying scale-pulse on every hit, regardless of type.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.35, 1.35), 0.06)\
		 .set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)\
		 .set_ease(Tween.EASE_IN_OUT)

func _trigger_type_effect(ball: RigidBody2D) -> void:
	match peg_type:
		PegType.ENERGY:
			emit_signal("energy_peg_hit")
			_flash_color(Color(1.0, 0.95, 0.3))   # golden flash
		PegType.SPLITTER:
			emit_signal("split_ball_requested", position, ball.linear_velocity)
			ball.on_split_event()
			_flash_color(Color(0.4, 0.85, 1.0))    # cyan flash
		PegType.NORMAL:
			_flash_color(Color(1.1, 1.1, 1.1))     # subtle white flash

func _flash_color(target: Color) -> void:
	var original: Color = _sprite.modulate
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate", target, 0.05)
	tween.tween_property(_sprite, "modulate", original, 0.15)

# -----------------------------------------------------------------------------
# Public API — called by the upgrade system (Phase 4)
# -----------------------------------------------------------------------------
func set_peg_type(new_type: PegType) -> void:
	peg_type = new_type
	_apply_visuals()

func _apply_visuals() -> void:
	if not is_node_ready() or not has_node("Sprite2D"):
		return
	match peg_type:
		PegType.NORMAL:
			_sprite.modulate = Color(0.85, 0.85, 0.85)  # grey metal
		PegType.ENERGY:
			_sprite.modulate = Color(1.0,  0.82, 0.1)   # warm gold
		PegType.SPLITTER:
			_sprite.modulate = Color(0.35, 0.80, 1.0)   # cool blue

# -----------------------------------------------------------------------------
# Gate anchor helpers (Phase 4)
# -----------------------------------------------------------------------------
## Returns true if this peg can participate in a Gate connection.
func is_gate_eligible() -> bool:
	return peg_type == PegType.NORMAL

## Called by GateManager to mark this peg as part of an active Gate.
func mark_as_gate_anchor(active: bool) -> void:
	if active:
		_sprite.modulate = Color(1.0, 0.5, 0.0)   # orange = gate anchor
	else:
		_apply_visuals()

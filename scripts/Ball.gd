# =============================================================================
# Ball.gd
# Attach to: RigidBody2D
#
# Scene tree expected:
#   Ball (RigidBody2D)          ← this script
#   ├── Sprite2D                ← visual (swap texture per skin)
#   ├── CollisionShape2D        ← CircleShape2D, radius = BALL_RADIUS
#   └── TrailParticles          ← GPUParticles2D (optional cosmetic)
#
# Physics feel: "Realistic/Heavy" — slow, satisfying bounces.
#   • High mass + moderate gravity = weighty descent
#   • Low restitution = pegs absorb most impact, no crazy ricochets
#   • Small linear damping = slight air resistance
#   • Random horizontal nudge on spawn = no two drops are identical
# =============================================================================
extends RigidBody2D

signal ball_removed(ball: RigidBody2D)

# -----------------------------------------------------------------------------
# Physics constants — tune here, nowhere else
# -----------------------------------------------------------------------------
const BALL_MASS:        float = 2.5
const BALL_RADIUS:      float = 12.0
const GRAVITY_SCALE_V:  float = 1.85    # heavier than default 1.0
const BOUNCE:           float = 0.28    # low = thuds, high = pinball
const BALL_FRICTION:    float = 0.45    # rolling friction against pegs
const LINEAR_DAMP_V:    float = 0.25    # tiny air-resistance drag
const MAX_SPEED:        float = 820.0   # prevents tunnelling through thin pegs

# Ball skin → modulate colour. Kept here so Ball is self-contained.
# Must stay in sync with ShopUI.SKINS colour values.
const SKIN_COLORS: Dictionary = {
	"default":     Color(0.72, 0.72, 0.72),
	"copper_ball": Color(0.72, 0.45, 0.20),
	"steel_ball":  Color(0.75, 0.78, 0.88),
	"timber":      Color(0.60, 0.40, 0.20),
	"crystal":     Color(0.50, 0.88, 1.00),
	"neon_blue":   Color(0.15, 0.45, 1.00),
	"toxic":       Color(0.20, 1.00, 0.30),
	"lava":        Color(1.00, 0.22, 0.05),
	"void":        Color(0.50, 0.00, 1.00),
	"arctic":      Color(0.75, 0.95, 1.00),
	"solar_gold":  Color(1.00, 0.85, 0.00),
	"obsidian":    Color(0.15, 0.05, 0.25),
	"prism":       Color(1.00, 0.45, 0.85),
}
const SPAWN_NUDGE_MIN:  float = -45.0
const SPAWN_NUDGE_MAX:  float =  45.0
const SPAWN_V_SPEED:    float =  60.0   # small downward push to start movement

# Safety: forcibly remove a ball that gets stuck or falls off-screen
const MAX_LIFETIME_SEC: float = 18.0

# -----------------------------------------------------------------------------
# Node references (set in _ready; $-paths match the scene tree above)
# -----------------------------------------------------------------------------
@onready var _sprite:   Sprite2D       = $Sprite2D
@onready var _col:      CollisionShape2D = $CollisionShape2D

var _lifetime: float = 0.0
var _slot_entered: bool = false   # prevents double-counting on fast entry

# -----------------------------------------------------------------------------
# _ready — apply physics material and initial velocity
# -----------------------------------------------------------------------------
func _ready() -> void:
	mass           = BALL_MASS
	gravity_scale  = GRAVITY_SCALE_V
	linear_damp    = LINEAR_DAMP_V
	
	# PhysicsMaterial controls bounce and friction per-body
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.bounce    = BOUNCE
	mat.friction  = BALL_FRICTION
	physics_material_override = mat

	# Collision layer: layer 2 = balls; mask: layer 1 = pegs + walls + slots
	collision_layer = 2
	collision_mask  = 1

	# Apply initial velocity (may be overridden by split-ball meta)
	var init_vel: Vector2 = get_meta("initial_velocity", Vector2.ZERO)
	if init_vel != Vector2.ZERO:
		linear_velocity = init_vel
	else:
		linear_velocity = Vector2(
			randf_range(SPAWN_NUDGE_MIN, SPAWN_NUDGE_MAX),
			SPAWN_V_SPEED
		)

	# Tint the sprite to match the active skin
	_sprite.modulate = SKIN_COLORS.get(GameManager.active_skin, Color.WHITE)

# -----------------------------------------------------------------------------
# _physics_process — lifetime guard + speed cap
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_lifetime += delta

	# Safety removal
	if _lifetime > MAX_LIFETIME_SEC:
		_remove()
		return

	# Clamp speed to prevent tunnelling through thin geometry
	var spd: float = linear_velocity.length()
	if spd > MAX_SPEED:
		linear_velocity = linear_velocity / spd * MAX_SPEED

# -----------------------------------------------------------------------------
# Called by Slot.gd when the ball enters a catching area
# -----------------------------------------------------------------------------
func enter_slot(resource_type: String) -> void:
	if _slot_entered:
		return    # already being processed
	_slot_entered = true

	if resource_type == "Gold":
		GameManager.award_gold(1.0)
	else:
		GameManager.collect_resource(resource_type)

	# TODO: spawn a small resource-icon particle at current position
	_remove()

# -----------------------------------------------------------------------------
# Called by Peg.gd when a SPLITTER peg is hit — peg handles spawning
# the extra ball via Board; we just continue as the original ball.
# Nothing special needed here, but the hook exists for future VFX.
# -----------------------------------------------------------------------------
func on_split_event() -> void:
	pass  # hook for future visual effect (e.g., flash white briefly)

# -----------------------------------------------------------------------------
# Internal removal
# -----------------------------------------------------------------------------
func _remove() -> void:
	set_physics_process(false)
	emit_signal("ball_removed", self)
	queue_free()

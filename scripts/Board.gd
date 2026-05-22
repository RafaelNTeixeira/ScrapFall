# =============================================================================
# Board.gd
# Attach to: Node2D named "Board" — the root of your Plinko board scene.
#
# Responsibilities:
#   • Procedurally generate the 9×12 staggered peg grid
#   • Detect taps and spawn balls at the correct drop position
#   • Generate the 5 resource collection slots at the bottom
#   • Handle split-ball spawning when the Splitter peg is hit
#   • Own all walls (left, right, bottom floor) as StaticBody2D
# =============================================================================
extends Node2D

# -----------------------------------------------------------------------------
# Grid constants — tweak PEG_SPACING_* to resize the whole board uniformly
# -----------------------------------------------------------------------------
const ROWS:        int   = 12
const COLS_ODD:    int   = 9    # rows 0, 2, 4 … (9 pegs)
const COLS_EVEN:   int   = 8    # rows 1, 3, 5 … (8 pegs, offset)

const PEG_SPACING_X: float = 62.0   # horizontal distance between peg centres
const PEG_SPACING_Y: float = 58.0   # vertical distance between rows

# Padding from the very top of the board area to row-0
const BOARD_TOP_PADDING: float = 100.0

# Slot geometry
const SLOT_COUNT:      int   = 5
const SLOT_HEIGHT:     float = 80.0

# -----------------------------------------------------------------------------
# Exported scenes — drag these into the Inspector on the Board node
# -----------------------------------------------------------------------------
@export var peg_scene:  PackedScene   ## res://scenes/Peg.tscn
@export var ball_scene: PackedScene   ## res://scenes/Ball.tscn
@export var slot_scene: PackedScene   ## res://scenes/Slot.tscn

# -----------------------------------------------------------------------------
# Runtime state
# -----------------------------------------------------------------------------
## 2-D grid of Peg nodes: peg_grid[row][col]
var peg_grid: Array = []

## Flat list for gate-selection logic (Phase 4)
var all_pegs: Array = []

## Active balls currently on the board
var active_balls: Array = []

## Cached board origin (top-left peg position, centred on viewport)
var board_origin: Vector2

## Slot nodes [Wood, Steel, Gold, Glass, Copper]
var slot_nodes: Array = []

const SLOT_TYPES: Array[String] = ["Wood", "Steel", "Gold", "Glass", "Copper"]

# -----------------------------------------------------------------------------
# Ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	_calculate_board_origin()
	_generate_pegs()
	_generate_slots()
	_generate_walls()

# -----------------------------------------------------------------------------
# Geometry helpers
# -----------------------------------------------------------------------------
func _calculate_board_origin() -> void:
	## Centre the board horizontally on whatever the current viewport width is.
	var board_width: float = (COLS_ODD - 1) * PEG_SPACING_X
	var viewport_width: float = get_viewport_rect().size.x
	board_origin = Vector2(
		(viewport_width - board_width) / 2.0,
		BOARD_TOP_PADDING
	)

## Returns the world position of peg (col, row).
## For even rows the column is offset by half a PEG_SPACING_X.
func peg_world_pos(col: int, row: int) -> Vector2:
	var is_odd_row: bool = (row % 2 == 0)   # row 0 is the "9-peg" row
	var x_offset: float  = 0.0 if is_odd_row else PEG_SPACING_X * 0.5
	return Vector2(
		board_origin.x + x_offset + col * PEG_SPACING_X,
		board_origin.y + row * PEG_SPACING_Y
	)

## Returns the world Y of the top drop line (just above row 0).
func drop_line_y() -> float:
	return board_origin.y - 35.0

## Returns the world Y where balls reach the slots.
func slots_y() -> float:
	return board_origin.y + ROWS * PEG_SPACING_Y + 20.0

# -----------------------------------------------------------------------------
# Peg generation
# -----------------------------------------------------------------------------
func _generate_pegs() -> void:
	peg_grid.clear()
	all_pegs.clear()

	for row in range(ROWS):
		var row_array: Array = []
		var cols: int = COLS_ODD if (row % 2 == 0) else COLS_EVEN

		for col in range(cols):
			var peg = peg_scene.instantiate()
			peg.position    = peg_world_pos(col, row)
			peg.peg_index   = Vector2i(col, row)

			# Wire up the energy-peg signal before adding to tree
			peg.energy_peg_hit.connect(_on_energy_peg_hit)
			peg.split_ball_requested.connect(_on_split_ball_requested)

			add_child(peg)
			row_array.append(peg)
			all_pegs.append(peg)

		peg_grid.append(row_array)

# -----------------------------------------------------------------------------
# Slot generation
# -----------------------------------------------------------------------------
func _generate_slots() -> void:
	slot_nodes.clear()
	var y: float     = slots_y()
	# Distribute 5 slots evenly across the board width
	var board_width: float = (COLS_ODD - 1) * PEG_SPACING_X
	var slot_width:  float = board_width / SLOT_COUNT

	for i in range(SLOT_COUNT):
		var slot = slot_scene.instantiate()
		slot.position       = Vector2(board_origin.x + slot_width * 0.5 + i * slot_width, y)
		slot.resource_type  = SLOT_TYPES[i]
		slot.slot_width     = slot_width
		slot.slot_height    = SLOT_HEIGHT
		add_child(slot)
		slot_nodes.append(slot)

# -----------------------------------------------------------------------------
# Boundary walls (keeps balls inside the board column)
# -----------------------------------------------------------------------------
func _generate_walls() -> void:
	var wall_thickness: float = 20.0

	# Wall spans from above the drop line all the way past the slots.
	# Starting above drop_line_y catches balls that drift sideways immediately.
	var wall_top:    float = drop_line_y() - 40.0
	var wall_bottom: float = slots_y() + SLOT_HEIGHT + wall_thickness
	var wall_height: float = wall_bottom - wall_top
	var wall_mid_y:  float = wall_top + wall_height * 0.5

	# Board left and right X edges
	var board_left:  float = board_origin.x - (0.1 * PEG_SPACING_X)
	var board_right: float = board_origin.x + (COLS_ODD - 0.9) * PEG_SPACING_X

	# Left wall — inner face flush with the board left edge
	_add_wall(
		Vector2(board_left - wall_thickness * 0.5, wall_mid_y),
		Vector2(wall_thickness, wall_height)
	)
	# Right wall — inner face flush with the board right edge
	_add_wall(
		Vector2(board_right + wall_thickness * 0.5, wall_mid_y),
		Vector2(wall_thickness, wall_height)
	)
	# Floor — spans full board width just below the slots
	_add_wall(
		Vector2((board_left + board_right) * 0.5, wall_bottom - wall_thickness * 0.5),
		Vector2(board_right - board_left + wall_thickness * 2.0, wall_thickness)
	)

func _add_wall(pos: Vector2, size: Vector2) -> void:
	var wall:      StaticBody2D     = StaticBody2D.new()
	var col:       CollisionShape2D = CollisionShape2D.new()
	var shape:     RectangleShape2D = RectangleShape2D.new()
	shape.size     = size
	col.shape      = shape
	wall.add_child(col)
	wall.position  = pos
	add_child(wall)

# -----------------------------------------------------------------------------
# Input — tap anywhere to drop a ball (clamped to board X range)
# -----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false
	var tap_x:   float = 0.0

	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		tap_x   = event.position.x
	elif event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		tap_x   = event.position.x

	if pressed:
		_try_drop_ball(tap_x)

## Spawns a ball at the tap X position (clamped inside the board),
## directly above the first row of pegs.
func _try_drop_ball(tap_x: float) -> void:
	if not GameManager.consume_drop_energy():
		# TODO: shake / flash the power meter UI
		return

	var clamped_x: float = clampf(
		tap_x,
		board_origin.x,
		board_origin.x + (COLS_ODD - 1) * PEG_SPACING_X
	)

	_spawn_ball(Vector2(clamped_x, drop_line_y()))

func _spawn_ball(spawn_pos: Vector2, inherit_velocity: Vector2 = Vector2.ZERO) -> void:
	var ball = ball_scene.instantiate()
	ball.position          = spawn_pos
	ball.ball_removed.connect(_on_ball_removed.bind(ball))

	if inherit_velocity != Vector2.ZERO:
		# Give split balls a nudge in the inherited direction
		ball.set_meta("initial_velocity", inherit_velocity)

	add_child(ball)
	active_balls.append(ball)

# -----------------------------------------------------------------------------
# Signal handlers
# -----------------------------------------------------------------------------
func _on_energy_peg_hit() -> void:
	GameManager.award_energy_peg_hit()

## Spawns a second ball when the Splitter peg fires.
func _on_split_ball_requested(origin_pos: Vector2, original_velocity: Vector2) -> void:
	# Mirror horizontal velocity so the two balls diverge
	var split_vel: Vector2 = Vector2(-original_velocity.x * 0.7, original_velocity.y * 0.7)
	_spawn_ball(origin_pos + Vector2(0.0, 5.0), split_vel)

func _on_ball_removed(ball: RigidBody2D) -> void:
	active_balls.erase(ball)

# -----------------------------------------------------------------------------
# Public helpers for Gate system (Phase 4)
# -----------------------------------------------------------------------------
## Returns the Peg node at a given grid coordinate (or null).
func get_peg(col: int, row: int) -> Node2D:
	if row < 0 or row >= peg_grid.size():
		return null
	var row_arr: Array = peg_grid[row]
	if col < 0 or col >= row_arr.size():
		return null
	return row_arr[col]

## Returns the Auto-Dropper drop line Y for placing auto-droppers.
func auto_dropper_y() -> float:
	return drop_line_y()

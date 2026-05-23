# =============================================================================
# AutoDropper.gd
# Attach to: Node2D
#
# Scene tree — no children required, built in code:
#   AutoDropper (Node2D)
#
# The player places an AutoDropper by tapping the top of the board while in
# "place dropper" mode (toggled from the upgrade UI in Phase 4).
# Board.gd calls spawn_auto_dropper(x_pos) to instantiate and position it.
#
# Each AutoDropper:
#   • Drops a ball every DROP_INTERVAL seconds
#   • Does NOT consume energy — fires on its own timer
#   • Stops when the power meter is empty
#   • Is saved/restored as an X position in the save file
# =============================================================================
extends Node2D

# Drop interval in seconds — upgradeable via resources
const DROP_INTERVAL_BASE: float = 5.0
var drop_interval: float = DROP_INTERVAL_BASE

var _timer: float = 0.0
var _board: Node  = null     # set by Board after spawning

# Visual — small mechanical arm indicator at top of board
@onready var _indicator: ColorRect = $Indicator if has_node("Indicator") else _make_indicator()

func _ready() -> void:
	_board = get_parent()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= drop_interval:
		_timer = 0.0
		_drop()

func _drop() -> void:
	if _board == null or not _board.has_method("spawn_ball_free"):
		return
	# Free spawn — auto-droppers don't consume energy per the GDD
	_board.spawn_ball_free(global_position.x)

# -----------------------------------------------------------------------------
# Called by Board when placing this dropper
# -----------------------------------------------------------------------------
func set_board(board: Node) -> void:
	_board = board

func set_drop_interval(interval: float) -> void:
	drop_interval = interval
	_timer = 0.0

# -----------------------------------------------------------------------------
# Visual indicator built in code
# -----------------------------------------------------------------------------
func _make_indicator() -> ColorRect:
	var rect := ColorRect.new()
	rect.size            = Vector2(14.0, 20.0)
	rect.position        = Vector2(-7.0, -20.0)
	rect.color           = Color(1.0, 0.75, 0.1)   # gold colour
	add_child(rect)
	return rect

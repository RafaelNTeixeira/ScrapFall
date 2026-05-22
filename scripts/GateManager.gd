# =============================================================================
# GateManager.gd
# Attach to: Node2D child of Board
#
# Handles gate placement mode:
#   1. UpgradeManager fires placement_mode_started("gate")
#   2. Board highlights tappable pegs and routes taps here
#   3. Player taps 2 pegs → GateManager snaps a ramp between them
#   4. Ramp is a rotated StaticBody2D that deflects balls
#
# Only one gate is allowed (enforced by UpgradeManager's one_time flag).
# =============================================================================
extends Node2D

signal gate_placed()

const GATE_THICKNESS: float = 8.0
const GATE_COLOR:     Color = Color(1.0, 0.60, 0.1)   # orange ramp

var _selected_pegs: Array  = []   # up to 2 Peg nodes
var _gate_body:     Node2D = null
var _is_active:     bool   = false

func _ready() -> void:
	UpgradeManager.placement_mode_started.connect(_on_placement_started)
	UpgradeManager.placement_mode_cancelled.connect(_on_placement_cancelled)

# -----------------------------------------------------------------------------
# Activation
# -----------------------------------------------------------------------------
func _on_placement_started(upgrade_id: String) -> void:
	if upgrade_id != "gate":
		return
	_is_active    = true
	_selected_pegs.clear()
	_highlight_all_pegs(true)

func _on_placement_cancelled() -> void:
	_cancel()

func _cancel() -> void:
	_is_active = false
	_selected_pegs.clear()
	_highlight_all_pegs(false)

# -----------------------------------------------------------------------------
# Called by Board when a peg is tapped during placement mode
# -----------------------------------------------------------------------------
func on_peg_tapped(peg: Node) -> void:
	if not _is_active:
		return
	if peg in _selected_pegs:
		return   # don't select the same peg twice

	_selected_pegs.append(peg)
	peg.mark_as_gate_anchor(true)

	if _selected_pegs.size() == 2:
		_build_gate()

# -----------------------------------------------------------------------------
# Build the gate ramp between two selected pegs
# -----------------------------------------------------------------------------
func _build_gate() -> void:
	var peg_a: Node2D = _selected_pegs[0]
	var peg_b: Node2D = _selected_pegs[1]

	var pos_a: Vector2 = peg_a.global_position
	var pos_b: Vector2 = peg_b.global_position
	var mid:   Vector2 = (pos_a + pos_b) * 0.5
	var diff:  Vector2 = pos_b - pos_a
	var length: float  = diff.length()
	var angle:  float  = diff.angle()

	# StaticBody2D ramp
	var body  := StaticBody2D.new()
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size         = Vector2(length, GATE_THICKNESS)
	col.shape          = shape
	body.rotation      = angle
	body.global_position = mid
	body.collision_layer = 1
	body.collision_mask  = 0

	# Physics material — low friction, slight bounce so balls slide along ramp
	var mat           := PhysicsMaterial.new()
	mat.friction       = 0.1
	mat.bounce         = 0.15
	body.physics_material_override = mat

	# Visual
	var visual         := ColorRect.new()
	visual.size         = Vector2(length, GATE_THICKNESS)
	visual.position     = Vector2(-length * 0.5, -GATE_THICKNESS * 0.5)
	visual.color        = GATE_COLOR
	body.add_child(visual)

	add_child(body)
	_gate_body = body

	# Cleanup
	_highlight_all_pegs(false)
	_is_active = false
	UpgradeManager.confirm_placement("gate")
	emit_signal("gate_placed")

# -----------------------------------------------------------------------------
# Highlight all eligible pegs while in placement mode
# -----------------------------------------------------------------------------
func _highlight_all_pegs(active: bool) -> void:
	var board: Node = get_parent()
	if not board or not board.has_method("get_peg"):
		return
	for peg in board.all_pegs:
		if peg.has_method("mark_as_gate_anchor") and peg.is_gate_eligible():
			peg.mark_as_gate_anchor(active)

# -----------------------------------------------------------------------------
# Serialization — save/restore gate anchor peg indices
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	if _selected_pegs.size() < 2:
		return {}
	return {
		"peg_a": {"col": _selected_pegs[0].peg_index.x, "row": _selected_pegs[0].peg_index.y},
		"peg_b": {"col": _selected_pegs[1].peg_index.x, "row": _selected_pegs[1].peg_index.y},
	}

func restore_from_save(data: Dictionary) -> void:
	if not data.has("peg_a") or not data.has("peg_b"):
		return
	var board: Node = get_parent()
	if board == null:
		return
	var peg_a: Node = board.get_peg(data["peg_a"]["col"], data["peg_a"]["row"])
	var peg_b: Node = board.get_peg(data["peg_b"]["col"], data["peg_b"]["row"])
	if peg_a == null or peg_b == null:
		return
	_selected_pegs = [peg_a, peg_b]
	_is_active     = true
	_build_gate()

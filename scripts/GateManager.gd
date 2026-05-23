# =============================================================================
# GateManager.gd  — Node2D child of Board
#
# Supports two independently purchased gates (gate_1, gate_2).
# Each gate is a rotated StaticBody2D ramp between two ADJACENT pegs.
# Relocation removes the old ramp and re-enters placement mode.
# =============================================================================
extends Node2D

const GATE_THICKNESS:    float  = 10.0
const GATE_COLOR:        Color  = Color(1.0, 0.60, 0.1)
const MAX_ADJACENT_DIST: float  = 95.0   # ~1.5 × PEG_SPACING_X — consecutive only

# Per-gate state
var _gates: Dictionary = {
	"gate_1": { "body": null, "pegs": [] },
	"gate_2": { "body": null, "pegs": [] },
}

var _active_id:     String = ""   # which gate slot is being placed right now
var _selected_pegs: Array  = []
var _is_active:     bool   = false

func _ready() -> void:
	UpgradeManager.placement_mode_started.connect(_on_placement_started)
	UpgradeManager.placement_mode_cancelled.connect(_on_placement_cancelled)

# -----------------------------------------------------------------------------
# Mode activation
# -----------------------------------------------------------------------------
func _on_placement_started(upgrade_id: String) -> void:
	if upgrade_id not in ["gate_1", "gate_2", "relocate_gate_1", "relocate_gate_2"]:
		return

	# Determine which slot
	_active_id = upgrade_id.replace("relocate_", "")

	# For relocation: destroy the existing ramp first
	if upgrade_id.begins_with("relocate_"):
		_destroy_gate(_active_id)

	_is_active = true
	_selected_pegs.clear()
	_highlight_eligible_pegs(true)

func _on_placement_cancelled() -> void:
	_is_active = false
	_selected_pegs.clear()
	_highlight_eligible_pegs(false)

# -----------------------------------------------------------------------------
# Called by Board when a peg is tapped during gate placement
# -----------------------------------------------------------------------------
func on_peg_tapped(peg: Node) -> void:
	if not _is_active:
		return
	if peg in _selected_pegs:
		return

	# First peg — just select and highlight
	if _selected_pegs.is_empty():
		_selected_pegs.append(peg)
		peg.mark_as_gate_anchor(true)
		return

	# Second peg — validate adjacency before accepting
	var dist: float = (peg.global_position - _selected_pegs[0].global_position).length()
	if dist > MAX_ADJACENT_DIST:
		# Too far — flash the first peg red as feedback and reset
		_selected_pegs[0].mark_as_gate_anchor(false)
		_selected_pegs.clear()
		_highlight_eligible_pegs(true)   # re-highlight all
		return

	_selected_pegs.append(peg)
	peg.mark_as_gate_anchor(true)
	_build_gate()

# -----------------------------------------------------------------------------
# Build ramp
# -----------------------------------------------------------------------------
func _build_gate() -> void:
	var peg_a: Node2D = _selected_pegs[0]
	var peg_b: Node2D = _selected_pegs[1]

	var pos_a:  Vector2 = peg_a.global_position
	var pos_b:  Vector2 = peg_b.global_position
	var mid:    Vector2 = (pos_a + pos_b) * 0.5
	var diff:   Vector2 = pos_b - pos_a
	var length: float   = diff.length()
	var angle:  float   = diff.angle()

	var body  := StaticBody2D.new()
	var col   := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size           = Vector2(length + 12.0, GATE_THICKNESS)  # +12 overhangs pegs
	col.shape            = shape
	body.collision_layer = 1
	body.collision_mask  = 0

	var mat           := PhysicsMaterial.new()
	mat.friction       = 0.05
	mat.bounce         = 0.2
	body.physics_material_override = mat

	var visual        := ColorRect.new()
	visual.size        = Vector2(length + 12.0, GATE_THICKNESS)
	visual.position    = Vector2(-(length + 12.0) * 0.5, -GATE_THICKNESS * 0.5)
	visual.color       = GATE_COLOR
	body.add_child(col)
	body.add_child(visual)

	# IMPORTANT: add to scene FIRST, then set global_position and rotation.
	# Setting global_position before add_child has no effect in Godot 4.
	add_child(body)
	body.global_position = mid
	body.rotation        = angle

	_gates[_active_id]["body"] = body
	_gates[_active_id]["pegs"] = _selected_pegs.duplicate()

	_highlight_eligible_pegs(false)
	_is_active = false
	UpgradeManager.confirm_placement(_active_id)

# -----------------------------------------------------------------------------
# Destroy a gate ramp (used for relocation)
# -----------------------------------------------------------------------------
func _destroy_gate(gate_id: String) -> void:
	var body: Node = _gates[gate_id]["body"]
	if body != null and is_instance_valid(body):
		body.queue_free()
	_gates[gate_id]["body"] = null
	# Un-mark old anchor pegs
	for peg in _gates[gate_id]["pegs"]:
		if is_instance_valid(peg):
			peg.mark_as_gate_anchor(false)
	_gates[gate_id]["pegs"].clear()

# -----------------------------------------------------------------------------
# Highlight eligible pegs while in placement mode
# -----------------------------------------------------------------------------
func _highlight_eligible_pegs(active: bool) -> void:
	var board: Node = get_parent()
	if not board or not board.has_method("get_peg"):
		return
	for peg in board.all_pegs:
		if peg.has_method("set_highlight") and peg.is_gate_eligible():
			peg.set_highlight(active)

# -----------------------------------------------------------------------------
# Serialization
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for id in _gates:
		var pegs: Array = _gates[id]["pegs"]
		if pegs.size() == 2:
			data[id] = {
				"peg_a": {"col": pegs[0].peg_index.x, "row": pegs[0].peg_index.y},
				"peg_b": {"col": pegs[1].peg_index.x, "row": pegs[1].peg_index.y},
			}
	return data

func restore_from_save(data: Dictionary) -> void:
	var board: Node = get_parent()
	if board == null:
		return
	for id in data:
		if not _gates.has(id):
			continue
		var d: Dictionary = data[id]
		var peg_a: Node = board.get_peg(d["peg_a"]["col"], d["peg_a"]["row"])
		var peg_b: Node = board.get_peg(d["peg_b"]["col"], d["peg_b"]["row"])
		if peg_a == null or peg_b == null:
			continue
		_active_id     = id
		_selected_pegs = [peg_a, peg_b]
		_is_active     = true
		_build_gate()

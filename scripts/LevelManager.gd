# =============================================================================
# LevelManager.gd — Autoload "LevelManager"
#
# Tracks current level, contract progress toward next level,
# and defines unique board layouts with hazards for each level.
# =============================================================================
extends Node

signal level_changed(new_level: int)
signal progress_changed(contracts_done: int, contracts_needed: int)
signal advance_available(available: bool)
signal show_advance_ui_requested()   # ShippingUI fires this; LevelTransitionUI listens

var current_level:          int = 1
var contracts_this_level:   int = 0

# -----------------------------------------------------------------------------
# Level requirements (scale with level)
# -----------------------------------------------------------------------------
func contracts_required() -> int:
	return 3 + (current_level - 1) * 2   # 3, 5, 7, 9, ...

func gold_required() -> int:
	return 100 * current_level            # 100, 200, 300, ...

func can_advance() -> bool:
	return contracts_this_level >= contracts_required() and GameManager.gold >= gold_required()

# Called by ContractManager when a contract is fulfilled
func on_contract_fulfilled() -> void:
	contracts_this_level += 1
	emit_signal("progress_changed", contracts_this_level, contracts_required())
	emit_signal("advance_available", can_advance())

# -----------------------------------------------------------------------------
# Perform level advance (called AFTER buff is chosen)
# -----------------------------------------------------------------------------
func advance(chosen_buff_id: String) -> void:
	BuffManager.apply_buff(chosen_buff_id)
	current_level          += 1
	contracts_this_level    = 0

	# Reset resources and gold
	for res in GameManager.resources:
		GameManager.resources[res] = 0
		GameManager.emit_signal("resource_collected", res, 0)
	GameManager.gold = 0.0
	GameManager.emit_signal("gold_changed", 0.0)
	GameManager.power_meter = GameManager.effective_power_max()

	# Apply start-of-level buffs (Head Start, Hot Start, etc.)
	BuffManager.apply_level_start_buffs()

	emit_signal("level_changed", current_level)
	emit_signal("progress_changed", 0, contracts_required())
	emit_signal("advance_available", false)

# -----------------------------------------------------------------------------
# Board layout definitions
# Hazard types: "portal", "moving_peg", "black_hole"
# grid_x / grid_y are fractional board-grid coordinates:
#   grid_x 0.0 = left edge peg column, 8.0 = right edge
#   grid_y 0.0 = top row, 11.0 = bottom row
# Portal pairs share the same "pair_id" integer.
# -----------------------------------------------------------------------------
const LAYOUTS: Array = [
	{   # Level 1
		"name": "The Factory Floor",
		"desc": "Standard layout. Learn the ropes.",
		"skip_pegs": [],
		"hazards": [],
	},
	{   # Level 2
		"name": "The Funnel",
		"desc": "Outer columns removed. Precision required.",
		"skip_pegs": [
			[0,2],[8,2],[0,3],[7,3],[0,4],[8,4],
			[0,5],[7,5],[0,6],[8,6],[0,7],[7,7],
		],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":1.5,"grid_y":3.5},
			{"type":"portal","pair_id":0,"grid_x":6.5,"grid_y":7.5},
		],
	},
	{   # Level 3
		"name": "Crossroads",
		"desc": "Moving pegs disrupt every path.",
		"skip_pegs": [
			[2,4],[4,4],[6,4],[1,5],[3,5],[5,5],[7,5],[2,6],[4,6],[6,6],
		],
		"hazards": [
			{"type":"moving_peg","grid_x":2.0,"grid_y":2.0,"range":80.0,"speed":45.0},
			{"type":"moving_peg","grid_x":5.0,"grid_y":5.0,"range":80.0,"speed":55.0},
			{"type":"moving_peg","grid_x":3.0,"grid_y":8.0,"range":60.0,"speed":35.0},
		],
	},
	{   # Level 4
		"name": "Black Mirror",
		"desc": "Void zones consume the careless.",
		"skip_pegs": [
			[3,3],[5,3],[4,4],[3,7],[5,7],[4,8],
		],
		"hazards": [
			{"type":"black_hole","grid_x":4.0,"grid_y":3.5},
			{"type":"black_hole","grid_x":2.0,"grid_y":7.0},
			{"type":"black_hole","grid_x":6.0,"grid_y":7.0},
			{"type":"portal","pair_id":0,"grid_x":0.5,"grid_y":5.0},
			{"type":"portal","pair_id":0,"grid_x":7.5,"grid_y":5.0},
		],
	},
	{   # Level 5
		"name": "Wormhole Alley",
		"desc": "Nothing goes where you expect.",
		"skip_pegs": [
			[1,1],[3,1],[5,1],[7,1],
			[0,3],[2,3],[4,3],[6,3],[8,3],
			[1,6],[3,6],[5,6],[7,6],
			[0,9],[2,9],[4,9],[6,9],[8,9],
		],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":1.0,"grid_y":2.0},
			{"type":"portal","pair_id":0,"grid_x":7.0,"grid_y":8.0},
			{"type":"portal","pair_id":1,"grid_x":4.0,"grid_y":1.0},
			{"type":"portal","pair_id":1,"grid_x":4.0,"grid_y":9.0},
			{"type":"moving_peg","grid_x":2.0,"grid_y":5.0,"range":100.0,"speed":50.0},
			{"type":"moving_peg","grid_x":6.0,"grid_y":5.0,"range":100.0,"speed":50.0},
			{"type":"black_hole","grid_x":4.0,"grid_y":5.5},
		],
	},
	{   # Level 6+ (cycles with escalating chaos)
		"name": "Maximum Chaos",
		"desc": "Pure entropy. Survive.",
		"skip_pegs": [
			[0,1],[2,1],[4,1],[6,1],[8,1],
			[1,3],[3,3],[5,3],[7,3],
			[0,5],[2,5],[4,5],[6,5],[8,5],
			[1,7],[3,7],[5,7],[7,7],
			[0,9],[2,9],[4,9],[6,9],[8,9],
		],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":0.5,"grid_y":2.0},
			{"type":"portal","pair_id":0,"grid_x":7.5,"grid_y":6.0},
			{"type":"portal","pair_id":1,"grid_x":4.0,"grid_y":0.5},
			{"type":"portal","pair_id":1,"grid_x":4.0,"grid_y":10.5},
			{"type":"moving_peg","grid_x":1.5,"grid_y":3.0,"range":90.0,"speed":60.0},
			{"type":"moving_peg","grid_x":6.0,"grid_y":3.0,"range":90.0,"speed":70.0},
			{"type":"moving_peg","grid_x":3.5,"grid_y":7.0,"range":110.0,"speed":80.0},
			{"type":"black_hole","grid_x":2.0,"grid_y":5.0},
			{"type":"black_hole","grid_x":6.0,"grid_y":5.0},
			{"type":"black_hole","grid_x":4.0,"grid_y":8.0},
		],
	},
]

func get_layout() -> Dictionary:
	var idx: int = mini(current_level - 1, LAYOUTS.size() - 1)
	return LAYOUTS[idx]

func get_layout_name() -> String:
	return get_layout().get("name", "Level %d" % current_level)

# -----------------------------------------------------------------------------
# Serialization
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return {
		"current_level":        current_level,
		"contracts_this_level": contracts_this_level,
	}

func apply_save_data(data: Dictionary) -> void:
	current_level        = data.get("current_level",        1)
	contracts_this_level = data.get("contracts_this_level", 0)

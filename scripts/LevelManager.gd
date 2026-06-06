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

var current_level:          int = 16
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
		"peg_overrides": [],
	},
	# ── NEW LAYOUTS ────────────────────────────────────────────────────────────
	{   # Level 7
		"name": "Checkerboard",
		"desc": "Every other peg refills energy. Keep dropping.",
		"skip_pegs": [],
		"hazards": [],
		"peg_pattern": "checkerboard_energy",
		"peg_overrides": [],
	},
	{   # Level 8
		"name": "The Hourglass",
		"desc": "Wide top, deadly waist, wide again. Thread the needle.",
		"skip_pegs": [
			[0,2],[8,2],
			[0,3],[7,3],
			[0,4],[1,4],[7,4],[8,4],
			[0,5],[1,5],[6,5],[7,5],
			[0,6],[1,6],[2,6],[6,6],[7,6],[8,6],
			[0,7],[1,7],[2,7],[5,7],[6,7],[7,7],
			[0,8],[1,8],[7,8],[8,8],
			[0,9],[7,9],
		],
		"hazards": [
			{"type":"black_hole","grid_x":4.0,"grid_y":6.0},
			{"type":"portal","pair_id":0,"grid_x":3.0,"grid_y":5.5},
			{"type":"portal","pair_id":0,"grid_x":5.0,"grid_y":5.5},
		],
		"peg_overrides": [],
	},
	{   # Level 9
		"name": "Spiral Arms",
		"desc": "Two energy arms cross the board. Portals loop the spiral.",
		"skip_pegs": [],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":0.5,"grid_y":11.0},
			{"type":"portal","pair_id":0,"grid_x":7.5,"grid_y":0.5},
			{"type":"portal","pair_id":1,"grid_x":7.5,"grid_y":11.0},
			{"type":"portal","pair_id":1,"grid_x":0.5,"grid_y":0.5},
		],
		"peg_overrides": [
			# Left arm — top-left to bottom-right
			{"col":0,"row":0,"type":"energy"},{"col":0,"row":1,"type":"energy"},
			{"col":1,"row":2,"type":"energy"},{"col":1,"row":3,"type":"energy"},
			{"col":2,"row":4,"type":"energy"},{"col":2,"row":5,"type":"energy"},
			{"col":3,"row":6,"type":"energy"},{"col":3,"row":7,"type":"energy"},
			{"col":4,"row":8,"type":"energy"},{"col":4,"row":9,"type":"energy"},
			{"col":5,"row":10,"type":"energy"},{"col":5,"row":11,"type":"energy"},
			# Right arm — top-right to bottom-left
			{"col":8,"row":0,"type":"energy"},{"col":7,"row":1,"type":"energy"},
			{"col":7,"row":2,"type":"energy"},{"col":6,"row":3,"type":"energy"},
			{"col":6,"row":4,"type":"energy"},{"col":5,"row":5,"type":"energy"},
			{"col":5,"row":6,"type":"energy"},{"col":4,"row":7,"type":"energy"},
			{"col":3,"row":9,"type":"energy"},{"col":3,"row":10,"type":"energy"},
			{"col":2,"row":11,"type":"energy"},
		],
	},
	{   # Level 10
		"name": "Gauntlet II: Crossfire",
		"desc": "Three fast sweepers own the middle. Time your drops.",
		"skip_pegs": [
			[1,4],[2,4],[3,4],[5,4],[6,4],[7,4],
			[1,6],[2,6],[3,6],[5,6],[6,6],[7,6],
			[1,8],[2,8],[3,8],[5,8],[6,8],[7,8],
		],
		"hazards": [
			{"type":"moving_peg","grid_x":4.0,"grid_y":4.0,"range":190.0,"speed":85.0},
			{"type":"moving_peg","grid_x":4.0,"grid_y":6.0,"range":190.0,"speed":100.0},
			{"type":"moving_peg","grid_x":4.0,"grid_y":8.0,"range":190.0,"speed":75.0},
			{"type":"black_hole","grid_x":0.5,"grid_y":6.0},
			{"type":"black_hole","grid_x":7.5,"grid_y":6.0},
		],
		"peg_overrides": [],
	},
	{   # Level 11
		"name": "Volcano",
		"desc": "Bouncy ring surrounds the void. Get close — but not too close.",
		"skip_pegs": [
			[2,4],[3,4],[4,4],[5,4],[6,4],
			[2,5],[3,5],[4,5],[5,5],
			[2,6],[3,6],[4,6],[5,6],[6,6],
			[2,7],[3,7],[4,7],[5,7],
		],
		"hazards": [
			{"type":"black_hole","grid_x":4.0,"grid_y":5.5},
		],
		"peg_overrides": [
			# Bouncy ring
			{"col":2,"row":3,"type":"bouncy"},{"col":4,"row":3,"type":"bouncy"},{"col":6,"row":3,"type":"bouncy"},
			{"col":1,"row":4,"type":"bouncy"},{"col":7,"row":4,"type":"bouncy"},
			{"col":1,"row":5,"type":"bouncy"},{"col":6,"row":5,"type":"bouncy"},
			{"col":1,"row":6,"type":"bouncy"},{"col":7,"row":6,"type":"bouncy"},
			{"col":1,"row":7,"type":"bouncy"},{"col":6,"row":7,"type":"bouncy"},
			{"col":2,"row":8,"type":"bouncy"},{"col":4,"row":8,"type":"bouncy"},{"col":6,"row":8,"type":"bouncy"},
		],
	},
	{   # Level 12
		"name": "The Web",
		"desc": "Nothing exits where it entered. Four portals weave the web.",
		"skip_pegs": [],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":0.0,"grid_y":3.0},
			{"type":"portal","pair_id":0,"grid_x":8.0,"grid_y":9.0},
			{"type":"portal","pair_id":1,"grid_x":8.0,"grid_y":3.0},
			{"type":"portal","pair_id":1,"grid_x":0.0,"grid_y":9.0},
			{"type":"moving_peg","grid_x":2.0,"grid_y":2.0,"range":35.0,"speed":18.0},
			{"type":"moving_peg","grid_x":6.0,"grid_y":2.0,"range":35.0,"speed":22.0},
			{"type":"moving_peg","grid_x":4.0,"grid_y":6.0,"range":35.0,"speed":26.0},
			{"type":"moving_peg","grid_x":2.0,"grid_y":10.0,"range":35.0,"speed":20.0},
			{"type":"moving_peg","grid_x":6.0,"grid_y":10.0,"range":35.0,"speed":18.0},
		],
		"peg_overrides": [],
	},
	{   # Level 13
		"name": "Energy Corridor",
		"desc": "Two energy columns on the flanks. Portals loop them back to the top.",
		"skip_pegs": [],
		"hazards": [
			{"type":"portal","pair_id":0,"grid_x":1.0,"grid_y":11.5},
			{"type":"portal","pair_id":0,"grid_x":1.0,"grid_y":0.5},
			{"type":"portal","pair_id":1,"grid_x":7.0,"grid_y":11.5},
			{"type":"portal","pair_id":1,"grid_x":7.0,"grid_y":0.5},
			{"type":"black_hole","grid_x":4.0,"grid_y":5.5},
		],
		"peg_overrides": [
			# Left energy column
			{"col":1,"row":0,"type":"energy"},{"col":1,"row":1,"type":"energy"},
			{"col":1,"row":2,"type":"energy"},{"col":1,"row":3,"type":"energy"},
			{"col":1,"row":4,"type":"energy"},{"col":1,"row":5,"type":"energy"},
			{"col":1,"row":6,"type":"energy"},{"col":1,"row":7,"type":"energy"},
			{"col":1,"row":8,"type":"energy"},{"col":1,"row":9,"type":"energy"},
			{"col":1,"row":10,"type":"energy"},{"col":1,"row":11,"type":"energy"},
			# Right energy column
			{"col":7,"row":0,"type":"energy"},{"col":7,"row":1,"type":"energy"},
			{"col":7,"row":2,"type":"energy"},{"col":7,"row":3,"type":"energy"},
			{"col":7,"row":4,"type":"energy"},{"col":7,"row":5,"type":"energy"},
			{"col":7,"row":6,"type":"energy"},{"col":7,"row":7,"type":"energy"},
			{"col":7,"row":8,"type":"energy"},{"col":7,"row":9,"type":"energy"},
			{"col":7,"row":10,"type":"energy"},{"col":7,"row":11,"type":"energy"},
		],
	},
	{   # Level 14+
		"name": "The Labyrinth",
		"desc": "Slow moving pegs wall off corridors. Every path is temporary.",
		"skip_pegs": [
			[0,1],[2,1],[4,1],[6,1],
			[1,2],[3,2],[5,2],[7,2],
			[0,3],[2,3],[4,3],[6,3],[8,3],
			[1,4],[5,4],[7,4],
			[0,5],[2,5],[4,5],[6,5],[8,5],
			[3,6],[5,6],[7,6],
			[0,7],[2,7],[4,7],[6,7],[8,7],
			[1,8],[3,8],[7,8],
			[0,9],[2,9],[4,9],[6,9],[8,9],
		],
		"hazards": [
			{"type":"moving_peg","grid_x":1.0,"grid_y":1.5,"range":55.0,"speed":12.0},
			{"type":"moving_peg","grid_x":5.0,"grid_y":3.5,"range":55.0,"speed":14.0},
			{"type":"moving_peg","grid_x":2.0,"grid_y":6.0,"range":55.0,"speed":10.0},
			{"type":"moving_peg","grid_x":6.0,"grid_y":7.5,"range":55.0,"speed":13.0},
			{"type":"portal","pair_id":0,"grid_x":0.5,"grid_y":5.0},
			{"type":"portal","pair_id":0,"grid_x":7.5,"grid_y":2.0},
			{"type":"black_hole","grid_x":4.0,"grid_y":9.5},
		],
		"peg_overrides": [],
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

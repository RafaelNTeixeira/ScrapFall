# =============================================================================
# BuffManager.gd — Autoload "BuffManager"
#
# Defines all permanent buffs, tracks how many times each has been picked,
# and applies their effects to game state.
# =============================================================================
extends Node

signal buffs_changed()

# How many times each buff has been picked across all levels
var buff_counts: Dictionary = {}

# -----------------------------------------------------------------------------
# Buff catalogue — every buff the game can offer
# -----------------------------------------------------------------------------
const BUFFS: Dictionary = {
	"energy_regen_1":      { "label": "Energy Overdrive",    "icon": "⚡",
		"desc": "Permanently +1 energy/sec regen.",
		"stat_label": "Bonus regen",   "stat_unit": "/sec",  "stat_per_stack": 1.0 },
	"power_max_10":        { "label": "Expanded Battery",    "icon": "🔋",
		"desc": "Permanently +10 max energy.",
		"stat_label": "Bonus max",     "stat_unit": " energy","stat_per_stack": 10.0 },
	"storage_100":         { "label": "Mega Silos",          "icon": "🏭",
		"desc": "All storage caps permanently +100.",
		"stat_label": "Bonus cap",     "stat_unit": " units", "stat_per_stack": 100.0 },
	"start_resources_100": { "label": "Head Start",          "icon": "📦",
		"desc": "Start each level with +100 of every resource.",
		"stat_label": "Bonus start",   "stat_unit": " units", "stat_per_stack": 100.0 },
	"dropper_speed_5pct":  { "label": "Clockwork Boost",     "icon": "⚙️",
		"desc": "Auto-Droppers fire 5% faster permanently.",
		"stat_label": "Speed bonus",   "stat_unit": "%",      "stat_per_stack": 5.0 },
	"contract_gold_10pct": { "label": "Trade Mastery",       "icon": "💰",
		"desc": "All contract gold rewards permanently +10%.",
		"stat_label": "Gold bonus",    "stat_unit": "%",      "stat_per_stack": 10.0 },
	"raw_rate_10pct":      { "label": "Black Market",        "icon": "📈",
		"desc": "Raw sale rates permanently +10%.",
		"stat_label": "Rate bonus",    "stat_unit": "%",      "stat_per_stack": 10.0 },
	"energy_peg_plus1":    { "label": "Supercharged Peg",   "icon": "🔆",
		"desc": "Energy peg returns +1 extra energy per hit.",
		"stat_label": "Bonus energy",  "stat_unit": " per hit","stat_per_stack": 1.0 },
	"contract_time_60":    { "label": "Extension Clause",    "icon": "⏳",
		"desc": "All new contracts get +60 sec duration.",
		"stat_label": "Time bonus",    "stat_unit": " sec",   "stat_per_stack": 60.0 },
	"offline_5pct":        { "label": "Remote Factory",      "icon": "💤",
		"desc": "Offline production permanently +5%.",
		"stat_label": "Offline bonus", "stat_unit": "%",      "stat_per_stack": 5.0 },
	"portal_energy":       { "label": "Void Tap",            "icon": "🌀",
		"desc": "Each portal transit gives +3 energy.",
		"stat_label": "Energy/transit","stat_unit": "",        "stat_per_stack": 3.0 },
	"start_full_meter":    { "label": "Hot Start",           "icon": "🔥",
		"desc": "Every level begins with a full power meter.",
		"stat_label": "Stacks",        "stat_unit": "",        "stat_per_stack": 1.0 },
}

const BUFF_IDS: Array = [
	"energy_regen_1","power_max_10","storage_100","start_resources_100",
	"dropper_speed_5pct","contract_gold_10pct","raw_rate_10pct",
	"energy_peg_plus1","contract_time_60","offline_5pct",
	"portal_energy","start_full_meter",
]

# -----------------------------------------------------------------------------
# Get 3 unique random buff IDs for the picker
# -----------------------------------------------------------------------------
func get_random_picks() -> Array:
	var pool: Array = BUFF_IDS.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)

# -----------------------------------------------------------------------------
# Get current stacked value of a buff
# -----------------------------------------------------------------------------
func stack_count(buff_id: String) -> int:
	return buff_counts.get(buff_id, 0)

func stacked_value(buff_id: String) -> float:
	if not BUFFS.has(buff_id):
		return 0.0
	return stack_count(buff_id) * BUFFS[buff_id]["stat_per_stack"]

# -----------------------------------------------------------------------------
# Apply a buff (called when player picks one on level-up)
# -----------------------------------------------------------------------------
func apply_buff(buff_id: String) -> void:
	buff_counts[buff_id] = buff_counts.get(buff_id, 0) + 1
	_apply_to_game(buff_id)
	emit_signal("buffs_changed")

## Re-applies all accumulated buffs — called on game load
func reapply_all() -> void:
	for buff_id in buff_counts:
		for _i in buff_counts[buff_id]:
			_apply_to_game(buff_id)

func _apply_to_game(buff_id: String) -> void:
	match buff_id:
		"energy_regen_1":
			GameManager.passive_regen_rate += 1.0
		"power_max_10":
			# Stored as a delta — GameManager reads POWER_METER_MAX + bonus
			GameManager.power_meter_bonus += 10.0
		"storage_100":
			for res in GameManager.storage_caps:
				GameManager.storage_caps[res] += 100
		"dropper_speed_5pct":
			GameManager.dropper_speed_multiplier *= 0.95
		"contract_gold_10pct":
			GameManager.contract_gold_multiplier += 0.10
		"raw_rate_10pct":
			GameManager.raw_rate_multiplier += 0.10
		"energy_peg_plus1":
			GameManager.energy_peg_bonus += 1.0
		"contract_time_60":
			GameManager.contract_time_bonus += 60.0
		"offline_5pct":
			GameManager.offline_multiplier += 0.05
		"portal_energy":
			GameManager.portal_energy_bonus += 3.0

## Called at the start of each new level (for "start_X" buffs)
func apply_level_start_buffs() -> void:
	var bonus_res: int = int(stacked_value("start_resources_100"))
	if bonus_res > 0:
		for res in GameManager.resources:
			GameManager.collect_resource(res, bonus_res)
	if stack_count("start_full_meter") > 0:
		GameManager.power_meter = GameManager.effective_power_max()

# -----------------------------------------------------------------------------
# Serialization
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	return buff_counts.duplicate()

func apply_save_data(data: Dictionary) -> void:
	buff_counts = data.duplicate()

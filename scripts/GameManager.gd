# =============================================================================
# GameManager.gd
# Autoload Singleton — Add via: Project > Project Settings > Autoload
# Name it exactly "GameManager" so all scripts can reference it globally.
# =============================================================================
extends Node

# -----------------------------------------------------------------------------
# Signals — UI nodes connect to these to stay reactive without polling
# -----------------------------------------------------------------------------
signal power_meter_changed(new_value: float)
signal resource_collected(resource_type: String, new_total: int)
signal gold_changed(new_total: float)
signal storage_full(resource_type: String)       # fires when a slot is capped
signal ball_drop_failed()                        # fires when energy too low
signal skin_changed(skin_id: String)             # emitted when active skin changes
signal theme_changed(theme_id: String)           # emitted when board theme changes

# -----------------------------------------------------------------------------
# Power Meter Constants
# -----------------------------------------------------------------------------
const POWER_METER_MAX:      float = 100.0
const DROP_COST:            float = 10.0
const ENERGY_PEG_GAIN:      float = 8.0   # net -2 per drop; net +6 if Splitter+Energy
const PASSIVE_REGEN_RATE:   float = 1.0   # energy per second (upgradeable)

var power_meter:            float = POWER_METER_MAX
var passive_regen_rate:     float = PASSIVE_REGEN_RATE   # mutable for upgrades
var _regen_accumulator:     float = 0.0

# -----------------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------------
const RESOURCE_TYPES: Array[String] = ["Copper", "Steel", "Glass", "Wood"]

var resources: Dictionary = {
	"Copper": 500,
	"Steel":  500,
	"Glass":  500,
	"Wood":   500,
}

# Base caps — can be upgraded via resource spending
var storage_caps: Dictionary = {
	"Copper": 500,
	"Steel":  500,
	"Glass":  500,
	"Wood":   500,
}

# -----------------------------------------------------------------------------
# Gold
# -----------------------------------------------------------------------------
var gold: float = 100000.0

# -----------------------------------------------------------------------------
# Buff-driven modifiers (accumulate permanently across levels)
# BuffManager._apply_to_game() mutates these. SaveManager persists them.
# -----------------------------------------------------------------------------
var power_meter_bonus:        float = 0.0   # "Expanded Battery"  +10 max energy/stack
var dropper_speed_multiplier: float = 1.0   # "Clockwork Boost"   x0.95/stack
var contract_gold_multiplier: float = 1.0   # "Trade Mastery"     +10%/stack
var raw_rate_multiplier:      float = 1.0   # "Black Market"      +10%/stack
var energy_peg_bonus:         float = 0.0   # "Supercharged Peg"  +1 energy/stack
var contract_time_bonus:      float = 0.0   # "Extension Clause"  +60 sec/stack
var portal_energy_bonus:      float = 0.0   # "Void Tap"          +3 energy/stack

# -----------------------------------------------------------------------------
# Shop Purchases — persisted by SaveManager, applied immediately on buy
# -----------------------------------------------------------------------------
var active_skin:             String = "default"  # currently equipped ball skin
var owned_skins:             Array  = ["default"] # all unlocked skin IDs
var active_theme:            String = "factory"   # board/panel colour theme
var offline_overdrive_tier:  int    = 0           # 0=10%  1=50%  2=100% offline prod
var contract_refresh_tokens: int    = 0           # max 10 held
var has_golden_drone:        bool   = false       # +20% contract gold (one-time)
var has_expanded_silos:      bool   = false       # +25% all storage caps (one-time)

# -----------------------------------------------------------------------------
# Upgrade Flags — prevent buying the same one-time upgrade twice
# -----------------------------------------------------------------------------
var has_splitter_peg:    bool = false
var has_energy_peg:      bool = false
var has_gate:            bool = false
var auto_dropper_count:  int  = 0
const MAX_AUTO_DROPPERS: int  = 2

# -----------------------------------------------------------------------------
# _process — passive regen tick every second
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if power_meter >= effective_power_max():
		return

	_regen_accumulator += delta
	# Accumulate until we have at least 1 full second, then award energy.
	# This keeps regen smooth even if passive_regen_rate is changed mid-game.
	while _regen_accumulator >= 1.0:
		_regen_accumulator -= 1.0
		_add_power(passive_regen_rate)

# -----------------------------------------------------------------------------
# Power Meter API
# -----------------------------------------------------------------------------
## Returns the actual max energy including buff bonuses.
func effective_power_max() -> float:
	return POWER_METER_MAX + power_meter_bonus

func can_drop() -> bool:
	return power_meter >= DROP_COST

## Called by Board when a drop is initiated. Returns false if not enough energy.
func consume_drop_energy() -> bool:
	if not can_drop():
		emit_signal("ball_drop_failed")
		return false
	power_meter = maxf(0.0, power_meter - DROP_COST)
	emit_signal("power_meter_changed", power_meter)
	return true

## Called by energy-peg logic, passive regen, and Overclock events.
func _add_power(amount: float) -> void:
	power_meter = minf(effective_power_max(), power_meter + amount)
	emit_signal("power_meter_changed", power_meter)

## Public wrapper used by Peg and future upgrade systems.
func award_energy_peg_hit() -> void:
	_add_power(ENERGY_PEG_GAIN + energy_peg_bonus)

# -----------------------------------------------------------------------------
# Resource Collection API
# -----------------------------------------------------------------------------
## Called by Slot when a ball lands. Returns how much was actually stored.
func collect_resource(resource_type: String, amount: int = 1) -> int:
	if resource_type not in resources:
		push_warning("GameManager: unknown resource type '%s'" % resource_type)
		return 0

	var cap:     int = storage_caps.get(resource_type, 500)
	var current: int = resources[resource_type]
	var storable: int = mini(amount, cap - current)

	if storable <= 0:
		emit_signal("storage_full", resource_type)
		return 0

	resources[resource_type] = current + storable
	emit_signal("resource_collected", resource_type, resources[resource_type])
	return storable

## Spend resources (returns false if insufficient).
func spend_resources(cost: Dictionary) -> bool:
	for res_type in cost:
		if resources.get(res_type, 0) < cost[res_type]:
			return false
	for res_type in cost:
		resources[res_type] -= cost[res_type]
		emit_signal("resource_collected", res_type, resources[res_type])
	return true

# -----------------------------------------------------------------------------
# Gold API
# -----------------------------------------------------------------------------
func award_gold(amount: float) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: float) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true

# -----------------------------------------------------------------------------
# Storage Cap Upgrades (called from upgrade UI)
# -----------------------------------------------------------------------------
func upgrade_storage(resource_type: String, increase: int) -> void:
	if resource_type in storage_caps:
		storage_caps[resource_type] += increase

# -----------------------------------------------------------------------------
# Regen Rate Upgrade (Gold-purchased)
# -----------------------------------------------------------------------------
func upgrade_regen_rate(new_rate: float) -> void:
	passive_regen_rate = new_rate

# -----------------------------------------------------------------------------
# Offline Progress — called by SaveManager on startup
# -----------------------------------------------------------------------------
## offline_multiplier: 0.1 default (10%), upgradeable to 0.5 or 1.0 via shop
var offline_multiplier: float = 0.1
const OFFLINE_CAP_HOURS: float = 8.0   # max hours of offline credit

func apply_offline_progress(elapsed_seconds: float) -> void:
	# Cap offline time so the game doesn't flood storage on long absences
	var capped: float  = minf(elapsed_seconds, OFFLINE_CAP_HOURS * 3600.0)
	var minutes: float = capped / 60.0

	# Award resources proportional to time — 1 unit per minute per resource
	# as a simple base rate. Upgrade system will multiply this later.
	var award: int = int(minutes * offline_multiplier)
	if award <= 0:
		return

	for res_type in RESOURCE_TYPES:
		collect_resource(res_type, award)

	# Also restore power meter fully after offline time
	_add_power(effective_power_max())

	# Store elapsed for UI to show "You were away X hours" popup
	last_offline_seconds = capped

var last_offline_seconds: float = 0.0

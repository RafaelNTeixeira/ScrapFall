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
	"Copper": 0,
	"Steel":  0,
	"Glass":  0,
	"Wood":   0,
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
var gold: float = 0.0

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
	if power_meter >= POWER_METER_MAX:
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
	power_meter = minf(POWER_METER_MAX, power_meter + amount)
	emit_signal("power_meter_changed", power_meter)

## Public wrapper used by Peg and future upgrade systems.
func award_energy_peg_hit() -> void:
	_add_power(ENERGY_PEG_GAIN)

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

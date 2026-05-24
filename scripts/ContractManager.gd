# =============================================================================
# ContractManager.gd
# Autoload — register as "ContractManager"
#
# Manages 3 active shipping contracts at all times.
# Each contract has a countdown timer; when it expires a new one replaces it.
# Fulfilling a contract pays 2× the raw gold rate.
# =============================================================================
extends Node

# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal contract_updated(slot: int)      # any change to a slot (new/tick)
signal contract_fulfilled(slot: int, gold_earned: float)
signal contract_expired(slot: int)

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const SLOT_COUNT: int = 3

const FACTIONS: Array[String] = [
	"The Core Grid", "Harbor District", "Iron Heights",
	"Crystal Labs",  "The Foundry",     "Skywatch Station",
	"Deep Mines Co.", "Neon Market",    "Rust & Co.",
]

## Base gold per unit when selling raw (1×)
const RAW_RATES: Dictionary = {
	"Copper": 0.5,
	"Steel":  0.8,
	"Glass":  0.7,
	"Wood":   0.4,
}

const CONTRACT_MULTIPLIER: float = 2.0   # contracts pay 2× raw rate
const CONTRACT_MIN_SECS:   float = 480.0 # 8 min
const CONTRACT_MAX_SECS:   float = 720.0 # 12 min

# -----------------------------------------------------------------------------
# State — array of 3 contract dicts
# -----------------------------------------------------------------------------
## Contract dict shape:
## { "faction", "resources": {res: amount}, "gold_reward", "duration", "time_remaining" }
var contracts: Array = []

var _tick_enabled: bool = true

# -----------------------------------------------------------------------------
# _ready
# -----------------------------------------------------------------------------
func _ready() -> void:
	randomize()
	# Slots filled either by SaveManager restore or fresh generation
	while contracts.size() < SLOT_COUNT:
		contracts.append(_generate_contract())

# -----------------------------------------------------------------------------
# _process — tick all contract timers
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _tick_enabled:
		return
	for i in SLOT_COUNT:
		contracts[i]["time_remaining"] -= delta
		if contracts[i]["time_remaining"] <= 0.0:
			contracts[i] = _generate_contract()
			emit_signal("contract_expired", i)
			emit_signal("contract_updated", i)

# -----------------------------------------------------------------------------
# Fulfill a contract — deducts resources, pays gold
# Returns false if the player can't afford it
# -----------------------------------------------------------------------------
func fulfill_contract(slot: int) -> bool:
	if slot < 0 or slot >= contracts.size():
		return false
	var c: Dictionary = contracts[slot]
	if not GameManager.spend_resources(c["resources"]):
		return false
	var gold: float = c["gold_reward"]
	GameManager.award_gold(gold)
	emit_signal("contract_fulfilled", slot, gold)
	contracts[slot] = _generate_contract()
	emit_signal("contract_updated", slot)
	return true

## Returns true if the player currently has all required resources for a slot.
func can_fulfill(slot: int) -> bool:
	if slot < 0 or slot >= contracts.size():
		return false
	var c: Dictionary = contracts[slot]
	for res in c["resources"]:
		if GameManager.resources.get(res, 0) < c["resources"][res]:
			return false
	return true

# -----------------------------------------------------------------------------
# Sell raw resources (1× rate)
# amounts: { "Copper": 50, "Steel": 20, … }
# -----------------------------------------------------------------------------
func sell_raw(amounts: Dictionary) -> float:
	var total_gold: float = 0.0
	for res in amounts:
		var qty: int = int(amounts[res])
		if qty <= 0:
			continue
		var available: int = GameManager.resources.get(res, 0)
		qty = mini(qty, available)
		if qty <= 0:
			continue
		GameManager.resources[res] -= qty
		# Emit the same signal ResourceBar listens to so the Warehouse UI updates
		GameManager.resource_collected.emit(res, GameManager.resources[res])
		var gold: float = qty * RAW_RATES.get(res, 0.5)
		total_gold += gold
	if total_gold > 0.0:
		GameManager.award_gold(total_gold)
	return total_gold

## Gold you'd get for selling `amount` units of `resource` raw.
func raw_gold_for(resource: String, amount: int) -> float:
	return amount * RAW_RATES.get(resource, 0.5)

# -----------------------------------------------------------------------------
# Contract generation
# -----------------------------------------------------------------------------
func _generate_contract() -> Dictionary:
	var faction: String = FACTIONS[randi() % FACTIONS.size()]

	# Pick 1–3 resource types
	var pool: Array = ["Copper", "Steel", "Glass", "Wood"]
	pool.shuffle()
	var count: int    = randi_range(1, 3)
	var resources: Dictionary = {}
	var raw_value: float      = 0.0

	for i in count:
		var res: String = pool[i]
		var amount: int = _contract_amount(res)
		resources[res]  = amount
		raw_value      += amount * RAW_RATES.get(res, 0.5)

	var duration: float = randf_range(CONTRACT_MIN_SECS, CONTRACT_MAX_SECS)

	return {
		"faction":        faction,
		"resources":      resources,
		"gold_reward":    raw_value * CONTRACT_MULTIPLIER,
		"duration":       duration,
		"time_remaining": duration,
	}

func _contract_amount(resource: String) -> int:
	var cap:    int = GameManager.storage_caps.get(resource, 500)
	var min_a:  int = maxi(20, int(cap * 0.12))
	var max_a:  int = maxi(60, int(cap * 0.35))
	return randi_range(min_a, max_a)

# -----------------------------------------------------------------------------
# Refresh token — instant reroll of one slot (purchased in Shop)
# -----------------------------------------------------------------------------
func refresh_slot(slot: int) -> void:
	if slot < 0 or slot >= contracts.size():
		return
	contracts[slot] = _generate_contract()
	emit_signal("contract_updated", slot)

# -----------------------------------------------------------------------------
# Serialization — called by SaveManager
# -----------------------------------------------------------------------------
func get_save_data() -> Array:
	return contracts.duplicate(true)

func apply_save_data(data: Array) -> void:
	contracts.clear()
	for c in data:
		contracts.append(c)
	while contracts.size() < SLOT_COUNT:
		contracts.append(_generate_contract())

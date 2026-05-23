# =============================================================================
# UpgradeManager.gd
# Autoload Singleton — register as "UpgradeManager"
#
# Single source of truth for every upgrade: definition, cost, purchased state.
# UI reads from here. Purchases go through here. Board listens to signals.
# =============================================================================
extends Node

# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal upgrade_purchased(upgrade_id: String)
signal upgrade_failed(upgrade_id: String, reason: String)
signal placement_mode_started(upgrade_id: String)
signal placement_mode_cancelled()
signal placement_confirmed(upgrade_id: String)

# -----------------------------------------------------------------------------
# Upgrade definitions
# All costs use the same key names as GameManager.resources / GameManager.gold
# "placement" = true means the upgrade needs a board interaction after purchase
# -----------------------------------------------------------------------------
var UPGRADES: Dictionary = {
	# ── Resource-purchased (physical board upgrades) ──────────────────────────
	"splitter_peg": {
		"label":        "Splitter Peg",
		"description":  "One peg splits every ball that hits it into two.",
		"cost_res":     {"Copper": 100, "Steel": 100},
		"cost_gold":    0.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
	},
	"energy_peg": {
		"label":        "Energy Peg",
		"description":  "One peg refills +8 energy on every hit.",
		"cost_res":     {"Steel": 100, "Glass": 100},
		"cost_gold":    0.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
	},
	"gate_1": {
		"label":        "Gate",
		"description":  "A ramp between two consecutive pegs guides balls left or right.",
		"cost_res":     {"Wood": 100, "Glass": 100},
		"cost_gold":    0.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
	},
	"gate_2": {
		"label":        "2nd Gate",
		"description":  "A second ramp for more advanced ball routing.",
		"cost_res":     {"Wood": 150, "Glass": 150},
		"cost_gold":    0.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
		"requires":     "gate_1",
	},
	"storage_copper": {
		"label":        "Copper Silo +200",
		"description":  "Increases Copper storage cap by 200.",
		"cost_res":     {"Copper": 150},
		"cost_gold":    0.0,
		"placement":    false,
		"one_time":     false,
		"purchased":    false,
	},
	"storage_steel": {
		"label":        "Steel Silo +200",
		"description":  "Increases Steel storage cap by 200.",
		"cost_res":     {"Steel": 150},
		"cost_gold":    0.0,
		"placement":    false,
		"one_time":     false,
		"purchased":    false,
	},
	"storage_glass": {
		"label":        "Glass Silo +200",
		"description":  "Increases Glass storage cap by 200.",
		"cost_res":     {"Glass": 150},
		"cost_gold":    0.0,
		"placement":    false,
		"one_time":     false,
		"purchased":    false,
	},
	"storage_wood": {
		"label":        "Wood Silo +200",
		"description":  "Increases Wood storage cap by 200.",
		"cost_res":     {"Wood": 150},
		"cost_gold":    0.0,
		"placement":    false,
		"one_time":     false,
		"purchased":    false,
	},
	"dropper_speed": {
		"label":        "Faster Dropper",
		"description":  "Auto-Dropper interval: 5s → 3s.",
		"cost_res":     {"Steel": 200, "Copper": 100},
		"cost_gold":    0.0,
		"placement":    false,
		"one_time":     true,
		"purchased":    false,
	},
	# ── Gold-purchased ─────────────────────────────────────────────────────────
	"auto_dropper_1": {
		"label":        "Auto-Dropper",
		"description":  "Places an automatic ball dropper at the top of the board.",
		"cost_res":     {},
		"cost_gold":    50.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
	},
	"auto_dropper_2": {
		"label":        "2nd Auto-Dropper",
		"description":  "A second automatic dropper slot.",
		"cost_res":     {},
		"cost_gold":    150.0,
		"placement":    true,
		"one_time":     true,
		"purchased":    false,
		"placed":       false,
		"requires":     "auto_dropper_1",  # must own the first one
	},
	"regen_rate_1": {
		"label":        "Regen Boost I",
		"description":  "Power meter regen: +1/s → +2/s.",
		"cost_res":     {},
		"cost_gold":    100.0,
		"placement":    false,
		"one_time":     true,
		"purchased":    false,
	},
	"regen_rate_2": {
		"label":        "Regen Boost II",
		"description":  "Power meter regen: +2/s → +3/s.",
		"cost_res":     {},
		"cost_gold":    300.0,
		"placement":    false,
		"one_time":     true,
		"purchased":    false,
		"requires":     "regen_rate_1",
	},
}

# ID of upgrade currently waiting for board placement
var pending_placement: String = ""

# -----------------------------------------------------------------------------
# Purchase flow
# -----------------------------------------------------------------------------
func can_afford(upgrade_id: String) -> bool:
	if not UPGRADES.has(upgrade_id):
		return false
	var upg: Dictionary = UPGRADES[upgrade_id]

	# Already purchased one-time upgrades can't be bought again
	if upg.get("one_time", false) and upg.get("purchased", false):
		return false

	# Check prerequisite
	if upg.has("requires"):
		var req: String = upg["requires"]
		if not UPGRADES.get(req, {}).get("purchased", false):
			return false

	# Check resource cost manually (Dry-run)
	for res in upg["cost_res"]:
		if GameManager.resources.get(res, 0) < upg["cost_res"][res]:
			return false

	# Check gold
	if upg["cost_gold"] > 0.0 and GameManager.gold < upg["cost_gold"]:
		return false

	return true

func purchase(upgrade_id: String) -> void:
	if not UPGRADES.has(upgrade_id):
		emit_signal("upgrade_failed", upgrade_id, "Unknown upgrade.")
		return

	var upg: Dictionary = UPGRADES[upgrade_id]

	if upg.get("one_time", false) and upg.get("purchased", false):
		emit_signal("upgrade_failed", upgrade_id, "Already purchased.")
		return

	if upg.has("requires") and not UPGRADES.get(upg["requires"], {}).get("purchased", false):
		emit_signal("upgrade_failed", upgrade_id, "Requires: " + upg["requires"])
		return

	# Deduct resources
	if not upg["cost_res"].is_empty():
		if not GameManager.spend_resources(upg["cost_res"]):
			emit_signal("upgrade_failed", upgrade_id, "Not enough resources.")
			return

	# Deduct gold
	if upg["cost_gold"] > 0.0:
		if not GameManager.spend_gold(upg["cost_gold"]):
			# Refund resources already spent
			for res in upg["cost_res"]:
				GameManager.resources[res] += upg["cost_res"][res]
			emit_signal("upgrade_failed", upgrade_id, "Not enough gold.")
			return

	# Mark purchased
	upg["purchased"] = true

	# Apply instant upgrades immediately
	_apply_instant(upgrade_id)

	emit_signal("upgrade_purchased", upgrade_id)

	# Board-placement upgrades enter placement mode
	if upg.get("placement", false) and not upg.get("placed", false):
		pending_placement = upgrade_id
		emit_signal("placement_mode_started", upgrade_id)

# -----------------------------------------------------------------------------
# Apply non-placement upgrades immediately
# -----------------------------------------------------------------------------
func _apply_instant(upgrade_id: String) -> void:
	match upgrade_id:
		"storage_copper":
			GameManager.upgrade_storage("Copper", 200)
		"storage_steel":
			GameManager.upgrade_storage("Steel", 200)
		"storage_glass":
			GameManager.upgrade_storage("Glass", 200)
		"storage_wood":
			GameManager.upgrade_storage("Wood", 200)
		"dropper_speed":
			# Board will apply this when it receives the signal
			pass
		"regen_rate_1":
			GameManager.upgrade_regen_rate(2.0)
		"regen_rate_2":
			GameManager.upgrade_regen_rate(3.0)

# -----------------------------------------------------------------------------
# Called by Board/GateManager after the player finishes placement
# -----------------------------------------------------------------------------
func confirm_placement(upgrade_id: String) -> void:
	if UPGRADES.has(upgrade_id):
		UPGRADES[upgrade_id]["placed"] = true
	pending_placement = ""
	emit_signal("placement_confirmed", upgrade_id)

func cancel_placement() -> void:
	# No refund — the upgrade is already paid for and owned.
	# Cancelling just dismisses the placement banner. The card in
	# UpgradeUI will show "Tap board to place" so the player can
	# re-enter placement mode by pressing that button again.
	if pending_placement.is_empty():
		return
	pending_placement = ""
	emit_signal("placement_mode_cancelled")

## Lets the player re-enter placement mode for an already-purchased upgrade.
func reenter_placement(upgrade_id: String) -> void:
	if not UPGRADES.has(upgrade_id):
		return
	var upg: Dictionary = UPGRADES[upgrade_id]
	if not upg.get("purchased", false) or upg.get("placed", false):
		return
	pending_placement = upgrade_id
	emit_signal("placement_mode_started", upgrade_id)

## Enters relocation mode for a placed upgrade (dropper or gate).
## upgrade_id: "relocate_dropper_1", "relocate_dropper_2", "relocate_gate_1", "relocate_gate_2"
func enter_relocate_mode(upgrade_id: String) -> void:
	pending_placement = upgrade_id
	emit_signal("placement_mode_started", upgrade_id)

# -----------------------------------------------------------------------------
# Serialization — called by SaveManager
# -----------------------------------------------------------------------------
func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for id in UPGRADES:
		data[id] = {
			"purchased": UPGRADES[id].get("purchased", false),
			"placed":    UPGRADES[id].get("placed",    false),
		}
	return data

func apply_save_data(data: Dictionary) -> void:
	for id in data:
		if UPGRADES.has(id):
			UPGRADES[id]["purchased"] = data[id].get("purchased", false)
			UPGRADES[id]["placed"]    = data[id].get("placed",    false)
	# Re-apply instant upgrades silently on load
	for id in UPGRADES:
		if UPGRADES[id].get("purchased", false):
			_apply_instant(id)

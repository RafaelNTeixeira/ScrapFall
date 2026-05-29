# =============================================================================
# SaveManager.gd
# Autoload Singleton — register as "SaveManager" in Project Settings > Autoload
#
# Handles all save/load via FileAccess JSON.
# Saves automatically on quit and every AUTO_SAVE_INTERVAL seconds.
# Also writes the Unix timestamp on quit for offline progress calculation.
# =============================================================================
extends Node

const SAVE_PATH:          String = "user://save_data.json"
const AUTO_SAVE_INTERVAL: float  = 60.0   # seconds between auto-saves

var _auto_save_timer: float = 0.0

# -----------------------------------------------------------------------------
# _ready — load on startup, then hand off offline time to GameManager
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Listen for app close on Android
	get_tree().set_auto_accept_quit(false)

	var data: Dictionary = _load_raw()
	if data.is_empty():
		return

	_apply_to_game_manager(data)

	# Offline progress — calculated once on load
	if data.has("quit_timestamp"):
		var elapsed: float = Time.get_unix_time_from_system() - float(data["quit_timestamp"])
		GameManager.apply_offline_progress(elapsed)

# -----------------------------------------------------------------------------
# _notification — catch QUIT on Android / desktop
# -----------------------------------------------------------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()

# -----------------------------------------------------------------------------
# _process — auto-save timer
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save()

# -----------------------------------------------------------------------------
# Public save
# -----------------------------------------------------------------------------
func save() -> void:
	var data: Dictionary = {
		# Power meter
		"power_meter":        GameManager.power_meter,
		"passive_regen_rate": GameManager.passive_regen_rate,
		# Resources
		"resources":          GameManager.resources.duplicate(),
		"storage_caps":       GameManager.storage_caps.duplicate(),
		# Gold
		"gold":               GameManager.gold,
		# Buff modifiers
		"power_meter_bonus":        GameManager.power_meter_bonus,
		"dropper_speed_multiplier": GameManager.dropper_speed_multiplier,
		"contract_gold_multiplier": GameManager.contract_gold_multiplier,
		"raw_rate_multiplier":      GameManager.raw_rate_multiplier,
		"energy_peg_bonus":         GameManager.energy_peg_bonus,
		"contract_time_bonus":      GameManager.contract_time_bonus,
		"portal_energy_bonus":      GameManager.portal_energy_bonus,
		# Upgrade flags
		"has_splitter_peg":   GameManager.has_splitter_peg,
		"has_energy_peg":     GameManager.has_energy_peg,
		"has_gate":           GameManager.has_gate,
		"auto_dropper_count": GameManager.auto_dropper_count,
		# Upgrade states
		"upgrades":           UpgradeManager.get_save_data(),
		# Gate anchor pegs
		"gate":               _get_gate_manager().get_save_data() if _get_gate_manager() else {},
		# Level and buff progress
		"level":              LevelManager.get_save_data(),
		"buffs":              BuffManager.get_save_data(),
		# Active contracts
		"contracts":          ContractManager.get_save_data(),
		# Auto-dropper positions
		"dropper_positions":  _get_board().get_dropper_positions() if _get_board() else [],
		# Shop state
		"active_skin":             GameManager.active_skin,
		"owned_skins":             GameManager.owned_skins.duplicate(),
		"active_theme":            GameManager.active_theme,
		"offline_overdrive_tier":  GameManager.offline_overdrive_tier,
		"contract_refresh_tokens": GameManager.contract_refresh_tokens,
		"has_golden_drone":        GameManager.has_golden_drone,
		"has_expanded_silos":      GameManager.has_expanded_silos,
		# Audio settings
		"sfx_enabled":    AudioManager.sfx_enabled,
		"music_enabled":  AudioManager.music_enabled,
		"sfx_volume_db":  AudioManager.sfx_volume_db,
		"music_volume_db": AudioManager.music_volume_db,
		# Offline timestamp — always written last so it's as fresh as possible
		"quit_timestamp":     int(Time.get_unix_time_from_system()),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# -----------------------------------------------------------------------------
# Internal load
# -----------------------------------------------------------------------------
func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open save file for reading.")
		return {}

	var text:   String     = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: save file is corrupt, starting fresh.")
		return {}

	return parsed

func _get_board() -> Node:
	## Finds the Board node in the scene tree — used for dropper persistence.
	var boards := get_tree().get_nodes_in_group("board")
	return boards[0] if not boards.is_empty() else null

func _apply_to_game_manager(data: Dictionary) -> void:
	if data.has("power_meter"):
		GameManager.power_meter        = float(data["power_meter"])
	if data.has("passive_regen_rate"):
		GameManager.passive_regen_rate = float(data["passive_regen_rate"])
	if data.has("resources"):
		for key in data["resources"]:
			if key in GameManager.resources:
				GameManager.resources[key] = int(data["resources"][key])
	if data.has("storage_caps"):
		for key in data["storage_caps"]:
			if key in GameManager.storage_caps:
				GameManager.storage_caps[key] = int(data["storage_caps"][key])
	if data.has("gold"):
		GameManager.gold               = float(data["gold"])
	for key in ["power_meter_bonus","dropper_speed_multiplier","contract_gold_multiplier",
			"raw_rate_multiplier","energy_peg_bonus","contract_time_bonus","portal_energy_bonus"]:
		if data.has(key):
			GameManager.set(key, float(data[key]))
	if data.has("has_splitter_peg"):
		GameManager.has_splitter_peg   = bool(data["has_splitter_peg"])
	if data.has("has_energy_peg"):
		GameManager.has_energy_peg     = bool(data["has_energy_peg"])
	if data.has("has_gate"):
		GameManager.has_gate           = bool(data["has_gate"])
	if data.has("auto_dropper_count"):
		GameManager.auto_dropper_count = int(data["auto_dropper_count"])
	# Shop purchases
	if data.has("active_skin"):
		GameManager.active_skin = str(data["active_skin"])
	if data.has("owned_skins") and data["owned_skins"] is Array:
		GameManager.owned_skins = data["owned_skins"].duplicate()
		# Always ensure "default" is present
		if "default" not in GameManager.owned_skins:
			GameManager.owned_skins.push_front("default")
	if data.has("active_theme"):
		GameManager.active_theme = str(data["active_theme"])
	if data.has("offline_overdrive_tier"):
		GameManager.offline_overdrive_tier  = int(data["offline_overdrive_tier"])
	if data.has("contract_refresh_tokens"):
		GameManager.contract_refresh_tokens = int(data["contract_refresh_tokens"])
	if data.has("has_golden_drone"):
		GameManager.has_golden_drone  = bool(data["has_golden_drone"])
	if data.has("has_expanded_silos"):
		GameManager.has_expanded_silos = bool(data["has_expanded_silos"])
	# Audio settings — applied directly to AudioManager
	if data.has("sfx_enabled"):
		AudioManager.set_sfx_enabled(bool(data["sfx_enabled"]))
	if data.has("music_enabled"):
		AudioManager.set_music_enabled(bool(data["music_enabled"]))
	if data.has("sfx_volume_db"):
		AudioManager.set_sfx_volume_db(float(data["sfx_volume_db"]))
	if data.has("music_volume_db"):
		AudioManager.set_music_volume_db(float(data["music_volume_db"]))
	# Dropper positions restored after Board is ready via call_deferred
	if data.has("dropper_positions") and not data["dropper_positions"].is_empty():
		call_deferred("_restore_droppers", data["dropper_positions"])
	if data.has("upgrades"):
		UpgradeManager.apply_save_data(data["upgrades"])
	if data.has("buffs"):
		BuffManager.apply_save_data(data["buffs"])
		BuffManager.reapply_all()
	if data.has("level"):
		LevelManager.apply_save_data(data["level"])
	if data.has("contracts"):
		ContractManager.apply_save_data(data["contracts"])
	if data.has("gate") and not data["gate"].is_empty():
		call_deferred("_restore_gate", data["gate"])

# -----------------------------------------------------------------------------
# Wipe save — useful for testing or a "reset" button in Settings
# -----------------------------------------------------------------------------
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

# -----------------------------------------------------------------------------
# hard_reset — wipes save file AND resets all autoload in-memory state.
#
# reload_current_scene() recreates scene nodes (Board, TabNavigator, etc.)
# but autoloads PERSIST across reloads — they keep their runtime values.
# We must manually restore every autoload to its startup defaults before
# reloading, otherwise the fresh Board reads stale level/buff/upgrade data.
# -----------------------------------------------------------------------------
func hard_reset() -> void:
	# 1. Delete the save file so a future load finds nothing
	delete_save()

	# 2. GameManager — all gameplay fields back to factory defaults
	GameManager.power_meter              = GameManager.POWER_METER_MAX
	GameManager.passive_regen_rate       = 1.0
	for res in GameManager.resources:
		GameManager.resources[res] = 0
	for res in GameManager.storage_caps:
		GameManager.storage_caps[res] = 500
	GameManager.gold                     = 0.0
	GameManager.power_meter_bonus        = 0.0
	GameManager.dropper_speed_multiplier = 1.0
	GameManager.contract_gold_multiplier = 1.0
	GameManager.raw_rate_multiplier      = 1.0
	GameManager.energy_peg_bonus         = 0.0
	GameManager.contract_time_bonus      = 0.0
	GameManager.portal_energy_bonus      = 0.0
	GameManager.offline_multiplier       = 0.1
	GameManager.has_splitter_peg         = false
	GameManager.has_energy_peg           = false
	GameManager.has_gate                 = false
	GameManager.auto_dropper_count       = 0
	GameManager.active_skin              = "default"
	GameManager.owned_skins              = ["default"]
	GameManager.active_theme             = "factory"
	GameManager.offline_overdrive_tier   = 0
	GameManager.contract_refresh_tokens  = 0
	GameManager.has_golden_drone         = false
	GameManager.has_expanded_silos       = false

	# 3. LevelManager
	LevelManager.current_level        = 1
	LevelManager.contracts_this_level = 0

	# 4. BuffManager — clear all stacks
	BuffManager.buff_counts = {}

	# 5. UpgradeManager — mark every upgrade as unpurchased/unplaced
	for id in UpgradeManager.UPGRADES:
		UpgradeManager.UPGRADES[id]["purchased"] = false
		if UpgradeManager.UPGRADES[id].has("placed"):
			UpgradeManager.UPGRADES[id]["placed"] = false
	UpgradeManager.pending_placement = ""

	# 6. ContractManager — regenerate all slots from scratch
	#    apply_save_data([]) clears then refills to SLOT_COUNT fresh contracts
	ContractManager.apply_save_data([])

	# 7. Reload scene — Board._ready() reads LevelManager.current_level (1),
	#    WarehouseUI._ready() reads clean GameManager + empty BuffManager, etc.
	get_tree().reload_current_scene()

func _get_gate_manager() -> Node:
	var board := _get_board()
	if board and board.has_node("GateManager"):
		return board.get_node("GateManager")
	return null

func _restore_gate(data: Dictionary) -> void:
	var gm := _get_gate_manager()
	if gm and gm.has_method("restore_from_save"):
		gm.restore_from_save(data)

func _restore_droppers(positions: Array) -> void:
	var board := _get_board()
	if board and board.has_method("restore_droppers"):
		# Reset count so restore_droppers can re-add them cleanly
		GameManager.auto_dropper_count = 0
		board.restore_droppers(positions)

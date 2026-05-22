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
	print("Saving data")
	var data: Dictionary = {
		# Power meter
		"power_meter":        GameManager.power_meter,
		"passive_regen_rate": GameManager.passive_regen_rate,
		# Resources
		"resources":          GameManager.resources.duplicate(),
		"storage_caps":       GameManager.storage_caps.duplicate(),
		# Gold
		"gold":               GameManager.gold,
		# Upgrade flags
		"has_splitter_peg":   GameManager.has_splitter_peg,
		"has_energy_peg":     GameManager.has_energy_peg,
		"has_gate":           GameManager.has_gate,
		"auto_dropper_count": GameManager.auto_dropper_count,
		# Auto-dropper positions
		"dropper_positions":  _get_board().get_dropper_positions() if _get_board() else [],
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
		print("Failed file access")
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
	print("Applying saved state")
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
	if data.has("has_splitter_peg"):
		GameManager.has_splitter_peg   = bool(data["has_splitter_peg"])
	if data.has("has_energy_peg"):
		GameManager.has_energy_peg     = bool(data["has_energy_peg"])
	if data.has("has_gate"):
		GameManager.has_gate           = bool(data["has_gate"])
	if data.has("auto_dropper_count"):
		GameManager.auto_dropper_count = int(data["auto_dropper_count"])
	# Dropper positions restored after Board is ready via call_deferred
	if data.has("dropper_positions") and not data["dropper_positions"].is_empty():
		call_deferred("_restore_droppers", data["dropper_positions"])

# -----------------------------------------------------------------------------
# Wipe save — useful for testing or a "reset" button in Settings
# -----------------------------------------------------------------------------
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _restore_droppers(positions: Array) -> void:
	var board := _get_board()
	if board and board.has_method("restore_droppers"):
		# Reset count so restore_droppers can re-add them cleanly
		GameManager.auto_dropper_count = 0
		board.restore_droppers(positions)

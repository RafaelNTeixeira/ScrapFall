# =============================================================================
# AudioManager.gd
# Autoload Singleton — register in Project > Project Settings > Autoload
# Name it exactly "AudioManager"
#
# Add your .wav or .ogg files to res://audio/ and assign them in the Inspector
# on the AudioManager node (or swap the @export vars for preloads once you
# have real assets). Placeholder-safe: every play call checks for null first
# so the game never crashes from a missing sound file.
# =============================================================================
extends Node

# -----------------------------------------------------------------------------
# Exported audio streams — drag .wav/.ogg files here in the Inspector
# -----------------------------------------------------------------------------
@export var sfx_ball_spawn:    AudioStream
@export var sfx_peg_hit:       AudioStream
@export var sfx_peg_energy:    AudioStream   # distinct sound for energy peg
@export var sfx_slot_collect:  AudioStream
@export var sfx_no_energy:     AudioStream   # buzz when meter is empty
@export var sfx_storage_full:  AudioStream   # warning when resource cap hit
@export var sfx_tab_switch:    AudioStream

@export var music_board:       AudioStream   # looping board background music

# -----------------------------------------------------------------------------
# Settings — toggled by SettingsUI (Phase 10)
# -----------------------------------------------------------------------------
var sfx_enabled:    bool  = true
var music_enabled:  bool  = true
var sfx_volume_db:  float = 0.0    # applied per-play; range -80..0
var music_volume_db: float = -6.0  # applied to _music_player

# -----------------------------------------------------------------------------
# Internal players
# -----------------------------------------------------------------------------
# Pool of one-shot SFX players so rapid sounds don't cancel each other
const SFX_POOL_SIZE: int = 6
var _sfx_pool:   Array[AudioStreamPlayer] = []
var _pool_index: int = 0

var _music_player: AudioStreamPlayer

func _ready() -> void:
	# Build SFX pool
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"          # route to SFX bus (create in AudioServer if needed)
		add_child(p)
		_sfx_pool.append(p)

	# Single music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus    = "Music"
	_music_player.volume_db = -6.0
	add_child(_music_player)

	# Connect GameManager signals so sounds fire automatically
	GameManager.ball_drop_failed.connect(func(): play(sfx_no_energy))
	GameManager.storage_full.connect(func(_r): play(sfx_storage_full))

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
func play(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % SFX_POOL_SIZE
	player.stream    = stream
	player.volume_db = sfx_volume_db + volume_db   # master sfx vol + per-call offset
	player.play()

func play_music() -> void:
	if not music_enabled or music_board == null:
		return
	if _music_player.playing:
		return
	_music_player.stream    = music_board
	_music_player.volume_db = music_volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for p in _sfx_pool:
			p.stop()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled:
		play_music()
	else:
		stop_music()

func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db
	# Running sounds keep their volume; new plays pick up sfx_volume_db automatically.

func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	_music_player.volume_db = db

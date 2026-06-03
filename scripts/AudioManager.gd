# =============================================================================
# AudioManager.gd
# Autoload — point at AudioManager.tscn (not the .gd) so @export slots appear
# in the Inspector. Name it exactly "AudioManager" in Project Settings > Autoload.
#
# MUSIC PLAYLIST
#   1. Set "Music Playlist" array size in the Inspector and drag .ogg/.wav files in.
#   2. Enable "Music Shuffle" to randomise playback order.
#   3. Tracks auto-advance when each one finishes; the playlist loops indefinitely.
#   4. Call next_track() / prev_track() to skip programmatically.
#
# SFX
#   All play() calls are null-safe — missing streams are silently ignored.
# =============================================================================
extends Node

# -----------------------------------------------------------------------------
# SFX streams — drag files here in the Inspector
# -----------------------------------------------------------------------------
@export var sfx_ball_spawn:   AudioStream
@export var sfx_peg_hit:      AudioStream
@export var sfx_peg_energy:   AudioStream   # distinct sound for energy pegs
@export var sfx_slot_collect: AudioStream
@export var sfx_no_energy:    AudioStream   # buzz when energy too low
@export var sfx_storage_full: AudioStream   # warning when resource cap hit
@export var sfx_tab_switch:   AudioStream

# -----------------------------------------------------------------------------
# Music playlist — drag any number of tracks here in the Inspector
# -----------------------------------------------------------------------------
@export var music_playlist: Array[AudioStream] = []
@export var music_shuffle:  bool = false   # randomise playback order

# Emitted whenever a new track starts playing (index into music_playlist)
signal track_changed(track_index: int)

# -----------------------------------------------------------------------------
# Settings — controlled by SettingsUI
# -----------------------------------------------------------------------------
var sfx_enabled:     bool  = true
var music_enabled:   bool  = true
var sfx_volume_db:   float = 0.0
var music_volume_db: float = -6.0

# -----------------------------------------------------------------------------
# Internal state
# -----------------------------------------------------------------------------
const SFX_POOL_SIZE: int = 6
var _sfx_pool:    Array[AudioStreamPlayer] = []
var _pool_index:  int = 0

var _music_player:     AudioStreamPlayer
var _playlist_pos:     int = 0   # position in _play_order
var _play_order:       Array[int] = []   # indices into music_playlist

# =============================================================================
func _ready() -> void:
	# SFX pool — round-robin so overlapping hits don't cancel each other
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# Single music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus        = "Music"
	_music_player.volume_db  = music_volume_db
	_music_player.finished.connect(_on_track_finished)
	add_child(_music_player)

	# Auto-wire GameManager signals
	GameManager.ball_drop_failed.connect(func(): play(sfx_no_energy))
	GameManager.storage_full.connect(func(_r):   play(sfx_storage_full))

# =============================================================================
# SFX API
# =============================================================================
## Play a one-shot sound effect.
## volume_offset_db is added on top of the master sfx_volume_db.
func play(stream: AudioStream, volume_offset_db: float = 0.0) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _sfx_pool[_pool_index]
	_pool_index      = (_pool_index + 1) % SFX_POOL_SIZE
	player.stream    = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.play()

# =============================================================================
# Music playlist API
# =============================================================================
## Start the playlist from the beginning (or a random position if shuffle).
## Safe to call repeatedly — does nothing if music is already playing.
func play_music() -> void:
	if not music_enabled or music_playlist.is_empty():
		return
	if not is_instance_valid(_music_player) or _music_player.playing:
		return
	_build_play_order()
	_playlist_pos = 0
	_play_current_track()

## Stop playback and reset playlist position.
func stop_music() -> void:
	if not is_instance_valid(_music_player):
		return
	_music_player.stop()

## Skip forward one track.
func next_track() -> void:
	if music_playlist.is_empty():
		return
	_playlist_pos = (_playlist_pos + 1) % _play_order.size()
	_play_current_track()

## Skip back one track.
func prev_track() -> void:
	if music_playlist.is_empty():
		return
	_playlist_pos = (_playlist_pos - 1 + _play_order.size()) % _play_order.size()
	_play_current_track()

## Returns the index of the currently playing track in music_playlist, or -1.
func current_track_index() -> int:
	if _play_order.is_empty() or _playlist_pos >= _play_order.size():
		return -1
	return _play_order[_playlist_pos]

## Returns the filename (without extension) of the current track, or "".
func current_track_name() -> String:
	var idx: int = current_track_index()
	if idx < 0 or music_playlist[idx] == null:
		return ""
	return music_playlist[idx].resource_path.get_file().get_basename()

# =============================================================================
# Settings setters (called by SettingsUI)
# =============================================================================
func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not enabled:
		for p in _sfx_pool:
			p.stop()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if not is_instance_valid(_music_player):
		return
	if enabled:
		play_music()
	else:
		stop_music()

func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db

func set_music_volume_db(db: float) -> void:
	music_volume_db = db
	if not is_instance_valid(_music_player):
		return
	_music_player.volume_db = db

# =============================================================================
# Internal helpers
# =============================================================================
func _play_current_track() -> void:
	if not is_instance_valid(_music_player):
		return
	if music_playlist.is_empty() or _play_order.is_empty():
		return

	var track_idx: int         = _play_order[_playlist_pos]
	var stream:    AudioStream = music_playlist[track_idx]

	if stream == null:
		# Skip null slots — advance to the next
		_on_track_finished()
		return

	_music_player.stream    = stream
	_music_player.volume_db = music_volume_db
	_music_player.play()
	emit_signal("track_changed", track_idx)

func _on_track_finished() -> void:
	if not music_enabled:
		return
	_playlist_pos += 1
	# Re-shuffle when the full playlist has played through
	if _playlist_pos >= _play_order.size():
		_playlist_pos = 0
		if music_shuffle:
			_build_play_order()   # new shuffle so consecutive runs differ
	_play_current_track()

func _build_play_order() -> void:
	_play_order.clear()
	for i in music_playlist.size():
		_play_order.append(i)
	if music_shuffle:
		_play_order.shuffle()

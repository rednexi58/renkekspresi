class_name AudioService
extends Node
## Music and sound effects. Respects the player's settings, ducks nothing and never
## stops other apps' audio (the iOS audio session stays "ambient" by default in Godot).

## Background loops by season (original compositions, see tools/compose_music.py).
const MUSIC := {
	Season.Kind.WINTER: preload("res://assets/audio/winter_lights.ogg"),
	Season.Kind.SUMMER: preload("res://assets/audio/summer_breeze.ogg"),
}
const MUSIC_DB := -15.0
const FADE_SECONDS := 1.2
const SOUNDS := {
	"tap": preload("res://assets/audio/tap.wav"),
	"match": preload("res://assets/audio/match.wav"),
	"fill": preload("res://assets/audio/fill.wav"),
	"win": preload("res://assets/audio/win.wav"),
	"lose": preload("res://assets/audio/lose.wav"),
	"whistle": preload("res://assets/audio/whistle.wav"),
}
const VOICES := 6

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _sound_on := true
var _music_on := true
var _season: Season.Kind = Season.Kind.WINTER


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = _looping(MUSIC[_season])
	_music.volume_db = MUSIC_DB
	add_child(_music)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -4.0
		add_child(voice)
		_voices.append(voice)


static func _looping(source: AudioStream) -> AudioStream:
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


## Switches to the season's loop with a short fade (no-op if it is already playing).
func set_season(season: Season.Kind) -> void:
	if season == _season:
		return
	_season = season
	if not _music_on or not _music.playing:
		_music.stream = _looping(MUSIC[season])
		return
	var fade := create_tween()
	fade.tween_property(_music, "volume_db", -40.0, FADE_SECONDS * 0.5)
	fade.tween_callback(func() -> void:
		_music.stream = _looping(MUSIC[_season])
		_music.play())
	fade.tween_property(_music, "volume_db", MUSIC_DB, FADE_SECONDS * 0.5)


func apply_settings(music_on: bool, sound_on: bool) -> void:
	_sound_on = sound_on
	_music_on = music_on
	if music_on and not _music.playing:
		_music.play()
	elif not music_on and _music.playing:
		_music.stop()


func play(sound: String) -> void:
	if not _sound_on or not SOUNDS.has(sound):
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = SOUNDS[sound]
	voice.pitch_scale = randf_range(0.96, 1.04) if sound == "match" else 1.0
	voice.play()

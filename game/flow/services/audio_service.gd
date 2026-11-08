class_name AudioService
extends Node
## Music and sound effects. Respects the player's settings, ducks nothing and never
## stops other apps' audio (the iOS audio session stays "ambient" by default in Godot).

const MUSIC := preload("res://assets/audio/calm_journey.ogg")
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


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	var stream := MUSIC.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = -14.0
	add_child(_music)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -4.0
		add_child(voice)
		_voices.append(voice)


func apply_settings(music_on: bool, sound_on: bool) -> void:
	_sound_on = sound_on
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

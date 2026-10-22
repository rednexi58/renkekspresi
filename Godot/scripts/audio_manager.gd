extends Node
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var last_play: Dictionary = {}
var last_haptic=-1000
const COOLDOWNS={"tap":90,"match":550,"fill":320,"win":1200,"lose":1200,"whistle":2000}
const VOLUMES={"tap":-18.0,"match":-23.0,"fill":-18.0,"win":-14.0,"lose":-17.0,"whistle":-22.0}
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 for key in COOLDOWNS:streams[key]=load("res://assets/audio/"+key+".wav")
 for i in range(3):
  var player=AudioStreamPlayer.new();player.bus="Master";add_child(player);players.append(player)
func play(key: String,pitch: float=1.0) -> void:
 if not SaveData.data.sound or not streams.has(key):return
 var now=Time.get_ticks_msec()
 if now-int(last_play.get(key,-10000))<int(COOLDOWNS[key]):return
 if key=="match" and now-int(last_play.get("fill",-10000))<350:return
 var playing=0
 for voice in players:
  if voice.playing:playing+=1
 if playing>=2 and key in ["tap","match"]:return
 last_play[key]=now
 var player=players[next_voice%players.size()];next_voice+=1
 player.stream=streams[key];player.volume_db=VOLUMES[key];player.pitch_scale=clampf(pitch,.95,1.05);player.play()
func vibrate(duration_ms: int=12) -> void:
 var now=Time.get_ticks_msec()
 if now-last_haptic<200:return
 last_haptic=now
 if SaveData.data.haptics and OS.has_feature("mobile"):Input.vibrate_handheld(mini(16,duration_ms),.22)

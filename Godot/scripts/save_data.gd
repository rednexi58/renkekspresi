extends Node
## Local-only saves. No advertising, tracking SDK, network ID or online telemetry.
const PATH = "user://train_jam_v015_test.json"
const BACKUP = "user://train_jam_v015_test.bak"
var data: Dictionary = {
 "schema": 1, "campaign": "v019", "unlocked": 1, "stars": {}, "best_seconds": {},
 "sound": true, "haptics": true, "quality": "auto", "tutorial_seen": false,
 "test_vip": false, "test_paid": false, "language": "auto", "records_v027": {}, "sessions": 0, "days": [], "attempts": [], "last_level": 0
}
var loaded_ok = false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 load_save()
 data.sessions = int(data.sessions) + 1
 var today = Time.get_date_string_from_system()
 if not data.days.has(today):
  data.days.append(today)
 commit()

func load_save() -> void:
 for candidate in [PATH, BACKUP]:
  if not FileAccess.file_exists(candidate):
   continue
  var f = FileAccess.open(candidate, FileAccess.READ)
  if not f:
   continue
  var parsed = JSON.parse_string(f.get_as_text())
  if parsed is Dictionary and int(parsed.get("schema", 0)) == 1:
   data.campaign=str(parsed.get("campaign",""))
   for key in data:
    if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
     data[key] = parsed[key]
    elif parsed.has(key) and key in ["unlocked", "sessions", "last_level"] and (parsed[key] is float or parsed[key] is int):
     data[key] = int(parsed[key])
   if data.campaign != "v019":
    var mapping={"0":"0","1":"5","2":"14","3":"24"}
    for key_name in ["stars","best_seconds"]:
     var migrated={}
     for old_key in data[key_name]:
      migrated[mapping.get(old_key,old_key)]=data[key_name][old_key]
     data[key_name]=migrated
    data.last_level=int(mapping.get(str(data.last_level),str(data.last_level)))
    data.unlocked=30
    data.campaign="v019"
   data.unlocked = clampi(int(data.unlocked), 1, 100)
   data.last_level = clampi(int(data.last_level), 0, 99)
   if not data.quality in ["auto", "high", "low"]:
    data.quality = "auto"
   loaded_ok = true
   return

func commit() -> bool:
 var temp = PATH + ".tmp"
 var f = FileAccess.open(temp, FileAccess.WRITE)
 if not f:
  push_warning("Local save unavailable; this session remains playable.")
  return false
 f.store_string(JSON.stringify(data))
 f.flush()
 f.close()
 if FileAccess.file_exists(PATH):
  DirAccess.copy_absolute(PATH, BACKUP)
 return DirAccess.rename_absolute(temp, PATH) == OK

func complete_level(index: int, stars: int, seconds: float) -> void:
 var key = str(index)
 data.unlocked = mini(100, maxi(int(data.unlocked), index + 2))
 data.stars[key] = maxi(stars, int(data.stars.get(key, 0)))
 data.best_seconds[key] = minf(seconds, float(data.best_seconds.get(key, 99999)))
 data.last_level = mini(99, index + 1)
 commit()

func record_attempt(index: int, outcome: String, seconds: float, taps: int, peak: int) -> void:
 data.attempts.append({"level": index + 1, "outcome": outcome, "seconds": snappedf(seconds, 0.01), "taps": taps, "peak_slots": peak, "date": Time.get_date_string_from_system()})
 if data.attempts.size() > 300:
  data.attempts.pop_front()
 commit()

func set_option(key: String, value: Variant) -> void:
 if key in ["sound", "haptics", "quality", "tutorial_seen", "language"]:
  data[key] = value
  commit()


func record_score(index:int,seconds:float,category:String)->void:
 if not is_finite(seconds) or seconds<=0 or index<0 or index>=100:return
 var records:Dictionary=data.records_v027
 var bucket:Dictionary=records.get(category,{})
 bucket[str(index)]=minf(seconds,float(bucket.get(str(index),INF)))
 records[category]=bucket
 commit()

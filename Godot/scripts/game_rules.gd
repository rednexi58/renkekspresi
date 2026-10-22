class_name GameRules
extends RefCounted
## v0.15: physical exposure, finite capacity, directional exits and recoil.
## The engine and tests share this deterministic state machine.
const GAP=1.8
const FIRST_GAP=2.2
var train: Array=[]
var wagon_ids: Array=[]
var distances: Array=[]
var parking: Array=[]
var slots: Array=[-1,-1,-1]
var slot_ids: Array=[-1,-1,-1]
var slot_ready: Array=[0.0,0.0,0.0]
var order: Array=[]
var targets: Array=[-1,-1,-1]
var departures: Array=[]
var jammed=false
var mode="loop"
var idle_seconds=75.0
var unloading_open=false
var departure_seconds=3.0/1.15
var prepare_seconds=4.0/1.15
var danger_speed_factor=.8
const POST_TEMPO=2.75
const MAX_SLOTS=6
var vip_active=false
var paid_active=false
var reward_slots=0
var collector_capacity=1
var match_all=false
var match_zone=false
var loading_distance=0.0
var loading_end=0.0
var loading_fraction=.50
var recoil_per_unit=1.45
var approach_speed=.9
var recoil_left=0.0
var end_distance=0.0
var brake_left=0.0
var brake_distance=0.0
var failure_reason=""
var arrival_seconds=.26
var active_count=2
var guided=true
var hint_uses=0
var dispatch_seconds=.75
var status="ready"
var elapsed=0.0
var head_distance=0.0
var track_length=70.0
var speed=5.5
var total=0
var taps=0
var blocked_taps=0
var peak_slots=0
var undo_left=2
var reward_used=false
var continue_used=false
var par_laps=3
var start_head=0.0
func reset(level: Dictionary) -> void:
 train=[];wagon_ids=[];distances=[];parking=level.parking.duplicate(true)
 for c in level.train:train.append(int(c))
 for i in range(train.size()):wagon_ids.append(i)
 slots=[-1,-1,-1];slot_ids=[-1,-1,-1];slot_ready=[0.0,0.0,0.0];targets=[-1,-1,-1];order=[]
 guided=bool(level.get("guided",true));hint_uses=0;dispatch_seconds=float(level.get("dispatch_seconds",.75))/1.75
 mode=str(level.get("mode","loop"));idle_seconds=float(level.get("idle_seconds",75));brake_left=0;recoil_left=0;failure_reason=""
 unloading_open=mode!="rescue"
 departures=[];jammed=false;active_count=int(level.get("active_count",2))
 total=train.size();elapsed=0;taps=0;blocked_taps=0;peak_slots=0;undo_left=2;reward_used=false;continue_used=false;reward_slots=0;vip_active=false;paid_active=false
 speed=float(level.speed);par_laps=int(level.par_laps);status="ready"
 collector_capacity=int(level.get("collector_capacity",1));match_all=level.get("match_scope","")=="all";match_zone=level.get("match_scope","")=="zone"
 loading_fraction=float(level.get("loading_fraction",.50));recoil_per_unit=float(level.get("recoil_per_unit",1.45));approach_speed=float(level.get("approach_speed",.9))
 for item in parking:
  item.state="parked";item.capacity=int(item.get("capacity",collector_capacity));item.remaining=item.capacity
func configure_track(length: float) -> void:
 track_length=length
 # Initial train is on the loop, approaching the station from the right.
 start_head=.8 if mode=="rescue" else track_length-5.0
 end_distance=track_length-.9
 if mode=="rescue":speed=approach_speed
 brake_distance=recoil_per_unit*.80
 loading_distance=start_head+(end_distance-start_head)*loading_fraction
 loading_end=end_distance-.2
 head_distance=start_head;distances=[]
 for i in range(train.size()):distances.append(head_distance-FIRST_GAP-i*GAP)
func blockers(id: int) -> Array:
 var result: Array=[]
 if id<0 or id>=parking.size():return result
 var item=parking[id]
 var key=int(item.get("requires",-1))
 if key>=0 and parking[key].state=="parked":result.append(key)
 var dx=int(item.get("dx",item.get("dir",1)));var dz=int(item.get("dz",0))
 for other in parking:
  if other.state!="parked" or other.id==item.id or result.has(int(other.id)):continue
  var x=int(other.col)-int(item.col);var z=int(other.row)-int(item.row)
  # Exact lattice ray; diagonal exits must not block a whole row and column.
  if (dx!=0 or dz!=0) and x*dz==z*dx and x*dx+z*dz>0:result.append(int(other.id))
 return result
func available(id: int) -> bool:
 return id>=0 and id<parking.size() and parking[id].state=="parked" and blockers(id).is_empty()
func is_locked(id: int) -> bool:
 if id<0 or id>=parking.size():return false
 var key=int(parking[id].get("requires",-1))
 return key>=0 and parking[key].state=="parked"
func danger() -> float:
 return clampf((head_distance-start_head)/maxf(1,end_distance-start_head),0,1) if mode=="rescue" else 0.0
func choose(id: int) -> Dictionary:
 if status!="playing":return {}
 if is_locked(id):blocked_taps+=1;return {"error":"locked"}
 if not available(id):blocked_taps+=1;return {"error":"blocked"}
 var slot=slots.find(-1)
 if slot<0:return {"error":"full"}
 var color=int(parking[id].color)
 parking[id].state="queued";slots[slot]=color;slot_ids[slot]=id;slot_ready[slot]=elapsed+arrival_seconds;targets[slot]=-1
 order.append(id);taps+=1;peak_slots=maxi(peak_slots,slots.size()-slots.count(-1))
 jammed=false
 return {"slot":slot,"color":color,"parking_id":id,"wagon_id":-1}
func can_collect(index: int) -> bool:
 return unloading_open and index>=0 and index<train.size() and (not match_zone or (float(distances[index])+.00001>=loading_distance and float(distances[index])<=loading_end))
func zone_count(color: int) -> int:
 var count=0
 for i in range(train.size()):
  if int(train[i])==color and can_collect(i):count+=1
 return count
func active_colors() -> Array:
 if match_zone:return [0,1,2,3,4]
 if match_all:
  var colors: Array=[]
  for color in range(5):
   if train.has(color):colors.append(color)
  return colors
 return train.slice(0,mini(active_count,train.size()))
func future_colors() -> Array:
 if match_zone:
  var next: Array=[]
  for i in range(train.size()):
   if not can_collect(i) and (next.is_empty() or next.back()!=train[i]):next.append(train[i])
   if next.size()>=3:break
  return next
 return train.slice(mini(active_count,train.size()),mini(active_count+4,train.size()))
func assign_targets() -> void:
 if not unloading_open:return
 for slot in range(slots.size()):
  if int(slots[slot])<0 or int(targets[slot])>=0 or elapsed+.000001<float(slot_ready[slot]):continue
  # Finish the oldest same-color collector before splitting its five-unit batch.
  var older_same_color=false
  if match_zone:
   for other in range(slots.size()):
    if other!=slot and int(slots[other])==int(slots[slot]) and order.find(slot_ids[other])<order.find(slot_ids[slot]):older_same_color=true;break
  if older_same_color:continue
  for index in target_candidates():
   if not can_collect(index):continue
   var wid=int(wagon_ids[index])
   if int(train[index])==int(slots[slot]) and not targets.has(wid):
    targets[slot]=wid;slot_ready[slot]=elapsed+dispatch_seconds
    departures.append({"slot":slot,"parking_id":int(slot_ids[slot]),"wagon_id":wid,"color":int(slots[slot])})
    break
func update_jam() -> void:
 if not unloading_open or match_zone:jammed=false;return
 jammed=not slots.has(-1) and targets.all(func(x):return int(x)<0)
 for ready in slot_ready:
  if float(ready)>elapsed:jammed=false
func undo() -> bool:
 if status!="playing" or undo_left<=0 or order.is_empty():return false
 var id=int(order.pop_back());var slot=slot_ids.find(id)
 if slot<0:return false
 parking[id].state="parked";slots[slot]=-1;slot_ids[slot]=-1;slot_ready[slot]=0;targets[slot]=-1
 undo_left-=1;jammed=false;return true
func target_candidates() -> Array:
 return range(train.size() if (match_all or match_zone) else mini(active_count,train.size()))
func append_slot() -> void:
 slots.append(-1);slot_ids.append(-1);slot_ready.append(0.0);targets.append(-1)
func grant_vip_slot() -> bool:
 if vip_active:return false
 vip_active=true
 if slots.size()<MAX_SLOTS:append_slot()
 return true
func grant_paid_slot()->bool:
 if paid_active:return false
 paid_active=true
 if slots.size()<MAX_SLOTS:append_slot()
 return true
func locked_slot_kinds()->Array:
 var kinds=[]
 if not vip_active:kinds.append("vip")
 if not reward_used:kinds.append("reward")
 if not paid_active:kinds.append("paid")
 return kinds
func can_unlock_slot() -> bool:
 return status=="playing" and not reward_used and slots.size()<MAX_SLOTS
func unlock_reward_slot() -> bool:
 if not can_unlock_slot():return false
 jammed=false;reward_used=true;reward_slots+=1;append_slot();return true
func tick(delta: float) -> Array:
 departures=[]
 var matches: Array=[]
 if status!="playing":return matches
 var remaining=maxf(0,delta)
 while remaining>.000001 and status=="playing":
  var step=minf(.025,remaining);remaining-=step;elapsed+=step
  var old_head=head_distance
  if not jammed:
   var advance_speed=speed
   if mode=="rescue":
    if not unloading_open:
     advance_speed=(end_distance-start_head)*(.5/departure_seconds if danger()<.5 else .25/prepare_seconds)
    elif unloading_open:
     advance_speed*=danger_speed_factor*POST_TEMPO
     if danger()<.75:advance_speed*=1.15 # Shorter recovery after successful collections.
   head_distance+=advance_speed*step
   if recoil_left>0:
    var recoil_step=minf(recoil_left,14.0*step)
    head_distance=maxf(start_head,head_distance-recoil_step);recoil_left-=recoil_step
   if mode=="rescue" and danger()>=.75:unloading_open=true
   brake_left=maxf(0,brake_left-step)
  var movement=head_distance-old_head
  for i in range(train.size()):
   distances[i]=move_toward(float(distances[i])+movement,head_distance-FIRST_GAP-i*GAP,step*5.45)
  assign_targets()
  for slot in range(slots.size()):
   if int(slots[slot])<0 or elapsed+.000001<float(slot_ready[slot]):continue
   var index=wagon_ids.find(int(targets[slot]))
   if index<0:continue
   if not can_collect(index):targets[slot]=-1;slot_ready[slot]=elapsed+.045;continue
   var id=int(slot_ids[slot]);var color=int(train[index]);var wagon_id=int(wagon_ids[index])
   parking[id].remaining-=1;targets[slot]=-1
   if int(parking[id].remaining)<=0:
    parking[id].state="done";order.erase(id);slots[slot]=-1;slot_ids[slot]=-1
   else:slot_ready[slot]=elapsed+.045
   matches.append({"slot":slot,"color":color,"wagon_id":wagon_id,"parking_id":id,"distance":float(distances[index]),"latency":dispatch_seconds})
   train.remove_at(index);wagon_ids.remove_at(index);distances.remove_at(index)
   if mode=="rescue":
    recoil_left+=brake_distance
    brake_left=.20
  if train.is_empty():status="won"
  elif mode=="rescue" and head_distance>=end_distance:status="lost";failure_reason="arrival"
  update_jam()
 return matches
func laps() -> int:return int((head_distance-start_head)/track_length)+1
func parked_count() -> int:
 var count=0
 for item in parking:
  if item.state=="parked":count+=1
 return count
func stars() -> int:
 return 3 if blocked_taps<=2 and undo_left==2 else (2 if blocked_taps<=6 else 1)

func rescue_continue()->bool:
 if status!="lost" or continue_used:return false
 continue_used=true;status="playing";failure_reason="";jammed=false
 var shift=(end_distance-start_head)*.22
 head_distance=maxf(start_head,head_distance-shift)
 for i in range(distances.size()):distances[i]-=shift
 targets.fill(-1);recoil_left=0
 return_last_collector()
 return true

func return_last_collector()->void:
 # Partial fill is retained; no removed colors are recreated and no collector is gifted.
 if order.is_empty():return
 var id=int(order.pop_back());var slot=slot_ids.find(id)
 if slot>=0:
  parking[id].state="parked";slots[slot]=-1;slot_ids[slot]=-1;slot_ready[slot]=0;targets[slot]=-1

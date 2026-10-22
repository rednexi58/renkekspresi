class_name MultiTrainRules
extends GameRules
## Independent, non-intersecting approach tracks share the collector budget.
## Only physically exposed wagons can be collected; no signal queue.
var train_count=2
var streams:Array=[]
var heads:Array=[]
var opened:Array=[]
var recoils:Array=[]
var waiting:Array=[]
var merge_distance=12.0

func reset(level:Dictionary)->void:
 super.reset(level)
 train_count=int(level.get("train_count",2));streams=[];heads=[];opened=[];recoils=[];waiting=[];continue_used=false
 for s in level.wagon_streams:streams.append(int(s))
 for s in range(train_count):heads.append(.8);opened.append(false);recoils.append(0.0);waiting.append(false)

func configure_track(length:float)->void:
 super.configure_track(length)
 var ranks={}
 for i in range(train.size()):
  var s=stream_of(int(wagon_ids[i]));var rank=int(ranks.get(s,0));ranks[s]=rank+1
  distances[i]=start_head-FIRST_GAP-rank*GAP

func stream_of(wagon_id:int)->int:return int(streams[wagon_id])
func remaining_in(s:int)->int:
 var count=0
 for id in wagon_ids:
  if stream_of(int(id))==s:count+=1
 return count
func tail_of(s:int)->float:
 var tail=float(heads[s])
 for i in range(train.size()):
  if stream_of(int(wagon_ids[i]))==s:tail=minf(tail,float(distances[i]))
 return tail
func danger()->float:
 var d=0.0
 for s in range(train_count):
  if remaining_in(s)>0:d=maxf(d,(float(heads[s])-start_head)/maxf(1,end_distance-start_head))
 return clampf(d,0,1)
func can_collect(index:int)->bool:
 if index<0 or index>=train.size():return false
 var s=stream_of(int(wagon_ids[index]))
 return bool(opened[s]) and float(distances[index])>=loading_distance-.00001 and float(distances[index])<=loading_end

func target_candidates() -> Array:
 # Target the most advanced eligible stream. Same-color collector FIFO is kept by the base engine.
 var lanes=range(train_count)
 lanes.sort_custom(func(a,b):return float(heads[a])>float(heads[b]) if not is_equal_approx(float(heads[a]),float(heads[b])) else a<b)
 var result=[]
 for lane in lanes:
  for i in range(train.size()):
   if stream_of(int(wagon_ids[i]))==lane:result.append(i)
 return result
func future_colors() -> Array:
 var result=[]
 for lane in range(train_count):
  for i in range(train.size()):
   if stream_of(int(wagon_ids[i]))==lane and not can_collect(i):
    result.append(train[i]);break
 return result
func tick(delta:float)->Array:
 departures=[];var matches:Array=[]
 if status!="playing":return matches
 var remaining=maxf(0,delta)
 while remaining>.000001 and status=="playing":
  var step=minf(.025,remaining);remaining-=step;elapsed+=step
  var before=heads.duplicate()
  for s in range(train_count):
   waiting[s]=false
   if remaining_in(s)==0:continue
   var progress=(float(heads[s])-start_head)/maxf(1,end_distance-start_head)
   var pace=approach_speed*danger_speed_factor*POST_TEMPO if opened[s] else (end_distance-start_head)*(.5/departure_seconds if progress<.5 else .25/prepare_seconds)
   if opened[s] and progress<.75:pace*=1.15
   pace*=.88 # v0.24: 12% slower approach and onward motion, collection stays responsive.
   var candidate=float(heads[s])+pace*step
   if float(recoils[s])>0:
    var back=minf(float(recoils[s]),14.0*step);candidate=maxf(start_head,candidate-back);recoils[s]-=back
   heads[s]=maxf(start_head,candidate)
   if (float(heads[s])-start_head)/(end_distance-start_head)>=.75:opened[s]=true
  var ranks={}
  for i in range(train.size()):
   var s=stream_of(int(wagon_ids[i]));var rank=int(ranks.get(s,0));ranks[s]=rank+1
   distances[i]=move_toward(float(distances[i])+float(heads[s])-float(before[s]),float(heads[s])-FIRST_GAP-rank*GAP,step*5.45)
  head_distance=start_head
  for s in range(train_count):
   if remaining_in(s)>0:head_distance=maxf(head_distance,float(heads[s]))
  unloading_open=opened.has(true);brake_left=maxf(0,brake_left-step)
  assign_targets()
  for slot in range(slots.size()):
   if int(slots[slot])<0 or elapsed+.000001<float(slot_ready[slot]):continue
   var index=wagon_ids.find(int(targets[slot]))
   if index<0:continue
   if not can_collect(index):targets[slot]=-1;slot_ready[slot]=elapsed+.045;continue
   var id=int(slot_ids[slot]);var color=int(train[index]);var wid=int(wagon_ids[index]);var s=stream_of(wid)
   parking[id].remaining-=1;targets[slot]=-1
   if int(parking[id].remaining)<=0:
    parking[id].state="done";order.erase(id);slots[slot]=-1;slot_ids[slot]=-1
   else:slot_ready[slot]=elapsed+.045
   matches.append({"slot":slot,"color":color,"wagon_id":wid,"parking_id":id,"distance":float(distances[index]),"latency":dispatch_seconds})
   train.remove_at(index);wagon_ids.remove_at(index);distances.remove_at(index)
   recoils[s]+=brake_distance;brake_left=.20
  if train.is_empty():status="won"
  elif danger()>=1:status="lost";failure_reason="arrival"
 return matches

func rescue_continue()->bool:
 if status!="lost" or continue_used:return false
 continue_used=true;status="playing";failure_reason="";jammed=false
 var before=heads.duplicate();var shift=(end_distance-start_head)*.22
 for s in range(train_count):heads[s]=maxf(start_head,float(heads[s])-shift);recoils[s]=0.0
 for i in range(distances.size()):
  var s=stream_of(int(wagon_ids[i]));distances[i]+=float(heads[s])-float(before[s])
 head_distance=float(heads.max());targets.fill(-1);return_last_collector()
 return true

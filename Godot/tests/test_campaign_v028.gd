extends SceneTree
var failures=0
func check(value:bool,message:String)->void:
 if not value:failures+=1;push_error(message)
func fresh(l:Dictionary)->GameRules:
 var r=MultiTrainRules.new() if int(l.get("train_count",1))>1 else GameRules.new()
 r.reset(l);var rail=RailSpline.new()
 if int(l.get("train_count",1))>1:rail.configure_junction(int(l.layout),int(l.train_count))
 else:rail.configure_open(int(l.layout))
 r.configure_track(rail.total_length);rail.free();r.status="playing";return r
func run_level(l:Dictionary,random_seed:int=-1,interval:float=.65)->Dictionary:
 var r=fresh(l);var at=0;var next=0.0;var trace=[];var rng=RandomNumberGenerator.new();rng.seed=random_seed
 while r.status=="playing" and r.elapsed<480:
  if r.elapsed>=next and r.slots.has(-1):
   var id=-1
   if random_seed<0:
    if at<l.design.solution.size():id=int(l.design.solution[at])
   else:
    var options=[]
    for item in r.parking:
     if r.available(int(item.id)):options.append(int(item.id))
    if not options.is_empty():id=options[rng.randi_range(0,options.size()-1)]
   if id>=0:
    var result=r.choose(id)
    if result.has("error"):return {"status":"illegal","time":r.elapsed,"error":result,"id":id}
    trace.append({"t":snapped(r.elapsed,.01),"id":id});at+=1;next=r.elapsed+interval
  r.tick(.05)
 return {"status":r.status,"time":snapped(r.elapsed,.01),"removed":r.total-r.train.size(),"trace":trace}
func _initialize()->void:call_deferred("run")
func run()->void:
 var levels=LevelData.new();check(levels.count()==100,"Campaign needs exactly 100 levels")
 var report=[];var signatures={}
 for l in levels.levels:
  for color in range(5):
   var capacity=0
   for item in l.parking:
    if int(item.color)==color:capacity+=int(item.capacity)
   check(capacity==l.train.count(float(color)) or capacity==l.train.count(color),"Color capacity mismatch "+str(l.id))
  var sig=JSON.stringify([l.train,l.parking]);check(not signatures.has(sig),"Duplicate puzzle");signatures[sig]=true
  var correct=run_level(l);check(correct.status=="won","Solution failed "+str(l.id)+str(correct))
  var human_pace=run_level(l,-1,1.25);check(human_pace.status=="won","Slow solution failed "+str(l.id))
  var idle=fresh(l);idle.tick(200);check(idle.status=="lost","Idle did not lose "+str(l.id))
  var wins=0;var losses=[]
  for seed_value in range(4):
   var random_run=run_level(l,190000+int(l.id)*101+seed_value)
   if random_run.status=="won":wins+=1
   elif losses.size()<2:losses.append(random_run)
  var entry={"level":l.id,"region":l.region,"train_units":l.train.size(),"solution":correct,"slower_solution":human_pace.status,"random_wins":wins,"random_trials":4,"wrong_choices":losses}
  report.append(entry);print("LEVEL ",l.id," ",correct.status," ",correct.time," random ",wins,"/4")
 # Physical window, directional blockers and full-slot rejection remain enforced.
 var r=fresh(levels.get_level(20));r.unloading_open=true
 for position in [r.loading_distance-.01,r.loading_end+.01,-1.0]:
  r.distances[0]=position;check(not r.can_collect(0),"Collected wagon outside its physical window")
 r.distances[0]=r.loading_distance+.01;check(r.can_collect(0),"Valid wagon rejected")
 r=fresh(levels.get_level(20))
 for item in r.parking:
  if not r.available(int(item.id)):
   check(r.choose(int(item.id)).has("error"),"Blocked move accepted");check(r.slots.count(-1)==3,"Blocked move consumed slot");break
 var f=FileAccess.open("res://docs/validation_v026.json",FileAccess.WRITE);f.store_string(JSON.stringify({"failures":failures,"levels":report},"  "))
 print("FAILURES: ",failures);quit(1 if failures else 0)

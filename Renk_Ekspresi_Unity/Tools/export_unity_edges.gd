extends SceneTree
var project=""
func _initialize()->void:
 var args=OS.get_cmdline_user_args();var index=args.find("--unity-project")
 if index<0 or index+1>=args.size():
  printerr("Pass -- --unity-project /absolute/path/to/Renk_Ekspresi_Unity");quit(1);return
 project=args[index+1]
 call_deferred("run")
func snapshot(r:GameRules)->Dictionary:
 return {"elapsed":r.elapsed,"head":r.head_distance,"heads":r.heads.duplicate() if r is MultiTrainRules else [r.head_distance],"status":r.status,"ids":r.wagon_ids.duplicate(),"slots":r.slot_ids.duplicate(),"distances":r.distances.duplicate(),"remaining":r.parking.map(func(c):return c.remaining),"stock":[r.booster_stock.freeze,r.booster_stock.blast,r.booster_stock.recall],"freeze":r.freeze_left,"targets":r.targets.duplicate(),"ready":r.slot_ready.duplicate()}
func run()->void:
 var all=LevelData.new().levels;var cases=[]
 for index in [0,9,19,30,49,69,89,99]:
  for variant in range(2):
   var level=all[index];var rail=RailSpline.new()
   if int(level.get("train_count",1))>1:rail.configure_junction(int(level.layout),int(level.train_count))
   else:rail.configure_open(int(level.layout))
   var r=MultiTrainRules.new() if int(level.get("train_count",1))>1 else GameRules.new();r.reset(level);r.configure_track(rail.total_length);r.status="playing"
   var actions=[];var frames=[];var rng=RandomNumberGenerator.new();rng.seed=901+index;var step=0
   while r.status=="playing" and step<8000:
    if variant==1 and step in [0,1]:
     var ok=r.grant_vip_slot() if step==0 else r.unlock_reward_slot();actions.append({"step":step,"kind":"vip" if step==0 else "slot","ok":ok})
    if step%23==0:
     var choices=[]
     for c in r.parking:
      if r.available(int(c.id)):choices.append(int(c.id))
     if not choices.is_empty():
      var id=choices[rng.randi_range(0,choices.size()-1)];var result=r.choose(id);actions.append({"step":step,"kind":"choose","id":id,"error":result.get("error","")})
    if variant==1 and step%67==0 and step>0:
     var kind=int(step/67)%3;var name=["freeze","blast","recall"][kind];var refill=r.refill_booster(name);actions.append({"step":step,"kind":"refill","id":kind,"ok":refill});var used=r.use_booster(name);actions.append({"step":step,"kind":"boost","id":kind,"error":used.get("error","")})
    r.tick(.05);step+=1
    if step%5==0 or r.status!="playing":var frame=snapshot(r);frame.step=step;frames.append(frame)
   cases.append({"level":level.id,"variant":variant,"actions":actions,"snapshots":frames});rail.free()
 var f=FileAccess.open(project.path_join("Verification/godot_edge_reference.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"cases":cases}));f.flush();f.close();print("EXPORTED 16 edge-case traces");quit()

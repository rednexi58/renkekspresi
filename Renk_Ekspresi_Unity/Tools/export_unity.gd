extends SceneTree
var output=""
var project=""
func _initialize()->void:
 var args=OS.get_cmdline_user_args();var index=args.find("--unity-project")
 if index<0 or index+1>=args.size():
  printerr("Pass -- --unity-project /absolute/path/to/Renk_Ekspresi_Unity");quit(1);return
 project=args[index+1]
 output=project.path_join("Assets/RenkEkspresi/Resources/")
 call_deferred("run")
func vec(v:Vector3)->Dictionary:return {"x":v.x,"y":v.y,"z":-v.z}
func write(path:String,data:Variant)->void:
 var f=FileAccess.open(output+path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.flush();f.close()
func snapshot(r:GameRules)->Dictionary:
 return {"elapsed":r.elapsed,"head":r.head_distance,"heads":r.heads.duplicate() if r is MultiTrainRules else [r.head_distance],"status":r.status,"ids":r.wagon_ids.duplicate(),"slots":r.slot_ids.duplicate(),"distances":r.distances.duplicate(),"remaining":r.parking.map(func(c):return c.remaining)}
func run()->void:
 var all=LevelData.new().levels;var cases=[]
 for level in all:
  var rail=RailSpline.new()
  if int(level.get("train_count",1))>1:rail.configure_junction(int(level.layout),int(level.train_count))
  else:rail.configure_open(int(level.layout))
  level.track_length=rail.total_length
  for item in level.parking:
   if not item.has("requires"):item.requires=-1
  var routes=[]
  var curves=rail.branches if not rail.branches.is_empty() else [rail.curve]
  for curve in curves:
   var count=int(ceil(curve.get_baked_length()/.08))
   var points=[]
   for i in range(count+1):points.append(vec(curve.sample_baked(curve.get_baked_length()*i/count,true)))
   routes.append({"length":curve.get_baked_length(),"points":points})
  write("Data/route_%03d.json"%int(level.id),{"routes":routes})
  var r=MultiTrainRules.new() if int(level.get("train_count",1))>1 else GameRules.new()
  r.reset(level);r.configure_track(rail.total_length);r.status="playing"
  var at=0;var next=0.0;var actions=[];var snapshots=[];var step=0
  while r.status=="playing" and r.elapsed<480:
   if at<level.design.solution.size() and r.elapsed>=next and r.slots.has(-1):
    var id=int(level.design.solution[at]);r.choose(id);actions.append({"step":step,"id":id});at+=1;next=r.elapsed+1.25
   r.tick(.05);step+=1
   if step%20==0 or r.status!="playing":
    var snap=snapshot(r);snap.step=step;snapshots.append(snap)
  cases.append({"level":level.id,"actions":actions,"snapshots":snapshots})
  rail.free()
 write("Data/campaign.json",{"levels":all})
 var f=FileAccess.open(project.path_join("Verification/godot_reference.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"cases":cases}))
 for color in range(-1,5):
  var model=MeshFactory.rail_model(color);var parts=[]
  for node in model.get_children():
   var arrays=node.mesh.surface_get_arrays(0);var vertices=[];var normals=[];var indices=[]
   for v in arrays[Mesh.ARRAY_VERTEX]:vertices.append(vec(v))
   for v in arrays[Mesh.ARRAY_NORMAL]:normals.append(vec(v))
   var src=arrays[Mesh.ARRAY_INDEX]
   if src==null or src.is_empty():
    for i in range(vertices.size()):indices.append(i)
   else:
    for i in src:indices.append(i)
   for i in range(0,indices.size(),3):var tmp=indices[i];indices[i]=indices[i+2];indices[i+2]=tmp
   var mat=node.material_override;var c=mat.albedo_color
   parts.append({"vertices":vertices,"normals":normals,"triangles":indices,"r":c.r,"g":c.g,"b":c.b,"metallic":mat.metallic,"roughness":mat.roughness})
  write("Models/"+("Locomotive" if color<0 else "Wagon%d"%color)+".json",{"parts":parts});model.free()
 print("UNITY REFERENCE EXPORTED: 100 levels, 100 deterministic traces, 6 mesh models")
 quit()

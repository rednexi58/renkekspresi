class_name TrainController
extends Node3D
var rail: RailSpline
var locomotive: Node3D
var engines:Array[Node3D]=[]
var vehicle_streams:Dictionary={}
var wagons: Array[Wagon] = []
var start_distance: float = 0
var head_distance: float = 0
var smoke_clock: float = 0
var active: bool = false
var station_targets: Array[Vector3] = []
var transfers: Array = []
var low_quality: bool = false
var wheel_spokes: MultiMeshInstance3D
var couplers: MultiMeshInstance3D
const GAP = 1.80
const FIRST_GAP = 2.20

func setup(track: RailSpline, colors: Array, count:int=1) -> void:
 rail = track
 locomotive = MeshFactory.rail_model(-1)
 add_child(locomotive)
 engines=[locomotive]
 for lane in range(1,count):
  var engine=MeshFactory.rail_model(-1);add_child(engine);engines.append(engine)
 # Carriages emerge from the entry tunnel; only the train moves.
 start_distance = 1.2
 head_distance = start_distance
 for i in range(colors.size()):
  var wagon = Wagon.new()
  wagon.name = "Wagon_%02d" % (i+1)
  wagon.wagon_id = i
  wagon.setup(int(colors[i]))
  wagon.distance = head_distance-FIRST_GAP-i*GAP
  add_child(wagon)
  wagons.append(wagon)
  var badge=Label3D.new();badge.name="ActiveOrder";badge.font=load("res://assets/fonts/World-Bold.ttf");badge.font_size=48;badge.pixel_size=.012;badge.position=Vector3(0,1.38,0);badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;badge.modulate=Color("fff8d6");badge.outline_modulate=Color("213e49");badge.outline_size=10;wagon.add_child(badge)
 couplers = MultiMeshInstance3D.new()
 couplers.name = "ArticulatedCouplings"
 var mesh = CylinderMesh.new()
 mesh.top_radius = .045
 mesh.bottom_radius = .045
 mesh.height = 1
 mesh.radial_segments = 8
 couplers.multimesh = MultiMesh.new()
 couplers.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 couplers.multimesh.mesh = mesh
 couplers.multimesh.instance_count = colors.size()
 couplers.material_override = MeshFactory.material(Color("33454c"),.4,.4)
 add_child(couplers)
 wheel_spokes = MultiMeshInstance3D.new()
 wheel_spokes.name = "RollingWheelSpokes"
 var spoke = BoxMesh.new()
 spoke.size = Vector3(.025,1,.045)
 wheel_spokes.multimesh = MultiMesh.new()
 wheel_spokes.multimesh.transform_format = MultiMesh.TRANSFORM_3D
 wheel_spokes.multimesh.mesh = spoke
 wheel_spokes.multimesh.instance_count = 6*count+colors.size()*4
 wheel_spokes.material_override = MeshFactory.material(Color("b9ccc9"),.65,.32)
 add_child(wheel_spokes)
 position_train(0,0)

func advance(progress: float, delta: float) -> void:
 var old_distance = head_distance
 head_distance = lerpf(start_distance,rail.total_length-.65,progress)
 var movement = head_distance-old_distance
 position_train(delta,movement)
 for wagon in wagons:wagon.roll(movement)
 if active:
  smoke_clock += delta
  if smoke_clock > (1.0 if low_quality else .55):
   smoke_clock = 0
   emit_smoke()

func pose_vehicle(vehicle: Node3D, distance: float, wheelbase: float, lane:int=0) -> void:
 var front = rail.route_point(lane,distance+wheelbase*.5)
 var rear = rail.route_point(lane,distance-wheelbase*.5)
 vehicle.position = (front+rear)*.5+Vector3.UP*.20
 var direction=(front-rear).normalized()
 if direction.length_squared()<.01:direction=rail.route_direction(lane,clampf(distance,0,rail.total_length))
 vehicle.basis = Basis.looking_at(direction)

func position_train(delta: float, movement: float = 0.0) -> void:
 pose_vehicle(locomotive,head_distance,1.3)
 for i in range(wagons.size()):
  var wagon = wagons[i]
  var target = head_distance-FIRST_GAP-i*GAP
  # Advance the whole consist equally, then close only the space left by a removed wagon.
  wagon.distance = target if delta == 0 else move_toward(wagon.distance+movement,target,delta*2.7)
  pose_vehicle(wagon,wagon.distance,.92)
  wagon.visible = true
 update_couplers()
 update_wheels()

func update_couplers() -> void:
 for i in range(couplers.multimesh.instance_count):
  var transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
  if i < wagons.size() and wagons[i].visible:
   var lane=int(vehicle_streams.get(wagons[i].wagon_id,0))
   var first=i==0 or int(vehicle_streams.get(wagons[i-1].wagon_id,0))!=lane
   var ahead = engines[lane] if first else wagons[i-1]
   var a = ahead.transform*Vector3(0,.38,1.04 if first else .90)
   var b = wagons[i].transform*Vector3(0,.38,-.90)
   var length = a.distance_to(b)
   if length > .015 and length < .65:
    transform = Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized()))*Basis.from_scale(Vector3(1,length,1)),(a+b)*.5)
  couplers.multimesh.set_instance_transform(i,transform)

func sync_rules(rules: GameRules, delta: float) -> void:
 head_distance=rules.head_distance
 if rules is MultiTrainRules:
  for lane in range(engines.size()):
   engines[lane].visible=rules.remaining_in(lane)>0
   engines[lane].set_meta("distance",float(rules.heads[lane]))
   pose_vehicle(engines[lane],float(rules.heads[lane]),1.3,lane)
 else:pose_vehicle(locomotive,head_distance,1.3)
 for wagon in wagons:
  var index=rules.wagon_ids.find(wagon.wagon_id)
  if index>=0:
   wagon.distance=rules.distances[index];wagon.visible=rail.looped or wagon.distance>=.3
   var lane=rules.stream_of(wagon.wagon_id) if rules is MultiTrainRules else 0
   vehicle_streams[wagon.wagon_id]=lane
   pose_vehicle(wagon,wagon.distance,.92,lane)
  var badge=wagon.get_node("ActiveOrder");badge.visible=index>=0 and rules.can_collect(index) and wagon.visible;badge.text="●" if rules.match_zone else str(index+1)
  wagon.scale=Vector3.ONE*(1.06 if rules.targets.has(wagon.wagon_id) else 1.0)
 update_couplers();update_wheels()
 if active:
  smoke_clock+=delta
  if smoke_clock>.65:smoke_clock=0;emit_smoke()

func remove_wagon(wagon_id: int, _slot_index: int) -> Vector3:
 var index=-1
 for i in range(wagons.size()):
  if wagons[i].wagon_id==wagon_id:index=i;break
 if index<0:return Vector3.ZERO
 var wagon=wagons[index];wagons.remove_at(index)
 # Complete the transfer where the moving carriage actually is.
 var origin=wagon.position
 var target=origin+Vector3.UP*.35
 transfers.append({"wagon":wagon,"origin":origin,"target":target,"time":0.0})
 update_couplers();return origin

func tick_transfers(delta: float) -> void:
 for i in range(transfers.size()-1,-1,-1):
  var item=transfers[i];item.time+=delta
  var t=clampf(item.time/.24,0,1)
  item.wagon.position=item.origin.lerp(item.target,t)
  item.wagon.scale=Vector3.ONE*lerpf(1.0,0.0,t)
  if t>=1:item.wagon.queue_free();transfers.remove_at(i)
 update_wheels()

func update_wheels() -> void:
 if not is_instance_valid(wheel_spokes):return
 var poses:Array=[]
 for engine in engines:
  if engine.visible:poses.append({"node":engine,"distance":float(engine.get_meta("distance",head_distance)),"engine":true})
 for wagon in wagons:
  if wagon.visible:poses.append({"node":wagon,"distance":wagon.distance,"engine":false})
 for item in transfers:poses.append({"node":item.wagon,"distance":item.wagon.distance+item.time*3,"engine":false})
 var index = 0
 for pose in poses:
  var radius = .24 if pose.engine else .19
  for z in ([-.65,.05,.65] if pose.engine else [-.46,.46]):
   for x in [-.574,.574]:
    var rotation = Basis(Vector3.RIGHT,-float(pose.distance)/radius)*Basis.from_scale(Vector3(1,radius*1.45,1))
    var transform = pose.node.transform*Transform3D(rotation,Vector3(x,.22,z))
    wheel_spokes.multimesh.set_instance_transform(index,transform)
    index += 1
 for i in range(index,wheel_spokes.multimesh.instance_count):
  wheel_spokes.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

func camera_focus() -> Vector3:
 return rail.point_at(head_distance-minf(2.8,wagons.size()*GAP*.5))

func emit_smoke() -> void:
 var emitter:Node3D=null
 for engine in engines:
  if engine.visible:emitter=engine;break
 if emitter==null:return
 var at = emitter.transform*Vector3(0,1.82,-.59)
 var puff = MeshFactory.sphere(self,"Steam",.09,at,Color("d9e4e4"))
 puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var t = create_tween().set_parallel(true)
 t.tween_property(puff,"position",at+Vector3(-.15,.65,.10),.85)
 t.tween_property(puff,"scale",Vector3.ONE*2.0,.7)
 t.chain().tween_property(puff,"scale",Vector3.ZERO,.15)
 t.chain().tween_callback(puff.queue_free)

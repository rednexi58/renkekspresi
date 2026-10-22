class_name GameWorld
extends Node3D
var rail: RailSpline
var train: TrainController
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var station_slots: Array[StationSlot] = []
var junction_lights:Array[MeshInstance3D]=[]
var particles: Array = []
var low_quality: bool = false
var stage: Node3D
var station: Node3D
var signal_lamp: MeshInstance3D
var current_theme: int = 0
var rescue_mode=false
var arrival_beacon: MeshInstance3D
var rescue_friend: Node3D
var friend_home=Vector3.ZERO
var friend_time=0.0
var rescue_result=""
var camera_anchor: Vector3 = Vector3.ZERO
var camera_ready: bool = false
var parking_nodes: Array = []
var parking_flights: Array = []
var hint_until=0.0
var board_rows: int = 2
var rng = RandomNumberGenerator.new()
const THEMES = [
 {"ground":"a1b88d","edge":"80966e","bg":"c4d8c3","leaves":"4b7953","accent":"d7ad72","roof":"9d6b50"},
 {"ground":"d4c49e","edge":"b5a17d","bg":"b7d6d7","leaves":"527c6c","accent":"7db8ba","roof":"807568"},
 {"ground":"b7bc88","edge":"919765","bg":"d5dcc0","leaves":"698553","accent":"cf9870","roof":"ad7955"},
 {"ground":"b4bcb1","edge":"88968b","bg":"c9d7d1","leaves":"536f60","accent":"c7a573","roof":"776c62"},
 {"ground":"c7a77f","edge":"a68360","bg":"dfc4a7","leaves":"788468","accent":"d3b08a","roof":"92705c"},
 {"ground":"c4d4cf","edge":"93aba5","bg":"d7e8e1","leaves":"477365","accent":"b9cdc8","roof":"7d6960"}
]

func _ready() -> void:
 environment = Environment.new()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color("dfeade")
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color("fff7e5")
 environment.ambient_light_energy = .28
 environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 var sky_material=ProceduralSkyMaterial.new()
 sky_material.sky_top_color=Color("87b0bf");sky_material.sky_horizon_color=Color("e7dec5")
 sky_material.ground_bottom_color=Color("4a6259");sky_material.ground_horizon_color=Color("a6b4a3")
 sky_material.sky_energy_multiplier=.45;sky_material.ground_energy_multiplier=.35
 var sky=Sky.new();sky.sky_material=sky_material;environment.sky=sky
 environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 environment.fog_enabled = false
 environment.fog_light_color = Color("dfeade")
 environment.fog_density = .004
 var world_environment = WorldEnvironment.new()
 world_environment.name = "SoftAmbient"
 world_environment.environment = environment
 add_child(world_environment)
 sun = DirectionalLight3D.new()
 sun.name = "AfternoonSun"
 sun.rotation_degrees = Vector3(-63,-32,0)
 sun.light_color = Color("fff5e8")
 sun.light_energy = .62
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 45
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
 sun.shadow_blur = 2.0
 sun.shadow_bias = .035
 sun.shadow_normal_bias = .7
 add_child(sun)
 camera = Camera3D.new()
 camera.name = "FixedMapCamera"
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect = Camera3D.KEEP_HEIGHT
 camera.fov = 52
 camera.near = .1
 camera.far = 180
 camera.position = Vector3(2.5,23,18)
 add_child(camera)
 camera.look_at(Vector3(0,.35,-.15))
 camera.current = true
 get_viewport().size_changed.connect(fit_camera)

func fit_camera() -> void:
 if not is_instance_valid(rail):return
 var screen=get_viewport().get_visible_rect().size
 var aspect=screen.x/maxf(1,screen.y)
 camera.position=Vector3(0,28,27)
 camera.look_at(Vector3.ZERO)
 var view=camera.global_transform.affine_inverse()
 var low=Vector2(INF,INF)
 var high=Vector2(-INF,-INF)
 var bounds=Array(rail.curve.get_baked_points())
 for branch in rail.branches:bounds.append_array(branch.get_baked_points())
 bounds.append_array([Vector3(-6.2,0,-12),Vector3(6.2,0,maxf(7.8,4.2+(board_rows-1)*2.35+2.2))])
 for at in bounds:
  var local=view*at
  low=low.min(Vector2(local.x,local.y));high=high.max(Vector2(local.x,local.y))
 low-=Vector2(1.5,1.7);high+=Vector2(1.5,1.7)
 var span=high-low
 camera.size=maxf(span.y/.74,span.x/(aspect*.94))
 var center=(low+high)*.5
 camera.position+=camera.basis.x*center.x+camera.basis.y*(center.y+.045*camera.size)
 camera_ready=true

func update_camera(_delta: float) -> void:
 # Fixed throughout play. Only a new map or resize changes framing.
 pass

func create_scenery(level: Dictionary) -> void:
 rescue_mode=level.get("mode","loop")=="rescue"
 current_theme=int(level.theme)
 var theme=THEMES[current_theme]
 environment.background_color=Color(theme.bg)
 rng.seed=int(level.map_seed)
 board_rows=int(level.rows)
 stage=Node3D.new();stage.name="LoopPark";add_child(stage)
 var ground=MeshFactory.box(stage,"Landscape",Vector3(240,.3,240),Vector3(0,-.22,0),Color(theme.ground))
 ground.material_override=MeshFactory.material(Color(theme.ground)).duplicate()
 ground.material_override.roughness=1.0
 var terrain_shader=Shader.new()
 terrain_shader.code="""shader_type spatial;
 uniform vec4 earth : source_color = vec4(0.5,0.6,0.4,1.0);
 varying vec3 world_position;
 float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
 float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
 void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
 void fragment(){float n=noise(world_position.xz*0.27)*0.65+noise(world_position.xz*1.2)*0.28+noise(world_position.xz*9.0)*0.07;ALBEDO=mix(earth.rgb*0.86,earth.rgb*1.08,n);ROUGHNESS=1.0;SPECULAR=0.15;}
 """
 var terrain_material=ShaderMaterial.new();terrain_material.shader=terrain_shader;terrain_material.set_shader_parameter("earth",Color(theme.ground).darkened(.12));ground.material_override=terrain_material
 rail=RailSpline.new();rail.configure(int(level.layout));rail.name="RailSpline";stage.add_child(rail)
 if int(level.get("train_count",1))>1:rail.configure_junction(int(level.layout),int(level.train_count))
 elif rescue_mode:rail.configure_open(int(level.layout))
 rail.build_meshes()
 if not rail.branches.is_empty():
  rail.build_branches()
  junction_lights.clear()
  for lane in range(rail.branches.size()):
   build_tunnel(0,true,theme,lane)
   var at=rail.route_point(lane,rail.total_length*.70)+Vector3(1.05,0,0)
   MeshFactory.cylinder(stage,"MergeSignalPost",.06,1.05,at+Vector3.UP*.52,Color("3e5255"))
   MeshFactory.box(stage,"MergeSignal",Vector3(.26,.42,.20),at+Vector3.UP*1.15,Color("28464a"),.06)
   var light=MeshFactory.sphere(rail,"JunctionLamp",.09,at+Vector3(0,1.17,.13),Color("d5ad5c"));junction_lights.append(light)
   var label=Label3D.new();label.text=str(lane+1);label.font=load("res://assets/fonts/World-Bold.ttf");label.font_size=46;label.pixel_size=.014;label.position=at+Vector3.UP*1.5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label)
 elif rescue_mode:build_tunnel(0,true,theme)
 build_campaign_landscape(theme,level)
 build_railway_details(theme)
 build_station(theme)
 batch_scenery()
 build_friend()
 build_parking(level)
 fit_camera()

func build_parking(level: Dictionary) -> void:
 parking_nodes.clear();parking_flights.clear()
 var rows=int(level.rows)
 var cols=int(level.get("cols",4))
 hint_until=0
 var spacing=2.35
 var yard_center=4.2+(rows-1)*spacing*.5
 MeshFactory.box(stage,"YardFoundation",Vector3(14.2,.16,rows*spacing+.85),Vector3(0,-.06,yard_center),Color("777c72"),.15)
 var paving=MeshFactory.box(stage,"StoneYard",Vector3(13.95,.05,rows*spacing+.60),Vector3(0,.035,yard_center),Color("9c9e8e"),.12)
 var paving_shader=Shader.new()
 paving_shader.code="""shader_type spatial;
 varying vec3 wp;
 void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
 void fragment(){vec2 p=wp.xz*vec2(2.2,3.6);p.x+=mod(floor(p.y),2.0)*0.5;vec2 f=fract(p);float seam=step(0.045,f.x)*step(0.06,f.y);float grain=fract(sin(dot(floor(p),vec2(12.9898,78.233)))*43758.5453);ALBEDO=mix(vec3(.36,.40,.38),vec3(.47,.51,.47)*(0.96+grain*.08),seam);ROUGHNESS=.94;}
 """
 var pm=ShaderMaterial.new();pm.shader=paving_shader;paving.material_override=pm
 for side in [-1,1]:
  MeshFactory.box(stage,"YardBorder",Vector3(.14,.12,rows*spacing+.45),Vector3(side*6.95,.12,yard_center),Color("c3b492"),.025)
  for row in range(rows):
   MeshFactory.box(stage,"YardDrain",Vector3(.19,.018,.60),Vector3(side*6.65,.075,4.2+row*spacing),Color("384b4d"),.018)
 for item in level.parking:
  var at=Vector3((int(item.col)-(cols-1)*.5)*4.2,.075,4.2+int(item.row)*spacing)
  var berth=Node3D.new();stage.add_child(berth);berth.position=at
  berth.basis=Basis.looking_at(Vector3(int(item.dx),0,int(item.dz)))
  # Short service rails beneath the car reinforce the railway theme.
  for z in [-.70,-.35,0,.35,.70]:MeshFactory.box(berth,"BerthSleeper",Vector3(1.73,.045,.13),Vector3(0,.01,z),Color("646d65"),.02)
  for side in [-1,1]:MeshFactory.box(berth,"BerthRail",Vector3(.055,.07,2.0),Vector3(side*.68,.06,0),Color("9eaaa7"),.015)
 for item in level.parking:
  var node=Node3D.new();node.name="ParkedWagon_%d"%int(item.id);stage.add_child(node)
  node.position=Vector3((int(item.col)-(cols-1)*.5)*4.2,.14,4.2+int(item.row)*spacing)
  var model=Wagon.new();model.setup(int(item.color));model.basis=Basis.looking_at(Vector3(int(item.dx),0,int(item.dz)));model.scale=Vector3(1.45,1.18,1.62 if int(item.dz)==0 else 1.16);node.add_child(model)
  var arrow=Label3D.new()
  var arrows={Vector2i(-1,-1):"↖",Vector2i(0,-1):"↑",Vector2i(1,-1):"↗",Vector2i(-1,0):"←",Vector2i(1,0):"→",Vector2i(-1,1):"↙",Vector2i(0,1):"↓",Vector2i(1,1):"↘"}
  arrow.text=arrows.get(Vector2i(int(item.dx),int(item.dz)),"↑")
  arrow.font=load("res://assets/fonts/World-Bold.ttf");arrow.font_size=72;arrow.pixel_size=.013
  arrow.position=Vector3(0,1.74,0);arrow.rotation_degrees.x=-90
  arrow.modulate=Color("ffffff");arrow.outline_modulate=Color("213e49");arrow.outline_size=7
  node.add_child(arrow)
  var halo=MeshFactory.box(node,"ClearExitMarker",Vector3(3.65,.025,1.8),Vector3(0,-.06,0),Color("a1b99a"),.12)
  var lock=Node3D.new();lock.name="KeyLock";node.add_child(lock)
  MeshFactory.box(lock,"LockBody",Vector3(.53,.37,.26),Vector3(0,1.12,0),Color("edb94c"),.06)
  var ring=MeshFactory.cylinder(lock,"Shackle",.17,.1,Vector3(0,1.4,0),Color("5b6267"));ring.rotation_degrees.x=90
  var tag=Label3D.new();tag.text=str(level.parking[int(item.get("requires",0))].get("key","A"));tag.font=load("res://assets/fonts/World-Bold.ttf");tag.font_size=42;tag.pixel_size=.009;tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tag.position=Vector3(0,1.37,.15);lock.add_child(tag)
  lock.visible=item.has("requires")
  if item.has("key"):
   var key=Node3D.new();key.name="KeyA";node.add_child(key)
   MeshFactory.cylinder(key,"KeyHead",.18,.08,Vector3(-.35,1.15,0),Color("ffdc62"))
   MeshFactory.box(key,"KeyStem",Vector3(.55,.08,.09),Vector3(-.02,1.15,0),Color("ffdc62"))
   MeshFactory.box(key,"KeyTooth",Vector3(.08,.08,.22),Vector3(.19,1.15,.08),Color("ffdc62"))
   var key_tag=Label3D.new();key_tag.text=str(level.parking[int(item.get("requires",0))].get("key","A"));key_tag.font=load("res://assets/fonts/World-Bold.ttf");key_tag.font_size=42;key_tag.pixel_size=.009;key_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;key_tag.position=Vector3(0,1.65,0);key_tag.modulate=Color("ffe69a");key.add_child(key_tag)
   arrow.position.z=.38
  var capacity=Label3D.new();capacity.name="Capacity";capacity.text=str(int(item.get("capacity",5)));capacity.font=load("res://assets/fonts/World-Bold.ttf");capacity.font_size=34;capacity.pixel_size=.016;capacity.position=Vector3(0,1.63,.74);capacity.billboard=BaseMaterial3D.BILLBOARD_ENABLED;capacity.modulate=Color("fff3bc");capacity.outline_size=8;capacity.outline_modulate=Color("334869");node.add_child(capacity)
  parking_nodes.append({"node":node,"origin":node.position,"halo":halo,"arrow":arrow,"lock":lock,"state":"parked","capacity":capacity})

func sync_parking(rules: GameRules) -> void:
 if rules is MultiTrainRules:
  for lane in range(junction_lights.size()):
   var warning=float(rules.heads[lane])>rules.end_distance*.9
   if not junction_lights[lane].has_meta("warning") or junction_lights[lane].get_meta("warning")!=warning:
    junction_lights[lane].material_override=MeshFactory.material(Color("d89c54") if warning else Color("89c6a1"));junction_lights[lane].set_meta("warning",warning)
 for i in range(parking_nodes.size()):
  var visual=parking_nodes[i];var state=rules.parking[i].state
  if state!=visual.state:
   visual.state=state;visual.node.visible=state=="parked"
   visual.node.position=visual.origin
  visual.capacity.text=str(int(rules.parking[i].remaining))
  visual.lock.visible=rules.is_locked(i)
  visual.arrow.visible=not rules.is_locked(i)
  visual.halo.visible=rules.available(i) and (rules.guided or rules.elapsed<hint_until)
  visual.arrow.modulate=Color.WHITE if not rules.guided or rules.available(i) else Color("b3c3c5")
 for i in range(station_slots.size()):
  station_slots[i].visible=true
  station_slots[i].position.x=-5.75+i*2.3
  if i<rules.slots.size():
   var color=int(rules.slots[i])
   if station_slots[i].color_id!=color:show_slot(i,color)
   var card=rules.parking[int(rules.slot_ids[i])] if color>=0 else {}
   station_slots[i].count_label.font_size=38
   station_slots[i].show_status(true,int(card.get("capacity",0))-int(card.get("remaining",0)),int(card.get("capacity",0)))
  else:
   if station_slots[i].color_id!=-1:show_slot(i,-1)
   station_slots[i].show_status(false)
   var kind=str(rules.locked_slot_kinds()[i-rules.slots.size()])
   station_slots[i].count_label.text={"vip":"VIP +","reward":"AD +","paid":"SHOP +"}[kind]
   station_slots[i].count_label.font_size=27

func launch_parking(id: int, slot: int, wagon_id: int, duration: float) -> void:
 var visual=parking_nodes[id]
 var copy=Wagon.new();copy.setup(int(visual.node.get_child(0).color_id));add_child(copy)
 copy.position=visual.origin;copy.basis=visual.node.get_child(0).basis
 var direction=-copy.basis.z
 var target: Node3D=null
 for wagon in train.wagons:
  if wagon.wagon_id==wagon_id:target=wagon;break
 if wagon_id<0:target=station_slots[slot]
 # A short colored transfer links this exact parked wagon to its reserved moving carriage.
 parking_flights.append({"node":copy,"id":id,"slot":slot,"target":target,"time":0.0,"duration":duration,"origin":visual.origin,"exit":visual.origin+direction*1.5})

func launch_waiting(info: Dictionary, duration: float) -> void:
 cancel_flight(int(info.parking_id))
 var target: Node3D=null
 for wagon in train.wagons:
  if wagon.wagon_id==int(info.wagon_id):target=wagon;break
 if not is_instance_valid(target):return
 var copy=MeshFactory.box(self,"CollectedColor",Vector3(.40,.35,.40),Vector3.ZERO,TrainPalette.color(int(info.color)),.08)
 var origin=target.global_position+Vector3.UP*.7
 target=station_slots[int(info.slot)]
 copy.position=origin
 parking_flights.append({"node":copy,"id":int(info.parking_id),"slot":int(info.slot),"target":target,"time":0.0,"duration":duration,"origin":origin,"exit":origin})

func show_hint(rules: GameRules) -> void:
 hint_until=rules.elapsed+2.5
 sync_parking(rules)

func cancel_flight(id: int) -> void:
 for i in range(parking_flights.size()-1,-1,-1):
  if int(parking_flights[i].id)==id:
   parking_flights[i].node.queue_free();parking_flights.remove_at(i)

func pick_parking(screen: Vector2, rules: GameRules) -> int:
 var best=-1;var distance=INF
 for i in range(parking_nodes.size()):
  if rules.parking[i].state!="parked":continue
  var node=parking_nodes[i].node
  var center=camera.unproject_position(node.position+Vector3.UP*.55)
  var extent=camera.unproject_position(node.position+Vector3(1.94,.55,0)).distance_to(center)
  var delta=screen-center
  if absf(delta.x)<extent and absf(delta.y)<extent*.98 and delta.length()<distance:
   distance=delta.length();best=i
 return best

func near_track(at: Vector3, margin: float) -> bool:
 if rail.curve.get_closest_point(at).distance_to(at)<margin:return true
 for branch in rail.branches:
  if branch.get_closest_point(at).distance_to(at)<margin:return true
 return false

func plant_tree(at: Vector3, factor: float, theme: Dictionary) -> void:
 var tree=Node3D.new();tree.name="SculptedTree";tree.position=at;tree.scale=Vector3.ONE*factor;stage.add_child(tree)
 MeshFactory.organic(tree,"RootMound",Vector3(0,-.04,0),Vector3(.65,.12,.54),Color(theme.edge),2,.13)
 MeshFactory.cylinder(tree,"Trunk",.12,1.7,Vector3(0,.85,0),Color("6c6656"),.045)
 if current_theme==5:
  for i in range(6):
   var radius=.79-i*.105
   MeshFactory.organic(tree,"FirBranchTier",Vector3(.03*sin(i),.85+i*.29,0),Vector3(radius,.40,radius),Color(theme.leaves).lightened(i*.013),float(i),.18)
   if i%2==0:MeshFactory.organic(tree,"SnowDust",Vector3(0,1.04+i*.29,0),Vector3(radius*.8,.18,radius*.8),Color("d7e0d9"),float(i),.13)
 else:
  for i in range(6):
   var angle=float(i)*2.4
   var branch=MeshFactory.cylinder(tree,"Branch",.05,.94,Vector3(cos(angle)*.23,1.20,sin(angle)*.23),Color("7c725e"),.012)
   branch.rotation=Vector3(sin(angle)*.73,0,-cos(angle)*.73)
   var pos=Vector3(cos(angle)*.43,1.61+float(i%3)*.22,sin(angle)*.40)
   MeshFactory.organic(tree,"LeafCrown",pos,Vector3(.56,.61,.49),Color(theme.leaves).lightened(float(i%3)*.035),float(i)*1.7,.085)
  MeshFactory.organic(tree,"TopFoliage",Vector3(.05,2.05,0),Vector3(.61,.55,.56),Color(theme.leaves).lightened(.07),4.3,.075)

func build_water(theme: Dictionary) -> void:
 var bank = MeshFactory.cylinder(stage,"RoundedPondShore",1,.05,Vector3(.15,.025,-7.6),Color(theme.edge).lightened(.24))
 bank.scale = Vector3(1.9,1,.93)
 var water = MeshFactory.cylinder(stage,"StillWater",1,.04,Vector3(.15,.06,-7.6),Color("66a9b6"))
 water.scale = Vector3(1.75,1,.78)
 water.material_override = MeshFactory.material(Color("66a9b6"),.15,.18)
 for i in range(4):
  MeshFactory.box(stage,"WaterRipple",Vector3(.38+i*.08,.01,.035),Vector3(-.9+i*.65,.09,-7.85+(i%2)*.44),Color("bcdae0"),.005)
 for i in range(6):
  MeshFactory.box(stage,"DockPlank",Vector3(.72,.10,.19),Vector3(1.5,.14,-8.1+i*.22),Color("b7946c"),.025)
 for z in [-8.1,-7.0]:
  MeshFactory.cylinder(stage,"DockPost",.065,.45,Vector3(1.88,.18,z),Color("7d6c57"))
 if current_theme == 1:
  MeshFactory.box(stage,"BeachTowel",Vector3(.65,.035,1.1),Vector3(-1.25,.05,-6.7),Color("f6dc9e"),.01)
  MeshFactory.cylinder(stage,"UmbrellaPole",.035,1.0,Vector3(-1.2,.5,-7.1),Color("f2e3c5"))
  MeshFactory.cylinder(stage,"SunUmbrella",.64,.25,Vector3(-1.2,1.05,-7.1),Color("d7896d"),0)

func build_landmarks(theme: Dictionary) -> void:
 if current_theme==1:
  for d in range(0,int(rail.total_length),3):
   var at=rail.point_at(float(d));MeshFactory.box(stage,"BridgeSupport",Vector3(1.5,.25,.42),at-Vector3.UP*.06,Color("ac805a"),.03)
  for at in [Vector3(-10,0,7),Vector3(10,0,-6)]:
   var boat=MeshFactory.box(stage,"HarborBoat",Vector3(1.2,.5,2.7),at,Color("f4e7ce"),.2)
   MeshFactory.box(boat,"BoatCabin",Vector3(.8,.7,1),Vector3(0,.55,.2),Color("3b707f"),.1)
 elif current_theme==2:
  for at in [Vector3(-10,0,-5),Vector3(10,0,7),Vector3(-10,0,8),Vector3(3,0,-9)]:
   if near_track(at,1.5):continue
   var rock=MeshFactory.sphere(stage,"Sandstone",1,at+Vector3.UP*.4,Color("c58d62"));rock.scale=Vector3(.9,.7,1.2)
   MeshFactory.cylinder(stage,"Cactus",.16,1.9,at+Vector3(1,.7,0),Color("478c70"))
 elif current_theme==3:
  for at in [Vector3(-10,0,-6),Vector3(10,0,7),Vector3(2,0,-9)]:
   if near_track(at,1.5):continue
   var snow=MeshFactory.sphere(stage,"SnowBank",1.4,at,Color("ecf5f8"));snow.scale=Vector3(1,.45,1)
 elif current_theme==4:
  for x in [-10.5,10.5]:
   for z in [-8,-3,3,8]:
    var house=MeshFactory.box(stage,"CityBuilding",Vector3(1.6,2,1.8),Vector3(x,1,z),Color("8aa3b0"),.12)
    for floor_y in [.4,1.1]:
     for wx in [-.4,.4]:MeshFactory.box(house,"CityWindow",Vector3(.3,.35,.05),Vector3(wx,floor_y-.7,.92),Color("f9dc96"),.02)

func build_cottage(at: Vector3, theme: Dictionary) -> void:
 var house = Node3D.new()
 stage.add_child(house)
 house.position = at
 MeshFactory.box(house,"Cottage",Vector3(1.8,1.05,1.2),Vector3(0,.53,0),Color("dfcbb0"),.08)
 for side in [-1,1]:
  var roof = MeshFactory.box(house,"Roof",Vector3(2.1,.13,.84),Vector3(0,1.19,side*.32),Color(theme.roof),.04)
  roof.rotation.x = side*.45
 MeshFactory.box(house,"Door",Vector3(.35,.65,.04),Vector3(0,.35,.62),Color("5a7467"),.02)
 for x in [-.55,.55]:
  MeshFactory.box(house,"Window",Vector3(.36,.35,.05),Vector3(x,.67,.62),Color("a2c6d2"),.025)
 MeshFactory.box(house,"Chimney",Vector3(.25,.55,.27),Vector3(.5,1.4,-.15),Color("8d7060"),.03)

func build_station(_theme: Dictionary) -> void:
 station=Node3D.new();station.name="SingleStation";stage.add_child(station)
 station.position=Vector3(0,0,.15)
 for x in [-7.0,7.0]:
  MeshFactory.box(station,"PlatformStoneCoping",Vector3(.18,.08,1.85),Vector3(x,.25,0),Color("c7c7b4"),.035)
 for x in range(-13,14):
  MeshFactory.box(station,"SafetyStripe",Vector3(.24,.015,.12),Vector3(x*.5,.29,.95),Color("e5cb8f"),.012)
 MeshFactory.box(station,"Platform",Vector3(14.2,.24,1.85),Vector3(0,.1,0),Color("8d9993"),.09)
 for i in range(6):
  var slot=StationSlot.new();slot.name="WaitingSlot%d"%(i+1);station.add_child(slot)
  slot.position=Vector3(-5.75+i*2.3,.3,0);slot.setup(i);station_slots.append(slot)
 for x in []:
  MeshFactory.cylinder(station,"SignalPost",.06,1.25,Vector3(x,.6,.8),Color("3a5b5b"))
  signal_lamp=MeshFactory.sphere(station,"Signal",.16,Vector3(x,1.3,.8),Color("4ac898"))
 # One painted crossing under every passing carriage.
 
 var sign=Label3D.new();sign.text="";sign.font=load("res://assets/fonts/World-Bold.ttf")
 sign.font_size=40;sign.pixel_size=.01;sign.rotation_degrees.x=-90
 sign.position=Vector3(0,.24,7.3);sign.modulate=Color("2d5758");sign.outline_size=0
 station.add_child(sign);sign.position.z=-1.4

func set_station_phase(_phase: int) -> void:
 pass

func build_tunnel(distance: float, entrance: bool, theme: Dictionary, lane:int=0) -> void:
 var tunnel = Node3D.new()
 tunnel.name = "Entrance" if entrance else "ExitTunnel"
 stage.add_child(tunnel)
 tunnel.position = rail.route_point(lane,distance)
 tunnel.basis = Basis.looking_at(rail.route_direction(lane,distance) * (-1 if entrance else 1))
 var stone = Color("a4a28e")
 for side in [-1,1]:
  MeshFactory.organic(tunnel,"CuttingBank",Vector3(side*1.65,.16,-1.25),Vector3(1.1,.65,1.8),Color(theme.edge),float(side)+2,.08)
  for row in range(4):
   for col in range(3):
    MeshFactory.box(tunnel,"WingWallBlock",Vector3(.45,.26,.48),Vector3(side*(1.18+col*.44),.16+row*.26,-.20-col*.15),stone.darkened(.025*(row%2)),.035)

 MeshFactory.box(tunnel,"DarkOpening",Vector3(1.6,1.8,.10),Vector3(0,.83,-.35),Color("203f49"),.045)
 for side in [-1,1]:
  MeshFactory.box(tunnel,"StonePier",Vector3(.28,1.6,1.05),Vector3(side*.95,.7,-.22),stone,.09)
 for i in range(9):
  var angle = float(i)/8*PI
  var at = Vector3(cos(angle)*.97,.92+sin(angle)*.92,-.22)
  var arch = MeshFactory.box(tunnel,"ArchStone",Vector3(.38,.36,.80),at,stone.lightened(.06 if i%2 else .14),.055)
  arch.rotation.z = angle-PI/2

 var sign = Label3D.new()
 sign.text = "GİRİŞ" if entrance else "VARIŞ"
 sign.font = load("res://assets/fonts/World-Bold.ttf")
 sign.font_size = 38
 sign.pixel_size = .0045
 sign.modulate = Color("f3e7c7")
 sign.outline_size = 0
 sign.position = Vector3(0,1.83,.23)
 tunnel.add_child(sign)

func load_level(level: Dictionary) -> void:
 for particle in particles:
  particle.node.queue_free()
 particles.clear()
 for flight in parking_flights:flight.node.queue_free()
 parking_flights.clear()
 if is_instance_valid(train):
  remove_child(train)
  train.queue_free()
 if is_instance_valid(stage):
  remove_child(stage)
  stage.queue_free()
 station_slots.clear();junction_lights.clear()
 create_scenery(level)
 train = TrainController.new()
 train.name = "TrainController"
 add_child(train)
 train.low_quality = low_quality
 train.setup(rail,level.train,int(level.get("train_count",1)))
 fit_camera()
 set_station_phase(-1)
 for slot in station_slots:
  train.station_targets.append(slot.global_position+Vector3.UP*.15)
  slot.set_color(-1)

func set_quality(low: bool) -> void:
 low_quality = low
 sun.shadow_enabled = not low
 sun.light_energy = .90 if low else .62
 environment.ambient_light_energy = .40 if low else .28
 get_viewport().msaa_3d = Viewport.MSAA_2X if low else Viewport.MSAA_4X
 if is_instance_valid(train):
  train.low_quality = low

func show_slot(index: int, color_id: int) -> void:
 station_slots[index].set_color(color_id)

func burst(at: Vector3, color_id: int, big: bool = false) -> void:
 var count = 5 if low_quality else (20 if big else 10)
 for i in range(count):
  var spark = MeshFactory.box(self,"Confetti",Vector3(.09,.09,.14),at+Vector3(0,.8,0),TrainPalette.color(color_id))
  spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  particles.append({"node":spark,"velocity":Vector3(randf_range(-1.7,1.7),randf_range(2,3.4),randf_range(-1.7,1.7)),"life":.7})

func tick_effects(delta: float) -> void:
 friend_time+=delta
 if is_instance_valid(rescue_friend):
  rescue_friend.position=friend_home+Vector3.UP*(.025*sin(friend_time*2.0))
  var tail=rescue_friend.get_node_or_null("WaggingTail")
  if tail:tail.rotation.y=sin(friend_time*(10.0 if rescue_result=="won" else 4.0))*.42
  if rescue_result=="won":rescue_friend.position.y+=absf(sin(friend_time*5))*.35
  elif rescue_result=="lost":rescue_friend.position.x+=minf(3.0,friend_time*1.5)
 for i in range(parking_flights.size()-1,-1,-1):
  var item=parking_flights[i];item.time+=delta
  var t=clampf(item.time/item.duration,0,1)
  var target=item.target.global_position if is_instance_valid(item.target) else item.exit
  if t<.22:item.node.position=item.origin.lerp(item.exit,t/.22)
  else:
   var travel=(t-.22)/.78
   item.node.position=item.exit.lerp(target,travel)+Vector3.UP*sin(travel*PI)*2.0
   item.node.scale=Vector3.ONE*lerpf(.95,.25,travel)
  if t>=1:item.node.queue_free();parking_flights.remove_at(i)
 for i in range(particles.size()-1,-1,-1):
  var particle = particles[i]
  particle.life -= delta
  particle.velocity.y -= delta*8
  particle.node.position += particle.velocity*delta
  particle.node.rotate_x(delta*4)
  particle.node.scale = Vector3.ONE*clampf(particle.life*2,0,1)
  if particle.life <= 0:
   particle.node.queue_free()
   particles.remove_at(i)

func batch_scenery() -> void:
 # Terrain and decorations are static; merge them by material for mobile draw-call cost.
 # Track MultiMeshes, runtime station slots and tunnel lettering retain their nodes.
 var groups: Dictionary = {}
 for child in stage.get_children():
  if child is Label3D or child == rail or child == station or child.name in ["ExitTunnel","Entrance","LoadingGate"]:
   continue
  MeshFactory.collect_surfaces(child,Transform3D.IDENTITY,groups)
  stage.remove_child(child)
  child.queue_free()
 for mat in groups:
  var st = SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for item in groups[mat]:st.append_from(item.mesh,0,item.transform)
  MeshFactory.mesh_node(stage,"BatchedScenery",st.commit(),Vector3.ZERO,mat)

func build_countryside(theme: Dictionary) -> void:
 for i in range(24):
  var place=Vector3(rng.randf_range(-11,11),0,rng.randf_range(-14,14))
  if near_track(place,2.2) or (absf(place.x)<3.4 and absf(place.z)<2):continue
  plant_tree(place,rng.randf_range(.65,.95),theme)
 for at in [Vector3(-3,0,-8.4),Vector3(3,0,7.7)]:
  if not near_track(at,2):build_cottage(at,theme)

func build_friend() -> void:
 rescue_result="";friend_time=0.0
 var end=rail.point_at(rail.total_length) if rail.branches.is_empty() else Vector3(0,0,-2.3)
 MeshFactory.box(stage,"RescueDock",Vector3(2.8,.30,2.3) if rail.branches.is_empty() else Vector3(16.8,.20,1.35),end+Vector3(0,.05,.4 if rail.branches.is_empty() else -.15),Color("b9b5a4"),.06)
 if not rail.branches.is_empty():
  MeshFactory.box(stage,"RescuePlatformEdge",Vector3(16.8,.035,.10),Vector3(0,.17,-3.10),Color("c8ad72"),.01)
 for x in ([-1.15,1.15] if rail.branches.is_empty() else [-7.8,7.8]):
  MeshFactory.cylinder(stage,"SafetyPost",.075,.7,end+Vector3(x,.45,.6),Color("437c80"))
 rescue_friend=Node3D.new();rescue_friend.name="LittleFriend";stage.add_child(rescue_friend)
 friend_home=end+Vector3(0,.35,.45);rescue_friend.position=friend_home
 # Pamuk: cream-and-cocoa puppy, floppy ears and a teal scarf.
 var fur=Color("d8c5a0");var cream=Color("f2e6cf");var cocoa=Color("775b4b")
 rescue_friend.scale=Vector3.ONE*1.24
 var body=MeshFactory.sphere(rescue_friend,"PuppyBody",.43,Vector3(0,.43,0),fur);body.scale=Vector3(.87,1.12,.78)
 var bib=MeshFactory.sphere(rescue_friend,"ChestPatch",.27,Vector3(0,.47,.26),cream);bib.scale=Vector3(.85,1.05,.35)
 var face=MeshFactory.sphere(rescue_friend,"PuppyHead",.48,Vector3(0,1.02,.05),cream);face.scale=Vector3(1,1,.9)
 var patch=MeshFactory.sphere(rescue_friend,"EyePatch",.22,Vector3(-.21,1.10,.39),fur);patch.scale=Vector3(1,1.18,.25)
 for side in [-1,1]:
  var ear=MeshFactory.sphere(rescue_friend,"FloppyEar",.23,Vector3(side*.43,.98,.02),cocoa);ear.scale=Vector3(.72,1.72,.65);ear.rotation.z=side*.20
  var paw=MeshFactory.sphere(rescue_friend,"Paw",.18,Vector3(side*.25,.14,.24),cream);paw.scale=Vector3(1,.75,1.28)
  MeshFactory.sphere(rescue_friend,"Eye",.079,Vector3(side*.18,1.10,.45),Color("25343b"))
  MeshFactory.sphere(rescue_friend,"EyeGlint",.027,Vector3(side*.18-.018,1.13,.51),Color("fffdf0"))
  MeshFactory.sphere(rescue_friend,"SoftMuzzle",.145,Vector3(side*.105,.91,.48),cream)
 var nose=MeshFactory.sphere(rescue_friend,"PuppyNose",.085,Vector3(0,.98,.60),Color("3c3835"));nose.scale=Vector3(1.2,.8,.8)
 var tongue=MeshFactory.sphere(rescue_friend,"Tongue",.065,Vector3(0,.82,.56),Color("c9827b"));tongue.scale=Vector3(.75,1,.4)
 MeshFactory.box(rescue_friend,"TealScarf",Vector3(.62,.15,.47),Vector3(0,.72,.08),Color("3d9896"),.07)
 var scarf=MeshFactory.box(rescue_friend,"ScarfEnd",Vector3(.16,.30,.055),Vector3(.16,.57,.34),Color("3d9896"),.04);scarf.rotation.z=-.2
 var tail=Node3D.new();tail.name="WaggingTail";tail.position=Vector3(.31,.40,-.15);rescue_friend.add_child(tail)
 var tip=MeshFactory.sphere(tail,"Tail",.16,Vector3(.19,.12,0),fur);tip.scale=Vector3(1.6,.65,.65);tip.rotation.z=.5

func set_rescue_result(result: String) -> void:
 rescue_result=result;friend_time=0.0

func theme_color(key:String)->String:
 return THEMES[current_theme][key]

func build_toy_scenery(theme:Dictionary)->void:
 # Big readable areas, with decorations only outside the input area.
 var pond_at=Vector3(0,-.01,-8)
 if not near_track(pond_at,2.8):
  var shore=MeshFactory.cylinder(stage,"PondSand",2.2,.08,pond_at,Color("fff3c9"));shore.scale.z=.58
  var water=MeshFactory.cylinder(stage,"PondWater",1.96,.09,pond_at+Vector3.UP*.04,Color("69d6db"));water.scale.z=.57
  for j in range(3):MeshFactory.box(stage,"PondGlint",Vector3(.65,.012,.04),pond_at+Vector3(-.8+j*.7,.11,-.15+j*.15),Color("dcffff"),.005)
 MeshFactory.box(stage,"BlueLagoon",Vector3(80,.06,30),Vector3(0,-.03,29),Color(theme.bg),.02)
 for i in range(3):
  MeshFactory.box(stage,"ShoreFoam",Vector3(80,.025,.18),Vector3(0,.015,14.1+i*.55),Color("fff9ea"),.01)
 for at in [Vector3(-9,0,-9),Vector3(9,0,-3),Vector3(-9,0,6),Vector3(9,0,10),Vector3(-7,0,14)]:
  if near_track(at,1.6):continue
  MeshFactory.cylinder(stage,"PalmStem",.13,1.3,at+Vector3.UP*.65,Color("c39669"))
  for j in range(5):
   var angle=j*TAU/5
   var leaf=MeshFactory.sphere(stage,"PalmLeaf",.7,at+Vector3(cos(angle)*.48,1.45,sin(angle)*.48),Color(theme.leaves))
   leaf.scale=Vector3(.48,.20,1.4);leaf.rotation.y=-angle+PI/2
 for i in range(12):
  var at=Vector3((-1 if i%2==0 else 1)*rng.randf_range(8.0,10.5),.08,rng.randf_range(-13,13))
  if near_track(at,1.4):continue
  var pebble=MeshFactory.sphere(stage,"Shell",.15,at,Color("fff8e3"));pebble.scale=Vector3(1.3,.4,1)
 var patch=MeshFactory.cylinder(stage,"RescueGarden",2.1,.10,rail.point_at(rail.total_length)+Vector3(0,-.02,.5),Color(theme.accent));patch.scale.z=.65

func build_rich_scenery(theme:Dictionary)->void:
 # Layered coast and greenery frame the board without crossing any exit or rail.
 for side in [-1,1]:
  for z in [-11.0,-5.0,2.0,8.0,13.0]:
   var at=Vector3(side*10.8,-.01,z)
   var bank=MeshFactory.sphere(stage,"LandscapeMound",1.4,at,Color(theme.leaves).lightened(.30));bank.scale=Vector3(1.2,.09,1.6)
   for j in range(3):
    var bush=MeshFactory.sphere(stage,"RoundShrub",.48,at+Vector3(-side*.8+j*.35,.22,-.6+j*.55),Color(theme.leaves));bush.scale.y=.65
    MeshFactory.sphere(stage,"GardenFlower",.12,at+Vector3(-side*.8+j*.35,.57,-.6+j*.55),Color(theme.accent))
 # Shore visible down both edges, not hidden entirely behind the bottom controls.
 for side in [-1,1]:
  for j in range(16):
   var z=2.0+j*.85;var x=side*(9.5+sin(j*.48)*.35)
   var water=MeshFactory.cylinder(stage,"ShoreWater",1.6,.025,Vector3(x,-.035,z),Color("73d4d1"));water.scale.x=1.4
   var foam=MeshFactory.sphere(stage,"FoamCrest",.26,Vector3(x-side*1.25,.01,z),Color("e9fff4"));foam.scale=Vector3(.45,.05,1.8)
 # Modelled station buildings and picnic details in the quiet middle of the upper map.
 var picnic=Vector3(-2.3,0,-8.2)
 if not near_track(picnic,2.5):
  build_cottage(picnic,theme)
  for j in range(4):MeshFactory.box(stage,"SteppingStone",Vector3(.38,.035,.28),picnic+Vector3(1.0+j*.43,.025,.65),Color("fff5d6"),.07)
 var shade=Vector3(2.5,0,-8.1)
 if not near_track(shade,2.0):
  MeshFactory.box(stage,"PicnicBlanket",Vector3(1.5,.025,1.1),shade,Color("f29b86"),.08)
  for k in range(3):MeshFactory.box(stage,"BlanketStripe",Vector3(1.5,.015,.08),shade+Vector3(0,.025,-.35+k*.35),Color("ffe7bf"),.02)
  MeshFactory.cylinder(stage,"SunshadePole",.045,1.4,shade+Vector3(.3,.7,-.2),Color("d2a56c"))
  MeshFactory.cylinder(stage,"Sunshade",.88,.36,shade+Vector3(.3,1.45,-.2),Color(theme.accent),.08)
 # Small fence and rocks restore depth from the earlier landscape treatment.
 for side in [-1,1]:
  for j in range(4):
   var at=Vector3(side*7.8,.22,4.0+j*1.3)
   MeshFactory.box(stage,"FencePost",Vector3(.13,.50,.13),at,Color("fff3d3"),.035)
   if j<3:MeshFactory.box(stage,"FenceRail",Vector3(.08,.12,1.3),at+Vector3(0,.08,.65),Color("fff3d3"),.03)
 for i in range(24):
  var side=-1 if i%2==0 else 1
  var at=Vector3(side*rng.randf_range(7.7,9.1),.07,rng.randf_range(-12,13))
  if near_track(at,1.2):continue
  var rock=MeshFactory.sphere(stage,"SmoothRock",rng.randf_range(.12,.28),at,Color("e0bf96"));rock.scale=Vector3(1.2,.55,.9)

func build_railway_landscape(theme:Dictionary)->void:
 # Track clearances and board remain unobstructed. Natural, low contrast scenery.
 for side in [-1,1]:
  for i in range(11):
   var at=Vector3(side*rng.randf_range(9.8,11.2),0,-13.0+i*2.4)
   if not near_track(at,1.7):plant_tree(at,rng.randf_range(1.1,1.65),theme)
  for i in range(16):
   var at=Vector3(side*rng.randf_range(8.0,10.0),.04,rng.randf_range(-14,14))
   if near_track(at,1.1):continue
   var rock=MeshFactory.sphere(stage,"WeatheredStone",rng.randf_range(.12,.38),at,Color("7c847c"));rock.scale=Vector3(1.5,.5,1.0)
  for i in range(8):
   var at=Vector3(side*7.6,.24,2.0+i*1.5)
   MeshFactory.box(stage,"SteelFencePost",Vector3(.065,.65,.065),at,Color("53615e"))
   if i<7:
    for y in [.0,.25]:MeshFactory.box(stage,"FenceRail",Vector3(.04,.035,1.5),at+Vector3(0,y,.75),Color("768780"))
 var at=Vector3(-.8,0,-8.7)
 if not near_track(at,2.4):
  build_cottage(at,theme)
  MeshFactory.box(stage,"DepotApron",Vector3(3.8,.05,2.6),at+Vector3(0,-.01,.2),Color("92978d"),.03)
  for i in range(3):
   MeshFactory.box(stage,"StackedTimber",Vector3(1.2,.14,.16),at+Vector3(1.4,.16+i*.14,.5),Color("7c6851"),.01)
 # Fine stones in the track bed add scale without competing with train colors.
 for i in range(int(rail.total_length*4)):
  var d=float(i)*.25;var point=rail.point_at(d);var normal=rail.direction_at(d).cross(Vector3.UP)
  var at_gravel=point+normal*rng.randf_range(-.67,.67)+Vector3.UP*.035
  var stone=MeshFactory.sphere(stage,"BallastStone",.065,at_gravel,Color("7e8178"));stone.scale.y=.4

func build_campaign_landscape(theme:Dictionary,level:Dictionary)->void:
 # A composed landscape: asymmetrical groves, an inset station courtyard, winding banks.
 # No scenery in the touch board; keep a 2m clearance around the rail.
 for side in [-1,1]:
  var bank_points=PackedVector3Array();var water_points=PackedVector3Array()
  for i in range(65):
   var z=-20.0+i*.65
   var x=side*(11.3+sin(z*.26+side)*1.1+sin(z*.61)*.28)
   bank_points.append(Vector3(x,.005,z));water_points.append(Vector3(x+side*.65,.018,z))
  MeshFactory.ribbon(stage,"CurvingBank",bank_points,4.4,Color(theme.edge).lightened(.13))
  MeshFactory.ribbon(stage,"StreamBed",water_points,3.7,Color("597d79") if current_theme!=4 else Color("ac8a65"))
  if current_theme!=4:
   var water=MeshFactory.ribbon(stage,"Stream",water_points,3.2,Color("739e9c") if current_theme!=5 else Color("adc7c7"))
   water.position.y=.024
   water.material_override=MeshFactory.material(Color("739e9c") if current_theme!=5 else Color("adc7c7"),.18,.29)
  # Organic clusters with gaps, never a repeating border.
  for cluster in range(4):
   var center=Vector3(side*rng.randf_range(9.2,10.4),0,-15+cluster*7.3+rng.randf_range(-1.8,1.8))
   MeshFactory.organic(stage,"RaisedGrassyBank",center-Vector3.UP*.16,Vector3(2.1,.42,2.4),Color(theme.edge).lightened(.09),float(cluster),.12)
   for j in range(3):
    var at=center+Vector3(rng.randf_range(-.7,.8),0,rng.randf_range(-1.1,1.1))
    if near_track(at,2.0):continue
    if current_theme==4:
     MeshFactory.organic(stage,"ErodedSandstone",at+Vector3.UP*.2,Vector3(.75,.55,.68),Color("a5866c"),float(j),.20)
    else:plant_tree(at,rng.randf_range(.82,1.36),theme)
   for j in range(7):
    var at=center+Vector3(rng.randf_range(-1.5,1.5),.05,rng.randf_range(-2,2))
    if near_track(at,1.35) or absf(at.x)<7.5:continue
    MeshFactory.organic(stage,"Understory",at,Vector3(.31,.21,.27),Color(theme.leaves).lightened(.12),float(j),.17)
  for i in range(12):
   var at=Vector3(side*rng.randf_range(8.3,10),.03,rng.randf_range(-16,16))
   if near_track(at,1.5):continue
   MeshFactory.organic(stage,"RiverStone",at,Vector3(.23,.16,.29),Color("9a9d88"),float(i),.18)
 # Choose one clear focal station, with paths joining the yard instead of scattered objects.
 for at in [Vector3(-1.2,0,-9.0),Vector3(2.1,0,-7.4),Vector3(-3.8,0,-8.2)]:
  if not near_track(at,2.6):
   MeshFactory.organic(stage,"StationGarden",at-Vector3.UP*.10,Vector3(3.1,.17,2.2),Color(theme.edge).lightened(.08),3,.12)
   var path=PackedVector3Array([at+Vector3(0,.015,.6),at+Vector3(1.3,.015,1.7),at+Vector3(2.4,.015,1.6)])
   MeshFactory.ribbon(stage,"GravelWalk",path,.68,Color("c0b6a0"))
   build_depot(at,theme)
   break
 # An intentionally quieter rail yard foreground, with timber and small service details.
 var yard_end=4.2+(int(level.rows)-1)*2.35+1.6
 for side in [-1,1]:
  var x=side*7.4
  for z in [2.1,yard_end]:
   var post=Vector3(x,0,z)
   MeshFactory.cylinder(stage,"YardBollard",.075,.58,post+Vector3.UP*.29,Color("556466"))
   MeshFactory.cylinder(stage,"BollardCap",.085,.055,post+Vector3.UP*.60,Color("c6b380"))
  if int(level.rows)<=3:
   build_bench(Vector3(side*4.8,0,yard_end+1.2),theme)
   for i in range(3):MeshFactory.organic(stage,"GardenBorderPlant",Vector3(side*6.0,.12,yard_end+.4+i*.45),Vector3(.28,.24,.33),Color(theme.leaves),float(i),.15)
 # Ballast grains close to the rail; low contrast so the gameplay colors stay dominant.
 for i in range(int(rail.total_length*3)):
  var d=float(i)/3;var point=rail.point_at(d);var normal=rail.direction_at(d).cross(Vector3.UP)
  var stone=MeshFactory.sphere(stage,"BallastStone",.055,point+normal*rng.randf_range(-.66,.66)+Vector3.UP*.035,Color("8b887d"));stone.scale.y=.4

func build_flower_bed(at:Vector3,theme:Dictionary)->void:
 MeshFactory.box(stage,"GardenBorder",Vector3(1.15,.12,.55),at+Vector3.UP*.02,Color("929c83"),.08)
 MeshFactory.box(stage,"Soil",Vector3(1.01,.05,.41),at+Vector3.UP*.10,Color("6c7960"),.07)
 for i in range(4):
  var pos=at+Vector3(-.38+i*.25,.19,0)
  var leaf=MeshFactory.sphere(stage,"FlowerLeaves",.17,pos,Color(theme.leaves));leaf.scale.y=.65
  MeshFactory.sphere(stage,"Bloom",.065,pos+Vector3.UP*.13,Color("e6d3a0") if i%2==0 else Color(theme.accent))

func build_bench(at:Vector3,theme:Dictionary)->void:
 for x in [-.52,.52]:MeshFactory.box(stage,"BenchLeg",Vector3(.08,.42,.40),at+Vector3(x,.21,0),Color("65776b"),.02)
 for z in [-.16,0,.16]:MeshFactory.box(stage,"BenchSlat",Vector3(1.35,.07,.12),at+Vector3(0,.46,z),Color("b89772"),.02)
 MeshFactory.box(stage,"BenchBack",Vector3(1.35,.29,.08),at+Vector3(0,.70,-.23),Color("b89772"),.035)

func build_old_depot(at:Vector3,theme:Dictionary)->void:
 MeshFactory.box(stage,"DepotPaving",Vector3(3.5,.055,2.5),at+Vector3(0,-.015,.25),Color("c4c5ae"),.15)
 build_cottage(at,theme)
 # Platform awning, lit windows, planter and a readable roof silhouette.
 MeshFactory.box(stage,"Awning",Vector3(2.25,.09,.70),at+Vector3(0,1.1,.95),Color(theme.roof),.04)
 for x in [-1.0,1.0]:MeshFactory.cylinder(stage,"AwningPost",.045,1.08,at+Vector3(x,.54,1.12),Color("899482"))
 build_flower_bed(at+Vector3(-1.25,0,-.25),theme)
 build_bench(at+Vector3(1.6,0,.25),theme)
 if current_theme==3:build_clock(at+Vector3(1.5,0,-.8),theme)

func build_clock(at:Vector3,_theme:Dictionary)->void:
 MeshFactory.cylinder(stage,"ClockPost",.055,1.5,at+Vector3.UP*.75,Color("526c65"))
 var clock=MeshFactory.cylinder(stage,"ClockFrame",.30,.10,at+Vector3.UP*1.6,Color("526c65"));clock.rotation_degrees.x=90
 var face=MeshFactory.cylinder(stage,"ClockFace",.25,.115,at+Vector3.UP*1.6,Color("e9dfbe"));face.rotation_degrees.x=90
 MeshFactory.box(stage,"ClockHand",Vector3(.025,.16,.02),at+Vector3(0,1.66,.065),Color("526c65"))
 MeshFactory.box(stage,"ClockHand",Vector3(.12,.025,.02),at+Vector3(.05,1.6,.065),Color("526c65"))

func build_depot(at:Vector3,theme:Dictionary)->void:
 var house=Node3D.new();stage.add_child(house);house.position=at
 MeshFactory.box(house,"StonePlinth",Vector3(3.3,.18,2.5),Vector3(0,.02,.1),Color("89938a"),.08)
 MeshFactory.box(house,"StuccoWalls",Vector3(2.6,1.48,1.8),Vector3(0,.82,0),Color("d5c7a7"),.045)
 MeshFactory.gable(house,Vector3(0,1.54,0),2.6,.66,1.8,Color("d5c7a7"))
 for y in [.20,.36]:MeshFactory.box(house,"FoundationCourse",Vector3(2.7,.13,1.88),Vector3(0,y,0),Color("8e9c96"),.02)
 for side in [-1,1]:
  var roof=MeshFactory.box(house,"PitchedRoof",Vector3(1.80,.10,2.25),Vector3(side*.80,1.93,0),Color("805443"),.025);roof.rotation.z=-side*.4636
  for row in range(7):
   for col in range(6):
    var x=side*(.12+row*.22);var z=-.94+col*.37
    var tile=MeshFactory.box(house,"TerracottaTile",Vector3(.24,.045,.35),Vector3(x,2.42-absf(x)*.5,z),Color(theme.roof).lightened(.04 if (row+col)%3==0 else 0),.025);tile.rotation.z=-side*.4636
  for x in [-.85,0,.85]:
   MeshFactory.box(house,"WindowSurround",Vector3(.48,.69,.07),Vector3(x,.98,side*.93),Color("f0e4c8"),.025)
   MeshFactory.box(house,"GlazedWindow",Vector3(.36,.53,.08),Vector3(x,1.0,side*.98),Color("436571"),.015)
   MeshFactory.box(house,"WindowMullion",Vector3(.028,.54,.095),Vector3(x,1.0,side*.99),Color("c9bba0"),.005)
   MeshFactory.box(house,"WindowCrossbar",Vector3(.37,.025,.095),Vector3(x,1.06,side*.99),Color("c9bba0"),.005)
   MeshFactory.box(house,"StoneSill",Vector3(.55,.075,.18),Vector3(x,.69,side*1.01),Color("aab6aa"),.015)
 MeshFactory.cylinder(house,"RidgeCap",.085,2.32,Vector3(0,2.46,0),Color("ad7d59")).rotation_degrees.x=90
 MeshFactory.box(house,"ChimneyStack",Vector3(.30,.65,.34),Vector3(.55,2.28,-.45),Color("a28b70"),.025)
 MeshFactory.box(house,"ChimneyCap",Vector3(.40,.09,.43),Vector3(.55,2.64,-.45),Color("6c7773"),.02)
 var canopy=MeshFactory.barrel_roof(house,"PlatformCanopy",2.8,.85,.10,Vector3(0,1.30,1.30),Color("3b6265"))
 for x in [-1.2,1.2]:
  MeshFactory.cylinder(house,"CastIronPost",.045,1.28,Vector3(x,.65,1.55),Color("304a50"))
  MeshFactory.box(house,"PostFoot",Vector3(.18,.14,.18),Vector3(x,.12,1.55),Color("9ca99d"),.02)
 build_bench(at+Vector3(1.7,0,.2),theme)
 build_flower_bed(at+Vector3(-1.7,0,.25),theme)

func build_water_tower(at:Vector3)->void:
 var tower=Node3D.new();stage.add_child(tower);tower.position=at
 MeshFactory.box(tower,"Footing",Vector3(1.8,.12,1.8),Vector3(0,.02,0),Color("99a393"),.05)
 for x in [-.52,.52]:
  for z in [-.52,.52]:MeshFactory.box(tower,"TimberLeg",Vector3(.13,1.75,.13),Vector3(x,.9,z),Color("756452"),.018)
 for side in [-1,1]:
  for tilt in [-1,1]:
   var brace=MeshFactory.box(tower,"DiagonalBrace",Vector3(.07,1.4,.07),Vector3(side*.52,.95,0),Color("8f795d"),.01);brace.rotation.x=tilt*.60
 MeshFactory.cylinder(tower,"TankBody",.76,1.05,Vector3(0,2.05,0),Color("75868a"))
 for y in [1.57,1.85,2.35,2.55]:MeshFactory.cylinder(tower,"SteelHoop",.78,.045,Vector3(0,y,0),Color("394f57"))
 MeshFactory.cylinder(tower,"ConicalRoof",.90,.42,Vector3(0,2.79,0),Color("394f57"),.08)
 for i in range(12):MeshFactory.box(tower,"TankSeam",Vector3(.025,.94,.025),Vector3(cos(i*TAU/12)*.765,2.05,sin(i*TAU/12)*.765),Color("9aaaa7"))
 MeshFactory.cylinder(tower,"Spout",.065,1.4,Vector3(.82,1.55,0),Color("455b63"))

func build_railway_details(theme:Dictionary)->void:
 for at in [Vector3(-8.8,0,-3.8),Vector3(8.8,0,-4.0)]:
  if not near_track(at,1.5):build_water_tower(at);break
 # Individual pavers and a brass platform edge replace an undetailed flat slab.
 for x in range(-13,14):
  for z in [-.57,.02,.61]:
   MeshFactory.box(stage,"StationPaver",Vector3(.46,.04,.54),Vector3(x*.5,.245,z+.15),Color("9da89e").lightened(.025 if x%2==0 else 0),.018)
 for z in [-.82,1.10]:MeshFactory.box(stage,"PlatformSafetyEdge",Vector3(14.0,.035,.09),Vector3(0,.27,z),Color("c8ad72"),.015)
 for side in [-1,1]:
  var at=Vector3(side*7.35,0,.1)
  MeshFactory.cylinder(stage,"PlatformLampPost",.055,1.9,at+Vector3.UP*.95,Color("304b54"))
  MeshFactory.box(stage,"LampBracket",Vector3(.45,.055,.055),at+Vector3(-side*.15,1.9,0),Color("304b54"),.01)
  var lamp=MeshFactory.box(stage,"FrostedLamp",Vector3(.25,.25,.20),at+Vector3(-side*.33,1.74,0),Color("f2dca7"),.035)
  lamp.material_override=MeshFactory.material(Color("f2dca7"),0,.25)
  MeshFactory.box(stage,"LampCap",Vector3(.33,.06,.28),at+Vector3(-side*.33,1.91,0),Color("304b54"),.025)

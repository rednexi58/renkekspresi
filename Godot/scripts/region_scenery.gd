class_name RegionScenery
extends RefCounted

# Geometry stays outside the interactive yard and clears the sampled rail.
static func build(world: GameWorld, level: Dictionary) -> void:
 var region=int((int(level.id)-1)/5)
 var stage=world.stage
 var theme=world.THEMES[world.current_theme]
 var variant=posmod(int(level.id)-1,5)
 world.sun.light_color=Color("fff1d8") if region==0 else Color("e5efff") if region==2 else Color("fff4e0")
 world.sun.rotation_degrees=Vector3(-63,-32+variant*7,0)
 if region==0:
  var shore=PackedVector3Array()
  for i in range(48):
   shore.append(Vector3(-11.7+sin(i*.27+variant)*.8,.025,-24+i*.9))
  MeshFactory.ribbon(stage,"CoastSand",shore,6.0,Color("e2d0ab"))
  var sea=MeshFactory.box(stage,"Sea",Vector3(38,.08,70),Vector3(-32,.015,-5),Color("568e9e"),.02)
  sea.material_override=MeshFactory.material(Color("568e9e"),.12,.28)
  for i in range(7):
   var line=PackedVector3Array()
   for j in range(28):line.append(Vector3(-13.6-i*.6+sin(j*.34+variant)*.28,.07,-22+j*1.5))
   MeshFactory.ribbon(stage,"SeaFoam",line,.055,Color("b1d4d2"))
  var at=Vector3(9.8,0,-9-variant*.7)
  MeshFactory.cylinder(stage,"LighthouseBase",1.05,.25,at,Color("b8b4a6"))
  MeshFactory.cylinder(stage,"Lighthouse",.62,3.6,at+Vector3.UP*1.8,Color("eee7d8"),.42)
  MeshFactory.cylinder(stage,"LighthouseBand",.52,.38,at+Vector3.UP*2.7,Color("a56654"))
  MeshFactory.cylinder(stage,"Lantern",.55,.52,at+Vector3.UP*3.7,Color("dec28a"))
  MeshFactory.cylinder(stage,"LanternRoof",.76,.38,at+Vector3.UP*4.1,Color("495a63"),0.0)
  for i in range(4):
   var p=Vector3(9.4,0,-18+i*6+variant*.4)
   if not world.near_track(p,2.0):world.plant_tree(p,.85,theme)
 elif region==1:
  var stream=PackedVector3Array()
  for i in range(45):stream.append(Vector3(11.8+sin(i*.32+variant)*.7,.02,-25+i))
  MeshFactory.ribbon(stage,"ForestRiverBank",stream,4.1,Color("7f9283"))
  MeshFactory.ribbon(stage,"ForestRiver",stream,2.7,Color("537f88"))
  for side in [-1,1]:
   for i in range(10):
    var p=Vector3(side*(9.5+world.rng.randf_range(0,1.9)),0,-23+i*4+world.rng.randf_range(-1,1))
    if not world.near_track(p,2.0):world.plant_tree(p,world.rng.randf_range(.95,1.55),theme)
  for i in range(5):
   var log=MeshFactory.cylinder(stage,"TimberStack",.17,2.5,Vector3(-9.3,.2+i*.22,-3+variant),Color("876c50"))
   log.rotation.z=PI/2
 else:
  for side in [-1,1]:
   for i in range(6):
    var p=Vector3(side*(11.4+world.rng.randf_range(0,2)),0,-24+i*7)
    MeshFactory.organic(stage,"GraniteRidge",p,Vector3(2.4,1.6+float(i%3)*.65,3.1),Color("839398"),float(i+variant),.14)
    MeshFactory.organic(stage,"SnowCap",p+Vector3.UP*(1.2+float(i%3)*.5),Vector3(1.5,.45,2),Color("e4e9e5"),float(i),.12)
    var tree_at=p+Vector3(-side*1.8,0,2)
    if not world.near_track(tree_at,2):world.plant_tree(tree_at,.9,theme)
  for i in range(6):
   var at=Vector3(-10,.1,-19+i*3.4)
   MeshFactory.box(stage,"MountainRetainingWall",Vector3(.65,1,2.9),at,Color("8a9695"),.12)
 # Landmark location changes with the actual rail layout, never over a rail.
 for p in [Vector3(-2,0,-9),Vector3(3,0,-8),Vector3(-3,0,-5)]:
  if not world.near_track(p,2.8):
   world.build_depot(p,theme)
   break
 var sign=Label3D.new()
 sign.text=str(level.get("region_en","")) if Locale.language=="en" else str(level.region)
 sign.font=load("res://assets/fonts/World-Bold.ttf")
 sign.font_size=40;sign.pixel_size=.012;sign.position=Vector3(0,.14,1.5)
 sign.rotation_degrees.x=-90;sign.modulate=Color("53666b")
 stage.add_child(sign)

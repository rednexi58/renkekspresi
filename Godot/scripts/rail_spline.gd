class_name RailSpline
extends Node3D
var curve: Curve3D
var total_length: float = 0.0
var looped: bool = false
var branches:Array[Curve3D]=[]
var common:Curve3D
var merge_distance=12.0

func _init() -> void:
 configure(0)

func configure(layout: int, _mirrored: bool = false) -> void:
 looped=true;curve=Curve3D.new();curve.bake_interval=.045
 var paths=[
  [[0,11],[-5,11],[-7.8,8],[-7.8,-8],[-5,-11],[5,-11],[7.8,-8],[7.8,8],[5,11]],
  [[0,11],[-5.5,8.5],[-8,0],[-5.5,-8.5],[0,-11],[5.5,-8.5],[8,0],[5.5,8.5]],
  [[0,11],[-5,10],[-8,6],[-8,-6],[-5,-10],[0,-11],[5,-10],[8,-6],[8,6],[5,10]],
  [[0,11],[-6,9],[-8.7,4],[-7.3,0],[-8.7,-4],[-6,-9],[0,-11],[6,-9],[8,0],[6,9]],
  [[0,11],[-6,9],[-8,0],[-6,-9],[0,-11],[6,-9],[8.7,-4],[7.3,0],[8.7,4],[6,9]],
  [[0,11],[-5.5,11],[-7.2,8],[-8.8,-8],[-6.8,-11],[4.8,-11],[7,-8],[8.7,8],[6.5,11]],
  [[0,11],[-5,11],[-8,7],[-8,-7],[-5,-11],[5,-11],[8,-7],[8,7],[5,11]],
  [[0,11],[-5.7,10],[-8.8,5],[-7.8,-1],[-8.8,-6],[-5,-11],[4,-11],[8,-7],[8,5],[5,10]],
  [[0,11],[-5.8,10],[-8.6,6],[-9,0],[-8.6,-6],[-5.8,-10],[0,-11],[5.8,-10],[8.6,-6],[9,0],[8.6,6],[5.8,10]],
  [[0,11],[-6,11],[-8.6,7],[-7.5,2],[-8.6,-4],[-7.5,-9],[-3,-11],[4,-10],[8.6,-7],[7.5,-2],[8.6,4],[7.5,9],[4,11]]
 ]
 var points=paths[posmod(layout,10)].duplicate(true)
 # Three families: original, mirrored with wider shoulders, tapered with shifted bend.
 var family=int(layout/10)
 for point in points:
  if family==1:point[0]=-float(point[0])*(1.02 if absf(float(point[1]))<8 else .98)
  if family==2:
   point[0]=float(point[0])*(1.04 if float(point[1])<0 else .98)
   point[1]=float(point[1])*.97+sin(float(point[0])*.3)*.2
 for i in range(points.size()+1):
  var index=i%points.size();var previous=points[posmod(index-1,points.size())];var next=points[(index+1)%points.size()]
  var at=Vector3(points[index][0],0,points[index][1]);var tangent=Vector3(next[0]-previous[0],0,next[1]-previous[1])*.13
  curve.add_point(at,-tangent,tangent)
 total_length=curve.get_baked_length()

func configure_open(layout: int) -> void:
 looped=false;curve=Curve3D.new();curve.bake_interval=.045
 var paths=[
  [[-8,-12],[-3,-12],[3,-12],[8,-10],[8,-6],[4,-4],[-2,-4],[-6,-2]],
  [[-8,-12],[-8,-8],[-3,-7],[3,-11],[8,-10],[8,-6],[3,-4],[-3,-2]],
  [[8,-12],[3,-12],[-4,-11],[-8,-8],[-5,-5],[2,-6],[7,-4],[5,-2]],
  [[-8,-12],[-3,-10],[3,-12],[8,-9],[4,-7],[-3,-7],[-7,-4],[-2,-2]],
  [[-8,-12],[-2,-11],[5,-12],[8,-9],[4,-6],[-3,-6],[-7,-4],[-3,-2]],
  [[8,-12],[1,-12],[-6,-10],[-8,-6],[-4,-4],[2,-5],[7,-4],[6,-2]],
  [[-8,-12],[-7,-8],[-2,-6],[5,-8],[8,-6],[5,-3],[-1,-2]],
  [[8,-12],[2,-11],[-5,-12],[-8,-9],[-4,-6],[4,-7],[7,-4],[2,-2]],
  [[-8,-12],[-3,-12],[3,-10],[8,-11],[8,-7],[2,-5],[-5,-5],[-7,-2]],
  [[8,-12],[7,-9],[2,-7],[-4,-9],[-8,-7],[-6,-4],[0,-3],[5,-2]]
 ]
 var points=paths[posmod(layout,10)].duplicate(true)
 var family=int(layout/10)
 for point in points:
  point[0]=float(point[0])*(-1.0 if family==1 else 1.0)*(1.0+float(posmod(layout,3))*.025)
  point[1]=float(point[1])*1.12
  if family==2:point[1]+=sin(float(point[0])*.45)*.45
 for i in range(points.size()):
  var before=points[maxi(0,i-1)];var after=points[mini(points.size()-1,i+1)]
  var tangent=Vector3(after[0]-before[0],0,after[1]-before[1])*.12
  curve.add_point(Vector3(points[i][0],0,points[i][1]),-tangent,tangent)
 total_length=curve.get_baked_length()

func add_point(point: Vector3, incoming: Vector3, outgoing: Vector3) -> void:
 curve.add_point(point,incoming,outgoing)

func point_at(distance: float) -> Vector3:
 if not branches.is_empty():return route_point(0,distance)
 return curve.sample_baked(fposmod(distance,total_length) if looped else clampf(distance,0,total_length),true)

func direction_at(distance: float) -> Vector3:
 return (point_at(distance+.05)-point_at(distance-.05)).normalized()

func build_meshes() -> void:
 build_ballast()
 # All sleepers batched into one MultiMesh draw call.
 var sleeper = BoxMesh.new()
 sleeper.size = Vector3(1.18,.12,.20)
 var multi = MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 multi.mesh = sleeper
 multi.instance_count = int(total_length/.37)+1
 for i in range(multi.instance_count):
  var d = i*.37
  var pos = point_at(d) + Vector3(0,.07,0)
  multi.set_instance_transform(i,Transform3D(Basis.looking_at(direction_at(d)),pos))
 var sleepers = MultiMeshInstance3D.new()
 sleepers.name = "BatchedSleepers"
 sleepers.multimesh = multi
 sleepers.material_override = MeshFactory.material(Color("685b4c"),0,.8)
 add_child(sleepers)
 for offset in [-.37,.37]:
  var st = SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var steps = int(total_length/.12)
  for i in range(steps):
   var corners: Array = []
   for d in [total_length*i/steps,total_length*(i+1)/steps]:
    var normal = direction_at(d).cross(Vector3.UP).normalized()
    var center = point_at(d) + normal*offset + Vector3(0,.17,0)
    corners.append_array([center-normal*.045,center+normal*.045,center+normal*.045+Vector3(0,.10,0),center-normal*.045+Vector3(0,.10,0)])
   for face in [[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
    for j in [0,2,1,0,3,2]:
     st.add_vertex(corners[face[j]])
  st.generate_normals()
  var mat = MeshFactory.material(Color("aebabc"),.65,.28)
  mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  MeshFactory.mesh_node(self,"ContinuousSteelRail",st.commit(),Vector3.ZERO,mat)


func build_ballast() -> void:
 var st = SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count = int(total_length/.16)
 for i in range(count):
  var vertices: Array = []
  for d in [total_length*i/count,total_length*(i+1)/count]:
   var side = direction_at(d).cross(Vector3.UP).normalized()
   vertices.append(point_at(d)+side*.70+Vector3.UP*.015)
   vertices.append(point_at(d)-side*.70+Vector3.UP*.015)
  for idx in [0,1,3,0,3,2]:
   st.set_normal(Vector3.UP)
   st.add_vertex(vertices[idx])
 var mat = MeshFactory.material(Color("7d8073"),0,1)
 mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 MeshFactory.mesh_node(self,"GravelBed",st.commit(),Vector3.ZERO,mat)

func configure_junction(layout:int,count:int)->void:
 # Kept as the entry-point name for existing loaders. These tracks never merge.
 looped=false;branches=[];common=null
 var width=16.0/float(count)
 var amplitude=width*.29
 var bend=1.0 if layout%2==0 else -1.0
 var variants=[[-20.5,-16.5,-12.0,-7.2,-3.2],[-20.5,-17.2,-12.5,-6.9,-3.2],[-20.5,-15.9,-11.4,-6.5,-3.2]]
 var zs=variants[posmod(int(layout/2),3)]
 for lane in range(count):
  var center=-8.0+width*(float(lane)+.5)
  var mirror=1.0 if lane%2==0 else -1.0
  var points=[]
  for i in range(zs.size()):
   var wave=[0.0,-1.0,1.0,-.8,0.0][i]
   points.append(Vector3(center+float(wave)*amplitude*bend*mirror,0,float(zs[i])))
  var branch=Curve3D.new();branch.bake_interval=.045
  for i in range(points.size()):
   var tangent=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)])*.17
   branch.add_point(points[i],-tangent,tangent)
  branches.append(branch)
 curve=branches[0];total_length=curve.get_baked_length();merge_distance=total_length

func route_point(lane:int,distance:float)->Vector3:
 if branches.is_empty():return point_at(distance)
 var branch=branches[clampi(lane,0,branches.size()-1)]
 return branch.sample_baked(clampf(distance,0,branch.get_baked_length()),true)

func route_direction(lane:int,distance:float)->Vector3:
 return (route_point(lane,distance+.05)-route_point(lane,distance-.05)).normalized()

func build_branches()->void:
 for lane in range(1,branches.size()):
  var extra=RailSpline.new();extra.curve=branches[lane];extra.looped=false;extra.total_length=extra.curve.get_baked_length()
  add_child(extra);extra.build_meshes()

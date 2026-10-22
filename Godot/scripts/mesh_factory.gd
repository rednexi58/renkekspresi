class_name MeshFactory
extends RefCounted
## Real mesh assets, shared across instances. Also saved to editable .tscn prefabs.
static var material_cache: Dictionary = {}
static var shape_cache: Dictionary = {}
static var optimized_models: Dictionary = {}

static func material(color: Color, metallic: float = 0.0, roughness: float = 0.58) -> StandardMaterial3D:
	var key = str(color) + str(metallic) + str(roughness)
	if not material_cache.has(key):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = metallic
		mat.roughness = roughness
		mat.metallic_specular = .55
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.0
		material_cache[key] = mat
	return material_cache[key]

static func instantiate_optimized(path: String) -> Node3D:
	if not optimized_models.has(path):
		var source = load(path).instantiate()
		var groups: Dictionary = {}
		collect_surfaces(source,Transform3D.IDENTITY,groups)
		var optimized = Node3D.new()
		optimized.name = source.name
		for mat in groups:
			var st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in groups[mat]:
				st.append_from(item.mesh,0,item.transform)
			var part = MeshInstance3D.new()
			part.name = "BatchedPart"
			part.mesh = st.commit()
			part.material_override = mat
			optimized.add_child(part)
			part.owner = optimized
		var packed = PackedScene.new()
		packed.pack(optimized)
		optimized_models[path] = packed
		optimized.free()
		source.free()
	return optimized_models[path].instantiate()

static func collect_surfaces(node: Node3D, parent_transform: Transform3D, groups: Dictionary) -> void:
	var transform = parent_transform*node.transform
	if node is MeshInstance3D and node.mesh:
		var mat = node.material_override
		if not groups.has(mat):
			groups[mat] = []
		groups[mat].append({"mesh":node.mesh,"transform":transform})
	for child in node.get_children():
		if child is Node3D:
			collect_surfaces(child,transform,groups)

static func mesh_node(parent: Node3D, label: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, color: Color, bevel: float = 0.0) -> MeshInstance3D:
	var mesh: Mesh
	if bevel > 0:
		mesh = rounded_box(size, bevel)
	else:
		var shape = BoxMesh.new()
		shape.size = size
		mesh = shape
	return mesh_node(parent, label, mesh, at, material(color))

static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var key = str(size) + str(radius)
	if shape_cache.has(key):
		return shape_cache[key]
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = size / 2.0
	radius = minf(radius,minf(half.x,minf(half.y,half.z))*.94)
	var inner = half - Vector3.ONE * radius
	var nsteps = 6
	# Face basis, with clockwise triangles as required by Godot.
	for face in [[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP], [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK], [Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP]]:
		var norm: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		for row in range(nsteps):
			for col in range(nsteps):
				var uv = [Vector2(col, row), Vector2(col+1,row), Vector2(col+1,row+1), Vector2(col,row+1)]
				for idx in [0,2,1,0,3,2]:
					var p = (norm + u * (uv[idx].x / nsteps * 2.0 - 1.0) + v * (uv[idx].y / nsteps * 2.0 - 1.0)) * half
					var clamped = p.clamp(-inner, inner)
					var normal = (p-clamped).normalized()
					st.set_normal(normal)
					st.add_vertex(clamped + normal * radius)
	var result = st.commit()
	shape_cache[key] = result
	return result

static func cylinder(parent: Node3D, label: String, radius: float, height: float, at: Vector3, color: Color, top_radius: float = -1.0) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius if top_radius < 0 else top_radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 32
	shape.rings = 1
	return mesh_node(parent, label, shape, at, material(color))

static func sphere(parent: Node3D, label: String, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius*2
	shape.radial_segments = 32
	shape.rings = 16
	return mesh_node(parent, label, shape, at, material(color))

static func wheels(parent: Node3D, engine: bool = false) -> void:
	var chassis = Color("263e43")
	var metal = Color("b2c6c3")
	var bogies = [-0.46,0.46] if not engine else [-0.65,0.05,0.65]
	for z in bogies:
		box(parent, "Bogie", Vector3(.83,.13,.30), Vector3(0,.29,z), chassis, .035)
		for x in [-.48,.48]:
			var radius = .24 if engine else .19
			var wheel = cylinder(parent, "Wheel", radius,.15,Vector3(x,.22,z),Color("203139"))
			wheel.rotation.z = PI/2
			wheel.add_to_group("train_wheels",true)
			var rim = cylinder(wheel,"Rim",radius*.68,.157,Vector3.ZERO,Color("a3b7b6"))
			rim.material_override = material(metal,.6,.28)
			cylinder(wheel,"Hub",radius*.24,.17,Vector3.ZERO,Color("e6b75f"))
	for end in [-1.0,1.0]:
		box(parent,"CouplerShaft",Vector3(.14,.12,.30),Vector3(0,.38,end*(.88 if engine else .77)),chassis,.035)
		var hook = cylinder(parent,"CouplerHook",.12,.07,Vector3(0,.38,end*(1.02 if engine else .9)),chassis)
		hook.rotation.x = PI/2

static func locomotive() -> Node3D:
	var root = Node3D.new()
	root.name = "Locomotive"
	var teal = Color("284a43")
	var dark = Color("173d50")
	var cream = Color("c1c9c9")
	var gold = Color("b99c62")
	box(root,"Chassis",Vector3(.96,.2,1.83),Vector3(0,.42,0),dark,.06)
	wheels(root,true)
	var boiler = cylinder(root,"Boiler",.40,1.0,Vector3(0,.93,-.38),teal)
	boiler.rotation.x = PI/2
	var front = cylinder(root,"BoilerFront",.32,.09,Vector3(0,.89,-.93),dark)
	front.rotation.x = PI/2
	var trim = cylinder(root,"BrassRing",.405,.045,Vector3(0,.93,-.77),gold)
	trim.rotation.x = PI/2
	box(root,"Cab",Vector3(1.06,.98,.80),Vector3(0,1.02,.48),teal,.085)
	box(root,"Roof",Vector3(1.28,.25,1.05),Vector3(0,1.61,.49),cream,.085)
	box(root,"CabRearWindow",Vector3(.70,.39,.03),Vector3(0,1.23,.89),Color("52788a"),.025)
	for side in [-1,1]:
		box(root,"WindowFrame",Vector3(.04,.43,.46),Vector3(side*.535,1.23,.5),cream,.012)
		box(root,"CabWindow",Vector3(.05,.31,.34),Vector3(side*.558,1.25,.5),Color("52788a"),.012)
		box(root,"RunningBoard",Vector3(.11,.06,1.3),Vector3(side*.51,.56,-.16),gold,.015)
		box(root,"SideRod",Vector3(.04,.07,1.36),Vector3(side*.58,.24,0),Color("adc9c7"),.018)
		box(root,"CabStep",Vector3(.19,.07,.29),Vector3(side*.5,.42,.62),dark,.02)
	cylinder(root,"Chimney",.15,.48,Vector3(0,1.43,-.59),dark,.17)
	cylinder(root,"ChimneyLip",.20,.09,Vector3(0,1.70,-.59),dark)
	cylinder(root,"SteamDome",.14,.22,Vector3(0,1.30,-.08),gold)
	var lamp = cylinder(root,"Headlight",.14,.10,Vector3(0,1.05,-1.0),gold)
	lamp.rotation.x = PI/2
	var glass = cylinder(lamp,"LampGlass",.105,.12,Vector3.ZERO,Color("fff5c8"))
	var light_mat = material(Color("fff5c8")).duplicate()
	light_mat.emission_enabled = true
	light_mat.emission = Color("ffe6a2")
	glass.material_override = light_mat
	box(root,"Pilot",Vector3(1.05,.22,.27),Vector3(0,.48,-1.02),Color("c7483e"),.06)
	for z in [-.40,-.06]:
		var ring=cylinder(root,"BoilerBand",.405,.035,Vector3(0,.93,z),gold)
		ring.rotation.x=PI/2
	for side in [-1,1]:
		box(root,"Piston",Vector3(.18,.20,.37),Vector3(side*.46,.37,-.76),Color("889da8"),.05)
		box(root,"WindowShine",Vector3(.055,.035,.24),Vector3(side*.566,1.35,.49),Color("92c9ce"),.01)
		var buffer=cylinder(root,"FrontBuffer",.10,.13,Vector3(side*.34,.48,-1.18),dark)
		buffer.rotation.x=PI/2
	for x in [-.32,-.16,0,.16,.32]:
		var bar=box(root,"PilotGrille",Vector3(.055,.30,.055),Vector3(x,.28,-1.12),Color("889da8"),.01)
		bar.rotation.x=-.40
	for side in [-1,1]:
		box(root,"CabLowerTrim",Vector3(.055,.10,.78),Vector3(side*.55,.77,.48),cream,.015)
		box(root,"CabDoor",Vector3(.055,.36,.22),Vector3(side*.55,.94,.68),teal.darkened(.1),.02)
		box(root,"DoorHandle",Vector3(.07,.035,.10),Vector3(side*.59,1.02,.64),gold,.01)
		var plate=cylinder(root,"NumberMedallion",.13,.025,Vector3(side*.56,.99,.18),gold)
		plate.rotation.z=PI/2
	var vent=box(root,"RoofVent",Vector3(.57,.12,.36),Vector3(0,1.78,.51),teal,.05)
	vent.material_override=material(teal,.18,.3)
	var paints={}
	for child in root.get_children():
		if child is MeshInstance3D and child.material_override:
			var original=child.material_override
			if not paints.has(original):
				var paint=original.duplicate()
				paint.roughness=.34;paint.metallic_specular=.5
				paints[original]=paint
			child.material_override=paints[original]

	return root

static func wagon(color_id: int = 0) -> Node3D:
	var root=Node3D.new()
	root.name="WagonMesh"
	var color=TrainPalette.color(color_id)
	var shade=color.darkened(.19)
	box(root,"Chassis",Vector3(1.03,.15,1.42),Vector3(0,.37,0),Color("20303b"),.04)
	wheels(root)
	box(root,"ColoredFloor",Vector3(.96,.15,1.30),Vector3(0,.50,0),shade,.035)
	for side in [-1,1]:
		box(root,"ColoredSide",Vector3(.105,.55,1.36),Vector3(side*.475,.78,0),color,.035)
		box(root,"TopRim",Vector3(.15,.08,1.45),Vector3(side*.48,1.075,0),color.lightened(.12),.03)
		for z in [-.48,0,.48]:
			box(root,"SideRib",Vector3(.04,.48,.055),Vector3(side*.54,.79,z),shade,.012)
		box(root,"BrakePlate",Vector3(.03,.16,.18),Vector3(side*.55,.72,0),color.lightened(.32),.015)
	for end in [-1,1]:
		box(root,"ColoredEnd",Vector3(.96,.55,.11),Vector3(0,.78,end*.66),color,.035)
		box(root,"EndRim",Vector3(1.08,.08,.15),Vector3(0,1.075,end*.66),color.lightened(.12),.03)
		for x in [-.31,.31]:box(root,"EndRib",Vector3(.045,.47,.03),Vector3(x,.79,end*.73),shade,.008)
	for z in [-.34,.25]:box(root,"PaintedCargo",Vector3(.67,.20,.47),Vector3(.02,.68,z),color.darkened(.20),.025)
	for side in [-1,1]:
		for z in [-.48,0,.48]:
			for y in [.61,.95]:sphere(root,"Rivet",.025,Vector3(side*.565,y,z),Color("b4bec0"))
	return root

static func tree(parent: Node3D, at: Vector3, scale_factor: float = 1.0) -> void:
	var root = Node3D.new()
	root.name = "ToyTree"
	parent.add_child(root)
	root.position = at
	root.scale = Vector3.ONE*scale_factor
	cylinder(root,"Trunk",.10,.65,Vector3(0,.33,0),Color("a87953"))
	var crown = sphere(root,"Canopy",.54,Vector3(0,1.02,0),Color("76af77"))
	crown.scale.y = 1.35
	sphere(root,"CanopySmall",.30,Vector3(.25,1.05,.12),Color("8cbe83"))

static func own_tree(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		own_tree(child,root)


static func rail_model(color_id: int = -1) -> Node3D:
	var key="rail21_"+str(color_id)
	if not optimized_models.has(key):
		var root=express_locomotive() if color_id<0 else freight_wagon(color_id)

		var groups:Dictionary={};collect_surfaces(root,Transform3D.IDENTITY,groups)
		var merged=Node3D.new();merged.name=root.name
		for mat in groups:
			var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in groups[mat]:st.append_from(item.mesh,0,item.transform)
			var part=mesh_node(merged,"RailMesh",st.commit(),Vector3.ZERO,mat);part.owner=merged
		var packed=PackedScene.new();packed.pack(merged);optimized_models[key]=packed;root.free();merged.free()
	return optimized_models[key].instantiate()

static func barrel_roof(parent:Node3D,label:String,width:float,length:float,rise:float,at:Vector3,color:Color)->MeshInstance3D:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var a=PI*float(i)/24;var b=PI*float(i+1)/24
		var v=[Vector3(cos(a)*width*.5,sin(a)*rise,-length*.5),Vector3(cos(b)*width*.5,sin(b)*rise,-length*.5),Vector3(cos(b)*width*.5,sin(b)*rise,length*.5),Vector3(cos(a)*width*.5,sin(a)*rise,length*.5)]
		for j in [0,2,1,0,3,2]:
			var angle=a if j==0 or j==3 else b
			st.set_normal(Vector3(cos(angle)/maxf(.01,width*.5),sin(angle)/maxf(.01,rise),0).normalized())
			st.add_vertex(v[j])
	var mat=material(color,.25,.36);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mesh_node(parent,label,st.commit(),at,mat)

static func freight_wagon(color_id:int)->Node3D:
	var root=Node3D.new();root.name="RivetedFreightCar"
	var paint=TrainPalette.color(color_id);var steel=Color("3e5059");var trim=paint.lightened(.06)
	box(root,"SteelUnderframe",Vector3(1.08,.17,1.58),Vector3(0,.36,0),Color("24313b"),.025)
	wheels(root)
	box(root,"FullPaintedBody",Vector3(1.04,.64,1.40),Vector3(0,.78,0),paint,.115)
	barrel_roof(root,"PressedRoof",1.13,1.49,.22,Vector3(0,1.085,0),trim)
	for side in [-1,1]:
		box(root,"DoorInset",Vector3(.035,.49,.57),Vector3(side*.535,.80,.02),paint.darkened(.14),.015)
		for z in [-.62,-.33,.32,.62]:
			box(root,"VerticalBrace",Vector3(.04,.59,.035),Vector3(side*.54,.79,z),trim,.008)
		box(root,"DoorRunner",Vector3(.045,.035,1.30),Vector3(side*.56,1.02,0),steel,.005)
		box(root,"DoorLatch",Vector3(.045,.20,.025),Vector3(side*.56,.76,.20),Color("9ba8ac"),.006)
		box(root,"IdentificationPlate",Vector3(.04,.09,.23),Vector3(side*.565,.60,-.43),Color("e9debb"),.005)
		for z in [-.62,.62]:
			for y in [.57,.96]:sphere(root,"Fastener",.018,Vector3(side*.565,y,z),Color("b8c1be"))
	for end in [-1,1]:
		box(root,"EndCrossMember",Vector3(.88,.06,.035),Vector3(0,.58,end*.725),trim,.008)
		for x in [-.35,.35]:box(root,"EndFrame",Vector3(.045,.52,.04),Vector3(x,.79,end*.72),trim,.008)
	for z in [-.5,0,.5]:barrel_roof(root,"RoofSeam",1.14,.022,.225,Vector3(0,1.085,z),paint.darkened(.06))
	return root

static func express_locomotive()->Node3D:
	var root=locomotive();root.name="HeritageExpress"
	# Replace the thick flat toy-like roof with a formed sheet roof and overhang.
	for child in root.get_children():
		if child.name in ["Roof","RoofVent"]:root.remove_child(child);child.free()
	barrel_roof(root,"CurvedCabRoof",1.34,1.02,.18,Vector3(0,1.51,.49),Color("233740"))
	box(root,"CabRoofLip",Vector3(1.38,.035,1.05),Vector3(0,1.51,.49),Color("8c9e9f"),.015)
	for side in [-1,1]:
		for z in [-.62,-.25]:
			var saddle=box(root,"BoilerSaddle",Vector3(.08,.22,.12),Vector3(side*.38,.62,z),Color("2e4149"),.012)
		box(root,"BrassHandrail",Vector3(.025,.025,1.05),Vector3(side*.43,1.10,-.30),Color("c2a76d"),.006)
		for z in [-.68,.08]:box(root,"RailBracket",Vector3(.07,.025,.025),Vector3(side*.40,1.10,z),Color("b6bcb0"),.005)
		for z in [.20,.42,.65]:sphere(root,"CabRivet",.022,Vector3(side*.57,.82,z),Color("c2a76d"))
	box(root,"CoalBunker",Vector3(.80,.36,.20),Vector3(0,.78,.92),Color("263a3d"),.025)
	for x in [-.25,0,.25]:sphere(root,"Coal",.12,Vector3(x,.97,.93),Color("26313a"))
	return root

static func organic(parent:Node3D,label:String,at:Vector3,size:Vector3,color:Color,seed_value:float=0.0,amount:float=.09)->MeshInstance3D:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings=12;var sides=24
	for row in range(rings):
		for col in range(sides):
			for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
				var phi=PI*(row+corner.y)/rings;var theta=TAU*(col+corner.x)/sides
				var n=Vector3(sin(phi)*cos(theta),cos(phi),sin(phi)*sin(theta))
				var noise=sin(n.x*7+seed_value)*sin(n.z*6-seed_value*.7)*sin(n.y*8+seed_value*.3)
				st.set_normal((n/size).normalized())
				st.add_vertex(n*size*(1.0+noise*amount))
	var mat=material(color,0,.95);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mesh_node(parent,label,st.commit(),at,mat)

static func ribbon(parent:Node3D,label:String,points:PackedVector3Array,width:float,color:Color)->MeshInstance3D:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left:Array[Vector3]=[];var right:Array[Vector3]=[]
	for i in range(points.size()):
		var tangent=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side=tangent.cross(Vector3.UP)*width*.5
		left.append(points[i]-side);right.append(points[i]+side)
	for i in range(points.size()-1):
		var corners=[left[i],right[i],right[i+1],left[i+1]]
		for j in [0,2,1,0,3,2]:st.set_normal(Vector3.UP);st.add_vertex(corners[j])
	var mat=material(color,0,.92);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mesh_node(parent,label,st.commit(),Vector3.ZERO,mat)

static func gable(parent:Node3D,at:Vector3,width:float,height:float,depth:float,color:Color)->void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		for p in [Vector3(-width*.5,0,side*depth*.5),Vector3(0,height,side*depth*.5),Vector3(width*.5,0,side*depth*.5)]:
			st.set_normal(Vector3(0,0,side));st.add_vertex(p)
	var mat=material(color);mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mesh_node(parent,"GableWalls",st.commit(),at,mat)

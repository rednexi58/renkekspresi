class_name StationSlot
extends Node3D
var index:int=0
var color_id:int=-1
var marker:MeshInstance3D
var token:Node3D
var count_label:Label3D
var plate:MeshInstance3D
func setup(slot_index:int)->void:
 index=slot_index
 MeshFactory.box(self,"BrassRim",Vector3(2.12,.14,1.45),Vector3.ZERO,Color("b9a77c"),.12)
 plate=MeshFactory.box(self,"InsetBerth",Vector3(1.96,.08,1.29),Vector3(0,.10,0),Color("566b6a"),.10)
 for x in [-.72,.72]:MeshFactory.box(self,"ServiceRail",Vector3(.035,.025,.98),Vector3(x,.15,0),Color("c9d1c6"),.01)
 marker=MeshFactory.cylinder(self,"SlotMarker",.19,.025,Vector3(0,.16,0),Color("8fa69b"))
 count_label=Label3D.new();count_label.font=load("res://assets/fonts/World-Bold.ttf");count_label.font_size=38;count_label.pixel_size=.012;count_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;count_label.outline_size=9;count_label.outline_modulate=Color("263d47");add_child(count_label)
func set_color(id:int)->void:
 color_id=id
 if is_instance_valid(token):token.queue_free();token=null
 if id>=0:
  token=MeshFactory.rail_model(id);add_child(token);token.position.y=.18;token.rotation.y=PI/2;token.scale=Vector3.ONE*.70
func show_status(open:bool,filled:int=0,capacity:int=0)->void:
 count_label.text=(str(filled)+" / "+str(capacity)) if color_id>=0 else (str(index+1) if open else "+")
 count_label.position=Vector3(0,1.24 if color_id>=0 else .30,.18)
 count_label.modulate=Color("fff3cb") if open else Color("c5b78f")
 marker.visible=color_id<0
 if not plate.has_meta("open") or plate.get_meta("open")!=open:
  plate.material_override=MeshFactory.material(Color("566b6a") if open else Color("899185"));plate.set_meta("open",open)

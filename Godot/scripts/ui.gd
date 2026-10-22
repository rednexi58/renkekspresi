class_name TrainUI
extends CanvasLayer
signal card_selected(index: int)
signal hint_requested
signal undo_requested
signal reward_requested
signal vip_requested
signal menu_requested
var root: Control
var frame: MarginContainer
var viewport: SubViewport
var column: VBoxContainer
var dock_column: VBoxContainer
var level_label: Label
var level_name: Label
var timer_label: Label
var remaining_label: Label
var hint_label: Label
var phase_label: Label
var station_label: Label
var progress: ProgressBar
var slots: Array=[]
var overlay: Control
var modal_box: VBoxContainer
var toast_tween: Tween
var toast_label: Label
var bold: Font
var regular: Font
var undo_button: Button
var vip_button: Button
var combo_count=0
var last_match_ms=0
var lesson=""
var stage_kind=""
var rescue=false
var danger_red=false
var target_labels: Array=[]
var future_label: Label
var hint_button: Button
func _ready() -> void:
 bold=load("res://assets/fonts/Interface-Bold.ttf");regular=load("res://assets/fonts/Interface.ttf")
 root=Control.new();root.name="Interface";root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 var theme=Theme.new();theme.default_font=regular;theme.default_font_size=22;root.theme=theme
 var board=SubViewportContainer.new();board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);board.stretch=true;board.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(board)
 viewport=SubViewport.new();viewport.name="GameViewport";viewport.size=Vector2i(720,1280);viewport.own_world_3d=true;viewport.handle_input_locally=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;board.add_child(viewport)
 build_hud()
 get_viewport().size_changed.connect(adapt_width);adapt_width()
func rebuild_hud() -> void:
 if is_instance_valid(toast_tween):toast_tween.kill()
 if is_instance_valid(vip_button):root.remove_child(vip_button);vip_button.queue_free()
 if is_instance_valid(frame):root.remove_child(frame);frame.queue_free()
 if is_instance_valid(toast_label):root.remove_child(toast_label);toast_label.queue_free()
 slots=[];target_labels=[]
 build_hud();adapt_width()

func build_hud() -> void:
 frame=MarginContainer.new();frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for edge in ["left","right","top","bottom"]:frame.add_theme_constant_override("margin_"+edge,20)
 root.add_child(frame);column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_theme_constant_override("separation",10);frame.add_child(column)
 var header=PanelContainer.new();header.add_theme_stylebox_override("panel",style(Color("182f3a"),18,18));column.add_child(header)
 var content=VBoxContainer.new();header.add_child(content);var row=HBoxContainer.new();content.add_child(row)
 var names=VBoxContainer.new();names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(names)
 level_label=label(Locale.t("RENK EKSPRESİ · BÖLÜM 01"),13,Color("9db4bb"),true);level_label.clip_text=true;names.add_child(level_label)
 level_name=label(Locale.t("Kumsal istasyonu"),27,Color("edf0e7"),true);level_name.clip_text=true;level_name.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;names.add_child(level_name)
 timer_label=label(Locale.t("TUR 1"),19,Color("e0ba78"),true);row.add_child(timer_label)
 var menu=button("Ⅱ",Vector2(48,48));menu.pressed.connect(func():menu_requested.emit());row.add_child(menu)
 progress=ProgressBar.new();progress.custom_minimum_size.y=7;progress.show_percentage=false
 progress.add_theme_stylebox_override("background",style(Color("3a535d"),4));progress.add_theme_stylebox_override("fill",style(Color("d7b77b"),4));content.add_child(progress)
 phase_label=label(Locale.t("ÖNÜ AÇIK VAGONA DOKUN"),15,Color("d3e0dc"),true);phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 phase_label.add_theme_stylebox_override("normal",style(Color(.09,.19,.23,.91),12,8));column.add_child(phase_label)
 var space=Control.new();space.mouse_filter=Control.MOUSE_FILTER_IGNORE;space.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(space)
 var dock=PanelContainer.new();dock.add_theme_stylebox_override("panel",style(Color(.075,.15,.19,.94),18,10));column.add_child(dock)
 dock_column=VBoxContainer.new();dock_column.add_theme_constant_override("separation",6);dock.add_child(dock_column)
 var orders=PanelContainer.new();orders.add_theme_stylebox_override("panel",style(Color(0,0,0,0),0,0));dock_column.add_child(orders)
 var orders_box=VBoxContainer.new();orders_box.add_theme_constant_override("separation",5);orders.add_child(orders_box)
 var orders_row=HBoxContainer.new();orders_row.add_theme_constant_override("separation",8);orders_box.add_child(orders_row)
 orders_row.visible=false
 for i in range(5):
  var target=label("",17,TrainPalette.INK,true);target.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;target.size_flags_horizontal=Control.SIZE_EXPAND_FILL;orders_row.add_child(target);target_labels.append(target)
 future_label=label("",14,TrainPalette.MUTED);future_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;orders_box.add_child(future_label)
 var title_row=HBoxContainer.new();dock_column.add_child(title_row);title_row.add_child(label(Locale.t("PAMUK EKSPRESİ"),13,Color("d7b77b"),true));spacer(title_row)
 remaining_label=label("",16,TrainPalette.MUTED);title_row.add_child(remaining_label)
 var slot_row=HBoxContainer.new();slot_row.visible=false;slot_row.add_theme_constant_override("separation",9);dock_column.add_child(slot_row)
 for i in range(6):
  var panel=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.custom_minimum_size=Vector2(0,62);panel.add_theme_stylebox_override("panel",style(Color("2d4652"),14));slot_row.add_child(panel)
  var txt=label(Locale.t("BOŞ"),15,TrainPalette.MUTED,true);txt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel.add_child(txt);slots.append({"panel":panel,"label":txt})
 var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",10);dock_column.add_child(actions)
 undo_button=button(Locale.t("↶ Geri · 2"),Vector2(0,48));undo_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;undo_button.add_theme_font_size_override("font_size",17);undo_button.pressed.connect(func():undo_requested.emit());actions.add_child(undo_button)
 hint_button=button(Locale.t("✦ İpucu"),Vector2(112,48));hint_button.add_theme_font_size_override("font_size",16);hint_button.pressed.connect(func():hint_requested.emit());actions.add_child(hint_button)
 vip_button=button("VIP +1",Vector2(92,44));vip_button.name="WorldVIP";vip_button.add_theme_font_size_override("font_size",16)
 for state in ["normal","hover","pressed"]:vip_button.add_theme_stylebox_override(state,style(Color("d8b76e").lightened(.10 if state=="hover" else 0),12,5))
 vip_button.add_theme_color_override("font_color",Color("293d44"));vip_button.add_theme_color_override("font_hover_color",Color("293d44"))
 vip_button.pressed.connect(func():vip_requested.emit());root.add_child(vip_button)
 hint_label=label(Locale.t("Okları aç · Pamuk’u kurtar"),13,TrainPalette.MUTED);hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint_label.visible=false;dock_column.add_child(hint_label)
 toast_label=label("",19,TrainPalette.INK,true);toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_label.modulate.a=0
 toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);toast_label.position=Vector2(-280,170);toast_label.size=Vector2(560,52);toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(toast_label)

func place_world_actions(world:GameWorld)->void:
 if not is_instance_valid(vip_button) or world.station_slots.size()<4:return
 var anchor=world.station_slots[3].global_position+Vector3(0,0,1.0)
 var pixel=world.camera.unproject_position(anchor)
 var screen=get_viewport().get_visible_rect().size
 pixel=pixel/Vector2(viewport.size)*screen
 vip_button.position=Vector2(clampf(pixel.x-46,12,screen.x-104),pixel.y-10)

func adapt_width() -> void:
 var screen=get_viewport().get_visible_rect().size;var side=maxf(0,(screen.x-760)/2);frame.offset_left=side;frame.offset_right=-side
 var safe=DisplayServer.get_display_safe_area();var physical=DisplayServer.window_get_size()
 if OS.has_feature("mobile") and physical.y>0:
  var ratio=screen.y/physical.y
  frame.add_theme_constant_override("margin_top",maxi(24,int(safe.position.y*ratio)+8));frame.add_theme_constant_override("margin_bottom",maxi(16,int((physical.y-safe.end.y)*ratio)+8))
func set_level(level: Dictionary,index: int) -> void:
 rescue=level.get("mode","loop")=="rescue";stage_kind=level.get("subtitle","RENK BULMACASI");danger_red=false
 level_label.text="%s · %02d / 100"%[("COLOR EXPRESS" if Locale.language=="en" else str(level.get("region","TREN YOLCULUĞU")).to_upper()),int(level.id)];level_name.text=("Level %d · %d trains"%[int(level.id),int(level.get("train_count",1))]) if Locale.language=="en" else level.name;combo_count=0;lesson=level.lesson
 progress.add_theme_stylebox_override("fill",style(Color("efad57") if rescue else Color("d7b77b"),4))
 toast_label.modulate.a=0
 if is_instance_valid(toast_tween):toast_tween.kill()
func update_state(rules: GameRules,_busy: bool=false) -> void:
 for i in range(6):
  var txt=slots[i].label;var color=int(rules.slots[i]) if i<rules.slots.size() else -2
  txt.text="+ YUVA" if color==-2 else ("%02d\nHAZIR"%(i+1) if color==-1 else TrainPalette.SYMBOLS[color])
  if color>=0:
   var capacity=int(rules.parking[int(rules.slot_ids[i])].capacity)
   var filled=capacity-int(rules.parking[int(rules.slot_ids[i])].remaining)
   txt.text=TrainPalette.SYMBOLS[color]+"\n%d / %d"%[filled,capacity]
   slots[i].panel.tooltip_text=TrainPalette.NAMES[color]
  slots[i].panel.add_theme_stylebox_override("panel",style(TrainPalette.color(color).darkened(.30) if color>=0 else Color("2d4652"),14))
  slots[i].panel.modulate.a=.55 if color==-2 else 1.0
 var active=rules.active_colors()
 for i in range(5):
  var target=target_labels[i]
  target.visible=i<active.size()
  if i<active.size():
   var color=int(active[i])
   target.text=TrainPalette.SYMBOLS[color]+" "+str(rules.zone_count(color) if rules.match_zone else rules.train.count(color))
   target.modulate.a=1.0 if not rules.match_zone or rules.zone_count(color)>0 else .38
   target.add_theme_stylebox_override("normal",style(TrainPalette.color(color).lightened(.65),10,6))
 var incoming=PackedStringArray()
 for color in rules.future_colors():incoming.append(TrainPalette.SYMBOLS[int(color)]+" "+Locale.t(TrainPalette.NAMES[int(color)]))
 future_label.text=Locale.t("YAKLAŞAN   ")+"  ·  ".join(incoming) if rules.unloading_open else Locale.t("PAMUK İÇİN VAGONLARINI HAZIRLA")
 remaining_label.text=Locale.t("%d / %d boşaltıldı")%[rules.total-rules.train.size(),rules.total]
 undo_button.text=Locale.t("↶ Geri · %d")%rules.undo_left;undo_button.disabled=rules.undo_left<=0 or rules.order.is_empty() or rules.status!="playing"
 vip_button.text="VIP ✓" if rules.vip_active else "VIP +1"
 update_clock(rules)
func update_clock(rules: GameRules) -> void:
 timer_label.text=Locale.t("VARIŞ %d%%")%int(rules.danger()*100) if rescue else "%d / %d"%[rules.total-rules.train.size(),rules.total]
 progress.value=rules.danger()*100 if rescue else 100.0*(rules.total-rules.train.size())/maxi(1,rules.total)
 var warning=rescue and (rules.danger()>=.9 or (rules.unloading_open and not rules.slots.has(-1) and rules.targets.all(func(x):return int(x)<0)))
 if warning!=danger_red:
  danger_red=warning;progress.add_theme_stylebox_override("fill",style(Color("e06452") if warning else Color("efad57"),4))
 phase_label.text=Locale.t("PAMUK SENİ BEKLİYOR · OKLARI AÇ")
 if rescue and rules.brake_left>0:phase_label.text=Locale.t("EŞLEŞTİ! VAGON BOŞALDI")
 elif rescue and not rules.unloading_open:
  phase_label.text=Locale.t("GARAJDAN ÇIKIŞ · RENKLERİ HAZIRLA") if rules.danger()<.5 else Locale.t("HAZIRLIK · %75’TE BOŞALTMA AÇILACAK")
 elif rescue and rules.danger()>=.9:phase_label.text=Locale.t("VARIŞ YAKIN · SON RENKLERİ TOPLA!")
 if rules.jammed:phase_label.text=Locale.t("ALAN DOLDU · GERİ AL VEYA EK YUVA AÇ")
 elif not rules.slots.has(-1):
  phase_label.text=Locale.t("HAZIRLIK TAMAM · %75’İ BEKLE") if not rules.unloading_open else (Locale.t("YUVALAR DOLU · YAKLAŞAN RENKLERİ İZLE") if rules.targets.all(func(x):return int(x)<0) else Locale.t("VAGONLAR DOLUYOR · TAMAMLANINCA YUVA AÇILIR"))
 elif rules.parked_count()==0:phase_label.text=Locale.t("SON VAGONLAR EŞLEŞİYOR!")
 if rules is MultiTrainRules and rules.status=="playing":
  var summary=PackedStringArray()
  for lane in range(rules.train_count):
   summary.append("%d: %s"%[lane+1,Locale.t("BİTTİ") if rules.remaining_in(lane)==0 else "%d%%"%int((float(rules.heads[lane])-rules.start_head)/(rules.end_distance-rules.start_head)*100)])
  phase_label.text="  ·  ".join(summary)
 if rules.status=="lost":phase_label.text=Locale.t("TREN VARIŞA ULAŞTI")
func match_feedback(count: int) -> void:
 var now=Time.get_ticks_msec()
 combo_count=combo_count+count if now-last_match_ms<2600 else count
 last_match_ms=now
 if combo_count in [5,15,30,50,100]:toast(Locale.t("%d PARÇALIK SERİ!")%combo_count)
func toast(message: String) -> void:
 if is_instance_valid(toast_tween):toast_tween.kill()
 toast_label.text = message
 toast_label.modulate.a = 1
 toast_label.add_theme_stylebox_override("normal",style(Color("223c48"),16,8))
 toast_tween = create_tween()
 toast_tween.tween_interval(.9)
 toast_tween.tween_property(toast_label,"modulate:a",0,.35)

func show_modal(title: String, description: String) -> VBoxContainer:
 close_modal()
 overlay = Control.new()
 overlay.name = "ModalOverlay"
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(overlay)
 var scrim = ColorRect.new()
 scrim.color = Color(.08,.19,.16,.68)
 scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(scrim)
 var center = CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(center)
 var panel = PanelContainer.new()
 panel.custom_minimum_size.x = 616
 panel.add_theme_stylebox_override("panel",style(Color("182f3a"),30,30))
 center.add_child(panel)
 modal_box = VBoxContainer.new()
 modal_box.add_theme_constant_override("separation",16)
 panel.add_child(modal_box)
 var title_label = label(title,34,TrainPalette.INK,true)
 title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 modal_box.add_child(title_label)
 if not description.is_empty():
  var desc = label(description,21,TrainPalette.MUTED)
  desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  desc.custom_minimum_size.x = 540
  modal_box.add_child(desc)
 return modal_box

func modal_button(text: String, action: Callable, primary: bool = false) -> Button:
 var btn = button(text,Vector2(0,60),primary)
 modal_box.add_child(btn)
 btn.pressed.connect(action)
 return btn

func close_modal() -> void:
 if is_instance_valid(overlay):
  root.remove_child(overlay)
  overlay.queue_free()
  overlay = null

func label(text: String, font_size: int = 22, color: Color = TrainPalette.INK, heavy: bool = false) -> Label:
 var node = Label.new()
 node.text = text
 node.add_theme_font_override("font",bold if heavy else regular)
 node.add_theme_font_size_override("font_size",font_size)
 node.add_theme_color_override("font_color",color)
 return node

func button(text: String, minimum: Vector2, primary: bool = false) -> Button:
 var btn = Button.new()
 btn.text = text
 btn.custom_minimum_size = minimum
 btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 var bg = TrainPalette.DARK if primary else Color("294752")
 btn.add_theme_stylebox_override("normal",style(bg,17,10))
 btn.add_theme_stylebox_override("hover",style(bg.lightened(.08),17,10))
 btn.add_theme_stylebox_override("pressed",style(bg.darkened(.07),17,10))
 btn.add_theme_stylebox_override("disabled",style(bg.darkened(.12),17,10))
 btn.add_theme_color_override("font_disabled_color",Color("849b9f"))
 btn.add_theme_color_override("font_color",Color("f9f9e9") if primary else TrainPalette.INK)
 btn.add_theme_color_override("font_hover_color",Color("f9f9e9") if primary else TrainPalette.INK)
 btn.add_theme_font_override("font",bold)
 btn.add_theme_font_size_override("font_size",21)
 return btn

func spacer(parent: Control) -> Control:
 var node = Control.new()
 node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(node)
 return node

func style(color: Color, radius: int = 12, padding: int = 0) -> StyleBoxFlat:
 var box = StyleBoxFlat.new()
 box.bg_color = color
 box.set_corner_radius_all(radius)
 box.border_color=Color(0.65,0.78,0.78,.13)
 box.set_border_width_all(1)
 box.shadow_color=Color(0.02,0.06,0.08,.18)
 box.shadow_size=3
 box.shadow_offset=Vector2(0,2)
 box.content_margin_left = padding
 box.content_margin_right = padding
 box.content_margin_top = padding
 box.content_margin_bottom = padding
 return box


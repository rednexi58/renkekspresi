class_name GameManager
extends Node
## Owns state transitions; input never addresses an individual station slot.
var rules = GameRules.new()
var ads=RewardedAds.new()
var purchases=PurchaseManager.new()
var ad_button: Button
var ad_generation=0
var reward_kind="slot"
var admin_page=0
var admin_filter=0
var build_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/build_config.json"))
var levels = LevelData.new()
var ui: TrainUI
var world: GameWorld
var level_index: int = 0
var paused: bool = false
var busy: bool = false
var animation_clock: float = 0.0
var animation_end: float = 0.0
var pending_matches: Array = []
var last_station_phase: int = -2
var result_recorded: bool = false
var quality_clock: float = 0.0
var slow_seconds: float = 0.0
var qa_mode: bool = false
var jam_shown=false
var hud_loaded=false
var zone_ui_clock=0.0

func _ready() -> void:
 Engine.max_fps = 60
 ads.provider=str(build_config.get("ads_provider","disabled"))
 purchases.configure(build_config,bool(SaveData.data.get("test_vip",false)))
 purchases.test_paid=bool(SaveData.data.get("test_paid",false)) and purchases.provider=="simulation"
 qa_mode = OS.has_feature("editor") and OS.get_cmdline_user_args().has("--qa")
 ui = TrainUI.new()
 ui.name = "UI"
 add_child(ui)
 world = GameWorld.new()
 world.name = "GameWorld"
 ui.viewport.add_child(world)
 ui.card_selected.connect(choose_card)
 ui.menu_requested.connect(open_menu)
 ui.undo_requested.connect(undo_card)
 ui.reward_requested.connect(open_reward)
 ui.vip_requested.connect(show_vip)
 ui.hint_requested.connect(show_hint)
 apply_quality()
 load_level(int(SaveData.data.last_level),false)
 if qa_mode:
  start_play()
 else:
  show_welcome()

func load_level(index: int, autostart: bool = true) -> void:
 if hud_loaded:ui.rebuild_hud()
 hud_loaded=true
 ads.cancel();ad_generation+=1
 level_index = clampi(index,0,levels.count()-1)
 var level = levels.get_level(level_index)
 rules=MultiTrainRules.new() if int(level.get("train_count",1))>1 else GameRules.new()
 rules.reset(level)
 if purchases.is_vip():rules.grant_vip_slot()
 if purchases.is_paid():rules.grant_paid_slot()
 jam_shown=false
 busy = false
 paused = false
 result_recorded = false
 last_station_phase = -2
 pending_matches.clear()
 ui.close_modal()
 world.load_level(level)
 rules.configure_track(world.rail.total_length)
 world.train.sync_rules(rules,0)
 world.sync_parking(rules)
 ui.set_level(level,level_index)
 ui.place_world_actions(world)
 ui.vip_button.visible=purchases.provider=="simulation"
 ui.update_state(rules)
 ui.update_clock(rules)
 SaveData.data.last_level = level_index
 SaveData.commit()
 if autostart:
  if not qa_mode and level_index in [9,11,24,49]:show_new_rule()
  else:start_play()

func show_new_rule() -> void:
 paused=true;world.train.active=false
 if level_index in [9,24,49]:
  ui.show_modal(Locale.t("%d tren · Ortak yuvalar")%int(levels.get_level(level_index).train_count),Locale.t("Trenler ayrı raylarda aynı anda ilerler.\nEşleşen tren geri çekilir; diğeri yoluna devam eder.\n\nYalnızca yakına gelen parçalar toplanır.\nAynı renkte iki hedef varsa varışa yakın tren önceliklidir.\nÜç yuvanı iki hattı da düşünerek kullan."))
 elif level_index==4:
  ui.show_modal(Locale.t("Yeni görev: Varışı durdur!"),Locale.t("Tren bu kez açık raydan varışa yaklaşıyor.\nDoğru renkleri temizledikçe fren yapıp geri çekilir.\n\nVagonları bitirmeden varış çizgisine gelirse kaybedersin.\nÜç bekleme yuvasını ve renk sırasını planla."))
 else:
  ui.show_modal(Locale.t("Yeni bulmaca: Anahtar A"),Locale.t("Altın A anahtarlı vagonu park alanından çıkar.\nBöylece A kilitli vagonların yolları açılır.\n\nAnahtarın rengi aktif değilse bir bekleme yuvasını kullanır.\nYol açmak için yer ayırmayı unutma."))
 ui.modal_button(Locale.t("Anladım · Başlat"),start_play,true)

func start_play() -> void:
 ui.close_modal()
 rules.status = "playing"
 paused = false
 world.train.active = true
 ui.update_state(rules)
 AudioManager.play("whistle")

func show_welcome() -> void:
 ui.show_modal(Locale.t("Renk Ekspresi"),Locale.t("Ok yönünde yolu açık vagona dokun.
İlk boş yuvaya gider; üzerindeki sayı kadar renk toplar.

Yakına gelen tren parçaları aynı renkteki vagonunu doldurur.
Yanlış rengi erken seçersen yuvayı meşgul eder.
Üç yuvayı doldurmadan yaklaşan renkleri düşün.

Tren Pamuk’a ulaşmadan bütün renkleri boşalt!
100 bölüm · 13 etap · 1–4 tren
Test için bütün bölümler açık."))
 ui.modal_button(Locale.t("Kurtarmaya başla · v0.27"),start_play,true)
 ui.modal_button(Locale.t("Bölüm seç · Test paneli"),show_levels)
 ui.modal_button(Locale.t("VIP · Ücretsiz test"),show_vip)

func show_hint() -> void:
 if paused or is_instance_valid(ui.overlay) or rules.status!="playing":return
 rules.hint_uses+=1;world.show_hint(rules);ui.toast(Locale.t("Yeşil altlıklı vagonların yolu açık."))

func _process(delta: float) -> void:
 if ads.state=="showing":
  ads.tick(delta)
  if is_instance_valid(ad_button):
   ad_button.text=Locale.t("Ödülü al") if ads.state=="earned" else Locale.t("Test reklamı · %d sn")%int(ceil(ads.seconds_left))
   ad_button.disabled=ads.state!="earned"
 if is_instance_valid(world):ui.place_world_actions(world)
 if not is_instance_valid(world) or paused:return
 if rules.status=="playing":
  var matches=rules.tick(delta)
  for departure in rules.departures:world.launch_waiting(departure,rules.dispatch_seconds)
  world.train.sync_rules(rules,delta)
  for match_info in matches:
   var location=world.train.remove_wagon(int(match_info.wagon_id),int(match_info.slot))
   world.burst(location,int(match_info.color))
  if not matches.is_empty():
   var completed=false
   for info in matches:
    if rules.parking[int(info.parking_id)].state=="done":completed=true
   AudioManager.play("fill" if completed else "match")
   if completed:AudioManager.vibrate(12)
  world.sync_parking(rules)
  zone_ui_clock+=delta
  if not matches.is_empty() or not rules.departures.is_empty() or zone_ui_clock>=.15:ui.update_state(rules);zone_ui_clock=0.0
  if not matches.is_empty():ui.match_feedback(matches.size())
  if not rules.jammed:jam_shown=false
  if rules.jammed and not jam_shown:show_jam()
  ui.update_clock(rules);monitor_performance(delta)
 world.tick_effects(delta);world.train.tick_transfers(delta)
 if world.train.transfers.is_empty() and rules.status in ["won","lost"] and not result_recorded:finish()

func choose_card(index: int) -> void:
 if paused or is_instance_valid(ui.overlay):return
 var result=rules.choose(index)
 if result.is_empty():return
 if result.has("error"):
  var messages={"blocked":Locale.t("Yolu kapalı. Önündeki vagonu çıkar."),"locked":Locale.t("Kilitli. Aynı harfli anahtar vagonunu önce çıkar."),"full":Locale.t("Yuvalar dolu. Bölgeye gelmeyen renk bekler; geri alabilirsin.")}
  ui.toast(messages.get(result.error,Locale.t("Bu hamle yapılamıyor.")))
  return
 world.launch_parking(index,int(result.slot),int(result.wagon_id),rules.arrival_seconds);world.sync_parking(rules);ui.update_state(rules)
 AudioManager.play("tap");AudioManager.vibrate(10)

func undo_card() -> void:
 if paused or is_instance_valid(ui.overlay):return
 var id=int(rules.order.back()) if not rules.order.is_empty() else -1
 if rules.undo():
  world.cancel_flight(id);world.sync_parking(rules);ui.update_state(rules);AudioManager.play("tap")

func open_reward(kind:String="slot") -> void:
 if ads.provider!="simulation":return
 if kind=="slot" and (not rules.can_unlock_slot() or is_instance_valid(ui.overlay)):return
 if kind=="continue" and (rules.continue_used or rules.status!="lost"):return
 reward_kind=kind
 paused=true;world.train.active=false
 var offer=Locale.t("%d. yuva bu bölümün sonuna kadar açılır. En fazla 6 yuva.")%(rules.slots.size()+1) if kind=="slot" else Locale.t("Trenler %22 geri çekilir; son bekleyen vagonun tahtaya döner.\nBölüm başına yalnızca bir kez.")
 ui.show_modal(Locale.t("Bir yuva daha aç") if kind=="slot" else Locale.t("Bir kurtarma şansı"),offer+Locale.t("\n\nVIP yalnızca bir kalıcı başlangıç yuvası verir.\nBu ek hak için reklam tamamlanmalıdır.\n\nTEST REKLAMI · Gerçek reklam değildir.\n3 saniyelik deneme tamamlanınca ödül verilir."))
 ui.modal_button(Locale.t("Test reklamını başlat"),begin_reward,true)
 ui.modal_button(Locale.t("Vazgeç"),cancel_reward)

func begin_reward() -> void:
 if not ads.begin():return
 ui.show_modal(Locale.t("TEST REKLAMI"),Locale.t("Gerçek reklam değildir.
Ödüllü reklam akışı deneniyor.

Tren ve oyun bu sırada duraklatıldı."))
 ad_button=ui.modal_button(Locale.t("Test reklamı · 3 sn"),claim_reward,true);ad_button.disabled=true
 ui.modal_button(Locale.t("Kapat · ödül alma"),cancel_reward)

func claim_reward() -> void:
 if not ads.claim():return
 apply_reward()

func apply_reward()->void:
 var applied=rules.unlock_reward_slot() if reward_kind=="slot" else rules.rescue_continue()
 if not applied:cancel_reward();return
 if reward_kind=="continue":
  result_recorded=false;world.rescue_result="";world.rescue_friend.position=world.friend_home
  for flight in world.parking_flights:flight.node.queue_free()
  world.parking_flights.clear()
  world.train.sync_rules(rules,0)
 world.sync_parking(rules);ui.update_state(rules)
 resume();ui.toast(Locale.t("%d. yuva bu bölüm için açıldı!")%rules.slots.size() if reward_kind=="slot" else Locale.t("Son bir şans · Yaklaşan renkleri planla!"))

func cancel_reward() -> void:
 ads.cancel()
 if rules.status=="lost":show_loss()
 else:resume()

func _input(event: InputEvent) -> void:
 if not is_instance_valid(ui) or paused or is_instance_valid(ui.overlay) or rules.status!="playing":return
 var at=Vector2.ZERO;var pressed=false
 if event is InputEventScreenTouch and event.pressed and event.device!=-1:at=event.position;pressed=true
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.device!=-1:at=event.position;pressed=true
 if not pressed:return
 # The floating VIP badge must consume its own touch before world picking.
 if ui.vip_button.visible and ui.vip_button.get_global_rect().has_point(at):return
 var size=get_viewport().get_visible_rect().size
 var screen=at/size*Vector2(ui.viewport.size)
 for i in range(rules.slots.size(),world.station_slots.size()):
  var slot_at=world.station_slots[i].global_position+Vector3.UP*.30
  var center=world.camera.unproject_position(slot_at)
  var radius=world.camera.unproject_position(slot_at+Vector3.RIGHT*.95).distance_to(center)
  if absf(screen.x-center.x)<radius and absf(screen.y-center.y)<radius*.7:
   var kinds=rules.locked_slot_kinds()
   var kind=str(kinds[i-rules.slots.size()])
   if kind=="vip":show_vip()
   elif kind=="paid":show_paid_slot()
   else:open_reward()
   return
 var id=world.pick_parking(screen,rules)
 if id>=0:choose_card(id)

func finish() -> void:
 result_recorded = true
 world.train.active = false
 world.set_rescue_result(rules.status)
 ui.update_state(rules)
 if not qa_mode:
  SaveData.record_attempt(level_index,rules.status,rules.elapsed,rules.taps,rules.peak_slots)
 if rules.status == "won":
  var stars = rules.stars()
  if not qa_mode:
   SaveData.complete_level(level_index,stars,rules.elapsed)
   var category="standard" if rules.slots.size()==3 and not rules.continue_used and rules.hint_uses==0 and rules.undo_left==2 else "assisted"
   if bool(build_config.get("test_tools",false)):category="practice_"+category
   SaveData.record_score(level_index,rules.elapsed,category)
  AudioManager.play("win")
  AudioManager.vibrate(70)
  for c in range(5):
   world.burst(Vector3(-3+c*1.5,1,0),c,true)
  ui.show_modal(Locale.t("Minik dost güvende!"),Locale.t("%s\n\n%d vagon · %.1f saniye\n%s") % ["★ ".repeat(stars)+"☆ ".repeat(3-stars),rules.total,rules.elapsed,Locale.t("Bir sonraki durak seni bekliyor.") if level_index<levels.count()-1 else Locale.t("100 durakta bütün dostları kurtardın!")])
  if level_index<15:
   var next_region=["Çam Ormanı","Dağ Geçidi","Yeni hatlar"][mini(2,int(level_index/5))]
   if Locale.language=="en":next_region=["Pine Forest","Mountain Pass","New routes"][mini(2,int(level_index/5))]
   var remaining=5-(level_index%5+1)
   var journey=("Next region unlocked: " if Locale.language=="en" else "Yeni bölge açıldı: ")+next_region if remaining==0 else ("%d levels to %s" if Locale.language=="en" else "%s için %d bölüm")%([remaining,next_region] if Locale.language=="en" else [next_region,remaining])
   var panel=ui.show_modal("ROUTE COMPLETE" if Locale.language=="en" else "HAT TAMAMLANDI","★ ".repeat(stars)+"☆ ".repeat(3-stars))
   var stats=HBoxContainer.new();stats.add_theme_constant_override("separation",16);panel.add_child(stats)
   for text in [("TIME\n%.1f s" if Locale.language=="en" else "SÜRE\n%.1f sn")%rules.elapsed,("MOVES\n%d" if Locale.language=="en" else "HAMLE\n%d")%rules.taps,("CLEARED\n%d" if Locale.language=="en" else "TEMİZLENEN\n%d")%rules.total]:
    var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",ui.style(Color("e8efe9"),14,12));stats.add_child(card)
    var text_label=ui.label(text,19);text_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(text_label)
   panel.add_child(ui.label(journey,20))
   var bar=ProgressBar.new();bar.max_value=5;bar.value=0;bar.show_percentage=false;bar.custom_minimum_size.y=12;bar.add_theme_stylebox_override("fill",ui.style(Color("c5a16a"),6));panel.add_child(bar)
   ui.create_tween().tween_property(bar,"value",float(level_index%5+1),.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  if level_index < levels.count()-1:
   ui.modal_button(Locale.t("Sıradaki durak  →"),func():load_level(level_index+1),true)
  else:
   ui.modal_button(Locale.t("Bütün bölümler"),show_levels,true)
  ui.modal_button(Locale.t("Tekrar oyna"),func():load_level(level_index))
 else:
  AudioManager.play("lose");AudioManager.vibrate(60)
  show_loss()

func show_loss()->void:
 ui.show_modal(Locale.t("Bu kez yetişemedik"),Locale.t("%d / %d parça boşaltıldı.\nPamuk güvenli alana kaçtı.\n\nYaklaşan renge bir yuva sakla.\nÜcretsiz yeniden deneyebilir veya tek kurtarma hakkını kullanabilirsin.")%[rules.total-rules.train.size(),rules.total])
 ui.modal_button(Locale.t("Tekrar dene"),func():load_level(level_index),true)
 if not rules.continue_used and ads.provider=="simulation":ui.modal_button(Locale.t("Kurtarma şansı · Test reklamı"),func():open_reward("continue"))
 ui.modal_button(Locale.t("Bölümler"),show_levels)

func open_menu() -> void:
 if rules.status != "playing" and rules.status != "ready":
  show_levels()
  return
 paused = true
 world.train.active = false
 ui.show_modal(Locale.t("Küçük bir mola"),"Tren seni bekliyor.")
 ui.modal_button(Locale.t("Oyuna dön"),resume,true)
 ui.modal_button(Locale.t("Yeniden başla"),confirm_restart)
 ui.modal_button(Locale.t("Bölüm test paneli"),show_levels)
 ui.modal_button(Locale.t("VIP · Ücretsiz test"),show_vip)
 ui.modal_button(Locale.t("Skor tablosu"),show_scoreboard)
 ui.modal_button(Locale.t("Kalıcı ek yuva"),show_paid_slot)
 ui.modal_button(Locale.t("Ses ve görüntü"),show_settings)
 ui.modal_button(Locale.t("Nasıl oynanır?"),show_help)

func resume() -> void:
 ads.cancel()
 ui.close_modal()
 paused = false
 if rules.status == "ready":
  start_play()
 else:
  world.train.active = rules.status == "playing"

func confirm_restart() -> void:
 ui.show_modal(Locale.t("Bu hattı yeniden başlat?"),Locale.t("Bu bölümdeki ilerlemen sıfırlanır.\nTamamladığın bölümler korunur."))
 ui.modal_button(Locale.t("Yeniden başla"),func():load_level(level_index),true)
 ui.modal_button(Locale.t("Oyuna dön"),resume)

func show_levels() -> void:
 paused=true;world.train.active=false
 var admin=bool(build_config.get("test_tools",false))
 var box=ui.show_modal(Locale.t("Bölüm test paneli") if admin else Locale.t("Bir sonraki durağın"),Locale.t("100 bölüm · 1–4 tren\n")+(Locale.t("TEST YETKİSİ · İstediğin bölümü doğrudan aç.") if admin else Locale.t("Başarılı oldukça yeni duraklar açılır.")))
 if admin:
  var jump=HBoxContainer.new();box.add_child(jump)
  var number=SpinBox.new();number.min_value=1;number.max_value=levels.count();number.value=level_index+1;number.custom_minimum_size=Vector2(180,52);jump.add_child(number)
  var go=ui.button(Locale.t("Bölüme git"),Vector2(340,52));go.pressed.connect(func():load_level(int(number.value)-1));jump.add_child(go)
  var filters=HBoxContainer.new();box.add_child(filters)
  for count in range(5):
   var filter_button=ui.button(Locale.t("Tümü") if count==0 else Locale.t("%d tren")%count,Vector2(100,44),count==admin_filter)
   filter_button.add_theme_font_size_override("font_size",16);filter_button.pressed.connect(func():admin_filter=count;admin_page=0;show_levels());filters.add_child(filter_button)
 var matching=[]
 for i in range(levels.count()):
  if admin_filter==0 or int(levels.get_level(i).get("train_count",1))==admin_filter:matching.append(i)
 var pages=maxi(1,int(ceil(matching.size()/20.0)));admin_page=clampi(admin_page,0,pages-1)
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,350);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
 var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
 for index in matching.slice(admin_page*20,mini(matching.size(),(admin_page+1)*20)):
  var level=levels.get_level(index);var stars=int(SaveData.data.stars.get(str(index),0));var count=int(level.get("train_count",1))
  var title=Locale.t("%03d · %s\n%d tren · %d parça %s")%[int(level.id),("Railway puzzle" if Locale.language=="en" else str(level.name).split(" · ")[0]),count,level.train.size(),"★".repeat(stars)]
  var btn=ui.button(title,Vector2(260,70));btn.add_theme_font_size_override("font_size",16);btn.disabled=not admin and index>=int(SaveData.data.unlocked)
  btn.pressed.connect(func():load_level(index));grid.add_child(btn)
 var page_row=HBoxContainer.new();box.add_child(page_row)
 var previous=ui.button(Locale.t("← Önceki"),Vector2(170,44));previous.disabled=admin_page==0;previous.pressed.connect(func():admin_page-=1;show_levels());page_row.add_child(previous)
 var page_label=ui.label("%d / %d"%[admin_page+1,pages],18,TrainPalette.INK);page_label.custom_minimum_size.x=180;page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;page_row.add_child(page_label)
 var next=ui.button(Locale.t("Sonraki →"),Vector2(170,44));next.disabled=admin_page>=pages-1;next.pressed.connect(func():admin_page+=1;show_levels());page_row.add_child(next)
 ui.modal_button(Locale.t("Oyuna dön"),resume)

func show_vip()->void:
 paused=true;world.train.active=false;ads.cancel()
 var active=purchases.is_vip()
 ui.show_modal(Locale.t("VIP Makinist")+(Locale.t(" · AKTİF") if active else ""),Locale.t("Her bölüme 4 yuvayla başla.\nVIP kalıcı olarak yalnızca +1 başlangıç yuvası verir.\nBir yuva reklamla bu bölüm için açılır.\nAyrı kalıcı yuva satın alınabilir. Toplam sınır 6.\n\nÜCRETSİZ TEST · Satın alma veya abonelik başlatılmaz.\nBu sürüm gerçek ödeme almaz."))
 if purchases.provider=="simulation":
  if active:ui.modal_button(Locale.t("VIP testini kapat · Bölümü yeniden başlat"),disable_vip_test)
  else:ui.modal_button(Locale.t("VIP’yi ücretsiz dene"),enable_vip_test,true)
 ui.modal_button(Locale.t("Oyuna dön"),resume)

func enable_vip_test()->void:
 if not purchases.activate_test_vip():return
 SaveData.data.test_vip=true;SaveData.commit();rules.grant_vip_slot()
 world.sync_parking(rules);ui.update_state(rules);resume();ui.toast(Locale.t("VIP test açık · +1 kalıcı başlangıç yuvası"))

func disable_vip_test()->void:
 purchases.deactivate_test_vip();SaveData.data.test_vip=false;SaveData.commit()
 load_level(level_index)

func show_settings() -> void:
 paused = true
 ui.show_modal(Locale.t("Ses ve görüntü"),Locale.t("Ayarların bu cihazda saklanır."))
 ui.modal_button(Locale.t("Ses efektleri  ·  ")+(Locale.t("Açık") if SaveData.data.sound else Locale.t("Kapalı")),func():
  SaveData.set_option("sound",not SaveData.data.sound)
  show_settings())
 ui.modal_button(Locale.t("Titreşim  ·  ")+(Locale.t("Açık") if SaveData.data.haptics else Locale.t("Kapalı")),func():
  SaveData.set_option("haptics",not SaveData.data.haptics)
  AudioManager.vibrate(25)
  show_settings())
 var names = {"auto":Locale.t("Otomatik"),"high":Locale.t("Yüksek · 60 FPS hedefi"),"low":Locale.t("Ekonomik · 30 FPS")}
 ui.modal_button(Locale.t("Görüntü  ·  ")+names[SaveData.data.quality],func():
  var options = ["auto","high","low"]
  SaveData.set_option("quality",options[(options.find(SaveData.data.quality)+1)%3])
  apply_quality()
  show_settings())
 ui.modal_button(Locale.t("Skor tablosu"),show_scoreboard)
 ui.modal_button("Language / Dil · "+Locale.language.to_upper(),func():
  Locale.toggle();ui.rebuild_hud();ui.set_level(levels.get_level(level_index),level_index);ui.update_state(rules);show_settings())
 ui.modal_button(Locale.t("Oyun istatistikleri"),show_stats)
 ui.modal_button(Locale.t("Gizlilik ve lisanslar"),show_privacy)
 ui.modal_button(Locale.t("Oyuna dön"),resume,true)

func show_stats() -> void:
 var wins = 0
 for attempt in SaveData.data.attempts:
  if attempt is Dictionary and attempt.get("outcome","") == "won":
   wins += 1
 ui.show_modal(Locale.t("Senin yolculuğun"),Locale.t("%d açılış · %d farklı gün\n%d deneme · %d başarı\n\nVeriler yalnızca bu cihazda tutulur.\nOyuncu testi için son 300 deneme saklanır.") % [SaveData.data.sessions,SaveData.data.days.size(),SaveData.data.attempts.size(),wins])
 ui.modal_button(Locale.t("Ayarlar"),show_settings,true)

func show_privacy() -> void:
 ui.show_modal(Locale.t("Sadece oyun"),Locale.t("Gerçek reklam SDK’sı yok; test reklamı simülasyonu var.\nKişisel veri toplanmaz veya gönderilmez.\nİlerleme ve oyun istatistikleri cihazda kalır.\n\nGodot Engine · MIT lisansı\nDejaVu yazı tipleri · Bitstream/DejaVu lisansı\nLisans metinleri kaynak paketinde yer alır."))
 ui.modal_button(Locale.t("Tam lisansları göster"),show_licenses)
 ui.modal_button(Locale.t("Ayarlar"),show_settings,true)

func show_licenses() -> void:
 var box = ui.show_modal(Locale.t("Açık kaynak lisansları"),"")
 var text = TextEdit.new()
 text.custom_minimum_size = Vector2(540,460)
 text.editable = false
 text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 text.add_theme_font_size_override("font_size",16)
 text.text = FileAccess.get_file_as_string("res://assets/LICENSES.txt")
 box.add_child(text)
 ui.modal_button(Locale.t("Geri dön"),show_privacy,true)

func show_help() -> void:
 ui.show_modal(Locale.t("Nasıl oynanır?"),Locale.t("Ok yönünde önü açık vagona dokun; ilk boş yuvaya gider.\n%75’te yükleme açılır. Her tren parçası ayrıca yükleme alanına ulaşmalıdır.\nIşıklı parçalar şu anda erişebildiğin renklerdir.\n\nYaklaşan bir rengi erken seçmek yuvayı bağlar.\nHer vagon üzerindeki sayı kadar parça alınca ayrılır.\nÜç yuva dolsa da tren ilerler; %100’de varış kaybı olur.\n\nGeri alma kalan kapasiteyi korur. A/B anahtarları aynı harfli kilitleri açar.\nÇoklu trenler ayrı raylarda aynı anda ilerler.\nEşleşme yalnızca ilgili treni geriletir.\nAynı renk için varışa yakın tren önceliklidir.\nVIP: yalnızca +1 kalıcı başlangıç yuvası.\nPeronda bir reklam yuvası ve bir ayrı kalıcı yuva bulunur.\nReklam yuvası bölüm içindir; toplam sınır 6’dır."))
 ui.modal_button(Locale.t("Anladım, devam"),resume,true)

func show_jam() -> void:
 jam_shown=true;paused=true;world.train.active=false
 if not qa_mode:SaveData.record_attempt(level_index,"jammed",rules.elapsed,rules.taps,rules.peak_slots)
 ui.show_modal(Locale.t("Bekleme alanı doldu"),Locale.t("Bekleyen renkler aktif hedeflere uymuyor.\nSon hamleni geri alıp başka bir yol deneyebilirsin."))
 if rules.undo_left>0:ui.modal_button("Son hamleyi geri al",func():resume();undo_card(),true)
 if rules.can_unlock_slot():ui.modal_button(Locale.t("+1 yuva · Test reklamı"),func():resume();open_reward())
 ui.modal_button("Yeniden dene",func():load_level(level_index))
 ui.modal_button("Tahtaya bak",resume)

func apply_quality() -> void:
 quality_clock = 0
 slow_seconds = 0
 var low = SaveData.data.quality == "low"
 world.set_quality(low)
 Engine.max_fps = 30 if low else 60
 ui.viewport.get_parent().stretch_shrink = 1

func monitor_performance(delta: float) -> void:
 if qa_mode or SaveData.data.quality != "auto" or world.low_quality:
  return
 quality_clock += delta
 if quality_clock < 4:
  return
 if Engine.get_frames_per_second() < 40:
  slow_seconds += delta
 else:
  slow_seconds = maxf(0,slow_seconds-delta)
 if slow_seconds > 4:
  world.set_quality(true)
  # Automatic mode preserves image sharpness; economy mode remains an explicit option.
  Engine.max_fps = 30

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_P,KEY_ESCAPE]:
   if paused:
    resume()
   else:
    open_menu()

func _notification(what: int) -> void:
 if not is_instance_valid(ui):
  return
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_GO_BACK_REQUEST]:
  if rules.status == "playing" and not paused and not qa_mode:
   open_menu()
  SaveData.commit()


func show_paid_slot()->void:
 paused=true;world.train.active=false;ads.cancel()
 ui.show_modal(Locale.t("Kalıcı ek yuva"),Locale.t("VIP’den ayrı bir kalıcı yuva. Her bölümde kullanılır.\nFiyat hedefi: Türkiye 200 TL · ABD 5 USD.\nFiyat oyun diline değil mağaza ülkesine bağlıdır.\n\nBu sürüm gerçek ödeme almaz. Ücretsiz testtir."))
 if purchases.provider=="simulation":
  if purchases.is_paid():ui.modal_button(Locale.t("Yuva testini kapat · Yeniden başlat"),disable_paid_test)
  else:ui.modal_button(Locale.t("Yuvayı ücretsiz dene"),enable_paid_test,true)
 ui.modal_button(Locale.t("Oyuna dön"),resume)

func enable_paid_test()->void:
 if not purchases.activate_test_paid():return
 SaveData.data.test_paid=true;SaveData.commit();rules.grant_paid_slot()
 world.sync_parking(rules);ui.update_state(rules);resume()

func disable_paid_test()->void:
 purchases.test_paid=false;SaveData.data.test_paid=false;SaveData.commit();load_level(level_index)

func show_scoreboard()->void:
 paused=true;world.train.active=false
 var box=ui.show_modal(Locale.t("Skor tablosu · Bu cihaz"),Locale.t("Çevrimiçi oyuncu sıralaması henüz bağlı değil.\nStandart: 3 yuva, ipucu/geri alma/kurtarma yok.\nEk hak kullanılan koşular ayrı tutulur.\nBu sürümün test koşuları dünya sıralamasına gönderilmez."))
 var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(540,280);box.add_child(scroll)
 var column=VBoxContainer.new();scroll.add_child(column)
 var categories={"standard":Locale.t("Standart"),"assisted":Locale.t("Destekli"),"practice_standard":Locale.t("Test · Standart"),"practice_assisted":Locale.t("Test · Destekli")}
 for category in categories:
  var records:Dictionary=SaveData.data.records_v027.get(category,{})
  column.add_child(ui.label(categories[category],19,TrainPalette.INK,true))
  var completed=0;var total=0.0
  while records.has(str(completed)):
   total+=float(records[str(completed)]);completed+=1
  column.add_child(ui.label(Locale.t("Ardışık tamamlanan: %d · Toplam en iyi süre: %.1f sn")%[completed,total],15))
  var ids=records.keys();ids.sort_custom(func(a,b):return int(a)<int(b))
  for id in ids:column.add_child(ui.label(Locale.t("Bölüm %03d · En iyi %.2f sn")%[int(id)+1,float(records[id])],17))
  if ids.is_empty():column.add_child(ui.label(Locale.t("Henüz tamamlanan bölüm yok."),16))
 ui.modal_button(Locale.t("Oyuna dön"),resume,true)

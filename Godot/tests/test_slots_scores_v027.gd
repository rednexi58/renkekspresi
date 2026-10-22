extends "res://tests/test_admin_flow_v022.gd"
func run()->void:
 var save=root.get_node("SaveData");var original=save.data.duplicate(true)
 root.get_node("Locale").language="tr"
 var level=LevelData.new().get_level(9)
 for order in [["vip","paid","reward"],["vip","reward","paid"],["paid","vip","reward"],["paid","reward","vip"],["reward","paid","vip"],["reward","vip","paid"]]:
  var r=GameRules.new();r.reset(level);r.status="playing"
  var expected=3
  for source in order:
   if source=="vip":r.grant_vip_slot()
   elif source=="paid":r.grant_paid_slot()
   else:r.unlock_reward_slot()
   expected+=1;check(r.slots.size()==expected,"Missing source slot")
  check(r.locked_slot_kinds().is_empty(),"Closed slots remain")
  check(not r.grant_vip_slot() and not r.grant_paid_slot() and not r.unlock_reward_slot(),"Duplicate entitlement")
  check(r.slots.size()==6,"Slot cap failed")
 save.data.test_vip=false;save.data.test_paid=false;save.data.records_v027={}
 var game=load("res://scenes/Main.tscn").instantiate();root.add_child(game);game.set_process(false);await process_frame;game.qa_mode=true;game.load_level(9)
 check(game.rules.locked_slot_kinds()==["vip","reward","paid"],"Wrong closed source mapping")
 for i in range(3,6):
  var touch=InputEventScreenTouch.new();touch.pressed=true;touch.device=0
  touch.position=game.world.camera.unproject_position(game.world.station_slots[i].global_position+Vector3.UP*.30)/Vector2(game.ui.viewport.size)*root.get_visible_rect().size
  game._input(touch)
  var expected=["VIP’yi ücretsiz dene","Test reklamını başlat","Yuvayı ücretsiz dene"][i-3]
  check(button_named(game.ui.overlay,expected)!=null,"Peron action mapped to wrong entitlement")
  game.resume()
 game.show_paid_slot();game.enable_paid_test();check(game.rules.slots.size()==4 and save.data.test_paid,"Paid slot test persistence")
 game.show_vip();game.enable_vip_test();check(game.rules.slots.size()==5,"VIP does not stack")
 game.open_reward();game.begin_reward();game.claim_reward();check(game.rules.slots.size()==5,"Early reward")
 game.cancel_reward();game._process(5);game.claim_reward();check(game.rules.slots.size()==5,"Cancelled reward")
 game.open_reward();game.begin_reward();game._process(3.1);game.claim_reward();game.claim_reward()
 check(game.rules.slots.size()==6 and not game.rules.can_unlock_slot(),"Single ad limit")
 game.load_level(24);check(game.rules.slots.size()==5 and game.rules.locked_slot_kinds()==["reward"],"Restart entitlement mismatch")
 var p=PurchaseManager.new();p.configure({"test_tools":false,"purchases_provider":"simulation"},true);p.test_paid=true
 check(not p.is_vip() and not p.is_paid(),"Test flag leaked into production")
 save.record_score(0,12.5,"standard");save.record_score(0,15.0,"standard");save.record_score(0,10.0,"assisted")
 save.record_score(1,-1,"standard")
 check(save.data.records_v027.standard["0"]==12.5 and not save.data.records_v027.standard.has("1"),"Record validation")
 check(save.data.records_v027.assisted["0"]==10,"Assisted separation")
 for language in ["tr","en"]:
  root.get_node("Locale").language=language
  game.ui.rebuild_hud();game.ui.set_level(level,9);game.ui.update_state(game.rules)
  game.show_scoreboard();check(is_instance_valid(game.ui.overlay),"Scoreboard missing")
  game.show_paid_slot();check(button_named(game.ui.overlay,"Yuva testini kapat · Yeniden başlat" if language=="tr" else "Disable test slot · Restart")!=null,"Purchase translation missing")
 game.queue_free();save.data=original;save.commit()
 for voice in root.get_node("AudioManager").players:voice.stop();voice.stream=null
 for i in range(4):await process_frame
 print("V027 SLOTS / SCORES / LANGUAGE FAILURES: ",failures);quit(1 if failures else 0)

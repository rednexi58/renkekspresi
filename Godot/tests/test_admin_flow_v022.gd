extends SceneTree
var failures=0
func check(ok:bool,msg:String)->void:
 if not ok:failures+=1;push_error(msg)
func _initialize()->void:call_deferred("run")
func button_named(node:Node,needle:String)->Button:
 if node is Button and node.text==needle:return node
 for child in node.get_children():
  var found=button_named(child,needle)
  if found:return found
 return null
func find_spin(node:Node)->SpinBox:
 if node is SpinBox:return node
 for child in node.get_children():
  var found=find_spin(child)
  if found:return found
 return null
func run()->void:
 var game=load("res://scenes/Main.tscn").instantiate();root.add_child(game);game.set_process(false);await process_frame;game.qa_mode=true
 game.show_levels();var spin=find_spin(game.ui.overlay);check(spin!=null,"Admin jump missing")
 spin.value=100;button_named(game.ui.overlay,"Bölüme git").pressed.emit()
 check(game.level_index==99 and game.rules is MultiTrainRules and game.rules.train_count==4,"Admin jump failed")
 game.show_levels();button_named(game.ui.overlay,"2 tren").pressed.emit();check(game.admin_filter==2,"Filter failed")
 game.resume();game.load_level(30);game.open_reward();game.begin_reward();var time=game.rules.elapsed
 game._process(3.1);check(game.rules.elapsed==time,"Ad did not pause gameplay")
 game.claim_reward();check(game.rules.reward_used and game.rules.slots.size()==4,"UI slot reward failed")
 game.rules.tick(250);check(game.rules.status=="lost","Loss setup failed")
 game.finish();game.open_reward("continue");game.begin_reward();game._process(3.1);game.claim_reward()
 check(game.rules.status=="playing" and game.rules.continue_used and not game.paused,"UI continue failed")
 game.rules.tick(250);check(game.rules.status=="lost","Second loss missing")
 game.finish();check(button_named(game.ui.overlay,"Kurtarma şansı · Test reklamı")==null,"Duplicate continue offered")
 for voice in root.get_node("AudioManager").players:voice.stop();voice.stream=null
 game.queue_free()
 for i in range(4):await process_frame
 print("ADMIN / UI REWARD FAILURES: ",failures);quit(1 if failures else 0)

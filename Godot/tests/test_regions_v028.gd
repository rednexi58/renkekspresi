extends "res://tests/test_admin_flow_v022.gd"
func run()->void:
 var game=load("res://scenes/Main.tscn").instantiate()
 root.add_child(game);game.set_process(false);await process_frame;game.qa_mode=true
 for language in ["tr","en"]:
  root.get_node("Locale").language=language
  for index in range(15):
   game.load_level(index)
   await process_frame
   check(game.world.current_theme==[1,0,5][int(index/5)],"Wrong region")
   check(game.world.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"Camera changed")
   check(game.world.rail.total_length>10,"Empty track")
   game.rules.status="won";game.finish()
   check(is_instance_valid(game.ui.overlay),"Result screen missing")
   game.world.set_quality(true)
   game.world.set_quality(false)
 for voice in root.get_node("AudioManager").players:voice.stop();voice.stream=null
 game.queue_free()
 for i in range(4):await process_frame
 print("V028 REGION / RESULT / LANGUAGE FAILURES: ",failures)
 quit(1 if failures else 0)

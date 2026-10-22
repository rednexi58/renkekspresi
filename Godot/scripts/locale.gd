extends Node
var language="tr"
var english:Dictionary={}
func _ready()->void:
 english=JSON.parse_string(FileAccess.get_file_as_string("res://data/en.json"))
 var saved=str(SaveData.data.get("language","auto"))
 language=("tr" if OS.get_locale_language()=="tr" else "en") if saved=="auto" else saved
func t(source:String)->String:
 return str(english.get(source,source)) if language=="en" else source
func toggle()->void:
 language="en" if language=="tr" else "tr"
 SaveData.set_option("language",language)

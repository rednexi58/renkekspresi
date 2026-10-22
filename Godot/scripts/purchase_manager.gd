class_name PurchaseManager
extends RefCounted
## No payment SDK or receipt verification is shipped in the browser test.
## The test flag is deliberately separate from production entitlements.
var provider="disabled"
var test_vip=false
var test_paid=false
func configure(config:Dictionary,saved_test_vip:bool)->void:
 provider="simulation" if bool(config.get("test_tools",false)) and config.get("purchases_provider","")=="simulation" else "disabled"
 test_vip=saved_test_vip and provider=="simulation"
func is_vip()->bool:return provider=="simulation" and test_vip
func activate_test_vip()->bool:
 if provider!="simulation":return false
 test_vip=true;return true
func deactivate_test_vip()->void:test_vip=false

func is_paid()->bool:return provider=="simulation" and test_paid
func activate_test_paid()->bool:
 if provider!="simulation":return false
 test_paid=true;return true

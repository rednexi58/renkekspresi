class_name DebugCommerce
extends CommerceService
## Development-only provider so the VIP slot and rewarded-slot flows can be played and
## tested before the real StoreKit and ad SDK are integrated. Every grant is immediate
## and in memory only. Main never selects it in a release export
## (OS.is_debug_build() is false there), so it cannot fabricate purchases for players.

var _vip := false


func has_vip() -> bool:
	return _vip


func can_purchase_vip() -> bool:
	return not _vip


func vip_price() -> String:
	return "TEST"


func purchase_vip(finished: Callable) -> void:
	_vip = true
	entitlements_changed.emit()
	finished.call(true)


func restore_purchases(finished: Callable) -> void:
	finished.call(_vip)


func can_show_rewarded() -> bool:
	return true


func show_rewarded(_placement: String, finished: Callable) -> void:
	finished.call(true)

class_name DebugCommerce
extends CommerceService
## Development and internal-playtest provider: every purchase and rewarded ad is granted
## immediately (prices are labelled TEST), so all flows can be played before StoreKit and
## the ad SDK are integrated. Main selects it only in debug builds or builds exported
## with the "playtest" feature; App Store builds never contain it as their provider.

var _owned := {}


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


func can_purchase(product_id: String) -> bool:
	return ProductCatalog.is_consumable(product_id) or not _owned.has(product_id)


func price(product_id: String) -> String:
	return "TEST " + ProductCatalog.FALLBACK_PRICES.get(product_id, "")


func purchase(product_id: String, finished: Callable) -> void:
	if not ProductCatalog.is_consumable(product_id):
		_owned[product_id] = true
		entitlements_changed.emit()
	finished.call(true)


func restore_purchases(finished: Callable) -> void:
	finished.call(true)


func can_show_rewarded() -> bool:
	return true


func show_rewarded(_placement: String, finished: Callable) -> void:
	finished.call(true)


func can_show_interstitial() -> bool:
	return false

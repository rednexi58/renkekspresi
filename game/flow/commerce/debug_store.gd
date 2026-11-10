class_name DebugStore
extends StoreProvider
## Development store: every purchase completes immediately (prices are labelled TEST) and
## the VIP subscription runs for SUBSCRIPTION_DAYS, so all flows can be played on a
## desktop. CommerceFactory never selects it on a device that has the StoreKit plugin.

const SUBSCRIPTION_DAYS := 30

var _owned := {}
var _expiry := {}
var _next_transaction := 1


func entitlements_known() -> bool:
	return true


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


func subscription_expiry(product_id: String) -> int:
	return _expiry.get(product_id, 0)


func can_purchase(product_id: String) -> bool:
	if ProductCatalog.is_subscription(product_id):
		return subscription_expiry(product_id) <= int(Time.get_unix_time_from_system())
	return ProductCatalog.is_consumable(product_id) or not _owned.has(product_id)


func price(product_id: String) -> String:
	return "TEST " + ProductCatalog.FALLBACK_PRICES.get(product_id, "")


func purchase(product_id: String, finished: Callable) -> void:
	if ProductCatalog.is_subscription(product_id):
		_expiry[product_id] = int(Time.get_unix_time_from_system()) + SUBSCRIPTION_DAYS * 86400
	elif not ProductCatalog.is_consumable(product_id):
		_owned[product_id] = true
	purchased.emit(product_id, "debug-%d" % _next_transaction)
	_next_transaction += 1
	entitlements_changed.emit()
	finished.call(true)


func restore(finished: Callable) -> void:
	entitlements_changed.emit()
	finished.call(true)

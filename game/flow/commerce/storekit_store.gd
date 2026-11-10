class_name StoreKitStore
extends StoreProvider
## App Store purchases through the "IOSInAppPurchase" plugin (StoreKit 2, see
## ci/fetch_ios_plugins.sh). The plugin answers every request through one `response`
## signal, emitted from StoreKit's background tasks; it is connected deferred so every
## answer is handled on the main thread.
##
## The plugin finishes verified transactions before reporting them. Each one carries
## StoreKit's transaction id (in its JSON); CommerceService's listener records delivered
## ids, so a transaction reported twice (e.g. on the next launch) is fulfilled once.

const SINGLETON := "IOSInAppPurchase"
const PRODUCTS_RETRY_SECONDS := [5.0, 15.0, 45.0, 120.0]

var _plugin: Object
var _host: Node
var _prices := {}
var _owned := {}
var _expiry := {}
var _known := false
## Product being bought and the callback waiting for it (StoreKit shows one purchase
## sheet at a time, so one pending purchase is enough).
var _purchasing := ""
var _purchase_finished := Callable()
var _restore_waiters: Array[Callable] = []
var _product_attempts := 0


static func is_supported() -> bool:
	return Engine.has_singleton(SINGLETON)


func start(host: Node) -> void:
	_host = host
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.connect("response", _on_response, Object.CONNECT_DEFERRED)
	_plugin.call("request", "startUpdateTask", {})
	_plugin.call("request", "proceedUnfinishedTransactions", {})
	_request_products()
	refresh()


func refresh() -> void:
	if _plugin != null:
		_plugin.call("request", "transactionCurrentEntitlements", {})


func entitlements_known() -> bool:
	return _known


func owns(product_id: String) -> bool:
	return _owned.has(product_id)


func subscription_expiry(product_id: String) -> int:
	return _expiry.get(product_id, 0)


func can_purchase(product_id: String) -> bool:
	if not _prices.has(product_id) or not _purchasing.is_empty():
		return false
	if ProductCatalog.is_subscription(product_id):
		return subscription_expiry(product_id) <= int(Time.get_unix_time_from_system())
	return ProductCatalog.is_consumable(product_id) or not owns(product_id)


func price(product_id: String) -> String:
	return _prices.get(product_id, "")


func purchase(product_id: String, finished: Callable) -> void:
	if not can_purchase(product_id):
		finished.call(false)
		return
	_purchasing = product_id
	_purchase_finished = finished
	if int(_plugin.call("request", "purchase", {"productID": product_id})) != 0:
		_end_purchase(false)


func restore(finished: Callable) -> void:
	_restore_waiters.append(finished)
	if _restore_waiters.size() == 1 and int(_plugin.call("request", "appStoreSync", {})) != 0:
		_finish_restore(false)


func _request_products() -> void:
	_plugin.call("request", "products", {"productIDs": ProductCatalog.all()})


func _on_response(response_name: String, data: Dictionary) -> void:
	match response_name:
		"products":
			_on_products(data)
		"purchase":
			_on_purchase(data)
		"transactionCurrentEntitlements":
			_on_entitlements(data)
		"appStoreSync":
			if data.get("result", "") == "success":
				refresh()
			else:
				_finish_restore(false)


func _on_products(data: Dictionary) -> void:
	if data.get("result", "") != "success":
		var delay: float = PRODUCTS_RETRY_SECONDS[mini(_product_attempts, PRODUCTS_RETRY_SECONDS.size() - 1)]
		_product_attempts += 1
		_host.get_tree().create_timer(delay).timeout.connect(_request_products)
		return
	for product: Variant in data.get("products", []):
		if product is Dictionary:
			_prices[str(product.get("id", ""))] = str(product.get("displayPrice", ""))
	products_changed.emit()


## Purchase responses come from purchase calls and also from StoreKit's update stream
## (renewals, approved Ask to Buy, transactions finished on a later launch).
func _on_purchase(data: Dictionary) -> void:
	var result := str(data.get("result", ""))
	var product_id := str(data.get("productID", _purchasing))
	if result == "success":
		var transaction := _transaction_json(data)
		if ProductCatalog.is_subscription(product_id):
			_expiry[product_id] = maxi(subscription_expiry(product_id), _expiry_of(transaction))
		elif not ProductCatalog.is_consumable(product_id):
			_owned[product_id] = true
		purchased.emit(product_id, str(transaction.get("transactionId", "")))
		entitlements_changed.emit()
		if product_id == _purchasing:
			_end_purchase(true)
		refresh()
	elif result == "revoked":
		refresh()
	elif not _purchasing.is_empty() and product_id == _purchasing:
		# Cancelled, pending (Ask to Buy: it arrives later through the update stream),
		# unverified or failed: nothing is granted now.
		_end_purchase(false)


func _end_purchase(ok: bool) -> void:
	var finished := _purchase_finished
	_purchasing = ""
	_purchase_finished = Callable()
	if finished.is_valid():
		finished.call(ok)


## Current entitlements: active subscriptions and owned non-consumables, without
## revoked ones. Replaces what was known before, so expiry and refunds take effect.
func _on_entitlements(data: Dictionary) -> void:
	if data.get("result", "") != "success":
		_finish_restore(false)
		return
	var owned := {}
	var expiry := {}
	var now := int(Time.get_unix_time_from_system())
	for entry: Variant in data.get("transactions", []):
		if not entry is Dictionary or str(entry.get("revocationDate", "")) != "" or entry.has("error"):
			continue
		var product_id := str(entry.get("productID", ""))
		if ProductCatalog.is_subscription(product_id):
			var ends := _parse_date(str(entry.get("expirationDate", "")))
			if ends > now:
				expiry[product_id] = maxi(expiry.get(product_id, 0), ends)
		elif ProductCatalog.NON_CONSUMABLES.has(product_id):
			owned[product_id] = true
	_owned = owned
	_expiry = expiry
	_known = true
	entitlements_changed.emit()
	_finish_restore(true)


func _finish_restore(ok: bool) -> void:
	var waiters := _restore_waiters
	_restore_waiters = []
	for waiter in waiters:
		waiter.call(ok)


static func _transaction_json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(str(data.get("json", "")))
	return parsed if parsed is Dictionary else {}


## StoreKit's JSON gives the subscription end as milliseconds since 1970.
static func _expiry_of(transaction: Dictionary) -> int:
	return int(float(transaction.get("expiresDate", 0)) / 1000.0)


## The plugin formats dates as ISO 8601 in UTC ("2026-12-10T08:30:00.000Z").
static func _parse_date(text: String) -> int:
	if text.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(text.substr(0, 19)))

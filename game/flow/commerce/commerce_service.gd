class_name CommerceService
extends RefCounted
## The game's only view of money: App Store purchases (StoreProvider) and ads
## (AdProvider). Game code asks what is available and requests an outcome; it never
## decides on its own that a reward was earned or a purchase made.
##
## Store and ads are separate providers because they vary independently (StoreKit with
## no ads on a simulator, test ads with real sandbox purchases on TestFlight...), and a
## class per concern keeps each one small and testable; this facade only composes them.

signal entitlements_changed
signal purchased(product_id: String, transaction_id: String)
signal products_changed
signal fullscreen_changed(showing: bool)

var store: StoreProvider
var ads: AdProvider


func _init(store_provider: StoreProvider = null, ad_provider: AdProvider = null) -> void:
	store = store_provider if store_provider != null else StoreProvider.new()
	ads = ad_provider if ad_provider != null else AdProvider.new()
	store.entitlements_changed.connect(func() -> void: entitlements_changed.emit())
	store.purchased.connect(func(product_id: String, transaction_id: String) -> void: purchased.emit(product_id, transaction_id))
	store.products_changed.connect(func() -> void: products_changed.emit())
	ads.fullscreen_changed.connect(func(showing: bool) -> void: fullscreen_changed.emit(showing))


func start(host: Node) -> void:
	store.start(host)
	ads.start(host)


func refresh() -> void:
	store.refresh()


func entitlements_known() -> bool:
	return store.entitlements_known()


func owns(product_id: String) -> bool:
	return store.owns(product_id)


func subscription_expiry(product_id: String) -> int:
	return store.subscription_expiry(product_id)


func can_purchase(product_id: String) -> bool:
	return store.can_purchase(product_id)


func price(product_id: String) -> String:
	return store.price(product_id)


func purchase(product_id: String, finished: Callable) -> void:
	store.purchase(product_id, finished)


func restore_purchases(finished: Callable) -> void:
	store.restore(finished)


func can_show_rewarded() -> bool:
	return ads.can_show_rewarded()


func show_rewarded(placement: String, finished: Callable) -> void:
	ads.show_rewarded(placement, finished)


func can_show_interstitial() -> bool:
	return ads.can_show_interstitial()


func show_interstitial(finished: Callable) -> void:
	ads.show_interstitial(finished)


func has_privacy_options() -> bool:
	return ads.has_privacy_options()


func show_privacy_options() -> void:
	ads.show_privacy_options()


func can_purchase_vip() -> bool:
	return can_purchase(ProductCatalog.VIP)

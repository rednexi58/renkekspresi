class_name StoreProvider
extends RefCounted
## The App Store side of CommerceService: products, purchases, entitlements. This base
## class is the "no store" provider (desktop release builds, or a device where the
## StoreKit plugin is missing): nothing is purchasable, so the interface hides every paid
## entry point instead of showing buttons that cannot work (App Review guideline 2.1).
##
## Every verified purchase, including ones that complete outside a purchase call (a
## renewal, an approved Ask to Buy, an interrupted purchase finished on the next launch),
## is announced once through `purchased`; fulfilment listens to that signal, so content
## is delivered exactly once whatever started the transaction.

## A verified transaction for `product_id`; `transaction_id` is unique per purchase.
signal purchased(product_id: String, transaction_id: String)
## Ownership or subscription state changed (entitlements re-read from the store).
signal entitlements_changed
## Localised prices arrived or changed.
signal products_changed


## Called once by the composition root; `host` gives access to the scene tree (timers).
func start(_host: Node) -> void:
	pass


## Re-reads entitlements (e.g. when the app returns to the foreground).
func refresh() -> void:
	pass


## True once the store has answered at least one entitlement query, so an absent
## entitlement really means "not owned" rather than "not known yet".
func entitlements_known() -> bool:
	return false


func owns(_product_id: String) -> bool:
	return false


## End of the current subscription period (Unix seconds), or 0 when not subscribed.
func subscription_expiry(_product_id: String) -> int:
	return 0


func can_purchase(_product_id: String) -> bool:
	return false


## Localised price to display, or "" when the product is unavailable.
func price(_product_id: String) -> String:
	return ""


## Starts a purchase; `finished` receives true only after a verified purchase has been
## announced through `purchased` (so it is already fulfilled when `finished` runs).
func purchase(_product_id: String, finished: Callable) -> void:
	finished.call(false)


## Asks the store to resynchronise purchases; `finished` receives true when it answered.
func restore(finished: Callable) -> void:
	finished.call(false)

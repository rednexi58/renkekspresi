class_name CommerceService
extends RefCounted
## The game's only view of money: App Store purchases and ads. Game code asks what is
## available and requests an outcome; it never decides on its own that a reward was
## earned or a purchase made.
##
## Concrete providers (StoreKit, an ad network) subclass this. While no real provider is
## attached, UnavailableCommerce reports nothing as available, so the interface hides
## every paid or rewarded entry point and the shipped app never contains a button that
## cannot work (App Review guideline 2.1).

signal entitlements_changed


## True if the player owns a non-consumable product.
func owns(_product_id: String) -> bool:
	return false


func can_purchase(_product_id: String) -> bool:
	return false


## Localised price to display, or "" when the product is unavailable.
func price(_product_id: String) -> String:
	return ""


## Starts a purchase; `finished` receives true only for a verified, completed purchase.
func purchase(_product_id: String, finished: Callable) -> void:
	finished.call(false)


## Restores non-consumables; `finished` receives true when the store answered.
func restore_purchases(finished: Callable) -> void:
	finished.call(false)


func can_show_rewarded() -> bool:
	return false


## Shows a rewarded ad; `finished` receives true only when the reward was earned.
func show_rewarded(_placement: String, finished: Callable) -> void:
	finished.call(false)


func can_show_interstitial() -> bool:
	return false


## Shows an interstitial if one is ready; `finished` is always called afterwards.
func show_interstitial(finished: Callable) -> void:
	finished.call()


# Convenience for the VIP slot flow.
func has_vip() -> bool:
	return owns(ProductCatalog.VIP)


func can_purchase_vip() -> bool:
	return can_purchase(ProductCatalog.VIP)

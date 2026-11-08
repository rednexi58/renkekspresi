class_name CommerceService
extends RefCounted
## The game's only view of money: the VIP purchase and rewarded ads. Game code asks
## what is available and requests an outcome; it never decides on its own that a reward
## was earned or a purchase made.
##
## Concrete providers (StoreKit for VIP, an ad network for rewarded videos) subclass
## this. While no real provider is attached, UnavailableCommerce reports nothing as
## available, so the interface hides every paid or rewarded entry point and the shipped
## app never contains a button that cannot work (App Review guideline 2.1).

signal entitlements_changed


## True once the player owns VIP (permanent extra slot).
func has_vip() -> bool:
	return false


func can_purchase_vip() -> bool:
	return false


## Localised price to show on the VIP button ("" when unknown).
func vip_price() -> String:
	return ""


## Starts the VIP purchase; `finished` receives true only for a verified purchase.
func purchase_vip(finished: Callable) -> void:
	finished.call(false)


func restore_purchases(finished: Callable) -> void:
	finished.call(false)


func can_show_rewarded() -> bool:
	return false


## Shows a rewarded ad; `finished` receives true only when the reward was earned.
func show_rewarded(_placement: String, finished: Callable) -> void:
	finished.call(false)

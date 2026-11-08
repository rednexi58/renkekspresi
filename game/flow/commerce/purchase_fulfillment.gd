class_name PurchaseFulfillment
extends RefCounted
## Applies what a completed purchase grants to the player's progress. Kept apart from
## the store provider so every provider (StoreKit, test) fulfils identically, and apart
## from UI so a purchase completing in the background is still fulfilled.


## Returns the coins granted (for the celebration message).
static func fulfil(product_id: String, progress: PlayerProgress) -> int:
	var coins := ProductCatalog.coins_for(product_id)
	match product_id:
		ProductCatalog.VIP:
			progress.owns_vip = true
		ProductCatalog.NO_ADS:
			progress.owns_no_ads = true
		ProductCatalog.STARTER:
			progress.owns_starter = true
			progress.owns_vip = true
			if not progress.owns_skin(ProductCatalog.STARTER_SKIN):
				progress.skins_owned.append(ProductCatalog.STARTER_SKIN)
		ProductCatalog.PIGGY:
			coins = progress.piggy_coins
			progress.piggy_coins = 0
	progress.add_coins(coins)
	return coins


## Re-applies entitlements reported by the store after a restore (no coins).
static func sync_entitlements(commerce: CommerceService, progress: PlayerProgress) -> void:
	progress.owns_vip = progress.owns_vip or commerce.owns(ProductCatalog.VIP) or commerce.owns(ProductCatalog.STARTER)
	progress.owns_no_ads = progress.owns_no_ads or commerce.owns(ProductCatalog.NO_ADS)
	progress.owns_starter = progress.owns_starter or commerce.owns(ProductCatalog.STARTER)
	if progress.owns_starter and not progress.owns_skin(ProductCatalog.STARTER_SKIN):
		progress.skins_owned.append(ProductCatalog.STARTER_SKIN)

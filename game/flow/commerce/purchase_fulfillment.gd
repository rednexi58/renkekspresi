class_name PurchaseFulfillment
extends RefCounted
## Applies what a completed purchase grants to the player's progress. Kept apart from
## the store provider so every provider (StoreKit, test) fulfils identically, and apart
## from UI so a purchase completing in the background is still fulfilled.


## Returns the coins granted (for the celebration message). `vip_expiry` is the end of
## the VIP subscription period as reported by the store (used for VIP only).
static func fulfil(product_id: String, progress: PlayerProgress, vip_expiry: int = 0) -> int:
	var coins := ProductCatalog.coins_for(product_id)
	match product_id:
		ProductCatalog.VIP:
			progress.vip_until = maxi(progress.vip_until, vip_expiry)
		ProductCatalog.NO_ADS:
			progress.owns_no_ads = true
		ProductCatalog.STARTER:
			progress.owns_starter = true
			if not progress.owns_skin(ProductCatalog.STARTER_SKIN):
				progress.skins_owned.append(ProductCatalog.STARTER_SKIN)
			for kind in 3:
				progress.booster_bank[kind] += ProductCatalog.STARTER_BOOSTERS[kind]
		ProductCatalog.PIGGY:
			coins = progress.piggy_coins
			progress.piggy_coins = 0
	progress.add_coins(coins)
	return coins


## Mirrors the store's entitlements into progress (no coins). Ownership of permanent
## products is only ever added; the subscription follows the store exactly once the
## store has answered, so an expired, cancelled or refunded VIP ends.
static func sync_entitlements(commerce: CommerceService, progress: PlayerProgress) -> void:
	progress.owns_no_ads = progress.owns_no_ads or commerce.owns(ProductCatalog.NO_ADS)
	progress.owns_starter = progress.owns_starter or commerce.owns(ProductCatalog.STARTER)
	if progress.owns_starter and not progress.owns_skin(ProductCatalog.STARTER_SKIN):
		progress.skins_owned.append(ProductCatalog.STARTER_SKIN)
	if commerce.entitlements_known():
		progress.vip_until = commerce.subscription_expiry(ProductCatalog.VIP)

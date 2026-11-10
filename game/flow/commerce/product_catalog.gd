class_name ProductCatalog
extends RefCounted
## The App Store products. Identifiers must match App Store Connect exactly.
## - VIP is a monthly auto-renewable subscription (one permanent extra slot in every
##   level and no interstitial ads while it is active).
## - No Ads and the Starter Pack are non-consumables: owned forever and restorable.
## - Coin packs and the piggy bank are consumables: their contents are granted once per
##   purchase.

const VIP := "com.bedogames.renkekspresi.vip.monthly"
const NO_ADS := "com.bedogames.renkekspresi.noads"
const STARTER := "com.bedogames.renkekspresi.starter"
const COINS_SMALL := "com.bedogames.renkekspresi.coins1000"
const COINS_MEDIUM := "com.bedogames.renkekspresi.coins5000"
const COINS_LARGE := "com.bedogames.renkekspresi.coins12000"
const PIGGY := "com.bedogames.renkekspresi.piggybank"

const SUBSCRIPTIONS := [VIP]
const NON_CONSUMABLES := [NO_ADS, STARTER]
const CONSUMABLES := [COINS_SMALL, COINS_MEDIUM, COINS_LARGE, PIGGY]

## Coins granted on purchase (the piggy bank grants whatever it holds instead).
const COINS := {
	NO_ADS: 2000,
	STARTER: 1500,
	COINS_SMALL: 1000,
	COINS_MEDIUM: 5000,
	COINS_LARGE: 12000,
}

## Boosters [freeze, blast, recall] banked by the starter pack for the next levels.
const STARTER_BOOSTERS := [3, 3, 3]

## Reference prices (Turkey) shown only by the development store; the real store
## always displays Apple's localised price.
const FALLBACK_PRICES := {
	VIP: "₺299,99",
	NO_ADS: "₺399,99",
	STARTER: "₺99,99",
	COINS_SMALL: "₺99,99",
	COINS_MEDIUM: "₺449,99",
	COINS_LARGE: "₺899,99",
	PIGGY: "₺129,99",
}

## Locomotive livery unlocked by the starter pack.
const STARTER_SKIN := "golden"

## Apple's standard licence agreement (Terms of Use) and subscription management page,
## both linked next to the subscription offer as App Review guideline 3.1.2 requires.
const TERMS_URL := "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
const MANAGE_SUBSCRIPTIONS_URL := "https://apps.apple.com/account/subscriptions"


static func all() -> Array:
	return SUBSCRIPTIONS + NON_CONSUMABLES + CONSUMABLES


static func is_consumable(product_id: String) -> bool:
	return CONSUMABLES.has(product_id)


static func is_subscription(product_id: String) -> bool:
	return SUBSCRIPTIONS.has(product_id)


static func coins_for(product_id: String) -> int:
	return COINS.get(product_id, 0)

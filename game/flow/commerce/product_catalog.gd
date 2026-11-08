class_name ProductCatalog
extends RefCounted
## The App Store products. Identifiers must match App Store Connect exactly.
## Non-consumables (VIP, No Ads, Starter) are owned forever and restorable; consumables
## (coin packs, piggy bank) grant their contents once per purchase.

const VIP := "com.bedogames.renkekspresi.vip"
const NO_ADS := "com.bedogames.renkekspresi.noads"
const STARTER := "com.bedogames.renkekspresi.starter"
const COINS_SMALL := "com.bedogames.renkekspresi.coins1000"
const COINS_MEDIUM := "com.bedogames.renkekspresi.coins5000"
const COINS_LARGE := "com.bedogames.renkekspresi.coins12000"
const PIGGY := "com.bedogames.renkekspresi.piggybank"

const NON_CONSUMABLES := [VIP, NO_ADS, STARTER]
const CONSUMABLES := [COINS_SMALL, COINS_MEDIUM, COINS_LARGE, PIGGY]

## Coins granted on purchase (the piggy bank grants whatever it holds instead).
const COINS := {
	NO_ADS: 2000,
	STARTER: 1500,
	COINS_SMALL: 1000,
	COINS_MEDIUM: 5000,
	COINS_LARGE: 12000,
}

## Reference prices shown until the store returns localised prices (Turkey tier).
const FALLBACK_PRICES := {
	VIP: "₺99,99",
	NO_ADS: "₺399,99",
	STARTER: "₺99,99",
	COINS_SMALL: "₺99,99",
	COINS_MEDIUM: "₺449,99",
	COINS_LARGE: "₺899,99",
	PIGGY: "₺129,99",
}

## Locomotive livery unlocked by the starter pack.
const STARTER_SKIN := "golden"


static func all() -> Array:
	return NON_CONSUMABLES + CONSUMABLES


static func is_consumable(product_id: String) -> bool:
	return CONSUMABLES.has(product_id)


static func coins_for(product_id: String) -> int:
	return COINS.get(product_id, 0)

class_name CommerceFactory
extends RefCounted
## Chooses the store and ad providers for the running build:
## - native plugin present (iOS device builds): StoreKit and AdMob;
## - development builds and "playtest" exports without the plugins: instant test
##   providers, so every paid and rewarded flow can be tried on a desktop;
## - anything else: the base providers, which offer nothing.
## The choice is made per provider, so a build can have one native and one test side.


static func create() -> CommerceService:
	var testing := OS.is_debug_build() or OS.has_feature("playtest")
	var store: StoreProvider
	if StoreKitStore.is_supported():
		store = StoreKitStore.new()
	elif testing:
		store = DebugStore.new()
	else:
		store = StoreProvider.new()
	var ads: AdProvider
	if AdMobAds.is_supported():
		ads = AdMobAds.new()
	elif testing:
		ads = DebugAds.new()
	else:
		ads = AdProvider.new()
	return CommerceService.new(store, ads)

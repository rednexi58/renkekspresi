class_name UnavailableCommerce
extends CommerceService
## Used whenever no real store or ad provider is attached (release builds before the
## StoreKit and ad SDK integration): every capability reports unavailable, so the game
## hides all paid and rewarded entry points instead of showing dead buttons.

class_name GameContext
extends RefCounted
## Shared, long-lived game state handed to menus and flows: the campaign, the player's
## progress, the store and the audio service. One object instead of globals keeps
## dependencies explicit and lets tests build a context without the scene tree.

signal progress_changed

const PRIVACY_URL := "https://rednexi58.github.io/renkekspresi/privacy.html"
const SUPPORT_URL := "https://rednexi58.github.io/renkekspresi/support.html"

var campaign: Campaign
var progress: PlayerProgress
var commerce: CommerceService
var audio: AudioService
var leaderboards: LeaderboardService
var _last_granted := {}


func save() -> void:
	SaveStore.save(progress)
	progress_changed.emit()


func apply_settings() -> void:
	TranslationServer.set_locale(LanguagePolicy.resolve(progress.language, OS.get_locale()))
	if audio != null:
		audio.apply_settings(progress.music_on, progress.sound_on)


func haptic(milliseconds: int = 18) -> void:
	if progress.haptics_on:
		Input.vibrate_handheld(milliseconds)


## Connects the store: every verified transaction is fulfilled here exactly once, whether
## it came from a purchase button, a renewal or a transaction finished on a later launch.
func attach_commerce(service: CommerceService) -> void:
	commerce = service
	commerce.purchased.connect(_fulfil)


func _fulfil(product_id: String, transaction_id: String) -> void:
	if not progress.mark_delivered(transaction_id):
		return
	_last_granted[product_id] = PurchaseFulfillment.fulfil(product_id, progress, commerce.subscription_expiry(ProductCatalog.VIP))
	save()


## Starts a purchase; `finished` gets the coins granted (or -1 when it did not complete).
## Fulfilment already happened in _fulfil by the time `finished` runs.
func buy(product_id: String, finished: Callable) -> void:
	_last_granted.erase(product_id)
	commerce.purchase(product_id, func(ok: bool) -> void:
		finished.call(int(_last_granted.get(product_id, 0)) if ok else -1))


func language() -> String:
	return TranslationServer.get_locale().substr(0, 2)


static func now() -> int:
	return int(Time.get_unix_time_from_system())


func has_vip() -> bool:
	return progress.has_vip(now())


func is_ad_free() -> bool:
	return progress.is_ad_free(now())

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


## Store purchase with fulfilment and saving in one place; `finished` gets the coins
## granted (or -1 when the purchase did not complete).
func buy(product_id: String, finished: Callable) -> void:
	commerce.purchase(product_id, func(ok: bool) -> void:
		if not ok:
			finished.call(-1)
			return
		var coins := PurchaseFulfillment.fulfil(product_id, progress)
		save()
		finished.call(coins))


func has_vip() -> bool:
	return progress.owns_vip or commerce.has_vip()

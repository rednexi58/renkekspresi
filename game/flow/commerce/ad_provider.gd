class_name AdProvider
extends RefCounted
## The advertising side of CommerceService. This base class is the "no ads" provider:
## no ad is ever ready, so rewarded offers are hidden and interstitials are skipped.

## A full-screen ad started (true) or ended (false); the game silences its music.
signal fullscreen_changed(showing: bool)


func start(_host: Node) -> void:
	pass


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


## True when the consent framework requires an in-app entry point to change privacy
## choices (European users); Settings shows the button only then.
func has_privacy_options() -> bool:
	return false


func show_privacy_options() -> void:
	pass

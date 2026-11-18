class_name AdProvider
extends RefCounted
## The advertising side of CommerceService. This base class is the "no ads" provider:
## this device has no ad network, so rewarded offers are hidden and interstitials skipped.

## A full-screen ad started (true) or ended (false); the game silences its music.
signal fullscreen_changed(showing: bool)


func start(_host: Node) -> void:
	pass


## True when this device can serve rewarded ads at all (an ad network is present).
## Offers are shown whenever this is true, even if no ad has finished loading yet: a
## button that comes and goes with ad availability looks broken to players and to App
## Review, so a tap on a not-yet-loaded ad explains itself instead (see prepare_rewarded).
func offers_rewarded() -> bool:
	return false


## True when a rewarded ad has loaded and can be shown right now.
func can_show_rewarded() -> bool:
	return false


## Asks for a rewarded ad to be loaded now (skipping any back-off wait), because a player
## just asked for one.
func prepare_rewarded() -> void:
	pass


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

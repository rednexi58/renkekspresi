class_name DebugAds
extends AdProvider
## Development ads: rewarded ads are always "watched", interstitials never shown.


func can_show_rewarded() -> bool:
	return true


func show_rewarded(_placement: String, finished: Callable) -> void:
	finished.call(true)

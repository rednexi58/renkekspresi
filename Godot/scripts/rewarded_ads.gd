class_name RewardedAds
extends RefCounted
## Explicit demo provider. Production adapter must call reward only from SDK reward callback.
var provider="simulation"
var state="idle"
var seconds_left=0.0
var session=0
func begin() -> bool:
 if provider!="simulation" or state in ["showing","earned"]:return false
 session+=1;state="showing";seconds_left=3.0;return true
func tick(delta: float) -> void:
 if state!="showing":return
 seconds_left=maxf(0,seconds_left-delta)
 if seconds_left<=0:state="earned"
func cancel() -> void:
 session+=1;state="idle";seconds_left=0
func claim() -> bool:
 if state!="earned":return false
 state="consumed";return true

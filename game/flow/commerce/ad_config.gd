class_name AdConfig
extends RefCounted
## AdMob identifiers for Renk Ekspresi (AdMob app 5181878094). Ad unit ids are not
## secrets: they ship inside every app binary.
##
## Builds exported with the "ads_test" feature request Google's test ads instead, so a
## developer can tap through ads without generating invalid traffic on the real units.

const APP_ID := "ca-app-pub-6370997467091906~5181878094"
const INTERSTITIAL_ID := "ca-app-pub-6370997467091906/4704520894"
const REWARDED_ID := "ca-app-pub-6370997467091906/3025266857"
const TEST_FEATURE := "ads_test"
## Shown by iOS in the App Tracking Transparency prompt (NSUserTrackingUsageDescription).
const TRACKING_TEXT := "Reklamları senin için daha uygun hale getirmek için kullanılır. Used to show you more relevant ads."


static func use_real_ads() -> bool:
	return not OS.has_feature(TEST_FEATURE) and not OS.is_debug_build()

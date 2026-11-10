class_name AdMobAds
extends AdProvider
## Google AdMob through the "AdmobPlugin" iOS plugin (godot-sdk-integrations/godot-admob,
## addon in res://addons/AdmobPlugin, native part fetched by ci/fetch_ios_plugins.sh).
##
## Start-up follows Google's and Apple's required order: ask Google's consent service
## (UMP) whether a consent form is needed and show it (European users), then show
## Apple's tracking prompt (ATT), then initialise the SDK and preload one interstitial
## and one rewarded ad. Ads are only ever shown after they finished loading, and a new
## one is loaded as soon as one is used; failed loads retry with a growing delay.

const SINGLETON := "AdmobPlugin"
const RETRY_SECONDS := [10.0, 30.0, 90.0, 240.0]
## If the tracking prompt never answers (it cannot be shown while the app is inactive),
## initialise anyway after this long; ads are then served without tracking.
const TRACKING_TIMEOUT := 8.0
const REWARD_GRACE := 0.3

var _host: Node
var _admob: Admob
var _initialised := false
var _tracking_asked := false
var _interstitial_ready := false
var _rewarded_ready := false
var _interstitial_retries := 0
var _rewarded_retries := 0
var _interstitial_done := Callable()
var _rewarded_done := Callable()
var _reward_earned := false


static func is_supported() -> bool:
	return Engine.has_singleton(SINGLETON)


func start(host: Node) -> void:
	_host = host
	_admob = Admob.new()
	_admob.name = "Admob"
	_admob.is_real = AdConfig.use_real_ads()
	_admob.ios_real_application_id = AdConfig.APP_ID
	_admob.ios_debug_application_id = AdConfig.APP_ID
	_admob.ios_real_interstitial_id = AdConfig.INTERSTITIAL_ID
	_admob.ios_real_rewarded_id = AdConfig.REWARDED_ID
	_admob.att_enabled = true
	_admob.att_text = AdConfig.TRACKING_TEXT
	# Everyone-friendly ads only: the game is rated for all ages.
	_admob.max_ad_content_rating = AdmobConfig.ContentRating.G
	host.add_child(_admob)
	var deferred := Object.CONNECT_DEFERRED
	_admob.consent_info_updated.connect(_on_consent_info_updated, deferred)
	_admob.consent_info_update_failed.connect(func(_error: FormError) -> void: _ask_tracking(), deferred)
	_admob.consent_form_loaded.connect(func() -> void: _admob.show_consent_form(), deferred)
	_admob.consent_form_failed_to_load.connect(func(_error: FormError) -> void: _ask_tracking(), deferred)
	_admob.consent_form_dismissed.connect(func(_error: FormError) -> void: _ask_tracking(), deferred)
	_admob.tracking_authorization_granted.connect(_initialise, deferred)
	_admob.tracking_authorization_denied.connect(_initialise, deferred)
	_admob.initialization_completed.connect(func(_status: InitializationStatus) -> void: _on_initialised(), deferred)
	_admob.interstitial_ad_loaded.connect(func(_ad: AdInfo, _info: ResponseInfo) -> void: _on_interstitial_loaded(), deferred)
	_admob.interstitial_ad_failed_to_load.connect(func(_ad: AdInfo, _error: LoadAdError) -> void: _retry_interstitial(), deferred)
	_admob.interstitial_ad_failed_to_show_full_screen_content.connect(func(_ad: AdInfo, _error: AdError) -> void: _end_interstitial(), deferred)
	_admob.interstitial_ad_dismissed_full_screen_content.connect(func(_ad: AdInfo) -> void: _end_interstitial(), deferred)
	_admob.rewarded_ad_loaded.connect(func(_ad: AdInfo, _info: ResponseInfo) -> void: _on_rewarded_loaded(), deferred)
	_admob.rewarded_ad_failed_to_load.connect(func(_ad: AdInfo, _error: LoadAdError) -> void: _retry_rewarded(), deferred)
	_admob.rewarded_ad_user_earned_reward.connect(func(_ad: AdInfo, _reward: RewardItem) -> void: _reward_earned = true, deferred)
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_ad: AdInfo, _error: AdError) -> void: _end_rewarded(), deferred)
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_ad: AdInfo) -> void: _end_rewarded(), deferred)
	_admob.update_consent_info()


func can_show_rewarded() -> bool:
	return _rewarded_ready and not _rewarded_done.is_valid()


func show_rewarded(_placement: String, finished: Callable) -> void:
	if not can_show_rewarded():
		finished.call(false)
		return
	_rewarded_ready = false
	_reward_earned = false
	_rewarded_done = finished
	fullscreen_changed.emit(true)
	_admob.show_rewarded_ad()


func can_show_interstitial() -> bool:
	return _interstitial_ready and not _interstitial_done.is_valid()


func show_interstitial(finished: Callable) -> void:
	if not can_show_interstitial():
		finished.call()
		return
	_interstitial_ready = false
	_interstitial_done = finished
	fullscreen_changed.emit(true)
	_admob.show_interstitial_ad()


func has_privacy_options() -> bool:
	return _initialised and _admob.is_consent_form_available()


func show_privacy_options() -> void:
	if has_privacy_options():
		_admob.load_consent_form()


# --- Start-up sequence ----------------------------------------------------------------

func _on_consent_info_updated() -> void:
	var consent := _admob.get_consent_status()
	if consent != null and consent.status == UserConsent.Status.REQUIRED and _admob.is_consent_form_available():
		_admob.load_consent_form()
	else:
		_ask_tracking()


func _ask_tracking() -> void:
	if _tracking_asked:
		return
	_tracking_asked = true
	_admob.request_tracking_authorization()
	_host.get_tree().create_timer(TRACKING_TIMEOUT).timeout.connect(_initialise)


func _initialise() -> void:
	if _initialised:
		return
	_initialised = true
	_admob.initialize()


func _on_initialised() -> void:
	_admob.load_interstitial_ad()
	_admob.load_rewarded_ad()


# --- Loading --------------------------------------------------------------------------

func _on_interstitial_loaded() -> void:
	_interstitial_ready = true
	_interstitial_retries = 0


func _on_rewarded_loaded() -> void:
	_rewarded_ready = true
	_rewarded_retries = 0


func _retry_interstitial() -> void:
	var delay: float = RETRY_SECONDS[mini(_interstitial_retries, RETRY_SECONDS.size() - 1)]
	_interstitial_retries += 1
	_host.get_tree().create_timer(delay).timeout.connect(func() -> void: _admob.load_interstitial_ad())


func _retry_rewarded() -> void:
	var delay: float = RETRY_SECONDS[mini(_rewarded_retries, RETRY_SECONDS.size() - 1)]
	_rewarded_retries += 1
	_host.get_tree().create_timer(delay).timeout.connect(func() -> void: _admob.load_rewarded_ad())


# --- Showing --------------------------------------------------------------------------

func _end_interstitial() -> void:
	var finished := _interstitial_done
	_interstitial_done = Callable()
	fullscreen_changed.emit(false)
	_admob.load_interstitial_ad()
	if finished.is_valid():
		finished.call()


## The SDK reports the reward and the closing separately and their order is not
## guaranteed, so the outcome is decided REWARD_GRACE seconds after the ad closes.
func _end_rewarded() -> void:
	var finished := _rewarded_done
	if not finished.is_valid():
		return
	fullscreen_changed.emit(false)
	_admob.load_rewarded_ad()
	_host.get_tree().create_timer(REWARD_GRACE).timeout.connect(func() -> void:
		_rewarded_done = Callable()
		var earned := _reward_earned
		_reward_earned = false
		finished.call(earned))

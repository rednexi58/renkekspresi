class_name LanguagePolicy
extends RefCounted
## Decides the interface language. A language the player chose always wins; a fresh
## install follows the device locale, defaulting to English outside Turkish devices so
## App Review and international players never meet an unreadable first screen.

const TURKISH := "tr"
const ENGLISH := "en"


static func is_supported(language: String) -> bool:
	return language == TURKISH or language == ENGLISH


static func resolve(saved: String, device_locale: String) -> String:
	if is_supported(saved):
		return saved
	return TURKISH if device_locale.to_lower().begins_with("tr") else ENGLISH

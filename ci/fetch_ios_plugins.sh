#!/bin/bash
# Downloads the native iOS plugins into game/ios/ before the Xcode export.
# The binaries (about 45 MB of frameworks) are not kept in git; each archive is pinned
# by URL and SHA-256, so every build uses exactly the reviewed version.
#   - AdMob: godot-sdk-integrations/godot-admob v6.0 (built for Godot 4.6); its GDScript
#     addon is versioned in game/addons/AdmobPlugin and must stay on the same version.
#   - In-app purchase: hrk4649/godot_ios_plugin_iap 0.3.0 (StoreKit 2, Godot 4.6).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() {
	local url="$1" sum="$2" out="$3"
	curl -fL --retry 3 --retry-delay 5 "$url" -o "$out"
	echo "$sum  $out" | shasum -a 256 -c -
}

fetch "https://github.com/godot-sdk-integrations/godot-admob/releases/download/v6.0/AdmobPlugin-iOS-v6.0.zip" \
	"0391e188ab662fd5c8c138119fdae87e315f1443730b7bb8e3e20986fd22f9b4" "$work/admob.zip"
fetch "https://github.com/hrk4649/godot_ios_plugin_iap/releases/download/0.3.0/ios-in-app-purchase-v0.3.0.zip" \
	"fb1ea1cb98c31b216a3599c035f0c3668e4b2ae0217d9cd9bc7c8062579920a1" "$work/iap.zip"

rm -rf "$root/game/ios"
mkdir -p "$root/game/ios"
unzip -q "$work/admob.zip" 'ios/*' -d "$root/game"
unzip -q "$work/iap.zip" 'ios/*' -d "$root/game"
test -f "$root/game/ios/plugins/AdmobPlugin.gdip"
test -d "$root/game/ios/framework/GoogleMobileAds.xcframework"
test -f "$root/game/ios/plugins/ios-in-app-purchase/ios-in-app-purchase.gdip"
echo "iOS plugins ready:"
find "$root/game/ios" -maxdepth 3 \( -name '*.gdip' -o -name '*.xcframework' \) | sed "s|$root/||"

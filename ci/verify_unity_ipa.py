"""Fail before uploading if the supplied Unity artifact is not this signed iOS app."""
import plistlib
import sys
import zipfile

EXPECTED_BUNDLE = "com.bedogames.renkekspresi"
EXPECTED_MIN_VERSION = (0, 40, 0)


def main(path):
    if not zipfile.is_zipfile(path):
        raise SystemExit("The downloaded artifact is not an IPA ZIP (check the link and authentication).")
    with zipfile.ZipFile(path) as ipa:
        names = ipa.namelist()
        apps = {p.split("/")[1] for p in names if p.startswith("Payload/") and ".app/Info.plist" in p and p.count("/") == 2}
        if len(apps) != 1:
            raise SystemExit("Expected exactly one Payload/*.app/Info.plist in the IPA.")
        app = apps.pop()
        prefix = f"Payload/{app}/"
        info = plistlib.loads(ipa.read(prefix + "Info.plist"))
        bundle = info.get("CFBundleIdentifier")
        version = str(info.get("CFBundleShortVersionString", ""))
        build = str(info.get("CFBundleVersion", ""))
        if bundle != EXPECTED_BUNDLE:
            raise SystemExit(f"Wrong bundle ID: {bundle!r}; expected {EXPECTED_BUNDLE}.")
        try:
            parsed = tuple(int(part) for part in version.split("."))
        except ValueError:
            raise SystemExit(f"Invalid version: {version!r}.")
        if parsed < EXPECTED_MIN_VERSION:
            raise SystemExit(f"Old version {version}; expected Unity 0.40.0 or newer.")
        if not build or not build.isdecimal() or int(build) < 1:
            raise SystemExit(f"Invalid CFBundleVersion: {build!r}.")
        if prefix + "_CodeSignature/CodeResources" not in names:
            raise SystemExit("IPA has no app code signature; sign it for App Store distribution first.")
        print(f"IPA metadata checked: {bundle} version {version} ({build}); code-signature files present.")
        print("The build number must exceed the last uploaded build of this version in App Store Connect.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 ci/verify_unity_ipa.py path/to/game.ipa")
    main(sys.argv[1])

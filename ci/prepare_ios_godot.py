"""Writes CI values into game/export_presets.cfg before the iOS export.

Inputs (environment):
  APPLE_TEAM_ID   10-character Apple developer team id (Codemagic group renk_ekspresi_ios)
  BUILD_NUMBER_IOS  integer CFBundleVersion, higher than every build already uploaded
  APP_VERSION     marketing version (CFBundleShortVersionString), e.g. 1.1.0
  PLAYTEST        "1" for internal TestFlight playtests: adds the "playtest" export
                  feature, which enables instant test grants for VIP/rewarded slots.
                  Must be unset for App Store submissions.
"""
import os
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
preset = root / "game" / "export_presets.cfg"

team = os.environ.get("APPLE_TEAM_ID", "")
build = os.environ.get("BUILD_NUMBER_IOS", "")
version = os.environ.get("APP_VERSION", "")
if not re.fullmatch(r"[A-Z0-9]{10}", team):
    raise SystemExit("APPLE_TEAM_ID must be the 10-character team id")
if not build.isdigit():
    raise SystemExit("BUILD_NUMBER_IOS must be an integer")
if not re.fullmatch(r"\d+\.\d+(\.\d+)?", version):
    raise SystemExit("APP_VERSION must look like 1.1.0")

text = preset.read_text()
values = {
    "application/app_store_team_id": f'"{team}"',
    "application/version": f'"{build}"',
    "application/short_version": f'"{version}"',
}
for key, value in values.items():
    pattern = r"^" + re.escape(key) + r"=.*$"
    if not re.search(pattern, text, re.M):
        raise SystemExit(f"Missing preset option {key}")
    text = re.sub(pattern, f"{key}={value}", text, flags=re.M)
playtest = os.environ.get("PLAYTEST", "") == "1"
text = re.sub(r'^custom_features=.*$', 'custom_features="playtest"' if playtest else 'custom_features=""', text, flags=re.M)
preset.write_text(text)
print(f"iOS preset prepared: version {version} ({build}), team {team}, playtest={playtest}")

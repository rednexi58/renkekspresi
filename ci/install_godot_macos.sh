#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == "Darwin" ]] || { echo 'macOS with Xcode is required'; exit 1; }
version=4.5.1
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
mkdir -p .ci-tools
curl -fL --retry 2 "$base/Godot_v${version}-stable_macos.universal.zip" -o .ci-tools/godot.zip
unzip -qo .ci-tools/godot.zip -d .ci-tools
curl -fL --retry 2 "$base/Godot_v${version}-stable_export_templates.tpz" -o .ci-tools/templates.zip
python3 - <<'PY'
from zipfile import ZipFile
from pathlib import Path
# Extract only iOS templates, preserving the official Godot file names.
target=Path.home()/'Library/Application Support/Godot/export_templates/4.5.1.stable'
target.mkdir(parents=True,exist_ok=True)
with ZipFile('.ci-tools/templates.zip') as z:
    members=[n for n in z.namelist() if n.endswith('/ios.zip') or n.endswith('/version.txt')]
    assert any(n.endswith('/ios.zip') for n in members), 'Missing iOS template'
    for name in members:(target/Path(name).name).write_bytes(z.read(name))
PY
.ci-tools/Godot.app/Contents/MacOS/Godot --version
xcodebuild -version

"""Prepare an explicitly labelled playtest build. Run on the CI checkout only."""
import os,re,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
team=os.environ.get('APPLE_TEAM_ID','')
if not re.fullmatch(r'[A-Z0-9]{10}',team):
    raise SystemExit('Set APPLE_TEAM_ID (10 letters/numbers) in Codemagic renk_ekspresi_ios group.')
build=os.environ.get('RENK_EKSPRESI_BUILD_NUMBER','')
if not build.isdigit() or int(build)<27:
    raise SystemExit('Set RENK_EKSPRESI_BUILD_NUMBER to an unused integer >=27; increase for every upload.')
p=root/'Godot/export_presets.cfg';s=p.read_text();a=s.index('[preset.4.options]')
prefix,ios=s[:a],s[a:]
ios=re.sub(r'application/app_store_team_id=".*?"',f'application/app_store_team_id="{team}"',ios)
ios=re.sub(r'application/version=".*?"',f'application/version="{build}"',ios)
settings={
 'application/export_project_only':'true',
 'application/min_ios_version':'"15.0"',
 'application/targeted_device_family':'0',
 'icons/icon_1024x1024':'"res://assets/app-icon-1024.png"',
 'icons/app_store_1024x1024':'"res://assets/app-icon-1024.png"'
}
for key,value in settings.items():
 pattern=r'^'+re.escape(key)+r'=.*$'
 if re.search(pattern,ios,re.M):ios=re.sub(pattern,key+'='+value,ios,flags=re.M)
 else:ios+='\n'+key+'='+value+'\n'
p.write_text(prefix+ios)
config=json.loads((root/'Godot/data/build_config.json').read_text())
# Intentional beta: commerce stays explicitly simulated, never claims a real transaction.
assert config['test_tools'] and config['ads_provider']=='simulation' and config['purchases_provider']=='simulation'
print('Prepared native PLAYTEST only. Real billing, ads and online rankings are not connected.')

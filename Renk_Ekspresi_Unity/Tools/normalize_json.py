"""Preserve values while emitting whole-number JSON tokens for Unity integer fields."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def normalize(value):
    if isinstance(value,dict): return {k:normalize(v) for k,v in value.items()}
    if isinstance(value,list): return [normalize(v) for v in value]
    if isinstance(value,float) and value.is_integer(): return int(value)
    return value
for relative in ['Assets/RenkEkspresi/Resources/Data/campaign.json','Verification/godot_reference.json','Verification/godot_edge_reference.json']:
    path=root/relative
    path.write_text(json.dumps(normalize(json.loads(path.read_text())),ensure_ascii=False,separators=(',',':')))

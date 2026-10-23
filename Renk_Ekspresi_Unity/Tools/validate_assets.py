"""Validate transferred content; does not replace Unity import/render/device testing."""
from pathlib import Path
import json,math,hashlib
root=Path(__file__).resolve().parents[1]
resources=root/'Assets/RenkEkspresi/Resources'
levels=json.loads((resources/'Data/campaign.json').read_text())['levels']
assert len(levels)==100
for i,level in enumerate(levels,1):
    assert level['id']==i and level['mode']=='rescue' and level['match_scope']=='zone'
    cards=level['parking'];assert len(cards)==level['rows']*level['cols']
    assert [c['id'] for c in cards]==list(range(len(cards)))
    for color in range(5):assert sum(c['capacity'] for c in cards if c['color']==color)==level['train'].count(color)
    for c in cards:assert c['requires'] in range(-1,len(cards)) and (c['dx'] or c['dz'])
    routes=json.loads((resources/f'Data/route_{i:03}.json').read_text())['routes']
    assert len(routes)==level.get('train_count',1)
    for route in routes:
        assert abs(route['length']-level['track_length'])<.001 and len(route['points'])>10
        assert all(math.isfinite(v) for point in route['points'] for v in point.values())
models=sorted((resources/'Models').glob('*.json'));assert len(models)==6
triangles=0
for model in models:
    data=json.loads(model.read_text());assert data['parts']
    for part in data['parts']:
        assert len(part['vertices'])==len(part['normals'])>0
        assert len(part['triangles'])%3==0
        assert all(0<=index<len(part['vertices']) for index in part['triangles'])
        assert all(math.isfinite(v) for point in part['vertices']+part['normals'] for v in point.values())
        triangles+=len(part['triangles'])//3
for f in ['Audio/calm_journey.ogg','Audio/steam_chuffs.ogg','Audio/tap.wav','Audio/match.wav','Audio/fill.wav','Audio/win.wav','Audio/lose.wav','UI/Interface.ttf','UI/Interface-Bold.ttf','UI/freeze.png','UI/blast.png','UI/recall.png','PaintedTrain.shader','Environment.shader']:
    assert (resources/f).stat().st_size>0,f
assert 'e8cb5d857f014370898200d621246b63' in (root/'Assets/RenkEkspresi/Scenes/Main.unity').read_text()
print(f'PASS: 100 valid campaigns and routes; 6 valid train meshes ({triangles:,} triangles across all six assets); all referenced fonts, icons, audio and shaders present.')

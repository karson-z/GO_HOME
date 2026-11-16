"""Refresh hashes after all source assets have been regenerated."""
from pathlib import Path
import hashlib, json
root = Path(__file__).resolve().parents[1] / 'go_home_mobile/assets'
target = root / 'data/asset_manifest.json'
records = [
    {'path': str(p.relative_to(root)), 'bytes': p.stat().st_size,
     'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in sorted(root.rglob('*')) if p.is_file() and p != target
]
target.write_text(json.dumps(records, indent=2) + '\n')
print(f'Recorded {len(records)} assets; manifest excludes its own hash.')

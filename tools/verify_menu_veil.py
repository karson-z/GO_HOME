"""Check the native opaque screenshot against the shipped ZN CSS colors.

Samples exclude the title's final fade at the upper right. This checks the veil
only, not whole-scene pixel parity. Requires the pause regression screenshots.
"""
import json
import math
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
image = Image.open(root / 'artifacts/pause-native/continue-fog-hold.png').convert('RGB')
fog = [89, 93, 107]  # YN #595d6b


def mix(a, b, k):
    return [x + (y - x) * k for x, y in zip(a, b)]


top = mix([223, 228, 238], fog, .84)
bottom = mix([28, 30, 40], fog, .82)
light = mix([255, 246, 232], fog, .88)
errors = []
for j in range(2, 18):
    for i in range(1, 20):
        u, v = i / 20, j / 20
        if u > .6 and v < .25:
            continue
        bed = mix(top, fog, v / .48) if v < .48 else mix(fog, bottom, (v - .48) / .52)
        radial = max(0, 1 - math.hypot((u - .5) / .7, (v - .62) / .55) / .7)
        expected = [round(c) for c in mix(bed, light, radial)]
        actual = image.getpixel((int(u * image.width), int(v * image.height)))
        errors.append(max(abs(x - y) for x, y in zip(actual, expected)))
report = {
    'source': 'sj/ZN/YN, CSS color-mix(in srgb), radial over vertical gradient',
    'screenshot': 'pause-native/continue-fog-hold.png',
    'samplePoints': len(errors),
    'maxSrgbError255': max(errors),
    'tolerance255': 2,
    'passed': max(errors) <= 2,
    'scope': 'Veil colors only; excludes upper-right title fade',
}
(root / 'artifacts/menu-veil-verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
assert report['passed'], report

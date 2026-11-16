"""Resize the original app icon for iOS/Android. Never compose replacement art."""
from pathlib import Path, PurePosixPath
from io import BytesIO
import argparse
import hashlib
import json
import plistlib
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'go_home_mobile'
CACHE = APP / 'resources/original_app_icon'


def mac_icon_path(info, resource_root):
    name = info.get('CFBundleIconFile')
    if not name:
        raise ValueError('The original app does not declare CFBundleIconFile.')
    name = PurePosixPath(name)
    if name.is_absolute() or '..' in name.parts:
        raise ValueError('Invalid CFBundleIconFile path.')
    if not name.suffix:
        name = name.with_suffix('.icns')
    return resource_root / name


def read_source(path):
    if path.suffix.lower() == '.zip':
        with zipfile.ZipFile(path) as archive:
            infos = [n for n in archive.namelist()
                     if n.endswith('.app/Contents/Info.plist')
                     and '/Frameworks/' not in n and not n.startswith('__MACOSX/')]
            if len(infos) != 1:
                raise ValueError(f'Expected one original app, found {len(infos)}.')
            info_path = PurePosixPath(infos[0])
            info = plistlib.loads(archive.read(str(info_path)))
            icon = mac_icon_path(info, info_path.parent / 'Resources')
            return archive.read(str(icon)), icon.suffix, f'{path.name}:{icon}'
    if path.is_dir() and path.suffix.lower() == '.app':
        info = plistlib.loads((path / 'Contents/Info.plist').read_bytes())
        icon = Path(mac_icon_path(info, path / 'Contents/Resources'))
        return icon.read_bytes(), icon.suffix, f'{path.name}:{icon.relative_to(path)}'
    if path.suffix.lower() not in {'.png', '.icns', '.ico'}:
        raise ValueError('Use the original .zip, .app, .icns, .ico or .png.')
    return path.read_bytes(), path.suffix.lower(), path.name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path,
                        help='Original macOS ZIP/app or original icon file.')
    args = parser.parse_args()
    if args.source:
        raw, extension, origin = read_source(args.source.expanduser().resolve())
    else:
        record = CACHE / 'origin.json'
        if not record.is_file():
            parser.error('Original app icon is missing. Pass --source with the original ZIP/app/icon; custom icon generation is disabled.')
        metadata = json.loads(record.read_text())
        raw = (CACHE / metadata['file']).read_bytes()
        if hashlib.sha256(raw).hexdigest() != metadata['sha256']:
            raise ValueError('Cached original icon hash does not match origin.json.')
        extension, origin = Path(metadata['file']).suffix, metadata['origin']

    # Decode the original highest-resolution representation; retain its colors,
    # composition and alpha. Only the platform-required dimensions are changed.
    with Image.open(BytesIO(raw)) as image:
        image.load()
        master = image.convert('RGBA')
    if master.width != master.height:
        raise ValueError('Original icon is not square; refusing to crop/redraw it.')
    output = APP / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    targets = {}
    for item in json.loads((output / 'Contents.json').read_text())['images']:
        size = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
        targets[output / item['filename']] = size
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        targets[APP / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'] = size
    for target, size in targets.items():
        master.resize((size, size), Image.Resampling.LANCZOS).save(target)
    CACHE.mkdir(parents=True, exist_ok=True)
    source_name = f'source{extension}'
    (CACHE / source_name).write_bytes(raw)
    metadata = {'file': source_name, 'origin': origin,
                'sha256': hashlib.sha256(raw).hexdigest(),
                'sourcePixels': [master.width, master.height],
                'operation': 'Original pixels; size conversion only. No composition, crop, recolor or replacement art.'}
    (CACHE / 'origin.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    (ROOT / 'artifacts').mkdir(exist_ok=True)
    master.save(ROOT / 'artifacts/app-icon.png')
    print(f'Imported original app icon: {origin}; {len(targets)} platform sizes.')


if __name__ == '__main__':
    main()

"""Package the existing GLBs into a spaced, independently selectable gallery.

Only the preview package is changed; source models and game data stay intact.
"""
import copy
import itertools
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts' / 'threejs-editor'
FIELDS = ('nodes', 'meshes', 'accessors', 'bufferViews', 'materials',
          'textures', 'images', 'samplers')


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


IDENTITY = [[int(i == j) for j in range(4)] for i in range(4)]


def transform(node):
    if 'matrix' in node:
        return [[node['matrix'][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    sx, sy, sz = node.get('scale', [1, 1, 1])
    tx, ty, tz = node.get('translation', [0, 0, 0])
    return [[(1-2*y*y-2*z*z)*sx, (2*x*y-2*z*w)*sy, (2*x*z+2*y*w)*sz, tx],
            [(2*x*y+2*z*w)*sx, (1-2*x*x-2*z*z)*sy, (2*y*z-2*x*w)*sz, ty],
            [(2*x*z-2*y*w)*sx, (2*y*z+2*x*w)*sy, (1-2*x*x-2*y*y)*sz, tz],
            [0, 0, 0, 1]]


def bounds(doc):
    points = []

    def visit(index, parent):
        node = doc['nodes'][index]
        matrix = multiply(parent, transform(node))
        if 'mesh' in node:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                accessor = doc['accessors'][primitive['attributes']['POSITION']]
                for point in itertools.product(*zip(accessor['min'], accessor['max'])):
                    points.append([sum(matrix[i][k] * (*point, 1)[k] for k in range(4)) for i in range(3)])
        for child in node.get('children', []):
            visit(child, matrix)

    for root in doc['scenes'][doc.get('scene', 0)]['nodes']:
        visit(root, IDENTITY)
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    result = {'asset': {'version': '2.0', 'generator': 'Go Home model gallery'},
              'scene': 0, 'scenes': [{'name': 'Go Home — 88 models', 'nodes': [0]}],
              **{field: [] for field in FIELDS}}
    result['nodes'].append({'name': 'Go Home · Model Gallery (88 GLBs)', 'children': []})
    binary = bytearray()
    catalog = []
    extensions_used, extensions_required = set(), set()
    # Put individually textured props at the front, then complete scene fragments.
    paths = sorted((ROOT / 'go_home_mobile/assets/models').glob('*.glb'),
                   key=lambda p: (not p.name.startswith('models_PROP_'), p.name))
    fallback = len(result['materials'])
    result['materials'].append({'name': 'Preview · untextured game geometry',
                               'pbrMetallicRoughness': {'baseColorFactor': [.39, .55, .48, 1],
                                                       'metallicFactor': 0, 'roughnessFactor': .9},
                               'doubleSided': True})
    for number, path in enumerate(paths):
        raw = path.read_bytes()
        json_length = struct.unpack_from('<I', raw, 12)[0]
        doc = json.loads(raw[20:20 + json_length])
        assert not doc.get('skins') and not doc.get('animations')
        # Mobile geometry exports retain stale image references after stripping
        # image buffer views. They are not standalone textured GLBs. Give the
        # preview valid, explicitly labelled materials instead of broken maps.
        def valid_image(image):
            view_index = image.get('bufferView', -1)
            views = doc.get('bufferViews', [])
            if not 0 <= view_index < len(views):
                return False
            start = 28 + json_length + views[view_index].get('byteOffset', 0)
            return raw[start:start + 12].startswith((b'RIFF', b'\x89PNG', b'\xff\xd8'))
        invalid_images = any(not valid_image(image) for image in doc.get('images', []))
        if invalid_images or not doc.get('materials'):
            lower = path.stem.lower()
            color = ([.29, .43, .32, 1] if any(word in lower for word in ['tree', 'pine', 'fir', 'willow', 'oak', 'larch', 'sapling'])
                     else [.47, .51, .55, 1] if any(word in lower for word in ['rock', 'cliff', 'boulder', 'peak', 'alpine', 'ridge', 'mount', 'cave', 'stone'])
                     else [.43, .53, .31, 1] if any(word in lower for word in ['reeds', 'sedge', 'cattail'])
                     else [.48, .34, .23, 1] if any(word in lower for word in ['trunk', 'log', 'snag', 'stump', 'dead', 'root'])
                     else [.39, .55, .48, 1])
            doc['materials'] = [{'name': 'Preview color · ' + path.stem,
                                  'pbrMetallicRoughness': {'baseColorFactor': color, 'metallicFactor': 0, 'roughnessFactor': .88},
                                  'doubleSided': True}]
            for mesh in doc['meshes']:
                for primitive in mesh['primitives']:
                    primitive['material'] = 0
            for field in ['images', 'textures', 'samplers', 'extensionsUsed', 'extensionsRequired']:
                doc.pop(field, None)
        low, high = bounds(doc)
        offsets = {field: len(result[field]) for field in FIELDS}
        chunk = copy.deepcopy(doc)
        bin_start = 20 + json_length
        bin_length = struct.unpack_from('<I', raw, bin_start)[0]
        payload = raw[bin_start + 8:bin_start + 8 + bin_length]
        binary.extend(b'\0' * (-len(binary) % 4))
        byte_offset = len(binary)
        binary.extend(payload)
        for view in chunk.get('bufferViews', []):
            assert view.get('buffer', 0) == 0
            view['buffer'] = 0
            view['byteOffset'] = view.get('byteOffset', 0) + byte_offset
        for accessor in chunk.get('accessors', []):
            accessor['bufferView'] += offsets['bufferViews']
        for node in chunk.get('nodes', []):
            if 'mesh' in node:
                node['mesh'] += offsets['meshes']
            if 'children' in node:
                node['children'] = [v + offsets['nodes'] for v in node['children']]
        for mesh in chunk.get('meshes', []):
            for primitive in mesh['primitives']:
                primitive['attributes'] = {k: v + offsets['accessors'] for k, v in primitive['attributes'].items()}
                if 'indices' in primitive:
                    primitive['indices'] += offsets['accessors']
                primitive['material'] = primitive['material'] + offsets['materials'] if 'material' in primitive else fallback
        def textures(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key.endswith('Texture') and isinstance(child, dict) and 'index' in child:
                        child['index'] += offsets['textures']
                    else:
                        textures(child)
            elif isinstance(value, list):
                for child in value:
                    textures(child)
        textures(chunk.get('materials', []))
        for texture in chunk.get('textures', []):
            if 'sampler' in texture:
                texture['sampler'] += offsets['samplers']
            if 'source' in texture:
                texture['source'] += offsets['images']
            for extension in texture.get('extensions', {}).values():
                if 'source' in extension:
                    extension['source'] += offsets['images']
        for image in chunk.get('images', []):
            image['bufferView'] += offsets['bufferViews']
        for field in FIELDS:
            result[field].extend(chunk.get(field, []))
        scale = 7 / max(max(high[i] - low[i] for i in range(3)), .001)
        center = [(low[i] + high[i]) / 2 for i in range(3)]
        col, row = number % 11, number // 11
        name = f'{number + 1:02d} · {path.stem.removeprefix("models_PROP_").removesuffix("_scene")}'
        index = len(result['nodes'])
        result['nodes'].append({'name': name, 'children': [i + offsets['nodes'] for i in doc['scenes'][doc.get('scene', 0)]['nodes']],
                                'scale': [scale] * 3,
                                'translation': [(col - 5) * 10 - center[0] * scale,
                                                -low[1] * scale,
                                                -row * 11 - center[2] * scale],
                                'extras': {'source': path.name, 'previewScale': scale}})
        result['nodes'][0]['children'].append(index)
        catalog.append({'number': number + 1, 'name': name, 'source': path.name,
                        'row': row + 1, 'column': col + 1, 'previewScale': scale})
        extensions_used.update(doc.get('extensionsUsed', []))
        extensions_required.update(doc.get('extensionsRequired', []))
    result['buffers'] = [{'byteLength': len(binary)}]
    if extensions_used:
        result['extensionsUsed'] = sorted(extensions_used)
    if extensions_required:
        result['extensionsRequired'] = sorted(extensions_required)
    encoded = json.dumps(result, ensure_ascii=False, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary.extend(b'\0' * (-len(binary) % 4))
    output = struct.pack('<III', 0x46546c67, 2, 28 + len(encoded) + len(binary))
    output += struct.pack('<II', len(encoded), 0x4e4f534a) + encoded
    output += struct.pack('<II', len(binary), 0x004e4942) + binary
    target = OUT / 'go-home-model-gallery.glb'
    target.write_bytes(output)
    (OUT / 'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2))
    print(f'{target}: {len(paths)} models, {len(result["meshes"])} meshes, {len(output) / 1024**2:.1f} MiB')


if __name__ == '__main__':
    main()

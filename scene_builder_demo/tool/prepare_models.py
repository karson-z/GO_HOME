"""Create standalone geometry-only GLBs from the user's Go Home exports.

Run with: python3 tool/prepare_models.py /path/to/go_home_mobile/assets/models
Original GLBs contain stale image references. Preview materials are supplied by
the Flutter renderer; original files are never changed.
"""
import argparse
import itertools
import json
from pathlib import Path
import struct

FILES = {
    'fir': 'models_PROP_W6_TreeFir.glb',
    'willow': 'models_PROP_W6_TreeWillow.glb',
    'rock': 'models_PROP_W6_ShoreBoulder.glb',
    'grass': 'models_PROP_W6_FeatherReeds.glb',
    'log': 'hh_log_log_scene.glb',
    'mountain': 'models_PROP_ending_alpine_a.glb',
    'gate': 'stone-gate_scene.glb',
}


def matrix(node):
    if 'matrix' in node:
        return [[node['matrix'][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = node.get('rotation', [0, 0, 0, 1])
    a, b, c = node.get('scale', [1, 1, 1])
    tx, ty, tz = node.get('translation', [0, 0, 0])
    return [[(1-2*y*y-2*z*z)*a, (2*x*y-2*z*w)*b, (2*x*z+2*y*w)*c, tx],
            [(2*x*y+2*z*w)*a, (1-2*x*x-2*z*z)*b, (2*y*z-2*x*w)*c, ty],
            [(2*x*z-2*y*w)*a, (2*y*z+2*x*w)*b, (1-2*x*x-2*y*y)*c, tz],
            [0, 0, 0, 1]]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def convert(source, destination):
    data = source.read_bytes()
    length = struct.unpack_from('<I', data, 12)[0]
    doc = json.loads(data[20:20+length])
    bin_start = 28 + length
    binary = data[bin_start:]
    doc.pop('materials', None)
    for field in ['images', 'textures', 'samplers', 'extensionsUsed', 'extensionsRequired']:
        doc.pop(field, None)
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            primitive.pop('material', None)
    points = []

    def visit(index, parent):
        node = doc['nodes'][index]
        world = multiply(parent, matrix(node))
        if 'mesh' in node:
            for primitive in doc['meshes'][node['mesh']]['primitives']:
                accessor = doc['accessors'][primitive['attributes']['POSITION']]
                for p in itertools.product(*zip(accessor['min'], accessor['max'])):
                    points.append([sum(world[i][k] * (*p, 1)[k] for k in range(4)) for i in range(3)])
        for child in node.get('children', []):
            visit(child, world)

    scene = doc['scenes'][doc.get('scene', 0)]
    for root in scene['nodes']:
        visit(root, [[int(i == j) for j in range(4)] for i in range(4)])
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    scale = 1 / max(hi[i] - lo[i] for i in range(3))
    center_x, center_z = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    root = len(doc['nodes'])
    doc['nodes'].append({'name': destination.stem, 'children': scene['nodes'],
                         'scale': [scale] * 3,
                         'translation': [-center_x * scale, -lo[1] * scale, -center_z * scale]})
    scene['nodes'] = [root]
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    output = struct.pack('<III', 0x46546c67, 2, 28 + len(encoded) + len(binary))
    output += struct.pack('<II', len(encoded), 0x4e4f534a) + encoded
    output += struct.pack('<II', len(binary), 0x004e4942) + binary
    destination.write_bytes(output)
    print(destination.name, f'{len(output) / 1024:.0f} KiB')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    target = Path(__file__).resolve().parents[1] / 'assets/models'
    target.mkdir(parents=True, exist_ok=True)
    for name, original in FILES.items():
        convert(args.source / original, target / f'{name}.glb')

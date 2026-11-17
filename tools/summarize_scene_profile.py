"""Summarize the saved native seam benchmark without mistaking GL submission for GPU time."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
args = parser.parse_args()
data = json.loads(args.report.read_text())
frames = data['frames']
events = data.get('streamEvents', [])

def stats(rows):
    if not rows:
        return {'frames': 0}
    times = sorted(f['intervalUs'] / 1000 for f in rows)
    def p(q):
        return times[min(len(times) - 1, int(len(times) * q))]
    def component(key):
        values = sorted(f[key] / 1000 for f in rows)
        return {'meanMs': sum(values) / len(values),
                'p95Ms': values[min(len(values) - 1, int(len(values) * .95))],
                'maxMs': values[-1]}
    return {'frames': len(times), 'fps': 1000 * len(times) / sum(times),
            'p50Ms': p(.5), 'p95Ms': p(.95), 'p99Ms': p(.99), 'maxMs': times[-1],
            'over20Ms': sum(t > 20 for t in times),
            'over34Ms': sum(t > 34 for t in times),
            'over50Ms': sum(t > 50 for t in times),
            'update': component('updateUs'),
            'renderSubmit': component('renderSubmitUs')}

near = [f for f in frames if abs(f['x'] - float(f['window'].split(':')[1])) <= 2]
far = [f for f in frames if abs(f['x'] - float(f['window'].split(':')[1])) >= 5]
worst = []
for f in sorted(frames, key=lambda x: x['intervalUs'], reverse=True)[:20]:
    related = [e for e in events if e['window'] == f['window'] and abs(e['tUs'] - f['tUs']) < 250000]
    worst.append({**f, 'streamEventsWithin250ms': related})
result = {'buildMode': data['buildMode'], 'baseline': data['baseline'],
          'completedWindows': data.get('completedWindows'),
          'expectedWindows': data.get('expectedWindows'),
          'quality': data['quality'], 'resolution': [data['physicalWidth'], data['physicalHeight']],
          'refreshRate': data['refreshRate'], 'overall': stats(frames), 'within2UnitsOfSeam': stats(near),
          'atLeast5UnitsFromSeam': stats(far), 'windows': data['summary'], 'worstFrames': worst,
          'streamEvents': len(events),
          'limits': 'Scripted travel with live game/audio/rendering; preparation excluded. GL submission CPU time is not GPU duration. Frame intervals include presentation and scheduling.'}
args.report.with_name('summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
lines = ['# Android Profile 区域切换测试', '',
         f"构建：{data['buildMode']}；画质：{data['quality']}；场景分辨率：{data['physicalWidth']} × {data['physicalHeight']}；显示刷新率：{data['refreshRate']:.1f} Hz。", '',
         f"完整基准：{'是' if data['baseline'] else '否'}；完成区间：{data.get('completedWindows', '未知')}/{data.get('expectedWindows', '未知')}。", '',
         '| 范围 | 帧数 | 平均 FPS | P50 ms | P95 ms | P99 ms | 最长 ms | >34 ms |',
         '|---|---:|---:|---:|---:|---:|---:|---:|']
for name, s in [('全部', result['overall']), ('距边界 ≤2 单位', result['within2UnitsOfSeam']), ('距边界 ≥5 单位', result['atLeast5UnitsFromSeam'])]:
    if s['frames']:
        lines.append(f"| {name} | {s['frames']} | {s['fps']:.1f} | {s['p50Ms']:.2f} | {s['p95Ms']:.2f} | {s['p99Ms']:.2f} | {s['maxMs']:.2f} | {s['over34Ms']} |")
lines += ['', '| 阶段 | 更新均值 ms | 更新 P95 ms | GL 提交均值 ms | GL 提交 P95 ms |',
          '|---|---:|---:|---:|---:|']
for name, s in [('全部', result['overall']), ('距边界 ≤2 单位', result['within2UnitsOfSeam']), ('距边界 ≥5 单位', result['atLeast5UnitsFromSeam'])]:
    if s['frames']:
        lines.append(f"| {name} | {s['update']['meanMs']:.2f} | {s['update']['p95Ms']:.2f} | {s['renderSubmit']['meanMs']:.2f} | {s['renderSubmit']['p95Ms']:.2f} |")
lines += ['', '| 区间 | 帧数 | P95 ms | 最长 ms | 更新/渲染统计 |', '|---|---:|---:|---:|---|']
for s in data['summary']:
    lines.append(f"| {s['window']} | {s['frames']} | {s['p95Ms']:.2f} | {s['maxMs']:.2f} | 渲染提交 P95 {s['renderP95Ms']:.2f} ms |")
lines += ['', '这里的帧间隔来自实际渲染循环。GL 命令提交计时包含 CPU/驱动调用，不等同于 GPU 执行时间；Flutter raster 时间也不能单独代表 ANGLE 绘制。准备与定位阶段排除在测量外。', '']
args.report.with_name('report.md').write_text('\n'.join(lines))
print(json.dumps({k:v for k,v in result.items() if k not in ['windows','worstFrames']}, ensure_ascii=False, indent=2))

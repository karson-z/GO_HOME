"""Summarize instrumented Android GL diagnostics separately from the baseline."""
import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
args = parser.parse_args()
data = json.loads(args.report.read_text())
frames = data['frames']
gpu = {s['frameId']: s for s in data.get('gpuSamples', []) if not s.get('disjoint')}

def stats(values):
    a = sorted(values)
    if not a:
        return None
    return {'mean': sum(a)/len(a), 'p50': a[len(a)//2],
            'p95': a[min(len(a)-1, int(len(a)*.95))], 'max': a[-1]}

def summarize(rows):
    stages = sorted({s for f in rows for s in f['renderDetails']['stages']})
    calls = defaultdict(lambda: {'count': 0, 'totalUs': 0, 'maxUs': 0})
    for f in rows:
        for name, c in f['renderDetails']['calls'].items():
            t = calls[name]
            t['count'] += c['count']
            t['totalUs'] += c['totalUs']
            t['maxUs'] = max(t['maxUs'], c['maxUs'])
    return {'frames': len(rows), 'fps': 1e6*len(rows)/sum(f['intervalUs'] for f in rows),
            'frameMs': stats([f['intervalUs']/1000 for f in rows]),
            'presentMs': stats([f['presentUs']/1000 for f in rows]),
            'submitMs': stats([f['renderSubmitUs']/1000 for f in rows]),
            'updateMs': stats([f['updateUs']/1000 for f in rows]),
            'drawCalls': stats([f['renderDetails']['drawCalls'] for f in rows]),
            'triangles': stats([f['renderDetails']['triangles'] for f in rows]),
            'gpuElapsedMs': stats([gpu[f['renderDetails']['frameId']]['elapsedNs32']/1e6 for f in rows if f['renderDetails']['frameId'] in gpu]),
            'resolution': rows[0]['renderDetails']['resolution'],
            'stagesMs': {s: stats([f['renderDetails']['stages'].get(s,0)/1000 for f in rows]) for s in stages},
            'calls': dict(sorted(calls.items(), key=lambda i:i[1]['totalUs'], reverse=True))}

windows = {w: summarize([f for f in frames if f['window']==w]) for w in dict.fromkeys(f['window'] for f in frames)}
slow = sorted(data.get('glSlowCalls', []), key=lambda c:c['durationUs'], reverse=True)
worst = sorted(frames, key=lambda f:f['intervalUs'], reverse=True)[:20]
for f in worst:
    stamp = f['vmTUs']
    f['nearbySlowCalls'] = [s for s in slow if stamp-f['intervalUs']-2000 <= s['tUs'] <= stamp][:20]
result = {'diagnostics': data.get('diagnostics'), 'complete': data['completedWindows']==data['expectedWindows'],
          'overall': summarize(frames), 'windows': windows, 'worstFrames': worst,
          'slowCalls': slow[:100], 'gpuTimerUnavailable': data.get('gpuTimerUnavailable')}
cp = args.report.with_name('cpu-samples.json')
if cp.is_file():
    cpu=json.loads(cp.read_text()); functions=cpu['functions']; samples=cpu['samples']
    # Select actual measured windows; exclude setup, checkpoint logging and teardown.
    ranges=sorted((f['vmTUs']-f['intervalUs'],f['vmTUs']) for f in frames)
    def profile(selected):
        inclusive=Counter(); exclusive=Counter(); tags=Counter()
        for s in selected:
            tags[s.get('vmTag','unknown')]+=1
            stack=s['stack']
            if stack: exclusive[stack[0]]+=1
            inclusive.update(set(stack))
        def row(i,n):
            f=functions[i]
            return {'name': (f.get('function') or {}).get('name',str(i)), 'kind':f.get('kind'),
                    'url':f.get('resolvedUrl'), 'samples':n,'percent':100*n/max(1,len(selected))}
        return {'sampleCount':len(selected), 'tags':dict(tags),
                'inclusive':[row(i,n) for i,n in inclusive.most_common(40)],
                'exclusive':[row(i,n) for i,n in exclusive.most_common(40)]}
    selected=[]; idx=0
    for s in sorted(samples,key=lambda s:s['timestamp']):
        while idx<len(ranges) and s['timestamp']>ranges[idx][1]:idx+=1
        if idx<len(ranges) and ranges[idx][0]<=s['timestamp']<=ranges[idx][1]:selected.append(s)
    result['cpu']=profile(selected)
    result['cpuAll']=profile(samples)
    result['cpuWindowCoverage']={'sampleOrigin':cpu.get('timeOriginMicros'),'sampleExtent':cpu.get('timeExtentMicros'),'requestedOrigin':data['cpuOriginUs'],'requestedEnd':data['cpuEndUs']}
args.report.with_name('diagnosis.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
lines=['# Android 渲染诊断','', '此构建记录 GL 调用、阶段计时和 CPU 采样，包含额外诊断开销；不替代上一轮未插桩 Profile 基准。','',
       '| 测量段 | FPS | 帧 P95 ms | 提交均值 ms | 呈现均值 ms | GPU elapsed 均值 ms | draw calls |',
       '|---|---:|---:|---:|---:|---:|---:|']
for w,s in windows.items():
    g=s['gpuElapsedMs'];g=f"{g['mean']:.2f}" if g else '不可用'
    lines.append(f"| {w} | {s['fps']:.1f} | {s['frameMs']['p95']:.2f} | {s['submitMs']['mean']:.2f} | {s['presentMs']['mean']:.2f} | {g} | {s['drawCalls']['mean']:.0f} |")
lines+=['','| 阶段 | 均值 ms | P95 ms | 最长 ms |','|---|---:|---:|---:|']
for name,s in result['overall']['stagesMs'].items():lines.append(f"| {name} | {s['mean']:.2f} | {s['p95']:.2f} | {s['max']:.2f} |")
lines+=['','| GL 调用 | 次数 | 累计 ms | 最长单次 ms |','|---|---:|---:|---:|']
for name,c in result['overall']['calls'].items():lines.append(f"| {name} | {c['count']} | {c['totalUs']/1000:.2f} | {c['maxUs']/1000:.2f} |")
if 'cpu' in result:
    coverage = result['cpuWindowCoverage']
    lines+=['',f"测量窗口内 CPU 样本：{result['cpu']['sampleCount']}。包含调用栈统计会重叠，不可相加。",
            f"采样缓冲实际覆盖 {coverage['sampleExtent']/1e6:.2f} 秒；整个测试持续 {(coverage['requestedEnd']-coverage['requestedOrigin'])/1e6:.2f} 秒。较早的样本可能已被环形缓冲覆盖，不能用这份尾段 CPU 采样解释更早的尖峰。", '',
            '| 调用栈含该函数 | 样本比例 |','|---|---:|']
    for c in result['cpu']['inclusive'][:20]:lines.append(f"| {c['name']} | {c['percent']:.1f}% |")
lines+=['','呈现计时包含 ANGLE 纹理拷贝及 glFinish 等待。GL 单次耗时是同步调用的墙钟时间，不等于全部都是 CPU 运算；GPU elapsed 查询也包含命令间的 GPU 时间线空档，不能当作利用率。半分辨率实验只改渲染目标宽高，保留场景与植被数量。','']
args.report.with_name('diagnosis.md').write_text('\n'.join(lines))
print(json.dumps({k:v for k,v in result.items() if k not in ['worstFrames','slowCalls','cpuAll','cpu','windows']},ensure_ascii=False,indent=2))

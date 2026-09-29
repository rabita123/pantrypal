#!/usr/bin/env python3
"""Turns `flutter test --reporter=json` output into a readable summary.

Usage: summarize.py <results.json> <suite-label>
Writes <results>.md next to the input and prints the summary to stdout.
"""
import json
import sys
from collections import defaultdict

path, label = sys.argv[1], sys.argv[2]

names, groups, results, errors, durations = {}, {}, {}, defaultdict(list), {}
group_names = {}

with open(path) as fh:
    for line in fh:
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = e.get('type')
        if t == 'group':
            group_names[e['group']['id']] = e['group'].get('name') or ''
        elif t == 'testStart':
            test = e['test']
            names[test['id']] = test['name']
            gids = test.get('groupIDs') or []
            groups[test['id']] = group_names.get(gids[-1], '') if gids else ''
        elif t == 'testDone':
            if e.get('hidden'):
                continue
            results[e['testID']] = 'skipped' if e.get('skipped') else e.get('result')
            durations[e['testID']] = e.get('time', 0)
        elif t == 'error':
            errors[e['testID']].append(e.get('error', ''))

passed = [i for i, r in results.items() if r == 'success']
failed = [i for i, r in results.items() if r not in ('success', 'skipped')]
skipped = [i for i, r in results.items() if r == 'skipped']
total = len(results)

lines = [f'# {label} suite', '']
lines.append(f'**{len(passed)}/{total} passed**'
             + (f' · {len(failed)} failed' if failed else '')
             + (f' · {len(skipped)} skipped' if skipped else ''))
lines.append('')

by_group = defaultdict(lambda: [0, 0])
for i, r in results.items():
    b = by_group[groups.get(i, '')]
    b[1] += 1
    if r == 'success':
        b[0] += 1

lines.append('| Group | Passed |')
lines.append('| --- | --- |')
for g, (p, t) in sorted(by_group.items()):
    lines.append(f'| {g or "(top level)"} | {p}/{t} |')
lines.append('')

if failed:
    lines.append('## Failures')
    lines.append('')
    for i in failed:
        lines.append(f'### {groups.get(i, "")} › {names.get(i, "?")}')
        lines.append('')
        for err in errors.get(i, [])[:1]:
            snippet = '\n'.join(err.strip().splitlines()[:6])
            lines.append('```')
            lines.append(snippet)
            lines.append('```')
        lines.append('')

out = path.rsplit('.', 1)[0] + '.md'
with open(out, 'w') as fh:
    fh.write('\n'.join(lines) + '\n')

print(f'{len(passed)}/{total} passed'
      + (f', {len(failed)} FAILED' if failed else '')
      + (f', {len(skipped)} skipped' if skipped else ''))
for i in failed:
    print(f'  FAIL  {groups.get(i, "")} › {names.get(i, "?")}')

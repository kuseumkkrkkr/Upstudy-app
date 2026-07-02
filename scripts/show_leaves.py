with open('all_leaves.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

leaves = []
for line in lines:
    line = line.strip()
    if not line:
        continue
    parts = line.split(': ')
    name = parts[0]
    chain = parts[1].split(' > ')
    leaves.append((name, chain))

from collections import defaultdict
by_top = defaultdict(list)
for name, chain in leaves:
    top = chain[0]
    by_top[top].append((name, chain))

for top, items in sorted(by_top.items()):
    print(f'{top}: {len(items)} leaves')
    for name, chain in items[:5]:
        chain_str = " > ".join(chain)
        print(f'  - {name}: {chain_str}')
    if len(items) > 5:
        print(f'  ... and {len(items)-5} more')

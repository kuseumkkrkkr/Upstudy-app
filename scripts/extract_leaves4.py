import re, json

with open('lib/models/concept_tag.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

stack = []
leaves = []

for i, line in enumerate(lines):
    stripped = line.strip()
    if not stripped:
        continue
    indent = len(line) - len(line.lstrip())
    
    m = re.search(r"name:\s*'([^']+)'", stripped)
    if m:
        name = m.group(1)
        if name in ['name', 'displayName', 'children', 'isExpanded', 'isSelected']:
            continue
        
        while stack and stack[-1][2] >= indent:
            stack.pop()
        
        stack.append((i, name, indent))
        
        is_leaf = True
        for j in range(i+1, min(i+20, len(lines))):
            next_line = lines[j]
            next_stripped = next_line.strip()
            if not next_stripped:
                continue
            next_indent = len(next_line) - len(next_line.lstrip())
            
            if 'children:' in next_stripped and next_indent <= indent:
                is_leaf = False
                break
            if next_stripped.startswith('),') and next_indent <= indent - 2:
                break
            if next_stripped.startswith('],') and next_indent <= indent - 2:
                break
            if next_indent <= indent - 2 and 'ConceptTag(' in next_stripped:
                break
        
        if is_leaf:
            chain = [item[1] for item in stack]
            leaves.append((name, chain))

with open('data/all_leaves.txt', 'w', encoding='utf-8') as f:
    for n, c in leaves:
        f.write(n + ': ' + ' > '.join(c) + '\n')

print('Total leaves:', len(leaves))
counts = {}
for n, c in leaves:
    key = c[0] if c else 'other'
    counts[key] = counts.get(key, 0) + 1
for k, v in counts.items():
    print(k + ':', v)


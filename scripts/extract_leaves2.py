import re

with open('lib/models/concept_tag.dart', 'r', encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')

stack = []  # list of (indent, name)
leaves = []  # list of (name, chain)

for i, line in enumerate(lines):
    stripped = line.strip()
    if not stripped:
        continue
    
    # Count leading spaces
    indent = len(line) - len(line.lstrip())
    
    m = re.search(r"name:\s*'([^']+)'", stripped)
    if m:
        name = m.group(1)
        # Pop items with >= indent from stack
        while stack and stack[-1][0] >= indent:
            stack.pop()
        
        stack.append((indent, name))
        
        # Check if leaf - look ahead for children: at higher indent
        is_leaf = True
        for j in range(i+1, min(i+20, len(lines))):
            next_stripped = lines[j].strip()
            if not next_stripped:
                continue
            next_indent = len(lines[j]) - len(lines[j].lstrip())
            if next_indent <= indent:
                break  # exiting this block
            if 'children:' in next_stripped:
                is_leaf = False
                break
        
        # Also skip class definition names
        if is_leaf and name not in ['name', 'displayName', 'children', 'isExpanded', 'isSelected']:
            chain = [item[1] for item in stack]
            # Skip class property names
            if len(chain) > 2 and chain[1] not in ['name', 'displayName']:
                leaves.append((name, chain[1:]))  # strip the first ConceptTag class level

print(f'Total leaves: {len(leaves)}')
print('First 20:')
for n, c in leaves[:20]:
    print(f'  {n}: {" > ".join(c)}')

math1 = [(n, c) for n, c in leaves if c[0] == '공통수학1']
math2 = [(n, c) for n, c in leaves if c[0] == '공통수학2']
calc = [(n, c) for n, c in leaves if c[0] == '미적분Ⅰ']

print(f'\n공통수학1: {len(math1)}')
print(f'공통수학2: {len(math2)}')
print(f'미적분Ⅰ: {len(calc)}')

import json
with open('data/concept_leaves.json', 'w', encoding='utf-8') as f:
    json.dump({'math1': math1, 'math2': math2, 'calculus': calc}, f, ensure_ascii=False, indent=2)


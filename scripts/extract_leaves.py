import re

with open('lib/models/concept_tag.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Parse the tree structure to extract leaf nodes with parent chains
# We use a stack-based approach with indentation
lines = content.split('\n')

stack = []  # list of (indent, name)
leaves = []  # list of (name, chain)

for i, line in enumerate(lines):
    stripped = line.strip()
    if not stripped:
        continue
    
    indent = len(line) - len(line.lstrip())
    # Pop stack to current indent level
    while stack and stack[-1][0] >= indent:
        stack.pop()
    
    # Check if this line contains name:
    m = re.search(r"name:\s*'([^']+)'", stripped)
    if m:
        name = m.group(1)
        stack.append((indent, name))
        
        # Check if this is a leaf (no children: at higher indent)
        is_leaf = True
        for j in range(i+1, min(i+20, len(lines))):
            next_stripped = lines[j].strip()
            if not next_stripped:
                continue
            next_indent = len(lines[j]) - len(lines[j].lstrip())
            if next_indent <= indent:
                break
            if 'children:' in next_stripped:
                is_leaf = False
                break
        
        if is_leaf:
            chain = [item[1] for item in stack]
            leaves.append((name, chain))

print(f'Total leaves: {len(leaves)}')

# Split by top-level subject
math1 = [(n, c) for n, c in leaves if c[0] == '공통수학1']
math2 = [(n, c) for n, c in leaves if c[0] == '공통수학2']
calc = [(n, c) for n, c in leaves if c[0] == '미적분Ⅰ']

print(f'공통수학1: {len(math1)}')
print(f'공통수학2: {len(math2)}')
print(f'미적분Ⅰ: {len(calc)}')

# Save to JSON for further processing
import json
with open('data/concept_leaves.json', 'w', encoding='utf-8') as f:
    json.dump({'math1': math1, 'math2': math2, 'calculus': calc}, f, ensure_ascii=False, indent=2)

print('Saved to concept_leaves.json')


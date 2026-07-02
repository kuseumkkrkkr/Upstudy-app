import re

with open('lib/models/concept_tag.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

leaves = []  # (name, chain)

# Better parsing: track ConceptTag boundaries
i = 0
root_chain = []

# We'll process character by character to track nesting
# Actually, a simpler approach: extract ALL ConceptTag blocks and determine if they have children

content = ''.join(lines)

# Find all ConceptTag blocks
# Approach: find ConceptTag( ... ) at matching parens
# But simpler: use regex to find leaf tags - single-line ConceptTag(name: ..., displayName: #...)
oneline_leaf = re.compile(r"ConceptTag\(\s*name:\s*'([^']+)'\s*,\s*displayName:\s*'#([^']+)'\s*\)")
# This finds only single-line leaves
single_leaves = oneline_leaf.findall(content)
print(f'Single-line leaves found: {len(single_leaves)}')

# Now we need to find multi-line concept tags and determine their hierarchy
# Let\'s process line by line properly

stack = []  # list of (line_idx, name, indent)
all_nodes = []

for i, line in enumerate(lines):
    stripped = line.strip()
    if not stripped:
        continue
    indent = len(line) - len(line.lstrip())
    
    # Detect ConceptTag(
    if 'ConceptTag(' in stripped and 'copyWith' not in stripped:
        # This is a new tag opening
        # Pop all with same or greater indent (they were parent contexts)
        # Well, this is happening on the header line, not the name line
        pass
    
    m = re.search(r"name:\s*'([^']+)'", stripped)
    if m:
        name = m.group(1)
        if name in ['name', 'displayName', 'children', 'isExpanded', 'isSelected']:
            continue
        
        # Pop stack for higher or equal indent
        while stack and stack[-1][2] >= indent:
            stack.pop()
        
        stack.append((i, name, indent))
        
        # Determine if leaf by looking within this tag\'s block
        # Find where this tag ends
        # Look for ), at same or lower indent after name
        is_leaf = True
        for j in range(i+1, len(lines)):
            next_line = lines[j]
            next_stripped = next_line.strip()
            if not next_stripped:
                continue
            next_indent = len(next_line) - len(next_line.lstrip())
            
            if next_stripped.startswith('),') and next_indent <= indent - 2:
                # Tag ended, no children found
                break
            if next_stripped.startswith('],') and next_indent <= indent - 2:
                break
            if 'children:' in next_stripped and next_indent <= indent:
                # This ConceptTag has children (children: is inside the tag block)
                is_leaf = False
                break
            if 'ConceptTag(' in next_stripped and next_indent <= indent - 2:
                # Sibling tag started without finding children, so must be leaf
                break
        
        # Build chain from stack
        chain = [item[1] for item in stack]
        
        # Only include actual data nodes (after conceptTagData array)
        if chain[0] != 'ConceptTag':
            if is_leaf:
                leaves.append((name, chain))
            else:
                # Non-leaf nodes still collected for full tree reference
                pass

print(f'Leaf count: {len(leaves)}')
for n, c in leaves[:30]:
    print(f'  {n}: {" > ".join(c)}')

# Categorize
math1 = [(n, c) for n, c in leaves if c[0] == '공통수학1']
math2 = [(n, c) for n, c in leaves if c[0] == '공통수학2']
calc = [(n, c) for n, c in leaves if c[0] == '미적분Ⅰ']

print(f'\n공통수학1 leaves: {len(math1)}')
print(f'공통수학2 leaves: {len(math2)}')
print(f'미적분Ⅰ leaves: {len(calc)}')

import json
with open('data/concept_leaves.json', 'w', encoding='utf-8') as f:
    json.dump({'math1': math1, 'math2': math2, 'calculus': calc}, f, ensure_ascii=False, indent=2)


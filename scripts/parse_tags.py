import re

with open('lib/models/concept_tag.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Split by ConceptTag( and check for children
blocks = re.split(r'ConceptTag\(', content)
leaves = []
for block in blocks:
    if 'children' not in block:
        m = re.search(r"name:\s*'([^']+)'\s*,\s*displayName:\s*'#([^']+)'", block)
        if m:
            leaves.append(m.group(1))

print(f'Leaf count (method 1): {len(leaves)}')

all_names = re.findall(r"name:\s*'([^']+)'", content)
real_names = [n for n in all_names if n not in ['name', 'displayName', 'children', 'isExpanded', 'isSelected']]
print(f'Total real concept names: {len(real_names)}')

unique = list(dict.fromkeys(real_names))
print(f'Unique names: {len(unique)}')
print('First 30:')
for n in unique[:30]:
    print(f'  {n}')

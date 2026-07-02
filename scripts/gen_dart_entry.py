# -*- coding: utf-8 -*-
import json

def dart_str(s):
    s = s.replace('\\', '\\\\\\\\')
    s = s.replace('$', '\\$')
    s = s.replace('"', '\\"')
    return '"' + s + '"'

out = []
out.append('import \"textbook.dart\";')
out.append('')
out.append('const Map<String, BookData> _kPart5 = {')

out.append('};')

with open('lib/models/concept_textbooks_part5.dart', 'w', encoding='utf-8') as f:
    for line in out:
        f.write(line + '\n')
print('Done')

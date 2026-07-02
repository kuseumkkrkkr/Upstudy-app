import json, codecs, os

concepts = json.load(open('data/concepts_part5.json','r',encoding='utf-8'))

# We will escape a paragraph for Dart double-quoted string
# Need to escape backslash and double-quote and dollar sign
# But our Korean/LaTeX strings only have backslash and dollar sign issues.

def dart_str(s):
    # For Dart double quoted string: escape backslash -> \\, dollar -> \$, quote -> \"
    s = s.replace('\\', '\\\\\\\\')
    s = s.replace('$', '\\$')
    s = s.replace('"', '\\"')
    return '"' + s + '"'

# For JSON tags/intro which have no special chars, simple quoting is fine.
out = []
out.append('import \"textbook.dart\";')
out.append('')
out.append('const Map<String, BookData> _kPart5 = {')

# Concept data

def add(c, path, tags, paras):
    out.append('  ' + dart_str(c) + ': BookData(')
    out.append('    id: ' + dart_str('concept_' + c) + ',')
    out.append('    title: ' + dart_str(c) + ',')
    out.append('    subtitle: ' + dart_str(path + ' > ' + c) + ',')
    out.append('    category: ' + dart_str('common') + ',')
    out.append('    tags: [' + ', '.join([dart_str(t) for t in tags]) + '],')
    out.append('    chapters: [')
    out.append('      BookChapter(')
    out.append('        title: ' + dart_str(c) + ',')
    out.append('        intro: [' + dart_str(path + ' > ' + c + ' 媛쒕뀗 ?숈뒿') + '],')
    out.append('        sections: [')
    out.append('          BookSection(')
    out.append('            title: ' + dart_str(c) + ',')
    out.append('            paragraphs: [')
    for i, p in enumerate(paras):
        comma = ',' if i < len(paras)-1 else ''
        out.append('              ' + dart_str(p) + comma)
    out.append('            ],')
    out.append('          ),')
    out.append('        ],')
    out.append('      ),')
    out.append('    ],')
    out.append('  ),')

print('funcs defined')

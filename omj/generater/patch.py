# -*- coding: utf-8 -*-
"""
Patch runner: JSON textbooks -> Dart BookData map.
Usage:
    python omj/generater/patch.py
        --input  gen_textbook/output
        --output lib/models/concept_textbooks.dart
        --leaves all_leaves.txt
"""

import argparse
import json
import os

# ---- Korean UI strings (unicode-escaped for 100% ASCII source safety) ----
DT = u'\uAC1C\uB150 \uC0C1\uC138 \uC124\uBA85'
FT = u'\uC8FC\uC694 \uACF5\uC2DD \uBC0F LaTeX'
ET = u'\uC608\uC81C \uBC0F \uD480\uC774'
PP = u'\uBB38\uC81C: '
SP = u'\uD480\uC774: '
PH = u' \uAC1C\uB150\uC5D0 \uB300\uD55C \uAD50\uC7AC \uB0B4\uC6A9\uC774 \uC900\uBE44 \uC911\uC785\uB2C8\uB2E4.'

def load_json_dir(d):
    R={}
    if not os.path.isdir(d): return R
    for f in sorted(os.listdir(d)):
        if not f.endswith('.json'): continue
        p=os.path.join(d,f); n=f[:-5]
        try:
            with open(p,'r',encoding='utf-8') as o: data=json.load(o)
            if isinstance(data,dict) and not data.get('_error'): R[n]=data
        except Exception as e: print(f"[WARN] {f}: {e}")
    return R

def load_leaves(p):
    M={}
    if not os.path.exists(p): return M
    with open(p,'r',encoding='utf-8') as o:
        for L in o:
            L=L.strip()
            if not L: continue
            if '\t' in L:
                a,b=L.split('\t',1); M[a]=b.split('|')
            else: M[L]=[L]
    return M

def esc(s):
    if not isinstance(s,str): s=json.dumps(s,ensure_ascii=False)
    return s.replace("'",r"\'")

def paras(data):
    P=[]
    d=data.get('description','')
    if d: P+=[DT,d.strip()]
    if data.get('formulas'):
        P+=[FT]
        for x in data['formulas']:
            if isinstance(x,dict):
                if x.get('latex'): P+=[x['latex'].strip()]
                if x.get('explanation'): P+=[x['explanation'].strip()]
    if data.get('examples'):
        P+=[ET]
        for x in data['examples']:
            if isinstance(x,dict):
                if x.get('problem'): P+=[PP+x['problem'].strip()]
                if x.get('solution'): P+=[SP+x['solution'].strip()]
    return P

def dp(P):
    return "\n".join([f"      '{esc(p)}'," for p in P])

def entry(name,path_list,data):
    e=esc(name); sub=" > ".join(path_list); es=esc(sub)
    tags=", ".join([f"'{esc(p)}'" for p in path_list])
    P=paras(data) or [name+PH]
    block=dp(P)
    return f"""
  '{e}': BookData(
    id: 'concept_{name}',
    title: '{e}',
    subtitle: '{es}',
    category: 'common',
    tags: [{tags}],
    chapters: [
      BookChapter(
        title: '{e}',
        intro: ['{es} {DT}'],
        sections: [
          BookSection(
            title: '{e}',
            paragraphs: [
{block}
            ],
          ),
        ],
      ),
    ],
  ),"""

def gen(genD,leavesM):
    out=[]
    out.append("// Auto-generated concept textbooks (LLM-generated)")
    out.append("import 'textbook.dart';")
    out.append("")
    out.append("final Map<String, BookData> kConceptTextbooks = {")
    for name,data in genD.items():
        out.append(entry(name,leavesM.get(name,[name]),data))
    out.append("};")
    out.append("")
    out.append("""
List<BookData> findConceptTextbooks(List<String> tags) {
  if (tags.isEmpty) {
    return kConceptTextbooks.values.toList();
  }
  final result = <BookData>[];
  final seen = <String>{};
  for (final tag in tags) {
    final key = tag.replaceFirst('#', '');
    if (kConceptTextbooks.containsKey(key) && !seen.contains(key)) {
      seen.add(key);
      result.add(kConceptTextbooks[key]!);
      continue;
    }
    for (final entry in kConceptTextbooks.entries) {
      if (entry.value.tags.contains(key) || entry.value.tags.contains(tag)) {
        if (!seen.contains(entry.key)) {
          seen.add(entry.key);
          result.add(entry.value);
        }
      }
    }
  }
  return result.isNotEmpty ? result : kConceptTextbooks.values.toList();
}

BookData buildConceptBook(List<String> tags) {
  final normalized = tags.map((t) => t.replaceFirst('#', '')).toList();
  final List<BookChapter> chapters = [];
  final seen = <String>{};
  for (final tag in normalized) {
    if (kConceptTextbooks.containsKey(tag)) {
      if (!seen.contains(tag)) {
        seen.add(tag);
        chapters.addAll(kConceptTextbooks[tag]!.chapters);
      }
      continue;
    }
    for (final entry in kConceptTextbooks.entries) {
      if (entry.value.tags.contains(tag) || entry.value.tags.contains('#' + tag)) {
        if (!seen.contains(entry.key)) {
          seen.add(entry.key);
          chapters.addAll(entry.value.chapters);
        }
      }
    }
  }
  final dt = normalized.take(3).join(', ') +
      (normalized.length > 3 ? ' \uC678 ' : '');
  return BookData(
    id: 'concept_study_' + normalized.join('_'),
    title: '\uAC1C\uB150 \uD559\uC2B5',
    subtitle: dt,
    category: 'common',
    tags: tags.toList(),
    chapters: chapters.isNotEmpty
        ? chapters
        : kConceptTextbooks.values.first.chapters,
  );
}
""")
    return "\n".join(out)

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--input",default="gen_textbook/output")
    p.add_argument("--output",default="lib/models/concept_textbooks.dart")
    p.add_argument("--leaves",default="all_leaves.txt")
    a=p.parse_args()
    G=load_json_dir(a.input)
    L=load_leaves(a.leaves)
    s=gen(G,L)
    os.makedirs(os.path.dirname(a.output) or ".", exist_ok=True)
    with open(a.output,"w",encoding="utf-8") as f: f.write(s)
    print(f"Patched {len(G)} concepts into {a.output}")

if __name__=="__main__":
    main()

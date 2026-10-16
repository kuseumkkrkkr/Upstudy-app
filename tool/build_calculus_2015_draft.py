"""Group available 2015 Calculus pages into official unit candidate drafts."""
from __future__ import annotations
import json
from collections import Counter, OrderedDict
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
OUTPUT=MANUSCRIPTS/"미적분_2015개정_통합초안"
UNIT_NAMES={"01":"수열의 극한과 급수","02":"미분법","03":"적분법"}

def signature(page):
 return json.dumps({k:page.get(k) for k in ("title","template","blocks")},ensure_ascii=False,sort_keys=True)

def main():
 grouped=OrderedDict(); expected=Counter()
 source=MANUSCRIPTS/"미적분_2015개정_수열의극한_BookData_시범.json"
 old=json.loads(source.read_text(encoding="utf-8")); old_tags=old.get("tags",[])
 old_pages=[p for c in old.get("chapters",[]) for p in c.get("pages",[])]
 if old_tags[:3]!=["미적분","2015 개정","수열의 극한"] or not old_pages: raise RuntimeError("Unexpected legacy Calculus source")
 grouped.setdefault("01",[]).append({"title":"기존 수열의 극한 시범","file":source.name,"pages":old_pages,"codes":[],"tags":old_tags})
 batch_path=MANUSCRIPTS/"미적분_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
 batch=json.loads(batch_path.read_text(encoding="utf-8"))
 for chapter in batch.get("chapters",[]):
  page_id=chapter["pages"][0]["id"]
  unit="01" if page_id.startswith("calc15-01") else "02" if page_id.startswith("calc15-02") else "03"
  grouped.setdefault(unit,[]).append({"title":chapter["title"],"file":batch_path.name,"pages":chapter["pages"],"codes":[],"tags":batch.get("tags",[])})
 for modules in grouped.values():
  for module in modules:
   for page in module["pages"]: expected[signature(page)]+=1
 OUTPUT.mkdir(parents=True,exist_ok=True); lines=["# 미적분 2015 개정 단원별 통합 초안","","기존 원고와 신규 V2 후보를 공식 대단원에 따라 나눴습니다. 신규 27모듈 135쪽과 기존 지면은 원본을 보존했습니다. 이 분류는 교과서 상품 범위나 독립 교사 검수를 뜻하지 않습니다.",""]
 actual=Counter(); ids=set(); module_total=0
 for unit,modules in grouped.items():
  chapters=[]
  for mi,module in enumerate(modules,1):
   pages=[{"id":f"calc15-{unit}-{mi:02d}-000","template":"opening","title":module["title"]+" · 출처와 범위","blocks":[{"type":"paragraph","text":" · ".join(module["tags"])},{"type":"paragraph","text":"성취기준 후보이며 범위·내용 검토가 남아 있습니다."}]}]+module["pages"]
   for pi,page in enumerate(pages,1):
    page["id"]=f"calc15-{unit}-{mi:02d}-{pi:03d}"
    if page["id"] in ids: raise RuntimeError("Duplicate page ID")
    ids.add(page["id"])
    if pi>1: actual[signature(page)]+=1
   chapters.append({"title":module["title"],"pages":pages,"source_file":module["file"],"candidate_standard_codes":module["codes"]})
   module_total+=1
  name=f"미적분_2015개정_{unit}_{'수열극한급수' if unit=='01' else UNIT_NAMES[unit]}_부분통합초안.json"
  result={"title":f"미적분 2015 개정 · {UNIT_NAMES[unit]} 부분 통합 초안","tags":["미적분","2015 개정",UNIT_NAMES[unit],"부분 통합"],"chapters":chapters,"metadata":{"status":"partial_draft","source_files":list(dict.fromkeys(m['file'] for m in modules))}}
  (OUTPUT/name).write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
  lines.append(f"- [{UNIT_NAMES[unit]}]({name}): {len(modules)} modules, {sum(len(m['pages']) for m in modules)} source pages")
 if actual!=expected: raise RuntimeError("Original page preservation check failed")
 lines += ["","기존 수열 원고는 세부 기준 코드가 미대조이므로 tag 후보로 올리지 않았습니다. 신규 공식 코드 후보는 독립 수학 교사 검수, 과목 상품 범위 승인, 권리 결정을 기다립니다. 그래프·HTML 원본은 별도 자산이며 앱 parity는 미검증입니다.","","재생성: `python tool/build_calculus_2015_draft.py`",""]
 (OUTPUT/"README.md").write_text("\n".join(lines),encoding="utf-8")
 print(f"Built {module_total} modules; preserved {sum(expected.values())} source pages; unique IDs and page payloads verified.")

if __name__=="__main__": main()

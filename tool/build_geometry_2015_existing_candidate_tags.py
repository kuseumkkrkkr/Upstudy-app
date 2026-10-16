"""Add explicit but provisional 2015 standard references to existing vector drafts."""
from __future__ import annotations
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
PACKAGE=MANUSCRIPTS/"기하_2015개정_기존벡터_예비기준연결"
SOURCES={
 "고등수학_기하_2015개정_개념서_시범_BookData.json":["12기하02-01","12기하02-02","12기하02-03","12기하02-04"],
 "고등수학_기하_벡터의덧셈과실수배_BookData_시범.json":["12기하02-01","12기하02-02"],
 "고등수학_기하_위치벡터와좌표_BookData_시범.json":["12기하02-03"],
 "고등수학_기하_평면벡터내적_BookData_시범.json":["12기하02-04"],
}
EXPECTED_PAGES={"고등수학_기하_2015개정_개념서_시범_BookData.json":9,"고등수학_기하_벡터의덧셈과실수배_BookData_시범.json":3,"고등수학_기하_위치벡터와좌표_BookData_시범.json":3,"고등수학_기하_평면벡터내적_BookData_시범.json":3}
PARTIAL={"12기하02-01":"vector meaning is introduced with operations; independent concept coverage remains partial", "12기하02-02":"operation examples exist; practice and complete operation coverage require review", "12기하02-03":"position vector and coordinates have two separate drafts; full criterion check pending", "12기하02-04":"dot product definition and coordinate form exist; application coverage pending"}

def main():
 records=[]
 for name,codes in SOURCES.items():
  path=MANUSCRIPTS/name; data=json.loads(path.read_text(encoding='utf-8'))
  tags=data.get('tags',[])
  if tags[:2]!=['기하','2015 개정']: raise RuntimeError(f'Unexpected edition tags: {name}')
  pages=[p for ch in data.get('chapters',[]) for p in ch.get('pages',[])]
  if len(pages)!=EXPECTED_PAGES[name]: raise RuntimeError(f'Unexpected source page count for {name}: {len(pages)}')
  # Preserve every page and its authored blocks; only edition/code metadata changes.
  data['curriculum_version']='2015'
  data['standard_codes']=codes
  data['tags']=list(dict.fromkeys([*tags,*codes,'official-code candidate mapping; content review pending']))
  path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
  records.append({"source_file":name,"sha256":canonical_file_sha256(path),"standard_codes":codes,"page_count":len(pages),"content_mapping_status":"partial_candidate_mapping; independent review pending","rights_status":"source rights not verified"})
 PACKAGE.mkdir(parents=True,exist_ok=True)
 old={}
 try: old=json.loads((PACKAGE/'REVIEW_MANIFEST.json').read_text(encoding='utf-8'))
 except (OSError,json.JSONDecodeError): pass
 same=old.get('source_files')==records
 manifest={"source_files":records,"candidate_code_references":sorted(PARTIAL),"candidate_code_reference_type":"2015_moe_appendix8_geometry_standards","curriculum_review_status":"official_codes_checked; body mapping partial","math_review_status":"pending_independent_teacher_review","teacher_review_status":"pending","rights_status":"existing source rights not verified","publication_eligibility":"not_eligible","source_html_status":"HTML assets retained separately; no automatic embedding or parity claim","runtime_import_status":old.get('runtime_import_status','pending_current_hash_validation') if same else 'pending_current_hash_validation',"runtime_validator_head":old.get('runtime_validator_head') if same else None,"notes":PARTIAL}
 (PACKAGE/'REVIEW_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 (PACKAGE/'README.md').write_text('# 기하 2015 개정 기존 벡터 원고의 예비 기준 연결\n\n기존 BookData 4개의 원고 본문과 지면은 유지하고 판본 메타데이터와 성취기준 후보만 추가했습니다. 연결 후보는 벡터 의미·연산·위치벡터·내적 4개이며 모두 부분 매핑으로 남겨 독립 교사 검수를 기다립니다. 기존 HTML 자산은 별도 파일로 보존되며 BookData에 자동으로 들어가거나 앱에서 그대로 실행된다는 뜻은 아닙니다. 출처 권리도 미확인입니다.\n',encoding='utf-8')
 print(f'Tagged {len(records)} page-preserved vector sources with 4 provisional standard candidates.')

if __name__=='__main__': main()

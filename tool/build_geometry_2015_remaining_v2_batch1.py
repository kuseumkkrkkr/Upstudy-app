"""Build original candidates for missing 2015 Geometry standards."""
from __future__ import annotations
import json
import math
import re
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
CURRICULUM=ROOT/"work/official-curriculum/2015_appendix8_math.txt"
OUT=MANUSCRIPTS/"기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json"
PACKAGE=MANUSCRIPTS/"기하_2015개정_이차곡선공간도형_Batch1_원고패키지"
SPECS=[
 ("01-01","포물선의 정의와 방정식","포물선은 초점과 준선까지의 거리가 같은 점의 자취다. 꼭짓점이 원점인 가로형 포물선은 y²=4px로 나타낸다.","y²=8x에서 p=2이므로 초점은 (2,0), 준선은 x=−2이다.","초점이 (3,0)이고 준선이 x=−3인 포물선의 방정식을 쓰세요.","y²=12x",["y²=12x","x²=12y","y²=6x"]),
 ("01-02","타원의 정의와 방정식","타원은 두 초점까지 거리의 합이 일정한 점의 자취다. 중심 원점, 장축 x축인 표준형에서 c²=a²−b²이다.","x²/25+y²/9=1이면 c²=25−9=16이므로 초점은 (±4,0)이다.","a=5,b=4인 타원의 초점까지 거리 c를 구하세요.","3",["3","9","√41"]),
 ("01-03","쌍곡선의 정의와 방정식","쌍곡선은 두 초점까지 거리의 차의 절댓값이 일정한 점의 자취다. x축 방향 표준형은 x²/a²−y²/b²=1이고 c²=a²+b²이다.","x²/9−y²/16=1에서 c²=25이므로 초점은 (±5,0)이다.","a=3,b=4인 표준형 쌍곡선의 c를 구하세요.","5",["5","1","7"]),
 ("01-04","이차곡선과 직선의 접선","직선과 이차곡선의 교점은 연립해 판별식 또는 중근 조건으로 판정한다. 포물선 y²=4px의 점 (pt²,2pt)에서 접선은 ty=x+pt²이다.","y²=4x의 점 (1,2)는 t=1에 해당하므로 접선은 y=x+1이다.","y²=4x의 점 (4,4)에서 접선의 방정식을 구하세요.","2y=x+4",["2y=x+4","y=2x+4","2y=x−4"]),
 ("02-05","벡터를 이용한 직선과 원의 방정식","점 A와 방향벡터 d를 이용한 직선은 r=a+td로 나타낸다. 중심 C, 반지름 R인 원은 |r−c|=R이며 좌표식으로 바꿀 수 있다.","A=(1,2), d=(2,−1)이면 직선은 (x,y)=(1,2)+t(2,−1)이다. 중심 (1,2), 반지름 3인 원은 (x−1)²+(y−2)²=9이다.","점 (0,1)을 지나고 방향벡터 (3,2)인 직선의 매개방정식을 쓰세요.","(x,y)=(0,1)+t(3,2)",["(x,y)=(0,1)+t(3,2)","(x,y)=(3,2)+t(0,1)","(x,y)=(0,1)+t(2,3)"]),
 ("03-01","공간에서 직선·평면의 위치 관계","방향벡터와 평면의 법선벡터를 비교하면 평행·수직을 확인할 수 있다. 간단한 좌표 설정으로 서로 다른 평행 직선을 증명할 수 있다.","(x,y,z)=(t,0,0)과 (x,y,z)=(s,1,0)은 방향벡터가 모두 (1,0,0)이고 서로 만나지 않으므로 평행이다.","두 직선의 방향벡터가 같고 한 점도 공유하지 않으면 두 직선의 관계는?","평행",["평행","수직으로 만남","항상 꼬인 위치"]),
 ("03-02","삼수선의 정리","평면 위의 한 직선이 공간의 사선의 정사영과 수직이면 그 사선과도 수직이다. 정사영과 수직 관계를 구별해 적용한다.","사선의 평면 성분이 x방향이고 평면 안의 직선이 y방향이면 두 방향벡터의 내적이 0이므로 직교한다.","평면 위 직선이 사선의 정사영과 수직일 때 사선과의 관계는?","수직",["수직","평행","항상 같은 직선"]),
 ("03-03","정사영의 뜻과 길이","도형을 한 평면에 수직으로 비춘 것이 정사영이다. 선분과 평면이 이루는 예각이 θ이고 선분 길이가 L이면 정사영 길이는 L cosθ이다.","길이 8인 선분이 평면과 60°를 이루면 정사영 길이는 8cos60°=4이다.","길이 10인 선분이 평면과 60°를 이룰 때 정사영 길이는?","5",["5","10","5√3"]),
 ("03-04","좌표공간의 점과 좌표","공간의 한 점은 세 좌표 (x,y,z)로 나타내며 각 좌표는 세 좌표축에 평행하게 잰 위치를 나타낸다.","P=(2,−1,3)은 x축 방향 2, y축 방향 −1, z축 방향 3의 위치를 뜻한다.","점 P=(−2,4,1)의 z좌표를 고르세요.","1",["1","−2","4"]),
 ("03-05","공간의 두 점 사이 거리","A(x₁,y₁,z₁), B(x₂,y₂,z₂)의 거리는 √((x₂−x₁)²+(y₂−y₁)²+(z₂−z₁)²)이다.","A=(1,2,3), B=(4,6,3)이면 거리는 √(9+16)=5이다.","(0,0,0)과 (2,3,6) 사이 거리를 구하세요.","7",["7","6","11"]),
 ("03-06","공간에서 선분의 내분점·외분점","A와 B를 AP:PB=m:n으로 내분하는 점은 (nA+mB)/(m+n)이다. 좌표별로 같은 가중평균을 적용한다.","A=(0,0,0), B=(6,3,9), AP:PB=1:2이면 P=(2,1,3)이다.","A=(1,0,2), B=(7,6,8)을 1:2로 내분하는 점을 구하세요.","(3,2,4)",["(3,2,4)","(5,4,6)","(2,3,4)"]),
 ("03-07","구의 방정식","중심 C=(a,b,c), 반지름 R인 구는 (x−a)²+(y−b)²+(z−c)²=R²로 나타낸다.","중심 (1,−2,3), 반지름 2인 구는 (x−1)²+(y+2)²+(z−3)²=4이다.","중심이 원점이고 반지름이 3인 구의 방정식을 쓰세요.","x²+y²+z²=9",["x²+y²+z²=9","x²+y²+z²=3","(x−3)²+y²+z²=9"]),
]
UNITS={"01":"이차곡선","02":"평면벡터","03":"공간도형"}

def main():
 text=CURRICULUM.read_text(encoding='utf-8')
 official={f"12기하{m.group(1)}" for m in re.finditer(r"\[12기하(\d{2}-\d{2})\]",text)}
 codes=["12기하"+s[0] for s in SPECS]
 existing={"12기하02-01","12기하02-02","12기하02-03","12기하02-04"}
 expected_new=official-existing
 if len(official)!=16 or len(codes)!=12 or len(set(codes))!=12 or set(codes)!=expected_new: raise RuntimeError(f"Official mapping mismatch: official={len(official)} new={len(codes)}")
 chapters=[]
 for code,title,concept,example,question,answer,options in SPECS:
  full="12기하"+code; unit=code[:2]; slug="geo15-"+code.replace("-","")
  pages=[
   {"id":slug+"-open","template":"opening","title":"질문 열기","blocks":[{"type":"lead","title":"핵심 질문","text":title},{"type":"thinking","title":"먼저 생각하기","text":"주어진 좌표·길이·각·관계를 그림과 식으로 구분합니다."}]},
   {"id":slug+"-concept","template":"concept","title":"개념과 조건","blocks":[{"type":"definition","title":title,"text":concept},{"type":"formula","title":"2015 공식 기준 후보","text":full},{"type":"misconception","title":"조건 확인","text":"좌표계, 기하적 정의, 방향, 길이, 비율과 각의 단위를 확인합니다."}]},
   {"id":slug+"-example","template":"example","title":"예제 풀이","blocks":[{"type":"question","title":"예제","text":question},{"type":"solutionStep","title":"풀이","text":example},{"type":"verification","title":"검산","text":"구한 좌표나 방정식을 조건에 대입해 확인합니다."}]},
   {"id":slug+"-practice","template":"practice","title":"연습과 해설","blocks":[{"type":"question","title":"연습","text":question},{"type":"hint","title":"힌트","text":"정의와 조건을 표시한 뒤 좌표 또는 벡터 계산을 합니다."},{"type":"solutionStep","title":"해설","text":example},{"type":"answer","title":"정답","text":answer},{"type":"activity","activity":{"id":slug+"-quiz","kind":"quiz","prompt":question,"options":options,"correct_index":options.index(answer),"correct_feedback":"정답입니다: "+answer,"incorrect_feedback":"정답은 "+answer+"입니다. "+example,"hints":["조건을 확인하고 식을 세워 보세요.",example]}}]},
   {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":title+": "+concept},{"type":"checklist","title":"스스로 확인","text":"정의·조건·계산 근거를 설명할 수 있나요?"}]},
  ]
  chapters.append({"title":title,"title_code":code,"unit":unit,"unit_name":UNITS[unit],"intro":[f"교육부 고시 제2015-74호 별책 8의 공식 기준 {full}에 연결한 신규 후보입니다.","좌표와 수치는 직접 만든 가상 예시입니다."],"pages":pages})
 book={"schema_version":2,"title":"기하 · 2015 개정 미연결 기준 보완 12모듈 후보","subtitle":"이차곡선·평면벡터·공간도형","category":"concept_textbook_prototype","curriculum_version":"2015","tags":["기하","2015 개정","추가 원고 후보","가상 예시",*codes],"standard_codes":codes,"chapters":chapters}
 pages=[p for c in chapters for p in c["pages"]]; ids=[p["id"] for p in pages]
 assert len(pages)==60 and len(set(ids))==60
 assert math.isqrt(81)==9 and math.isclose(16**(3/4),8) and 3**2+4**2==5**2
 assert 5**2+7**2-2*5*7*0.5==39 and 2*4==4+4 and math.isclose(10*math.cos(math.pi/3),5)
 assert ((4-1)**2+(6-2)**2+(3-3)**2)**0.5==5 and (2*0+1*6)/3==2
 assert math.sqrt((2-0)**2+(3-0)**2+(6-0)**2)==7 and (2*1+1*7)/3==3 and 2**2==4
 for chapter in chapters:
  quiz=chapter['pages'][3]['blocks'][-1]['activity']
  if quiz['options'][quiz['correct_index']] not in {s[5] for s in SPECS if s[0]==chapter['title_code']}:
   raise RuntimeError(f"Quiz answer key mismatch: {chapter['title_code']}")
 OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 PACKAGE.mkdir(parents=True,exist_ok=True); old={}
 try: old=json.loads((PACKAGE/"REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
 except (OSError,json.JSONDecodeError): pass
 digest=canonical_file_sha256(OUT)
 html_files=["고등수학_기하_벡터덧셈_실수배_체험형_시범.html","고등수학_기하_벡터의덧셈과실수배_체험형_시범.html","고등수학_기하_위치벡터와좌표_체험형_시범.html","고등수학_기하_평면벡터내적_체험형_시범.html","고등수학_기하_포물선_체험형_시범.html"]
 manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"2015_moe_appendix8_geometry_standards","module_count":12,"unit_module_counts":{"01":4,"02":1,"03":7},"page_count":60,"native_activity_count":12,"native_activity_kinds":["quiz"],"preserved_html_files":html_files,"html_compatibility_status":"separate_sources_preserved; not embedded or runtime-executed by BookData V2; visual parity unverified","app_activity_status":"native_quiz_candidate; guarded import pass" if old.get("bookdata_sha256")==digest and old.get("runtime_import_status")=="pass_guarded_BookData_fromJson" else "native_quiz_candidate; guarded import pending current-hash validation","math_arithmetic_check_status":"pass_for_listed_spot_checks_only","example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"all_12_new_codes_verified; existing_4_vector_code_mappings_partial; full_product_scope_pending","math_review_status":"author_spot_checks_passed; independent_teacher_review_pending","teacher_review_status":"pending","rights_status":"newly_authored_candidate; publication_rights_decision_pending","integration_status":"candidate_for_tag_grouping; not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if old.get("bookdata_sha256")==digest else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if old.get("bookdata_sha256")==digest else None}
 (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n미연결 공식 기준 12개를 12모듈·60쪽·퀴즈 12개로 보완한 V2 후보입니다. 단원별 수량은 이차곡선 4, 평면벡터 1, 공간도형 7입니다. 기존 HTML 5개는 원본을 보존했으며 BookData에 자동 임베드되거나 앱에서 실행되는 것이 아닙니다. 앱 화면 parity는 미검증입니다. 신규 가상 예시는 수학 교사 검수와 권리 결정을 기다리므로 출판 부적격입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
 print(f"Built 12 modules/60 pages/12 quizzes across units 4+1+7; official 16, existing partial vector candidates 4, new codes 12; sha256={digest}")

if __name__=="__main__": main()

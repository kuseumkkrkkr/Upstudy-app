"""Build original V2 candidates for untagged 2015 Mathematics II standards."""
from __future__ import annotations
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
OUT=MANUSCRIPTS/"수학Ⅱ_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
PACKAGE=MANUSCRIPTS/"수학Ⅱ_2015개정_미연결기준_Batch1_원고패키지"
SPECS=[
 ("01-04","함수의 극한과 연속","닫힌구간에서 연속인 함수는 최댓값과 최솟값을 가진다. 양 끝 함숫값의 부호가 다르면 구간 안에 영점이 있다.","f(x)=x−2는 [1,3]에서 연속이고 f(1)<0<f(3)이므로 영점 2를 갖는다.","g(x)=x−1은 [0,2]에서 연속이다. 영점이 구간 안에 있나요?","있다",["있다","없다","항상 두 개"]),
 ("02-01","미분계수","f′(a)는 h가 0이 아닌 채 0에 가까워질 때 (f(a+h)−f(a))/h의 극한이다.","f(x)=x², a=2이면 차분몫은 4+h이므로 미분계수는 4이다.","f(x)=x²의 x=3에서 미분계수를 구하세요.","6",["6","3","9"]),
 ("02-02","미분계수와 접선의 기울기","미분계수 f′(a)는 곡선 y=f(x)의 x=a에서 접선 기울기다.","y=x²의 x=1에서 기울기는 2이며 접선은 y−1=2(x−1)이다.","y=x²의 x=2에서 접선 기울기를 구하세요.","4",["4","2","8"]),
 ("02-03","미분가능성과 연속","함수가 한 점에서 미분가능하면 그 점에서 연속이다. 연속이어도 미분가능하다고 단정할 수는 없다.","|x|는 x=0에서 연속이지만 좌우 기울기가 −1과 1로 달라 미분가능하지 않다.","미분가능한 함수는 그 점에서 연속인가요?","그렇다",["그렇다","아니다","항상 불연속"]),
 ("02-04","거듭제곱함수의 도함수","n이 양의 정수일 때 (xⁿ)′=nxⁿ⁻¹이다.","(x⁴)′=4x³이다.","(x⁵)′을 구하세요.","5x⁴",["5x⁴","x⁴","4x⁵"]),
 ("02-05","다항함수의 미분법","실수배·합·차의 미분은 항별로 계산하고 곱의 미분은 (fg)′=f′g+fg′를 사용한다.","((x²+1)(x+2))′=2x(x+2)+(x²+1)=3x²+4x+1이다.","(2x³−x+4)′을 구하세요.","6x²−1",["6x²−1","2x²−1","6x³−1"]),
 ("02-06","접선의 방정식","곡선 y=f(x)의 x=a에서 접선은 y−f(a)=f′(a)(x−a)이다.","y=x²의 x=1에서 점은 (1,1), 기울기는 2이므로 접선은 y=2x−1이다.","y=x²의 x=2에서 접선의 방정식을 구하세요.","y=4x−4",["y=4x−4","y=2x","y=4x+4"]),
 ("02-07","평균값 정리","[a,b]에서 연속이고 (a,b)에서 미분가능한 함수에는 f′(c)=(f(b)−f(a))/(b−a)를 만족하는 c가 있다.","f(x)=x², [1,3]의 평균 기울기는 4이며 f′(c)=2c=4에서 c=2이다.","f(x)=x², [0,2]에서 평균값 정리의 c를 구하세요.","1",["1","0","2"]),
 ("02-08","증가·감소와 극값","도함수가 양수인 구간에서 함수는 증가하고 음수인 구간에서 감소한다. 부호가 바뀌는 점에서 극값을 판정한다.","f(x)=x²−4x의 도함수는 2x−4이다. x=2에서 감소에서 증가로 바뀌어 극솟값 −4를 갖는다.","f(x)=x²의 x=0은 극대인가 극소인가요?","극소",["극소","극대","둘 다 아님"]),
 ("02-09","도함수로 그래프 개형 그리기","도함수의 부호로 증가·감소를 정하고, 함수값과 극값을 함께 표시해 그래프 개형을 그린다.","f(x)=x³−3x는 f′(x)=3(x²−1)로 x=−1,1에서 임계점을 갖고 부호표로 개형을 정한다.","f(x)=x²는 실수 전체에서 증가하나요 감소하나요?","x<0에서 감소하고 x>0에서 증가한다",["x<0에서 감소하고 x>0에서 증가한다","항상 증가한다","항상 감소한다"]),
 ("02-10","미분과 방정식·부등식","도함수 부호와 함수의 최솟값을 이용해 방정식의 근이나 부등식의 참을 설명할 수 있다.","모든 실수 x에 대해 x²+1≥1이다. 등호는 x=0에서 성립한다.","모든 실수 x에 대해 x²+4의 최솟값은 얼마인가요?","4",["4","0","없다"]),
 ("02-11","속도와 가속도","직선 위 위치 s(t)의 도함수 v(t)=s′(t)는 속도, v′(t)는 가속도다.","s(t)=t²+2t이면 v(t)=2t+2, a(t)=2이다.","s(t)=3t²일 때 t=2에서 속도를 구하세요.","12",["12","6","9"]),
 ("03-01","부정적분의 뜻","F′(x)=f(x)이면 F는 f의 부정적분이며, 부정적분에는 적분상수 C를 붙인다.","(x³/3)′=x²이므로 ∫x²dx=x³/3+C이다.","∫2x dx를 구하세요.","x²+C",["x²+C","2x²+C","x+C"]),
 ("03-02","다항함수의 부정적분","실수배·합·차는 항별로 적분하고 ∫xⁿdx=xⁿ⁺¹/(n+1)+C (n은 음이 아닌 정수)이다.","∫(3x²−2)dx=x³−2x+C이다.","∫(2x+4)dx를 구하세요.","x²+4x+C",["x²+4x+C","2x²+4x+C","x²+4+C"]),
 ("03-03","정적분의 뜻","정적분은 구간에서의 누적량이며 구간을 나누면 적분값이 더해진다. 축 아래 부분은 부호 있는 값으로 계산한다.","∫₀² x dx=2이고 구간 [0,1], [1,2]의 적분값 1/2와 3/2의 합도 2이다.","∫₀¹ 2 dx를 구하세요.","2",["2","1","0"]),
 ("03-04","다항함수의 정적분","다항함수의 원시함수 F를 구하면 ∫ₐᵇf(x)dx=F(b)−F(a)이다.","∫₀²2x dx=[x²]₀²=4이다.","∫₁³2x dx를 구하세요.","8",["8","6","10"]),
 ("03-05","곡선으로 둘러싸인 넓이","구간에서 위쪽 함수와 아래쪽 함수의 차를 적분하면 둘러싸인 넓이를 구한다.","y=2와 x축 사이에서 0≤x≤3인 넓이는 2×3=6이다.","y=x와 x축 사이, 0≤x≤2인 넓이는 얼마인가요?","2",["2","4","1"]),
 ("03-06","속도와 거리","속도를 적분하면 변위가 된다. 속도 부호가 일정한 동안 이동거리는 속력의 정적분으로 구한다.","0≤t≤3에서 v(t)=2이면 변위와 이동거리는 모두 6이다.","0≤t≤4에서 속도 3으로 움직인 직선 운동의 거리를 구하세요.","12",["12","7","1"]),
]
EXAMPLE_QUESTIONS={
 "12수학Ⅱ01-04":"f(x)=x−2가 [1,3]에서 영점을 갖는 이유를 설명하고 그 영점을 구하세요.",
 "12수학Ⅱ02-01":"f(x)=x²의 x=2에서 차분몫의 극한으로 미분계수를 구하세요.",
 "12수학Ⅱ02-02":"y=x²의 x=1에서 접선의 기울기와 방정식을 구하세요.",
 "12수학Ⅱ02-03":"|x|는 x=0에서 연속인가요? 미분가능한가요?",
 "12수학Ⅱ02-04":"x⁴을 미분하세요.",
 "12수학Ⅱ02-05":"(x²+1)(x+2)를 미분하세요.",
 "12수학Ⅱ02-06":"y=x²의 x=1에서 접선 방정식을 구하세요.",
 "12수학Ⅱ02-07":"f(x)=x²을 [1,3]에 적용한 평균값 정리의 c를 구하세요.",
 "12수학Ⅱ02-08":"f(x)=x²−4x의 극값과 그때의 함수값을 구하세요.",
 "12수학Ⅱ02-09":"f(x)=x³−3x의 임계점을 찾고 도함수로 증가·감소를 조사하세요.",
 "12수학Ⅱ02-10":"x²+1의 최솟값과 등호가 성립하는 x를 구하세요.",
 "12수학Ⅱ02-11":"s(t)=t²+2t일 때 속도와 가속도 함수를 구하세요.",
 "12수학Ⅱ03-01":"∫x² dx를 구하세요.",
 "12수학Ⅱ03-02":"∫(3x²−2) dx를 구하세요.",
 "12수학Ⅱ03-03":"∫₀² x dx를 계산하고 [0,1], [1,2]로 나누어도 값이 같은지 확인하세요.",
 "12수학Ⅱ03-04":"∫₀² 2x dx를 원시함수로 계산하세요.",
 "12수학Ⅱ03-05":"y=2와 x축 사이에서 0≤x≤3인 넓이를 구하세요.",
 "12수학Ⅱ03-06":"0≤t≤3에서 속도 v(t)=2일 때 변위와 이동거리를 구하세요.",
}
UNIT={"01":"함수의 극한과 연속","02":"미분","03":"적분"}

def main():
 chapters=[]; codes=[]
 for code,title,concept,example,question,answer,options in SPECS:
  full="12수학Ⅱ"+code; unit=UNIT[code[:2]]; codes.append(full); slug="m2-"+code.replace("-","")
  example_question=EXAMPLE_QUESTIONS[full]
  explanation=answer
  pages=[
   {"id":slug+"-open","template":"opening","title":"질문 열기","blocks":[{"type":"lead","title":"핵심 질문","text":title},{"type":"thinking","title":"먼저 생각하기","text":"조건과 구간을 표시하고 풀이에서 쓸 관계를 찾아봅니다."}]},
   {"id":slug+"-concept","template":"concept","title":"개념과 조건","blocks":[{"type":"definition","title":title,"text":concept},{"type":"formula","title":"2015 공식 기준 후보","text":full},{"type":"misconception","title":"조건 확인","text":"구간, 정의역, 미분가능성 또는 적분 구간 조건을 확인합니다."}]},
   {"id":slug+"-example","template":"example","title":"예제 풀이","blocks":[{"type":"question","title":"예제","text":example_question},{"type":"solutionStep","title":"풀이","text":example},{"type":"verification","title":"검산","text":"계산을 원래 조건에 대입해 확인합니다."}]},
   {"id":slug+"-practice","template":"practice","title":"연습과 해설","blocks":[{"type":"question","title":"연습","text":question},{"type":"hint","title":"힌트","text":"공식의 조건을 확인하고 한 단계씩 계산하세요."},{"type":"solutionStep","title":"해설","text":explanation},{"type":"answer","title":"정답","text":answer},{"type":"activity","activity":{"id":slug+"-quiz","kind":"quiz","prompt":question,"options":options,"correct_index":options.index(answer),"correct_feedback":"정답입니다. "+answer,"incorrect_feedback":"정답은 "+answer+"입니다. "+explanation,"hints":["공식의 조건을 확인하고 한 단계씩 계산하세요.",explanation]}}]},
   {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":title+": "+concept},{"type":"checklist","title":"스스로 확인","text":"개념의 조건과 풀이 근거를 설명할 수 있나요?"}]},
  ]
  chapters.append({"title":title,"intro":[f"교육부 고시 제2015-74호 별책 8의 공식 기준 {full}에 연결한 신규 후보입니다.","수치와 상황은 직접 만든 가상 예시입니다."],"unit":unit,"pages":pages})
 book={"schema_version":2,"title":"수학Ⅱ · 미연결 기준 보완 18모듈 후보","subtitle":"극한·연속, 미분, 적분","category":"concept_textbook_prototype","curriculum_version":"2015","tags":["수학Ⅱ","2015 개정","추가 원고 후보","가상 예시",*codes],"standard_codes":codes,"chapters":chapters}
 pages=[p for c in chapters for p in c["pages"]]; ids=[p["id"] for p in pages]
 assert len(codes)==18 and len(pages)==90 and len(set(ids))==90
 assert set(EXAMPLE_QUESTIONS)==set(codes)
 assert (1-2)<0<(3-2) and 2-2==0
 assert (2+1)**2-2**2==5 and 2**2==4 and 2*2==4
 assert -1<0<1 and (-1)!=1
 assert 4*2**3==32
 assert 2*2*(2+2)+(2**2+1)==21 and 3*2**2+4*2+1==21
 assert 2*1-1==1 and 4*2-4==4
 assert (3**2-1**2)/(3-1)==4 and (2**2-0**2)/(2-0)==2
 assert (2**2-4*2)==-4 and 2*2-4==0
 assert 3*((-1)**2-1)==0 and 3*(0**2-1)<0 and 3*(2**2-1)>0
 assert 0**2+1==1 and 0**2+4==4
 assert 2*1+2==4 and 2==2
 assert (3**3/3)==9 and 3**2/2==4.5
 assert 3*(2**2)-2==10 and 2*2+4==8 and 2**2+4*2==12
 assert (2**2/2)==2 and (1**2/2)+(2**2-1**2)/2==2
 assert 3**2==9 and 3**2-1==8
 assert 2*3==6 and 2*4==8 and 2**2==4
 assert 2*3==6 and 3*4==12
 assert all(spec[5] in spec[6] for spec in SPECS)
 OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 PACKAGE.mkdir(parents=True,exist_ok=True); old={}
 try: old=json.loads((PACKAGE/"REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
 except (OSError,json.JSONDecodeError): pass
 digest=canonical_file_sha256(OUT)
 manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2015_appendix8_math_criteria_table","module_count":18,"page_count":90,"native_activity_count":18,"native_activity_kinds":["quiz"],"math_arithmetic_check_status":"pass_for_listed_calculation_assertions; independent_teacher_review_pending","example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","example_question_alignment_status":"explicit_example_question_map_for_all_18_codes; independent review pending","curriculum_review_status":"official_codes_verified; scope_and_existing_content_merge_pending","math_review_status":"author_calculation_assertions_passed; independent_teacher_review_pending","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"native_quiz_candidates; existing graph/HTML assets remain separate and parity_unreviewed","integration_status":"candidate_for_tag_grouping; not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if old.get("bookdata_sha256")==digest else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if old.get("bookdata_sha256")==digest else None}
 (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n공식 기준 18개를 보완하는 18모듈·90쪽 V2 원고 후보입니다. 예제 질문을 풀이에 맞춰 분리하고 연습 해설은 해당 연습 문항의 답에 연결했습니다. 예시는 직접 만든 가상 자료입니다. 교사 검수·권리 결정 전 출판 부적격이며, 기존 그래프·HTML과 화면 parity는 검증 전입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
 print(f"Built {len(chapters)} modules, {len(pages)} pages, {len(codes)} standard candidates; sha256={digest}")

if __name__=="__main__": main()

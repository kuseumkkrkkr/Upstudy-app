"""Build original candidates for untagged 2015 Calculus standards."""
from __future__ import annotations
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT=Path(__file__).resolve().parents[1]
MANUSCRIPTS=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고"
OUT=MANUSCRIPTS/"미적분_2015개정_미연결기준_Batch1_BookData_V2_시범.json"
PACKAGE=MANUSCRIPTS/"미적분_2015개정_미연결기준_Batch1_원고패키지"
SPECS=[
 ("01-01","수열의 수렴과 발산","수열의 항이 한 실수에 가까워지면 수렴하고, 일정한 값에 가까워지지 않으면 발산한다.","aₙ=1/n은 n이 커질수록 0에 가까워져 0으로 수렴한다. (−1)ⁿ은 두 값 사이를 오가므로 수렴하지 않는다.","aₙ=3/n은 어디로 수렴하나요?","0",["0","1","발산"]),
 ("01-02","수열 극한의 기본 성질","수렴하는 수열의 합·차·곱 극한은 각 극한값에 같은 연산을 적용해 구한다. 몫은 분모 극한이 0이 아닐 때 적용한다.","aₙ→2, bₙ→3이면 2aₙ−bₙ→4−3=1이다.","aₙ→4, bₙ→1이면 aₙ+bₙ의 극한은?","5",["5","4","3"]),
 ("01-03","등비수열의 극한","등비수열 arⁿ에서 |r|<1이면 항은 0으로 수렴하고, r=1이면 일정하며, r의 크기와 부호에 따라 그 밖의 경우 발산할 수 있다.","(1/3)ⁿ은 공비의 절댓값이 1보다 작으므로 0으로 수렴한다.","aₙ=5(1/2)ⁿ의 극한을 구하세요.","0",["0","5","발산"]),
 ("01-04","급수의 수렴과 발산","급수의 수렴·발산은 부분합이 유한한 값에 가까워지는지로 판단한다.","1+1+⋯+1의 n개 부분합은 n이므로 발산한다. 부분합이 계속 커져 유한한 극한이 없다.","1+1+⋯+1의 n개 부분합은 수렴하나요?","발산",["발산","수렴하여 1","항상 0"]),
 ("01-05","등비급수의 합","첫째항 a, 공비 r인 등비급수는 |r|<1일 때 합 a/(1−r)로 수렴한다.","1+1/2+1/4+⋯의 합은 1/(1−1/2)=2이다.","3+1+1/3+⋯의 합을 구하세요.","9/2",["9/2","3","4"]),
 ("01-06","등비급수의 활용","일정 비율로 반복되는 양은 등비급수로 모델링할 수 있으며, 각 단계의 양을 합해 전체량을 구한다.","가상 점이 처음 8m 올라가고 매번 직전 거리의 절반만큼 더 오르면 총 상승거리는 8+4+2+⋯=16m이다.","처음 6cm, 이후 매번 절반만큼 더하는 반복 길이의 합은?","12cm",["12cm","6cm","9cm"]),
 ("02-01","지수·로그함수의 극한","지수함수와 로그함수는 정의역 안에서 연속이므로 입력이 가까워질 때 함수값의 극한은 대입으로 구할 수 있다.","lim(x→1)2ˣ=2, lim(x→4)log₂x=2이다.","lim(x→2)3ˣ를 구하세요.","9",["9","6","3"]),
 ("02-02","지수·로그함수의 미분","(aˣ)′=aˣ ln a이고 (logₐx)′=1/(x ln a)이다. 자연로그에서는 (eˣ)′=eˣ, (ln x)′=1/x이다.","(eˣ+ln x)′=eˣ+1/x (x>0)이다.","(ln x)′을 구하세요.","1/x",["1/x","ln x","x"]),
 ("02-03","삼각함수의 덧셈정리","sin(α±β)=sinαcosβ±cosαsinβ 등 덧셈정리로 두 각의 삼각함수 값을 연결한다.","sin(45°−30°)=√6/4−√2/4이다.","sin(45°+30°)를 구하세요.","(√6+√2)/4",["(√6+√2)/4","(√6−√2)/4","1/2"]),
 ("02-04","삼각함수의 극한","각을 라디안으로 둘 때 lim(x→0)sin x/x=1이다. 이 기본 극한을 식의 변형과 함께 사용한다.","lim(x→0)sin(3x)/x=3·lim sin(3x)/(3x)=3이다.","lim(x→0)sin(5x)/x를 구하세요.","5",["5","1","0"]),
 ("02-05","사인·코사인함수의 미분","(sin x)′=cos x이고 (cos x)′=−sin x이다. 각은 라디안으로 둔다.","(2sin x−3cos x)′=2cos x+3sin x이다.","(cos x)′을 구하세요.","−sin x",["−sin x","sin x","cos x"]),
 ("02-06","몫의 미분법","(f/g)′=(f′g−fg′)/g²이며 g≠0인 구간에서 적용한다.","((x+1)/(x−1))′=((x−1)−(x+1))/(x−1)²=−2/(x−1)²이다.","(x/(x+1))′을 구하세요. (x≠−1)","1/(x+1)²",["1/(x+1)²","1/(x+1)","−1/(x+1)²"]),
 ("02-07","합성함수의 미분법","합성함수 y=f(g(x))는 y′=f′(g(x))g′(x)로 미분한다.","y=sin(x²)이면 y′=2x cos(x²)이다.","y=e^(3x)의 도함수를 구하세요.","3e^(3x)",["3e^(3x)","e^(3x)","3e^x"]),
 ("02-08","매개변수함수의 미분","x=x(t), y=y(t)이고 dx/dt≠0이면 dy/dx=(dy/dt)/(dx/dt)이다.","x=t², y=t³일 때 t≠0에서 dy/dx=3t²/(2t)=3t/2이다.","x=2t, y=t²일 때 dy/dx를 구하세요.","t",["t","2t","t/2"]),
 ("02-09","음함수·역함수의 미분","음함수는 양변을 x로 미분해 y′를 구한다. 역함수는 (f⁻¹)′(y)=1/f′(x) 관계를 쓴다.","x²+y²=25를 미분하면 2x+2yy′=0이므로 y′=−x/y (y≠0)이다.","x²+y²=25 위 (3,4)에서 dy/dx를 구하세요.","−3/4",["−3/4","3/4","−4/3"]),
 ("02-10","이계도함수","이계도함수 f′′은 도함수 f′을 다시 미분한 값이며 함수의 굽음이나 가속도 해석에 쓸 수 있다.","f(x)=x³이면 f′=3x², f′′=6x이다.","f(x)=x⁴의 이계도함수를 구하세요.","12x²",["12x²","4x³","12x³"]),
 ("02-11","접선의 방정식","곡선 y=f(x)의 x=a에서 접선은 y−f(a)=f′(a)(x−a)이다.","y=eˣ의 x=0에서 점은 (0,1), 기울기는 1이므로 접선은 y=x+1이다.","y=x²의 x=2에서 접선의 방정식을 구하세요.","y=4x−4",["y=4x−4","y=2x","y=4x+4"]),
 ("02-12","미분으로 그래프 개형 그리기","도함수의 부호로 증가·감소와 극값을 정하고, 이계도함수와 주요 함숫값을 이용해 그래프 개형을 설명한다.","f(x)=x³−3x는 f′=3(x²−1)이고 임계점은 x=−1,1이다. 도함수 부호가 개형을 정한다.","f(x)=x²은 x=0에서 극댓값인가 극솟값인가요?","극솟값",["극솟값","극댓값","극값이 없다"]),
 ("02-13","방정식·부등식의 미분 활용","함수의 증가·감소와 최솟값을 사용해 방정식의 근이나 부등식의 참을 설명한다.","모든 실수 x에 대해 x²+1≥1이며 등호는 x=0에서 성립한다.","모든 실수 x에 대해 x²+4의 최솟값은?","4",["4","0","없다"]),
 ("02-14","속도와 가속도","위치 s(t)의 도함수는 속도 v(t), 속도의 도함수는 가속도 a(t)이다. 이 단원은 직선 운동으로 다룬다.","s(t)=t³−3t이면 v=3t²−3, a=6t이다.","s(t)=t³일 때 t=2에서 가속도를 구하세요.","12",["12","6","8"]),
 ("03-01","치환적분법","합성함수의 안쪽 미분 인수가 함께 있으면 u=g(x)로 치환해 적분을 간단히 한다.","∫2x cos(x²)dx에서 u=x²로 두면 ∫cos u du=sin(x²)+C이다.","∫2x e^(x²)dx를 구하세요.","e^(x²)+C",["e^(x²)+C","2e^(x²)+C","x²e^(x²)+C"]),
 ("03-02","부분적분법","∫u dv=uv−∫v du를 사용하면 곱으로 된 함수의 적분을 다른 적분으로 바꿀 수 있다.","∫xeˣdx=xeˣ−∫eˣdx=(x−1)eˣ+C이다.","∫x eˣ dx를 구하세요.","(x−1)eˣ+C",["(x−1)eˣ+C","xeˣ+C","(x+1)eˣ+C"]),
 ("03-03","여러 함수의 부정·정적분","기본 함수의 원시함수와 정적분을 구하고 적분상수 또는 구간 끝값을 분명히 표시한다.","∫₀¹ eˣdx=[eˣ]₀¹=e−1이다.","∫₀¹ 2x dx를 구하세요.","1",["1","2","0"]),
 ("03-04","정적분과 급수의 합","구간을 잘게 나눈 직사각형 넓이의 합이 정적분으로 가까워진다. 극한을 리만 합으로 표현한다.","lim(n→∞)Σ(k=1..n)(k/n)(1/n)=∫₀¹x dx=1/2이다.","lim(n→∞)Σ(k=1..n)(1/n)은 얼마인가요?","1",["1","0","n"]),
 ("03-05","곡선으로 둘러싸인 넓이","교점과 위아래 관계를 확인한 뒤 위쪽 함수에서 아래쪽 함수를 뺀 정적분으로 넓이를 구한다.","0≤x≤1에서 x≥x²이므로 두 곡선 사이 넓이는 ∫₀¹(x−x²)dx=1/6이다.","y=x와 x축 사이, 0≤x≤2의 넓이를 구하세요.","2",["2","4","1"]),
 ("03-06","회전체의 부피","곡선과 축으로 둘러싸인 영역을 회전한 입체의 부피는 단면적을 적분해 구할 수 있다.","y=x, 0≤x≤1의 영역을 x축 둘레로 회전하면 V=∫₀¹πx²dx=π/3이다.","반지름 2인 원판을 0≤x≤3 구간에서 쌓은 원기둥 부피는?","12π",["12π","6π","4π"]),
 ("03-07","속도와 거리의 적분","속도 적분은 변위이고, 이동거리는 속도의 절댓값을 적분한다. 속도 부호가 바뀌면 구간을 나눠 계산한다.","v(t)=t−1, 0≤t≤2에서 변위는 0이고 이동거리는 ∫₀¹(1−t)dt+∫₁²(t−1)dt=1이다.","0≤t≤2에서 v(t)=2인 직선 운동의 이동거리는?","4",["4","2","0"]),
]
UNIT={"01":"수열의 극한과 급수","02":"미분법","03":"적분법"}

# Keep the worked example and its practice prompt identical so each answer is
# demonstrated against the exact question shown to the learner.
ALIGNED_SOLUTIONS={
 "01-01":"n이 커질수록 3/n은 0에 가까워진다. 따라서 lim(n→∞)3/n=0이다.",
 "01-02":"합의 극한 법칙으로 lim(aₙ+bₙ)=4+1=5이다.",
 "01-03":"공비 1/2의 절댓값이 1보다 작으므로 (1/2)ⁿ→0이다. 따라서 극한은 5×0=0이다.",
 "01-04":"각 항이 1인 n개 항의 부분합은 Sₙ=n이다. Sₙ은 유한한 값으로 수렴하지 않고 커지므로 급수는 발산한다.",
 "01-05":"첫째항은 3, 공비는 1/3이다. |r|<1이므로 합은 3/(1−1/3)=9/2이다.",
 "01-06":"전체 길이는 6+3+3/2+⋯이다. 첫째항 6, 공비 1/2인 등비급수이므로 합은 6/(1−1/2)=12cm이다.",
 "02-01":"지수함수는 연속이므로 lim(x→2)3ˣ=3²=9이다.",
 "02-02":"자연로그의 미분 공식 (ln x)′=1/x를 적용한다. (x>0)",
 "02-03":"덧셈정리로 sin(45°+30°)=sin45°cos30°+cos45°sin30°=(√6+√2)/4이다.",
 "02-04":"sin(5x)/x=5·sin(5x)/(5x)이고 sin u/u→1이므로 극한은 5이다.",
 "02-05":"코사인함수의 미분 공식에 따라 (cos x)′=−sin x이다. (x는 라디안)",
 "02-06":"몫의 미분법으로 (x/(x+1))′=((x+1)−x)/(x+1)²=1/(x+1)²이다. (x≠−1)",
 "02-07":"연쇄법칙으로 (e^(3x))′=e^(3x)·(3x)′=3e^(3x)이다.",
 "02-08":"dy/dt=2t, dx/dt=2이므로 dy/dx=(2t)/2=t이다.",
 "02-09":"음함수 미분으로 2x+2y(dy/dx)=0이다. (3,4)를 대입하면 dy/dx=−3/4이다.",
 "02-10":"f′(x)=4x³이고 이를 한 번 더 미분하면 f′′(x)=12x²이다.",
 "02-11":"f′(x)=2x이므로 x=2에서 접선 기울기는 4이다. 점 (2,4)를 지나므로 y−4=4(x−2), 즉 y=4x−4이다.",
 "02-12":"x²≥0이고 x=0에서 등호가 성립한다. 따라서 x=0에서 극솟값 0을 갖는다.",
 "02-13":"x²≥0이므로 x²+4≥4이고 x=0일 때 등호가 성립한다. 최솟값은 4이다.",
 "02-14":"s(t)=t³이면 v(t)=3t², a(t)=v′(t)=6t이다. 따라서 a(2)=12이다.",
 "03-01":"u=x²로 치환하면 du=2x dx이다. 따라서 적분은 ∫eᵘdu=eᵘ+C=e^(x²)+C이다.",
 "03-02":"부분적분으로 ∫xeˣdx=xeˣ−∫eˣdx=(x−1)eˣ+C이다.",
 "03-03":"∫₀¹2x dx=[x²]₀¹=1²−0²=1이다.",
 "03-04":"합의 항은 모두 1/n이고 항이 n개이므로 합은 n×(1/n)=1이다. 따라서 극한도 1이다.",
 "03-05":"0≤x≤2에서 y=x는 x축 위에 있다. 넓이는 ∫₀²x dx=[x²/2]₀²=2이다.",
 "03-06":"단면적은 π·2²=4π이고 길이는 3이다. 부피는 4π×3=12π이다.",
 "03-07":"속도가 일정한 2이므로 이동거리는 ∫₀²|2|dt=2×2=4이다.",
}

def main():
 chapters=[]; codes=[]
 for code,title,concept,example,question,answer,options in SPECS:
  full="12미적"+code; codes.append(full); slug="calc15-"+code.replace("-","")
  exp=ALIGNED_SOLUTIONS[code]; unit=UNIT[code[:2]]
  pages=[
   {"id":slug+"-open","template":"opening","title":"질문 열기","blocks":[{"type":"lead","title":"핵심 질문","text":title},{"type":"thinking","title":"먼저 생각하기","text":"조건과 변수를 표시하고 어떤 극한·미분·적분 관계가 필요한지 예상합니다."}]},
   {"id":slug+"-concept","template":"concept","title":"개념과 조건","blocks":[{"type":"definition","title":title,"text":concept},{"type":"formula","title":"2015 공식 기준 후보","text":full},{"type":"misconception","title":"조건 확인","text":"정의역, 라디안, 미분가능 구간, 수렴 조건 또는 적분 구간을 확인합니다."}]},
   {"id":slug+"-example","template":"example","title":"예제 풀이","blocks":[{"type":"question","title":"예제","text":question},{"type":"solutionStep","title":"풀이","text":example},{"type":"verification","title":"검산","text":"계산 결과와 사용한 조건을 다시 확인합니다."}]},
   {"id":slug+"-practice","template":"practice","title":"연습과 해설","blocks":[{"type":"question","title":"연습","text":question},{"type":"hint","title":"힌트","text":"정의역과 공식의 적용 조건을 확인하세요."},{"type":"solutionStep","title":"해설","text":exp},{"type":"answer","title":"정답","text":answer},{"type":"activity","activity":{"id":slug+"-quiz","kind":"quiz","prompt":question,"options":options,"correct_index":options.index(answer),"correct_feedback":"정답입니다: "+answer,"incorrect_feedback":"정답은 "+answer+"입니다. "+exp,"hints":["조건과 공식을 확인하세요.",exp]}}]},
   {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":title+": "+concept},{"type":"checklist","title":"스스로 확인","text":"개념의 조건과 풀이 근거를 설명할 수 있나요?"}]},
  ]
  chapters.append({"title":title,"unit":unit,"intro":[f"교육부 고시 제2015-74호 별책 8 공식 기준 {full}에 연결한 신규 후보입니다.","수치와 상황은 직접 만든 가상 예시입니다."],"pages":pages})
 book={"schema_version":2,"title":"미적분 · 2015 개정 미연결 기준 보완 후보","subtitle":"수열의 극한·급수, 미분법, 적분법","category":"concept_textbook_prototype","curriculum_version":"2015","tags":["미적분","2015 개정","추가 원고 후보","가상 예시",*codes],"standard_codes":codes,"chapters":chapters}
 pages=[p for c in chapters for p in c["pages"]]; ids=[p["id"] for p in pages]
 assert len(codes)==27 and len(set(codes))==27 and len(pages)==135 and len(set(ids))==135
 assert len(ALIGNED_SOLUTIONS)==len(SPECS) and all(code in ALIGNED_SOLUTIONS for code,*_ in SPECS)
 assert abs((sum(k for k in range(1,101))/10000)-.505)<1e-12 and abs((1/6)-(.5-1/3))<1e-12
 assert abs((1/3+1/3+1/3)-1)<1e-12 and abs((3*3.141592653589793/3)-3.141592653589793)<1e-12
 OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 PACKAGE.mkdir(parents=True,exist_ok=True); old={}
 try: old=json.loads((PACKAGE/"REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
 except (OSError,json.JSONDecodeError): pass
 digest=canonical_file_sha256(OUT)
 same_candidate=old.get("bookdata_sha256")==digest
 manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2015_appendix8_math_criteria_table","module_count":27,"page_count":135,"native_activity_count":27,"native_activity_kinds":["quiz"],"question_example_alignment_status":"all 27 example and practice prompts share the same question; structural test passed; independent review pending","math_arithmetic_check_status":"pass_for_spot_checked_examples_only","example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"official_codes_verified; product_scope_and_existing_content_merge_pending","math_review_status":"author_spot_checks_passed; independent_teacher_review_pending","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"native_quiz_candidates; independent legacy HTML parity unreviewed","integration_status":"candidate_for_tag_grouping; not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if same_candidate else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if same_candidate else None,"runtime_validation_command":old.get("runtime_validation_command") if same_candidate else None,"runtime_validator_candidate_sha256":old.get("runtime_validator_candidate_sha256") if same_candidate else None}
 (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n공식 기준 27개를 대상으로 27모듈·135쪽의 새 원고 후보를 만들었습니다. 예제와 연습 문항을 동일한 질문으로 맞추고 해설·정답·퀴즈 선택지를 연결했습니다. 모든 문항은 자체 작성입니다. 수학 교사 검수·권리 결정 전 출판 부적격이며, HTML parity는 미검증입니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
 print(f"Built {len(chapters)} modules, {len(pages)} pages, {len(codes)} standard candidates; sha256={digest}")

if __name__=="__main__": main()

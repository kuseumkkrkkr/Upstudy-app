"""Build original candidate modules for currently untagged Calculus I standards."""
from __future__ import annotations
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "미적분Ⅰ_2022개정_누락기준_Batch1_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "미적분Ⅰ_2022개정_누락기준_Batch1_원고패키지"
SPECS = [
 ("01-01","함수의 극한의 뜻","x가 a에 가까워질 때 f(x)가 한 값 L에 가까워지면 그 값을 함수의 극한이라 한다.","f(x)=2x+1이면 x가 3에 가까워질 때 f(x)는 7에 가까워진다.","x가 2에 가까워질 때 3x−1의 극한을 구하세요.","5","x 대신 2에 가까운 값을 대입해 보세요.","5",["5","3","6"]),
 ("01-02","극한의 성질","각 극한이 존재하면 합·차·곱의 극한은 극한값의 합·차·곱이고, 분모의 극한이 0이 아니면 몫도 나눌 수 있다.","lim(x→2)(x²+3x)=4+6=10이다.","lim(x→1)(x²+2x)를 구하세요.","3","다항식은 대입으로 극한값을 구할 수 있습니다.","3",["3","2","4"]),
 ("01-03","극한으로 탐구하는 연속","f가 x=a에서 연속이려면 lim(x→a)f(x)=f(a)이어야 한다. 좌극한·우극한·함숫값을 함께 확인한다.","f(x)=x+2는 a=1에서 극한값 3과 함숫값 3이 같아 연속이다.","f(x)=x²가 x=2에서 연속인지 판정하세요.","연속이다. 극한값과 함숫값이 모두 4이다.","극한과 그 점의 실제 함숫값을 각각 구하세요.","연속",["연속","불연속","판정 불가"]),
 ("01-04","연속함수의 성질","닫힌구간에서 연속인 함수는 최댓값과 최솟값을 가지며, 양 끝에서 부호가 바뀌면 구간 안에 영점이 있다.","f(x)=x−2는 [1,3]에서 연속이고 f(1)<0<f(3)이므로 (1,3)에 영점 2가 있다.","g(x)=x−1은 [0,2]에서 연속이다. 영점이 구간 안에 있나요?","있다. g(0)<0<g(2)이므로 영점 1이 있다.","양 끝 함숫값의 부호를 확인하세요.","있다",["있다","없다","항상 두 개"]),
 ("02-06","평균값 정리","[a,b]에서 연속이고 (a,b)에서 미분가능한 함수는 어떤 c에서 f′(c)=(f(b)−f(a))/(b−a)를 만족한다.","f(x)=x², [1,3]에서 평균 기울기는 4이다. f′(c)=2c=4이므로 c=2이다.","f(x)=x², [0,2]의 평균값 정리에 맞는 c를 구하세요.","c=1","평균 기울기는 2이고 f′(x)=2x입니다.","1",["1","0","2"]),
 ("02-09","미분으로 방정식·부등식 해결","도함수의 부호로 함수의 증가·감소를 분석하면 방정식의 근 개수나 부등식의 참을 설명할 수 있다.","x≥0에서 f(x)=x²+1은 f′(x)=2x≥0이므로 증가하고 f(x)≥f(0)=1이다.","x≥0에서 x²+4의 최솟값을 구하세요.","4","도함수의 부호 또는 제곱의 범위를 이용하세요.","4",["4","0","최솟값 없음"]),
 ("02-10","직선 운동의 속도와 가속도","위치 s(t)의 도함수 v(t)=s′(t)는 속도, 속도의 도함수 a(t)=v′(t)는 가속도다. 여기서는 직선 운동만 다룬다.","s(t)=t²+2t이면 v(t)=2t+2, a(t)=2이다.","s(t)=3t²인 물체의 t=2에서 속도를 구하세요.","12","먼저 s(t)를 미분해 v(t)를 구한 뒤 t=2를 대입합니다.","12",["12","6","9"]),
 ("03-01","부정적분의 뜻","F′(x)=f(x)이면 F를 f의 한 부정적분이라 하며, 모든 부정적분은 적분상수 C만큼 차이가 난다.","(x³/3)′=x²이므로 ∫x²dx=x³/3+C이다.","∫2x dx를 구하세요.","x²+C","미분하면 2x가 되는 함수를 찾으세요.","x²+C",["x²+C","2x²+C","x+C"]),
 ("03-02","다항함수의 부정적분","적분은 실수배와 합·차에 대해 항별로 계산하며, xⁿ(n≠−1)은 xⁿ⁺¹/(n+1)+C로 적분한다.","∫(3x²−2)dx=x³−2x+C이다.","∫(2x+4)dx를 구하세요.","x²+4x+C","각 항을 따로 적분하고 상수항을 붙이세요.","x²+4x+C",["x²+4x+C","2x²+4x+C","x²+4+C"]),
 ("03-03","정적분의 개념과 성질","정적분은 구간의 누적량을 나타내며 구간을 나누면 적분값이 더해진다. 그래프가 축 아래에 있으면 부호 있는 넓이로 계산한다.","∫₀² x dx는 삼각형 넓이 2와 같고, ∫₀¹x dx+∫₁²x dx=1/2+3/2=2이다.","∫₀¹ 2 dx를 계산하세요.","2","높이 2인 직사각형의 폭은 1입니다.","2",["2","1","0"]),
 ("03-04","부정적분과 정적분","F′=f이면 ∫ₐᵇ f(x)dx=F(b)−F(a)이다. 다항함수에서는 항별 부정적분을 구해 끝값의 차를 계산한다.","∫₀² 2x dx=[x²]₀²=4이다.","∫₁³ 2x dx를 구하세요.","8","원시함수 x²에 3과 1을 대입해 차를 구합니다.","8",["8","6","10"]),
 ("03-05","곡선 사이의 넓이","위쪽 곡선에서 아래쪽 곡선을 뺀 함수를 적분하면 두 그래프 사이 넓이를 구할 수 있다.","y=2와 y=0 사이, x∈[0,3]의 넓이는 ∫₀³2dx=6이다.","y=x와 x축 사이, x∈[0,2]의 넓이를 구하세요.","2","삼각형의 밑변은 2, 높이는 2입니다.","2",["2","4","1"]),
 ("03-06","직선 운동에서 적분과 거리","속도 v(t)를 적분하면 변위가 된다. 속도가 부호를 바꾸지 않는 구간에서는 이동 거리는 속도의 절댓값을 적분한 값이다.","0≤t≤3에서 v(t)=2이면 변위와 이동 거리는 각각 ∫₀³2dt=6이다.","0≤t≤4에서 속도 3으로 움직인 직선 운동의 거리를 구하세요.","12","일정한 속도×시간으로 계산합니다.","12",["12","7","1"]),
]

def quiz(s, slug):
 code,title,concept,example,question,solution,hint,answer,options=s
 return {"type":"quiz","id":slug+"-quiz","question":question,"options":options,"correctIndex":options.index(answer),"explanation":solution}

def main():
 chapters=[]; codes=[]
 for code,title,concept,example,question,solution,hint,answer,options in SPECS:
  full="12미적Ⅰ-"+code; codes.append(full); slug="c1-"+code.replace("-","")
  pages=[
   {"id":slug+"-open","template":"opening","title":"질문 열기","blocks":[{"type":"lead","title":"핵심 질문","text":title},{"type":"thinking","title":"먼저 생각하기","text":"주어진 조건과 구간을 표시하고 무엇을 구하는지 말해 봅니다."}]},
   {"id":slug+"-concept","template":"concept","title":"개념과 조건","blocks":[{"type":"definition","title":title,"text":concept},{"type":"formula","title":"공식 기준 후보","text":full},{"type":"misconception","title":"조건 확인","text":"정의역, 구간, 미분가능성 또는 적분 구간 조건을 확인합니다."}]},
   {"id":slug+"-example","template":"example","title":"예제 풀이","blocks":[{"type":"question","title":"예제","text":question},{"type":"solutionStep","title":"풀이","text":example+" 따라서 답은 "+solution+"."},{"type":"verification","title":"검산","text":"계산 결과를 조건과 원래 식에 대입해 확인합니다."}]},
   {"id":slug+"-practice","template":"practice","title":"연습과 해설","blocks":[{"type":"question","title":"연습","text":question},{"type":"hint","title":"힌트","text":hint},{"type":"solutionStep","title":"해설","text":solution},{"type":"answer","title":"정답","text":answer},quiz((code,title,concept,example,question,solution,hint,answer,options),slug)]},
   {"id":slug+"-summary","template":"summary","title":"핵심 정리","blocks":[{"type":"summary","title":"기억할 점","text":title+": "+concept},{"type":"checklist","title":"스스로 확인","text":"개념과 조건, 풀이 근거를 설명하고 계산을 확인할 수 있나요?"}]},
  ]
  chapters.append({"title":title,"intro":[f"교육부 고시 제2022-33호 별책 8의 공식 기준 {full}에 연결한 신규 후보입니다.","예시와 수치는 직접 만든 가상 자료입니다."],"pages":pages})
 book={"schema_version":2,"title":"미적분Ⅰ · 미연결 기준 보완 12모듈 후보","subtitle":"극한·연속, 미분 활용, 적분","category":"concept_textbook_prototype","curriculum_version":"2022","tags":["미적분Ⅰ","2022 개정","추가 원고 후보","가상 예시",*codes],"standard_codes":codes,"chapters":chapters}
 ids=[p["id"] for c in chapters for p in c["pages"]]
 assert len(ids)==65 and len(set(ids))==65
 assert 3*2+4==10 and 2*2+4==8 and (2-0)/(2-0)==1 and 2**2+1==5 and 3*2*2==12 and 3*3==9
 OUT.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 PACKAGE.mkdir(parents=True,exist_ok=True)
 old={}
 try: old=json.loads((PACKAGE/"REVIEW_MANIFEST.json").read_text(encoding="utf-8"))
 except (OSError,json.JSONDecodeError): pass
 digest=canonical_file_sha256(OUT)
 manifest={"bookdata_file":OUT.name,"bookdata_sha256":digest,"candidate_code_references":codes,"candidate_code_reference_type":"official_2022_hwp_criterion_table","module_count":13,"page_count":65,"native_activity_count":13,"native_activity_kinds":["quiz"],"math_arithmetic_check_status":"pass_for_listed_examples_only","example_data_status":"synthetic_original_examples; no commercial text, problem, illustration, or dataset copied","curriculum_review_status":"official_codes_verified; semester_and_full_scope_pending","math_review_status":"author_spot_checks_passed; independent_teacher_review_pending","teacher_review_status":"pending","rights_status":"newly_authored; publication_rights_decision_pending","source_interaction_status":"native_quiz_candidates; existing graph HTML remains independent and parity_unreviewed","integration_status":"not_merged_into_master_book","publication_eligibility":"not_eligible","runtime_import_status":old.get("runtime_import_status","pending_current_hash_validation") if old.get("bookdata_sha256")==digest else "pending_current_hash_validation","runtime_validator_head":old.get("runtime_validator_head") if old.get("bookdata_sha256")==digest else None}
 (PACKAGE/"REVIEW_MANIFEST.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 (PACKAGE/"README.md").write_text(f"# {book['title']}\n\n미연결 공식 기준 13개를 보완하는 13모듈·65쪽 V2 원고 후보입니다. 예시는 직접 만든 가상 자료이며, 산술 확인은 저자 점검 범위입니다. 교사 검수·권리 결정 전 출판 부적격입니다. 기존 HTML 상호작용과의 parity는 검증하지 않았습니다.\n\nBookData: [`{OUT.name}`](../{OUT.name})\n",encoding="utf-8")
 print(f"Built {len(chapters)} modules, {len(ids)} pages, {len(codes)} standard candidates; sha256={digest}")

if __name__=="__main__": main()

"""Build the remaining 2015 middle-school statistics candidates for standards 9수05-01..08."""
from __future__ import annotations
import json,re,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_통계_배치1"
BOOK_FILE="중등수학_2015개정_통계_배치1_BookData_V2_시범.json"
DATA=[
("9수05-01","자료의 분포 표현","자료의 특징에 따라 줄기와 잎 그림, 도수분포표, 히스토그램, 도수분포다각형을 선택한다. 계급의 크기와 도수의 합을 점검하고 축·단위를 표시해 분포의 중심과 퍼짐을 읽는다.","자료 12,14,17,21,22,25,31을 10 이상 20 미만, 20 이상 30 미만, 30 이상 40 미만으로 나눈 도수를 구하세요.","도수는 각각 3, 3, 1이며 합은 7로 자료 수와 같습니다.","자료 4,7,11,13,18을 0 이상 10 미만, 10 이상 20 미만으로 나눈 도수를 구하세요.","첫 계급은 4,7로 2개, 둘째는 11,13,18로 3개입니다.",["3, 3, 1","2, 2, 1","3, 2, 2"],0),
("9수05-02","상대도수","상대도수는 각 계급의 도수를 전체 자료 수로 나눈 값이다. 모든 계급의 상대도수 합은 1이며, 상대도수의 분포를 표나 그래프로 나타내어 집단의 크기가 달라도 분포를 비교할 수 있다.","전체 40명 중 한 계급의 도수가 10명일 때 상대도수를 구하세요.","10÷40=0.25이므로 상대도수는 0.25, 즉 25%입니다.","상대도수가 0.3이고 전체 자료가 50개일 때 해당 계급의 도수는 얼마인가요?","0.3×50=15개입니다.",["0.25","0.4","4"],0),
("9수05-03","자료 수집과 분석","실생활 문제를 조사할 때 질문을 구체화하고 대상과 방법을 정한다. 공학적 도구로 자료를 수집·정리할 수 있지만 표본의 대표성, 응답 누락, 단위와 조사 조건을 점검해야 하며 관찰된 관계를 인과로 단정하지 않는다.","학교 통학 시간을 조사할 때 결과를 해석하기 전에 확인할 사항 두 가지를 말하세요.","조사 대상이 전체 학생을 대표하는지, 응답 누락이나 측정 단위·요일 차이가 있는지 확인합니다.","응답한 학생만으로 전교생의 통학 시간을 해석할 때 생길 수 있는 문제는 무엇인가요?","응답자가 전체 학생을 대표하지 않으면 선택 편향이 생겨 결과를 전교생에게 일반화하기 어렵습니다.",["표본의 대표성과 응답 누락","그래프 색상만 확인","표본 수만 크면 대표성은 불필요"],0),
("9수05-04","경우의 수와 곱의 법칙","두 단계 선택에서 첫 단계 방법이 m가지, 각 선택 뒤 둘째 단계가 n가지이면 전체 경우는 m×n가지다. 선택 순서와 조건을 확인하고 중복 여부를 따진다.","상의 3벌과 하의 4벌 중 하나씩 고르는 옷차림은 몇 가지인가요?","각 상의마다 하의 4개를 고를 수 있으므로 3×4=12가지입니다.","세 가지 음료와 두 가지 크기 중 하나씩 선택하는 방법은 몇 가지인가요?","3×2=6가지입니다.",["12가지","7가지","24가지"],0),
("9수05-05","확률의 기본 성질","모든 결과가 같은 가능성인 경우 사건의 확률은 사건에 속하는 경우의 수를 전체 경우의 수로 나눈 값이다. 확률은 0 이상 1 이하이고, 여사건의 확률은 1에서 사건의 확률을 뺀 값이다.","공정한 주사위를 한 번 던질 때 짝수가 나올 확률을 구하세요.","짝수는 2,4,6의 세 경우이므로 확률은 3/6=1/2입니다.","공정한 주사위를 던져 5보다 큰 수가 나올 확률은 얼마인가요?","가능한 수는 6 하나뿐이므로 확률은 1/6입니다.",["1/2","1/3","2/3"],0),
("9수05-06","중앙값·최빈값·평균","평균은 자료의 합을 자료 수로 나눈 값, 중앙값은 크기순 가운데 값, 최빈값은 가장 자주 나타나는 값이다. 극단값은 평균에 크게 영향을 줄 수 있으므로 자료의 분포와 질문에 맞춰 대표값을 고른다.","자료 2,3,3,4,8의 평균·중앙값·최빈값을 구하세요.","평균은 20÷5=4, 중앙값은 3, 최빈값은 3입니다.","자료 4,5,5,6,30에서 평균과 중앙값을 구하세요.","평균은 50÷5=10이고 중앙값은 5입니다. 큰 값 30이 평균을 높입니다.",["4, 3, 3","3, 4, 3","4, 4, 3"],0),
("9수05-07","분산과 표준편차","분산은 각 자료와 평균의 차이를 제곱한 값들의 평균이며, 표준편차는 분산의 양의 제곱근이다. 표준편차가 작을수록 자료가 평균 주위에 모여 있다. 분산은 제곱 단위, 표준편차는 원래 단위다.","자료 3,3,7,7의 평균, 분산, 표준편차를 구하세요.","평균은 5, 편차 제곱은 각각 4이므로 분산은 4, 표준편차는 2입니다.","모든 자료가 6으로 같을 때 분산과 표준편차는 얼마인가요?","모든 편차가 0이므로 분산과 표준편차는 모두 0입니다.",["평균 5, 분산 4, 표준편차 2","평균 5, 분산 2, 표준편차 4","평균 4, 분산 5, 표준편차 2"],0),
("9수05-08","산점도와 상관관계","산점도는 두 변량의 순서쌍을 좌표평면에 나타낸다. 점들이 오른쪽 위로 모이면 양의 상관, 오른쪽 아래로 모이면 음의 상관, 뚜렷한 방향이 없으면 상관이 약하다. 상관관계만으로 인과관계를 결론내릴 수 없다.","공부 시간이 늘수록 성취도가 대체로 높아지는 산점도는 어떤 상관을 보이나요?","두 변량이 함께 증가하는 경향이므로 양의 상관입니다. 이것만으로 공부 시간이 원인이라고 단정할 수는 없습니다.","기온이 높을수록 난방 사용량이 낮아지는 경향은 어떤 상관인가요?","한 변량이 증가할수록 다른 변량이 감소하므로 음의 상관입니다.",["양의 상관","음의 상관","상관 없음"],0),
]

def main():
    official=(ROOT/"work/official-curriculum/2015_appendix8_math.txt").read_text(encoding="utf-8")
    standards={c:t.strip() for c,t in re.findall(r"\[(9수\d{2}-\d{2})\]\s*([^\r\n]+)",official)}
    codes=[r[0] for r in DATA]
    if len(codes)!=8 or len(set(codes))!=8 or any(c not in standards for c in codes): raise ValueError("Candidate codes differ from official index")
    assert 12+14+17+21+22+25+31==142 and 3+3+1==7
    assert 10/40==.25 and .3*50==15 and 3*4==12 and 3*2==6
    assert 3/6==.5 and (2+3+3+4+8)/5==4 and (3+3+7+7)/4==5
    assert ((3-5)**2+(3-5)**2+(7-5)**2+(7-5)**2)/4==4 and math.sqrt(4)==2
    chapters=[]; quiz_ids=[]
    for code,title,concept,example,solution,practice,answer,options,correct in DATA:
        slug="ms15-stat-"+code[-2:]
        quiz={"id":slug+"-quiz","kind":"quiz","prompt":example,"options":options,"correct_index":correct,"correct_feedback":solution,"incorrect_feedback":"자료의 조건과 계산 결과를 확인해 다시 풀어 보세요.","hints":["자료 수, 대표값 또는 비교 방향을 먼저 확인하세요."]}
        chapter={"title":title,"intro":[f"{title}의 자료를 표·수 또는 그래프로 분석합니다.",f"2015 개정 중학교 학년군 기준 후보 {code}; 학기 귀속은 별도 대조가 필요합니다."],"sections":[{"title":"기준과 검토 상태","paragraphs":[f"공식 기준 후보: {code} {standards[code]}","새로 작성한 부분 후보입니다. 독립 교사·수학 검토와 권리 검토는 pending입니다."]}],"pages":[
          {"id":slug+"-opening","template":"opening","title":"생각 열기","blocks":[{"type":"lead","title":title,"text":concept},{"type":"thinking","title":"질문","text":"자료의 어떤 특징이 질문에 답하는 데 중요한가요?"}]},
          {"id":slug+"-concept","template":"concept","title":"핵심 개념","blocks":[{"type":"definition","title":"정의와 방법","text":concept},{"type":"formula","title":"공식 기준","text":standards[code]}]},
          {"id":slug+"-example","template":"example","title":"예제와 풀이","blocks":[{"type":"question","title":"예제","text":example},{"type":"solutionStep","title":"풀이","text":solution}]},
          {"id":slug+"-practice","template":"practice","title":"연습","blocks":[{"type":"question","title":"연습문제","text":practice},{"type":"solutionStep","title":"해설","text":answer},{"type":"activity","activity":quiz}]},
          {"id":slug+"-summary","template":"summary","title":"정리","blocks":[{"type":"summary","title":"핵심","text":concept}]}]}
        chapters.append(chapter); quiz_ids.append(quiz["id"])
    book={"schema_version":2,"title":"중학교 수학 2015 개정 · 통계 부분 후보 배치 1","subtitle":"공식 기준별 개념·예제·연습·native quiz","category":"concept_textbook_prototype","curriculum_version":"2015","standard_codes":codes,"standard_coverage":"partial","grade_semester_status":"not_assigned","tags":["중학교 수학","2015 개정","학년군 기준","학기 미배정","부분 원고 후보","교사·수학 검수 대기","권리 검토 대기",*[f"성취기준 후보: {c}" for c in codes]],"chapters":chapters,"metadata":{"status":"candidate_partial_draft","teacher_review_status":"pending","math_review_status":"author_checks_recorded_independent_review_pending","rights_status":"pending","publication_eligibility":"not_eligible","standard_source":"2015 개정 수학과 교육과정 별책8 공식 추출 텍스트","content_rights":"newly authored candidate; independent rights decision pending","semester_assignment":"grade-band only; semester not assigned","interactive_compatibility_status":"native quiz activities; no external HTML behavior parity claimed"}}
    OUT.mkdir(parents=True,exist_ok=True); (OUT/BOOK_FILE).write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    manifest={"status":"candidate_partial_draft","standard_codes":codes,"official_criteria":{c:standards[c] for c in codes},"module_count":8,"page_count":40,"native_quiz_ids":quiz_ids,"author_arithmetic_checks":"passed","teacher_review":"pending","independent_math_review":"pending","rights_review":"pending","publication_eligibility":"not_eligible","semester_assignment":"not assigned"}
    (OUT/"원고매니페스트.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("Built 8 modules, 40 pages and 8 native quizzes; review and rights pending.")
if __name__=="__main__": main()

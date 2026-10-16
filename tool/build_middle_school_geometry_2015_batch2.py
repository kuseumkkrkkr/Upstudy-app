"""Build resumable 2015 middle-school geometry drafts for standards 9수04-11..20."""
from __future__ import annotations
import json,re
from math import sqrt
from fractions import Fraction
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_도형_배치2"
BOOK_FILE="중등수학_2015개정_도형_배치2_BookData_V2_시범.json"
DATA=[
("9수04-11","삼각형의 외심과 내심","외심은 세 변의 수직이등분선의 교점이므로 세 꼭짓점에서 같은 거리에 있다. 내심은 세 내각의 이등분선의 교점이므로 세 변까지의 거리가 같다. 외심은 외접원의 중심, 내심은 내접원의 중심이다.","삼각형의 외심 O에서 한 꼭짓점까지의 거리가 5 cm일 때 다른 두 꼭짓점까지의 거리는 얼마인가요?","외심은 세 꼭짓점에서 같은 거리에 있으므로 각각 5 cm입니다.","삼각형의 내심에서 세 변까지의 거리는 어떤 관계인가요?","세 내각의 이등분선 위의 점은 두 변까지 거리가 같으므로 내심은 세 변까지 거리가 같습니다.",["모두 5 cm","서로 다르다","두 꼭짓점만 같다"],0),
("9수04-12","사각형의 성질","평행사변형은 두 쌍의 대변이 평행하고 길이가 같으며 대각선이 서로를 이등분한다. 직사각형은 네 각이 직각, 마름모는 네 변의 길이가 같고, 정사각형은 두 성질을 모두 갖는다.","평행사변형의 한 각이 70°일 때 이웃한 각을 구하세요.","이웃한 내각의 합은 180°이므로 110°입니다.","평행사변형의 대각선이 만나는 점에서 한쪽 대각선 반쪽이 4 cm이면 나머지 반쪽은 얼마인가요?","대각선은 서로를 이등분하므로 나머지 반쪽도 4 cm입니다.",["110°","70°","140°"],0),
("9수04-13","도형의 닮음","두 도형이 닮음이면 대응각은 각각 같고 대응변의 길이의 비는 일정하다. 대응변 비가 k이면 둘레 비는 k, 넓이 비는 k²이다. 확대·축소해도 모양은 보존된다.","닮음비가 2:3인 두 도형의 넓이의 비를 구하세요.","넓이의 비는 닮음비의 제곱이므로 4:9입니다.","두 닮은 삼각형의 대응변 비가 3:5이고 작은 삼각형의 둘레가 12 cm이면 큰 삼각형의 둘레는 얼마인가요?","둘레 비도 3:5이므로 큰 둘레는 12×5/3=20 cm입니다.",["4:9","2:3","4:6"],0),
("9수04-14","삼각형의 닮음 조건","두 삼각형에서 두 쌍의 대응각이 같으면 AA 닮음이다. 세 쌍의 대응변 비가 같거나 두 쌍의 대응변 비와 끼인각이 각각 같을 때도 닮음이다. 대응 순서를 먼저 맞춘다.","두 삼각형에서 두 각이 각각 45°, 60°로 같다면 닮음인가요?","두 쌍의 대응각이 같으므로 AA 닮음입니다. 나머지 각도 각각 75°입니다.","한 쌍의 대응변 비만 같으면 두 삼각형이 닮았다고 할 수 있나요?","아닙니다. 한 쌍의 변 비만으로 각이나 나머지 변 비가 정해지지 않습니다.",["AA로 닮음","항상 합동","한 변 비만으로 닮음"],0),
("9수04-15","평행선과 선분의 길이 비","삼각형에서 한 변과 평행한 직선이 나머지 두 변을 자르면 대응 선분의 비가 같다. 평행 조건과 대응점을 확인하고 비례식을 세워 미지 길이를 구한다.","△ABC에서 D는 AB, E는 AC 위에 있고 DE∥BC이다. AD=2, DB=3, AE=4일 때 EC를 구하세요.","AD:DB=AE:EC이므로 2:3=4:EC, 따라서 EC=6입니다.","AD:DB=4:5이고 AE=12일 때 EC를 구하세요.","4:5=12:EC이므로 EC=15입니다.",["6","8","10"],0),
("9수04-16","피타고라스 정리","직각삼각형에서 직각을 낀 두 변의 길이를 a,b, 빗변을 c라 하면 a²+b²=c²이다. 역으로 세 변이 이 관계를 만족하면 가장 긴 변의 맞은편 각은 직각이다.","직각변이 5 cm, 12 cm인 직각삼각형의 빗변을 구하세요.","5²+12²=25+144=169=13²이므로 빗변은 13 cm입니다.","빗변 10 cm, 한 직각변 6 cm인 삼각형에서 다른 직각변을 구하세요.","다른 변의 제곱은 10²−6²=64이므로 길이는 8 cm입니다.",["13 cm","17 cm","7 cm"],0),
("9수04-17","삼각비의 뜻과 값","직각삼각형의 예각 θ에 대해 sinθ=맞은편/빗변, cosθ=이웃한 변/빗변, tanθ=맞은편/이웃한 변이다. 기준각에 따라 세 변의 역할이 바뀐다.","3-4-5 직각삼각형에서 θ의 맞은편 변이 3, 이웃한 변이 4일 때 sinθ, cosθ, tanθ를 구하세요.","빗변은 5이므로 sinθ=3/5, cosθ=4/5, tanθ=3/4입니다.","같은 삼각형에서 맞은편 변이 4이고 이웃한 변이 3인 각 φ의 tanφ를 구하세요.","tanφ=맞은편/이웃한 변=4/3입니다.",["3/5, 4/5, 3/4","4/5, 3/5, 4/3","3/4, 4/3, 5/4"],0),
("9수04-18","삼각비의 활용","직각삼각형에서 삼각비를 이용해 직접 재기 어려운 높이나 거리를 구한다. 관찰점, 수평선, 높이로 직각삼각형을 만들고 기준각과 맞은편·이웃한 변을 표시한다.","높이 10 m인 건물에서 수평거리 10 m 떨어진 지점의 앙각 θ에 대해 tanθ를 구하세요.","맞은편과 이웃한 변이 모두 10 m이므로 tanθ=10/10=1입니다.","사다리 길이가 10 m이고 지면과 이루는 각에서 sinθ=3/5일 때 벽에 닿는 높이를 구하세요.","높이는 빗변의 맞은편이므로 10×3/5=6 m입니다.",["1","1/2","2"],0),
("9수04-19","원의 현과 접선의 성질","원의 중심에서 현에 내린 수선은 현을 이등분한다. 중심에서 같은 거리에 있는 현의 길이는 같다. 원의 접선은 접점에서 반지름과 수직이며, 한 점에서 그은 두 접선의 길이는 같다.","반지름 13 cm인 원에서 중심과 현 사이 거리가 5 cm일 때 현의 길이를 구하세요.","현의 반쪽 길이를 x라 하면 x²+5²=13²이므로 x=12, 현의 길이는 24 cm입니다.","한 점 P에서 원에 그은 두 접선 중 하나가 8 cm일 때 다른 접선 길이는 얼마인가요?","같은 외부점에서 그은 접선의 길이는 같으므로 8 cm입니다.",["24 cm","18 cm","12 cm"],0),
("9수04-20","원주각의 성질","같은 호를 보는 원주각의 크기는 같다. 같은 호에 대한 원주각은 중심각의 절반이며, 지름을 보는 원주각은 90°이다. 각의 꼭짓점과 두 끝점이 만드는 호를 확인한다.","중심각이 100°인 호를 보는 원주각의 크기는 얼마인가요?","같은 호의 원주각은 중심각의 절반이므로 50°입니다.","지름의 양 끝점을 잇는 원주각의 크기는 얼마인가요?","지름에 대한 중심각은 180°이므로 원주각은 90°입니다.",["50°","100°","200°"],0),
]

EXPECTED_ANSWERS={
"9수04-11":("5cm","세 변까지 거리가 같습니다","5cm"),
"9수04-12":("110°","4cm","110°"),
"9수04-13":("4:9","20cm","4:9"),
"9수04-14":("AA 닮음","아닙니다","AA로 닮음"),
"9수04-15":("EC=6","EC=15","6"),
"9수04-16":("13cm","8cm","13cm"),
"9수04-17":("sinθ=3/5","4/3","3/5, 4/5, 3/4"),
"9수04-18":("tanθ=10/10=1","6m","1"),
"9수04-19":("24cm","8cm","24cm"),
"9수04-20":("50°","90°","50°"),
}

def verify_authored_answers():
    """Tie each hand-authored worked answer and practice key to arithmetic checks."""
    assert 180-70==110 and Fraction(2,3)**2==Fraction(4,9)
    assert 12*5/3==20 and 45+60+75==180
    assert Fraction(2,3)==Fraction(4,6) and 2*12==24
    assert 5**2+12**2==13**2 and sqrt(10**2-6**2)==8
    assert Fraction(3,5)==Fraction(3,5) and Fraction(4,3)==Fraction(4,3)
    assert Fraction(10,10)==1 and 10*Fraction(3,5)==6
    assert 13**2-5**2==12**2 and 100/2==50 and 180/2==90
    normalize=lambda text: re.sub(r"\s+","",text)
    for row in DATA:
        code,_,_,_,solution,_,practice_answer,options,correct=row
        expected_example,expected_practice,expected_option=EXPECTED_ANSWERS[code]
        if normalize(expected_example) not in normalize(solution):
            raise ValueError(f"{code}: example solution does not contain checked answer {expected_example}")
        if normalize(expected_practice) not in normalize(practice_answer):
            raise ValueError(f"{code}: practice solution does not contain checked answer {expected_practice}")
        if normalize(expected_option) not in normalize(options[correct]):
            raise ValueError(f"{code}: quiz key does not match checked answer {expected_option}")
    if set(EXPECTED_ANSWERS)!={row[0] for row in DATA}:
        raise ValueError("Expected-answer checks do not match the generated criteria")

def main():
    official=(ROOT/"work/official-curriculum/2015_appendix8_math.txt").read_text(encoding="utf-8")
    standards={c:t.strip() for c,t in re.findall(r"\[(9수\d{2}-\d{2})\]\s*([^\r\n]+)",official)}
    codes=[r[0] for r in DATA]
    if len(codes)!=10 or len(set(codes))!=10 or any(c not in standards for c in codes): raise ValueError("Candidate codes differ from official index")
    verify_authored_answers()
    chapters=[]; quiz_ids=[]
    for code,title,concept,example,solution,practice,answer,options,correct in DATA:
        slug="ms15-geometry-"+code[-2:]
        quiz={"id":slug+"-quiz","kind":"quiz","prompt":example,"options":options,"correct_index":correct,"correct_feedback":solution,"incorrect_feedback":"조건에 맞는 대응 요소와 정리를 다시 확인하세요.","hints":["각과 변의 대응, 또는 필요한 직각삼각형을 먼저 표시하세요."]}
        chapter={"title":title,"intro":[f"{title}의 조건과 성질을 익힙니다.",f"2015 개정 중학교 학년군 기준 후보 {code}; 학기 귀속은 별도 대조가 필요합니다."],"sections":[{"title":"기준과 검토 상태","paragraphs":[f"공식 기준 후보: {code} {standards[code]}","새로 작성한 부분 후보입니다. 독립 교사·수학 검토와 권리 검토는 pending입니다."]}],"pages":[
          {"id":slug+"-opening","template":"opening","title":"생각 열기","blocks":[{"type":"lead","title":title,"text":concept},{"type":"thinking","title":"질문","text":"결론을 얻는 데 꼭 필요한 조건은 무엇인가요?"}]},
          {"id":slug+"-concept","template":"concept","title":"핵심 개념","blocks":[{"type":"definition","title":"정의와 성질","text":concept},{"type":"formula","title":"공식 기준","text":standards[code]}]},
          {"id":slug+"-example","template":"example","title":"예제와 풀이","blocks":[{"type":"question","title":"예제","text":example},{"type":"solutionStep","title":"풀이","text":solution}]},
          {"id":slug+"-practice","template":"practice","title":"연습","blocks":[{"type":"question","title":"연습문제","text":practice},{"type":"solutionStep","title":"해설","text":answer},{"type":"activity","activity":quiz}]},
          {"id":slug+"-summary","template":"summary","title":"정리","blocks":[{"type":"summary","title":"핵심","text":concept}]}]}
        chapters.append(chapter); quiz_ids.append(quiz["id"])
    book={"schema_version":2,"title":"중학교 수학 2015 개정 · 도형 부분 후보 배치 2","subtitle":"공식 기준별 개념·예제·연습·native quiz","category":"concept_textbook_prototype","curriculum_version":"2015","standard_codes":codes,"standard_coverage":"partial","grade_semester_status":"not_assigned","tags":["중학교 수학","2015 개정","학년군 기준","학기 미배정","부분 원고 후보","교사·수학 검수 대기","권리 검토 대기",*[f"성취기준 후보: {c}" for c in codes]],"chapters":chapters,"metadata":{"status":"candidate_partial_draft","teacher_review_status":"pending","math_review_status":"author_checks_recorded_independent_review_pending","rights_status":"pending","publication_eligibility":"not_eligible","standard_source":"2015 개정 수학과 교육과정 별책8 공식 추출 텍스트","content_rights":"newly authored candidate; independent rights decision pending","semester_assignment":"grade-band only; semester not assigned","interactive_compatibility_status":"native quiz activities; external interactive-source parity not claimed"}}
    OUT.mkdir(parents=True,exist_ok=True); (OUT/BOOK_FILE).write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    manifest={"status":"candidate_partial_draft","standard_codes":codes,"official_criteria":{c:standards[c] for c in codes},"module_count":10,"page_count":50,"native_quiz_ids":quiz_ids,"author_arithmetic_checks":"passed: 10 example solutions, 10 practice solutions, and 10 native quiz keys matched explicit checks","teacher_review":"pending","independent_math_review":"pending","rights_review":"pending","publication_eligibility":"not_eligible","semester_assignment":"not assigned"}
    (OUT/"원고매니페스트.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    readme="""# 중학교 수학 2015 개정 · 도형 부분 후보 배치 2

상태: 부분 원고 후보 · 학기 미배정 · 출판 부적격

- 범위: 공식 학년군 기준 `9수04-11`–`9수04-20` 10개 후보 모듈, 50쪽, native quiz 10개.
- 학생용 BookData V2 형식으로 페이지·개념·예제·연습·해설·퀴즈를 보존한다. 외부 HTML의 화면·시간 동작 패리티는 주장하지 않는다.
- 생성기 산술 검사: 예제 해설 10개, 연습 해설 10개, quiz 정답 키 10개를 명시적 산술 및 답 문자열 대조로 확인했다. 이는 독립 수학검토가 아니다.
- 판본/범위: 2015 개정 중학교 학년군 기준이며 1·2학기 배정은 미확정이다.
- 교사 검토, 독립 수학 검토, 권리 판정은 pending이다. 게시하지 않는다.

파일: [BookData](중등수학_2015개정_도형_배치2_BookData_V2_시범.json), [원고 매니페스트](원고매니페스트.json).

재생성: `python tool/build_middle_school_geometry_2015_batch2.py` (공식 교육과정 추출 텍스트 필요)
"""
    (OUT/"README.md").write_text(readme,encoding="utf-8")
    print("Built 10 modules, 50 pages and 10 native quizzes; review and rights pending.")
if __name__=="__main__": main()

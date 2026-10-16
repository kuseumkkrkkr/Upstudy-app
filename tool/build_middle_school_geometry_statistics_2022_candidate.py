"""Build the remaining exact-tag 2022 middle-school geometry/statistics candidates."""
from __future__ import annotations
import importlib.util, json
from math import isclose, sqrt
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2022개정_도형과통계_부분초안"
BOOK_FILE="중등수학_2022개정_도형과통계_BookData_V2_시범.json"
# code, title, concept, example, solution, practice, answer, choices, correct
DATA=[
("9수03-02","평행선과 각","두 평행선을 한 직선이 가로지를 때 엇각과 동위각은 각각 같다. 한 쌍의 동위각이 같으면 두 직선은 평행하고, 엇각도 같은 기준으로 평행 여부를 확인한다.","한 쌍의 평행선에서 한 각이 68°일 때 그 각의 엇각과 이웃한 내각을 구하세요.","엇각은 68°입니다. 이웃한 내각은 한 직선 위의 각이므로 180°−68°=112°입니다.","평행선에서 한 각이 125°일 때 동위각과 이웃한 내각을 구하세요.","동위각은 125°, 이웃한 내각은 180°−125°=55°입니다.",["엇각 68°, 이웃각 112°","엇각 112°, 이웃각 68°","둘 다 68°"],0),
("9수03-04","삼각형의 합동","삼각형은 대응하는 세 변과 세 각이 각각 같을 때 합동이다. 세 변(SSS), 두 변과 끼인각(SAS), 한 변과 양 끝각(ASA)처럼 충분한 조건을 확인한다. 세 각만 같은 것은 크기가 다른 삼각형일 수 있어 합동 조건이 아니다.","두 삼각형에서 두 변의 길이와 그 끼인각이 각각 같을 때 합동임을 설명하세요.","SAS 합동 조건에 해당합니다. 두 변과 그 사이의 각이 같으므로 두 삼각형은 합동입니다.","세 각이 각각 같은 두 삼각형은 항상 합동인가요? 이유를 쓰세요.","아닙니다. 세 각만 같으면 모양만 같고 크기는 다를 수 있어 닮음일 뿐 합동을 보장하지 않습니다.",["항상 합동이다","닮음은 보장되지만 합동은 보장되지 않는다","각 하나만 같으면 합동이다"],1),
("9수03-06","부채꼴의 호와 넓이","반지름 r, 중심각 θ인 부채꼴에서 호의 길이는 원둘레의 θ/360 비율이고 넓이는 원 넓이의 같은 비율이다. 따라서 l=2πr·θ/360, A=πr²·θ/360이다.","반지름 6 cm, 중심각 60°인 부채꼴의 호의 길이와 넓이를 구하세요.","전체 원의 1/6이므로 호의 길이는 12π/6=2π cm, 넓이는 36π/6=6π cm²입니다.","반지름 4 cm, 중심각 90°인 부채꼴의 호의 길이와 넓이를 구하세요.","전체의 1/4이므로 호의 길이는 8π/4=2π cm, 넓이는 16π/4=4π cm²입니다.",["2π cm, 6π cm²","π cm, 6π cm²","2π cm, 12π cm²"],0),
("9수03-08","입체도형의 겉넓이와 부피","각기둥·각뿔·원기둥·원뿔·구의 겉넓이와 부피는 밑면과 높이, 반지름을 구분해 계산한다. 원기둥은 밑면 넓이×높이, 원뿔은 그 값의 1/3이며 단위를 확인한다.","반지름 3 cm, 높이 5 cm인 원기둥의 부피를 구하세요.","밑면 넓이는 9π cm²이므로 부피는 9π×5=45π cm³입니다.","반지름 2 cm, 높이 6 cm인 원뿔의 부피를 구하세요.","원뿔 부피는 밑면 넓이×높이÷3이므로 (4π×6)÷3=8π cm³입니다.",["8π cm³","24π cm³","12π cm³"],0),
("9수03-10","삼각형의 외심과 내심","외심은 세 변의 수직이등분선의 교점으로 세 꼭짓점에서 같은 거리에 있다. 내심은 세 내각의 이등분선의 교점으로 세 변까지의 거리가 같다. 두 점의 등거리 대상이 다르다.","삼각형의 외심 O가 세 꼭짓점 A,B,C에서 같은 거리에 있는 이유를 설명하세요.","O는 변들의 수직이등분선 위에 있으므로 OA=OB이고, 다른 수직이등분선에도 있으므로 OB=OC입니다. 따라서 OA=OB=OC입니다.","내심 I에서 삼각형의 세 변까지의 거리는 어떤 관계인가요?","내심은 각의 이등분선 위에 있으므로 세 변까지의 수선거리(내접원의 반지름)가 같습니다.",["세 꼭짓점까지의 거리만 같다","세 변까지의 거리가 같다","세 각의 크기가 같다"],1),
("9수03-12","도형의 닮음과 닮음비","닮은 도형은 대응각의 크기가 같고 대응변의 길이의 비가 일정하다. 닮음비가 k이면 둘레의 비는 k, 넓이의 비는 k²이다. 대응하는 꼭짓점의 순서를 맞춘다.","닮음비가 2:3인 두 삼각형에서 작은 삼각형의 둘레가 10 cm이면 큰 삼각형의 둘레는 얼마인가요?","둘레의 비도 2:3이므로 큰 삼각형의 둘레는 10×3/2=15 cm입니다.","두 닮은 도형의 대응변 비가 3:5입니다. 넓이의 비를 구하세요.","넓이의 비는 대응변 비의 제곱이므로 9:25입니다.",["3:5","6:10","9:25"],2),
("9수03-13","삼각형의 닮음 조건","두 삼각형에서 두 쌍의 대응각이 같으면 나머지 각도 같아 AA 닮음이다. 세 쌍 대응변의 비가 같거나 두 변의 비와 끼인각이 같을 때도 닮음을 판정할 수 있다.","두 삼각형의 두 각이 각각 40°, 65°로 같다면 닮음이라고 할 수 있나요?","나머지 각은 각각 180°−40°−65°=75°입니다. 두 쌍의 대응각이 같으므로 AA 닮음입니다.","두 삼각형에서 한 쌍의 각만 같으면 닮음을 확정할 수 있나요?","아닙니다. 한 각이 같다는 정보만으로 다른 두 각이나 대응변의 비가 정해지지 않습니다.",["항상 닮음이다","추가 조건 없이 확정할 수 없다","항상 합동이다"],1),
("9수03-14","평행선과 선분의 길이의 비","삼각형에서 한 변과 평행한 직선이 다른 두 변을 자르면 대응 선분의 비가 같다. 평행 조건과 대응 순서를 확인한 뒤 비례식을 세운다.","△ABC에서 D는 AB 위, E는 AC 위이고 DE∥BC이다. AD=2, DB=3, AE=4일 때 EC를 구하세요.","평행선의 기본 성질로 AD:DB=AE:EC이므로 2:3=4:EC, 따라서 EC=6입니다.","AD:DB=3:2이고 AE=9일 때 EC를 구하세요.","3:2=9:EC이므로 3EC=18, EC=6입니다.",["4","6","12"],1),
("9수03-16","삼각비의 뜻","직각삼각형에서 예각 θ에 대해 sinθ=맞은편 변/빗변, cosθ=이웃한 변/빗변, tanθ=맞은편 변/이웃한 변이다. 기준각을 먼저 표시하고 변을 구분한다.","직각삼각형의 변의 길이가 3,4,5이고 θ의 맞은편 변이 3, 빗변이 5일 때 sinθ와 cosθ를 구하세요.","이웃한 변은 4이므로 sinθ=3/5, cosθ=4/5입니다.","같은 삼각형에서 θ의 맞은편 변이 3, 이웃한 변이 4이면 tanθ는 얼마인가요?","tanθ=맞은편/이웃한 변=3/4입니다.",["3/5","4/5","3/4"],2),
("9수03-18","원의 현과 접선","원의 중심에서 현에 내린 수선은 현을 이등분한다. 한 점에서 원에 그은 두 접선의 길이는 같다. 접선은 접점에서 반지름과 수직이다.","반지름 13 cm인 원에서 중심과 현 사이의 거리가 5 cm일 때 현의 길이를 구하세요.","중심에서 현에 내린 수선이 현을 이등분합니다. 반쪽 길이를 x라 하면 x²+5²=13²이므로 x=12, 현의 길이는 24 cm입니다.","한 점 P에서 원에 그은 두 접선의 길이가 하나는 7 cm일 때 다른 접선 길이는 얼마인가요?","같은 외부점에서 그은 접선의 길이는 같으므로 7 cm입니다.",["5 cm","7 cm","14 cm"],1),
("9수03-19","원주각의 성질","같은 호를 보는 원주각의 크기는 같다. 같은 호에 대한 원주각은 그 호의 중심각의 절반이다. 지름을 보는 원주각은 직각이다.","중심각이 100°인 호를 보는 원주각의 크기를 구하세요.","같은 호에 대한 원주각은 중심각의 절반이므로 100°÷2=50°입니다.","지름의 양 끝점을 잇는 원주각의 크기는 얼마인가요?","지름이 만드는 중심각은 180°이므로 원주각은 그 절반인 90°입니다.",["45°","90°","180°"],1),
("9수04-02","자료의 분포 나타내기","자료를 줄기와 잎 그림, 도수분포표, 히스토그램, 도수분포다각형으로 나타내면 분포의 중심·퍼짐·형태를 살필 수 있다. 계급의 폭과 도수의 합을 확인하고, 그래프 축과 단위를 표시한다.","자료 12,14,17,21,22,25,31을 계급 10 이상 20 미만, 20 이상 30 미만, 30 이상 40 미만으로 나눈 도수를 구하세요.","각 계급의 도수는 각각 3, 3, 1입니다. 합은 7로 자료 수와 일치합니다.","자료 5,8,12,15,19를 0 이상 10 미만, 10 이상 20 미만으로 나눈 도수를 구하세요.","첫 계급에는 5,8이 있어 2개, 둘째 계급에는 12,15,19가 있어 3개입니다.",["2,3","3,2","1,4"],0),
("9수04-07","분산과 표준편차","분산은 각 자료와 평균의 차이를 제곱한 값의 평균이다. 표준편차는 분산의 양의 제곱근으로 자료가 평균 주위에 퍼진 정도를 원래 자료와 같은 단위로 나타낸다.","자료 2,4,6의 분산과 표준편차를 구하세요.","평균은 4입니다. 편차 제곱은 4,0,4이고 분산은 8/3, 표준편차는 √(8/3)입니다.","자료 3,3,7,7의 평균, 분산, 표준편차를 구하세요.","평균은 5, 편차 제곱은 4,4,4,4이므로 분산은 4, 표준편차는 2입니다.",["평균 5, 분산 4, 표준편차 2","평균 5, 분산 2, 표준편차 4","평균 4, 분산 5, 표준편차 √5"],0),
]

def main():
    helper_spec=importlib.util.spec_from_file_location("helper",ROOT/"tool/build_middle_school_1_2_2022_candidate.py")
    helper=importlib.util.module_from_spec(helper_spec); helper_spec.loader.exec_module(helper)
    standards={r["code"]:r["criterion"] for r in json.loads((ROOT/"work/official-curriculum/2022_math_standards.json").read_text(encoding="utf-8"))["standards"]}
    codes=[r[0] for r in DATA]
    if len(codes)!=13 or len(set(codes))!=13 or any(c not in standards for c in codes): raise ValueError("Candidate codes differ from official index")
    assert (180-68, 180-125) == (112, 55)
    assert isclose(12*60/360, 2) and isclose(3.141592653589793*36*60/360, 6*3.141592653589793)
    assert isclose(3.141592653589793*4*6/3, 8*3.141592653589793)
    assert 10*3/2 == 15 and (3**2, 5**2) == (9, 25)
    assert isclose(4*6/3, 8) and isclose(3/4, .75)
    assert 3+3+1 == 7 and isclose(((-2)**2+0**2+2**2)/3, 8/3)
    chapters=[]; activities=[]
    for i,(code,title,concept,example,solution,practice,answer,options,correct) in enumerate(DATA,1):
        slug=f"ms22-rem-{code.replace('수','m')}"
        ch=helper.make_chapter(code,slug,title,standards[code],"내장형 연습 활동",f"{title}: 조건을 표시하고 관계를 그림이나 식으로 설명해 보세요.",concept,example,solution,practice,answer,[title+"의 정의와 조건을 말한다.","계산 결과를 조건과 단위로 확인한다."])
        quiz={"id":slug+"-quiz","kind":"quiz","prompt":example,"options":options,"correct_index":correct,"correct_feedback":solution,"incorrect_feedback":"정의와 대응 조건을 확인한 뒤 다시 계산하세요.","hints":["문제의 조건과 대응하는 대상을 먼저 표시하세요."]}
        ch["pages"][1]["blocks"]=[{"type":"lead","title":"native 확인 활동","text":"아래 확인 문항을 풀고 조건과 계산을 함께 점검하세요."},{"type":"activity","activity":quiz},{"type":"thinking","title":"확장 질문","text":"조건 하나가 달라지면 결론은 어떻게 바뀌나요?"}]
        chapters.append(ch); activities.append(quiz)
    book={"schema_version":2,"title":"중등수학 2022 개정 · 도형과 통계 부분 후보","subtitle":"공식 학년군 기준별 개념·예제·연습·native quiz","category":"concept_textbook_prototype","curriculum_version":"2022","standard_codes":codes,"standard_coverage":"partial","grade_semester_status":"not_assigned","tags":["중등수학","2022 개정","학년군 기준","학년·학기 미배정","부분 원고 후보","교사·수학 검수 대기","권리 검토 대기",*[f"성취기준 후보: {c}" for c in codes]],"chapters":chapters,"metadata":{"status":"candidate_partial_draft","teacher_review_status":"pending","math_review_status":"author_checks_recorded_independent_review_pending","rights_status":"pending","publication_eligibility":"not_eligible","standard_source":"교육부 고시 제2022-33호 별책8 공식 기준 인덱스","content_rights":"newly authored candidate; independent rights decision pending","semester_assignment":"not assigned; middle-school codes are grade-band standards","interactive_compatibility_status":"native quiz activities; external interactive-source parity not claimed"}}
    OUT.mkdir(parents=True,exist_ok=True); path=OUT/BOOK_FILE; path.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    manifest={"status":"candidate_partial_draft","standard_codes":codes,"official_criteria":{c:standards[c] for c in codes},"module_count":len(chapters),"page_count":sum(len(c["pages"]) for c in chapters),"native_quiz_ids":[a["id"] for a in activities],"arithmetic_checks":"author examples and answers manually cross-checked; independent math review pending","teacher_review":"pending","independent_math_review":"pending","rights_review":"pending","publication_eligibility":"not_eligible","semester_assignment":"not assigned"}
    (OUT/"원고매니페스트.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Built {len(chapters)} modules, {manifest['page_count']} pages, 13 native quizzes; review and rights pending.")
if __name__=="__main__": main()

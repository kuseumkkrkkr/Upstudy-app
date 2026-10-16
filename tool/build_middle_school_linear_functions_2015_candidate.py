"""Build original 2015 middle-school function candidates for six untagged standards."""
from __future__ import annotations
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_함수그래프_부분초안"
BOOK_FILE="중등수학_2015개정_함수그래프_BookData_V2_시범.json"
DATA=[
("9수03-05","일차함수와 그래프","일차함수는 y=ax+b(a≠0)로 나타내며 그래프는 직선이다. x가 1만큼 변할 때 y의 변화량 a가 기울기이고, b는 y절편이다.","y=2x+1에서 기울기와 y절편을 말하고, 점 (2,5)가 그래프 위인지 확인하세요.","기울기는 2, y절편은 1입니다. x=2를 대입하면 y=5이므로 (2,5)는 그래프 위에 있습니다.","y=−3x+4의 그래프에서 x절편을 구하세요.","y=0을 두면 0=−3x+4, 따라서 x=4/3입니다.","2*x+1",[("직선의 기울기는 2, y절편은 1",0),("기울기는 1, y절편은 2",1),("그래프는 포물선",2)]),
("9수03-06","일차함수 그래프의 성질","y=ax+b에서 a>0이면 x가 증가할 때 y도 증가하고, a<0이면 감소한다. |a|가 클수록 직선은 더 가파르며, b가 바뀌면 그래프는 위아래로 평행이동한다.","y=3x−2와 y=−x−2를 비교해 증가·감소와 y절편을 설명하세요.","첫째는 기울기 3>0이므로 증가, 둘째는 −1<0이므로 감소합니다. 두 그래프의 y절편은 모두 −2입니다.","y=−2x+5는 증가함수인가요? y절편은 무엇인가요?","기울기가 −2<0이므로 감소하고, y절편은 5입니다.",["3*x-2","-x-2"],[("둘 다 증가하고 y절편은 −2",0),("첫째는 증가, 둘째는 감소하며 y절편은 −2",1),("둘 다 감소하며 y절편은 2",2)]),
("9수03-07","일차함수와 일차방정식","두 변수의 일차방정식 ax+by+c=0의 해 (x,y)는 좌표평면에서 직선 위의 점이다. 식을 y에 대해 정리하면 일차함수 그래프와 같은 직선으로 나타난다.","2x−y+1=0을 y=… 꼴로 바꾸고 (1,3)이 해인지 확인하세요.","y=2x+1입니다. x=1일 때 y=3이므로 (1,3)은 직선 위의 점이며 원래 방정식도 참입니다.","3x+y−6=0에서 y를 x의 식으로 나타내고 x=2일 때 y를 구하세요.","y=−3x+6이고 x=2이면 y=0입니다.","2*x+1",[("y=2x+1이고 (1,3)은 해이다",0),("y=2x−1이고 (1,3)은 해이다",1),("그래프는 포물선이다",2)]),
("9수03-08","두 직선과 연립일차방정식","연립일차방정식의 해는 두 직선 모두 위에 있는 점, 즉 교점의 좌표다. 한 점에서 만나면 해가 하나, 평행하면 해가 없고, 두 직선이 겹치면 해가 무수히 많다.","y=x+1과 y=−x+5의 교점이 연립방정식의 해임을 확인하세요.","x+1=−x+5이므로 x=2, y=3입니다. (2,3)은 두 식을 모두 만족하므로 해입니다.","y=2x와 y=2x+3의 연립방정식은 해가 몇 개인가요?","기울기가 같고 y절편이 달라 서로 평행하므로 교점이 없고 해가 없습니다.",["x+1","-x+5"],[("(2,3) 한 개",0),("해가 없다",1),("무수히 많다",2)]),
("9수03-09","이차함수와 그래프","이차함수 y=ax²(a≠0)는 x의 제곱에 비례하는 함수이며 그래프는 포물선이다. a>0이면 위로, a<0이면 아래로 열린다. 좌표를 대입해 점이 그래프 위인지 확인할 수 있다.","y=2x²에서 x=−2일 때 y를 구하고 그래프의 모양을 말하세요.","y=2×(−2)²=8입니다. a=2>0이므로 포물선은 위로 열립니다.","y=−x²에서 x=3일 때 함숫값을 구하세요.","y=−3²=−9입니다.","2*x^2",[("8, 위로 열린다",0),("−8, 아래로 열린다",1),("4, 위로 열린다",2)]),
("9수03-10","이차함수 그래프의 성질","y=ax²에서 y축은 대칭축이고 꼭짓점은 원점이다. a>0이면 최솟값 0, a<0이면 최댓값 0을 갖는다. |a|가 커질수록 포물선은 좁아진다.","y=−2x²의 대칭축, 꼭짓점, 최댓값을 구하세요.","y축(x=0)에 대칭이고 꼭짓점은 (0,0)입니다. 아래로 열리므로 최댓값은 0입니다.","y=3x²에서 x=−1과 x=1의 함숫값을 비교하고 대칭축을 말하세요.","두 값은 모두 3이며 y축에 대칭입니다.","a*x^2",[("대칭축 x=0, 꼭짓점 (0,0), 최댓값 0",0),("대칭축 y=0, 꼭짓점 (0,1), 최댓값 1",1),("대칭축 x=1, 꼭짓점 (1,0)",2)]),
]

def main():
    official=(ROOT/"work/official-curriculum/2015_appendix8_math.txt").read_text(encoding="utf-8")
    standards={code:text.strip() for code,text in __import__('re').findall(r"\[(9수\d{2}-\d{2})\]\s*([^\r\n]+)",official)}
    codes=[r[0] for r in DATA]
    if len(set(codes))!=6 or any(c not in standards for c in codes): raise ValueError("Missing 2015 official standard")
    assert 2*2+1 == 5 and -3*(4/3)+4 == 0
    assert 3*2-2 == 4 and -2+3 == 1
    assert 2+1 == -2+5 and 2*2 != 2*2+3
    assert 2*(-2)**2 == 8 and -(3**2) == -9
    chapters=[]; html=[]
    for i,(code,title,concept,example,solution,practice,answer,expr,choices) in enumerate(DATA,1):
        slug=f"ms15-function-{code[-2:]}"
        quiz={"id":slug+"-quiz","kind":"quiz","prompt":example,"options":[x[0] for x in choices],"correct_index":next(i for i,x in enumerate(choices) if x[1]==0),"correct_feedback":solution,"incorrect_feedback":"기울기·절편 또는 대입 결과를 확인한 뒤 다시 풀어 보세요.","hints":["식을 그래프 형태로 읽고 조건을 대입하세요."]}
        expressions=expr if isinstance(expr,list) else [expr]
        parameters = ([{"id":"a","label":"계수 a","value":1,"min":-3,"max":3,"step":0.5}] if code == "9수03-10" else [])
        declared = {parameter["id"] for parameter in parameters}
        supported = {"x","pi","e","abs","max","min","sqrt","pow","exp","ln","log","sin","cos","tan","ceil","floor","round"}
        for formula in expressions:
            symbols = set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", formula))
            if symbols - declared - supported:
                raise ValueError(f"Undeclared graph symbols for {code}: {sorted(symbols - declared - supported)}")
        settings={"showAxes":True,"showGrid":True,"lockViewport":True,"degreeMode":False,"viewport":{"left":-5,"right":5,"top":10,"bottom":-10}}
        if parameters:
            settings["parameters"] = parameters
        graph={"items":[{"id":f"function-{j+1}","type":"function","label":f"{title} {j+1}" if len(expressions)>1 else title,"colorHex":["#315DA8","#D97706"][j%2],"enabled":True,"expression":formula} for j,formula in enumerate(expressions)],"settings":settings}
        chapter={"title":title,"intro":[f"{title}의 식과 그래프를 연결해 봅니다.",f"2015 개정 중학교 학년군 기준 후보 {code}; 학기 귀속은 공식 기준에서 분리합니다."],"sections":[{"title":"기준과 검토 상태","paragraphs":[f"공식 기준 후보: {code} {standards[code]}","새로 작성한 부분 후보이며 학기 배정, 교사·독립 수학 검토, 권리 검토는 대기 중입니다."]}],"pages":[
          {"id":slug+"-opening","template":"opening","title":"생각 열기","blocks":[{"type":"lead","title":title,"text":concept},{"type":"thinking","title":"질문","text":"계수 하나를 바꾸면 그래프에서 무엇이 달라질지 예측하세요."}]},
          {"id":slug+"-graph","template":"experiment","title":"그래프로 확인하기","blocks":[{"type":"lead","title":"앱 내 그래프","text":"그래프의 점을 읽고 식에 대입해 좌표가 조건을 만족하는지 확인하세요."},{"type":"graph","title":title,"text":concept,"graph":graph}]},
          {"id":slug+"-concept","template":"concept","title":"핵심 개념","blocks":[{"type":"definition","title":"정의와 성질","text":concept},{"type":"formula","title":"공식 기준","text":standards[code]}]},
          {"id":slug+"-example","template":"example","title":"예제와 풀이","blocks":[{"type":"question","title":"예제","text":example},{"type":"solutionStep","title":"풀이","text":solution}]},
          {"id":slug+"-practice","template":"practice","title":"연습","blocks":[{"type":"question","title":"연습문제","text":practice},{"type":"solutionStep","title":"해설","text":answer},{"type":"activity","activity":quiz}]},
          {"id":slug+"-summary","template":"summary","title":"정리","blocks":[{"type":"summary","title":"핵심","text":concept}]}]}
        chapters.append(chapter); html.append((code,graph))
    book={"schema_version":2,"title":"중학교 수학 2015 개정 · 함수 그래프 부분 후보","subtitle":"공식 기준별 설명·예제·연습·네이티브 그래프와 퀴즈","category":"concept_textbook_prototype","curriculum_version":"2015","standard_codes":codes,"standard_coverage":"partial","grade_semester_status":"not_assigned","tags":["중학교 수학","2015 개정","학년군 기준","학기 미배정","부분 원고 후보","교사·수학 검수 대기","권리 검토 대기",*[f"성취기준 후보: {c}" for c in codes]],"chapters":chapters,"metadata":{"status":"candidate_partial_draft","teacher_review_status":"pending","math_review_status":"author_checks_recorded_independent_review_pending","rights_status":"pending","publication_eligibility":"not_eligible","standard_source":"2015 개정 수학과 교육과정 별책8 공식 추출 텍스트","content_rights":"newly authored candidate; independent rights decision pending","semester_assignment":"grade-band only; semester not assigned","interactive_compatibility_status":"native BookData graph plus quiz; external source parity not claimed"}}
    OUT.mkdir(parents=True,exist_ok=True); p=OUT/BOOK_FILE; p.write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    manifest={"status":"candidate_partial_draft","standard_codes":codes,"official_criteria":{c:standards[c] for c in codes},"module_count":len(chapters),"page_count":36,"native_quiz_ids":[ch["pages"][4]["blocks"][2]["activity"]["id"] for ch in chapters],"native_graphs":6,"teacher_review":"pending","independent_math_review":"pending","rights_review":"pending","publication_eligibility":"not_eligible","semester_assignment":"not assigned"}
    manifest["native_quiz_ids"]=[ch["pages"][4]["blocks"][2]["activity"]["id"] for ch in chapters]
    (OUT/"원고매니페스트.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("Built 6 modules, 36 pages, 6 native graphs and quizzes; review and rights pending.")
if __name__=="__main__": main()

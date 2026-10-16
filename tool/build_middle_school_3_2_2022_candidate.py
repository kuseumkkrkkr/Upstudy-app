"""Build a partial, original 2022 middle-school 3-2 statistics candidate."""
from __future__ import annotations
import hashlib, importlib.util, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중학수학3-2_2022개정_통합시범"
DATA = [
    ("9수04-04", "통계적 탐구 계획", "학생 20명의 통학 시간을 조사해 학년별 차이를 알아보려 합니다. 조사 대상, 변수, 수집 방법을 먼저 정하세요.", "통계적 탐구는 질문 설정, 계획, 자료 수집·분석, 맥락에 맞는 해석으로 이어집니다. 대상과 변수를 분명히 하고 누락·편향을 점검합니다.", "학급별 독서 시간을 비교할 조사 계획을 쓰세요.", "비교할 학급과 기간, 시간 단위, 기록 방법, 익명성 및 누락 처리 방법을 정합니다. 같은 기준으로 수집해야 비교할 수 있습니다.", "휴대전화 이용 시간 조사에서 편향을 줄일 방법은 무엇인가요?", "같은 요일과 기간을 정하고 측정 방법을 명시합니다. 자발적 응답자만 조사하면 편향될 수 있으므로 대상과 응답률을 함께 기록합니다.", ["질문·대상·변수를 정한다.", "수집 방법과 누락 자료를 점검한다.", "분석 결과를 질문과 연결한다."]),
    ("9수04-08", "상자그림으로 분포 비교", "두 반의 중앙값이 같아도 점수 분포는 다를 수 있습니다. 중앙값과 사분위수를 비교해 보세요.", "상자그림은 최솟값, 제1사분위수, 중앙값, 제3사분위수, 최댓값을 나타냅니다. 상자 길이는 사분위 범위이며 두 집단의 중심과 퍼짐을 비교할 때 표본 크기와 단위도 확인합니다.", "A반 요약이 40,55,70,80,95이고 B반이 45,60,70,75,85일 때 중앙값과 사분위 범위를 비교하세요.", "두 중앙값은 70입니다. A의 사분위 범위는 80−55=25, B는 75−60=15이므로 A의 가운데 절반이 더 넓게 퍼져 있습니다.", "제1·제3사분위수가 42,63일 때 사분위 범위를 구하고 뜻을 쓰세요.", "63−42=21입니다. 정렬한 자료 가운데 절반이 폭 21인 구간에 놓입니다.", ["상자그림은 다섯 수치 요약을 나타낸다.", "사분위 범위는 제3사분위수−제1사분위수다.", "중심과 퍼짐을 나누어 비교한다."]),
    ("9수04-09", "산점도와 상관관계", "운동 시간이 길수록 달리기 기록 시간이 짧아지는 경향은 산점도에서 어떤 방향일까요?", "산점도는 두 변량의 짝 자료를 점으로 나타냅니다. 한 변량이 커질 때 다른 변량도 대체로 커지면 양의 상관, 작아지면 음의 상관이며 뚜렷한 방향이 없으면 상관관계가 없습니다. 상관관계만으로 인과를 단정할 수 없습니다.", "기온이 높을수록 아이스크림 판매량이 늘어나는 자료를 설명하세요.", "점들이 오른쪽 위로 모이는 경향은 양의 상관입니다. 계절이나 유동 인구 등 다른 변수가 있을 수 있어 기온이 원인이라고 단정할 수 없습니다.", "점들이 오른쪽 아래 방향으로 놓인 산점도는 어떤 상관인가요?", "음의 상관관계입니다. 다른 변수가 작용할 수 있으므로 인과관계로 단정하지 않습니다.", ["산점도는 두 변량의 짝을 표시한다.", "방향에 따라 양·음·무 상관을 구분한다.", "상관관계와 인과관계를 구별한다."]),
    ("9수04-01", "자료에 맞는 대푯값", "자료 4,5,5,6,30에서는 평균과 중앙값 중 어느 값이 가운데 자료를 더 잘 나타낼까요?", "평균은 합을 자료 수로 나눈 값, 중앙값은 크기순 가운데 값, 최빈값은 가장 자주 나타난 값입니다. 극단값이 있으면 평균이 크게 달라질 수 있어 목적에 맞게 선택합니다.", "자료 4,5,5,6,30의 평균과 중앙값을 구하세요.", "평균은 50÷5=10, 중앙값은 5입니다. 큰 값 30이 평균을 끌어올려 중앙값이 전형적인 중심을 더 잘 나타낼 수 있습니다.", "자료 2,3,3,4,8의 최빈값과 평균을 구하세요.", "최빈값은 3이고 평균은 20÷5=4입니다. 적절한 대푯값은 자료의 분포와 목적에 따라 판단합니다.", ["평균·중앙값·최빈값은 다른 정보를 준다.", "극단값은 평균에 영향을 준다.", "자료의 분포와 목적을 살핀다."]),
]

def main():
    helper_spec = importlib.util.spec_from_file_location("candidate_helpers", ROOT / "tool/build_middle_school_1_2_2022_candidate.py")
    helper = importlib.util.module_from_spec(helper_spec); helper_spec.loader.exec_module(helper)
    official = (ROOT / "work/official-curriculum/2022_appendix8_math.txt").read_text(encoding="utf-8")
    codes = [d[0] for d in DATA]
    if any(f"[{code}]" not in official for code in codes): raise ValueError("Candidate code absent from official appendix")
    OUT.mkdir(parents=True, exist_ok=True); chapters=[]; html_names=[]
    for code, title, opening, concept, example, solution, practice, answer, summary in DATA:
        slug = "ms32-22-" + code.replace("수", "m").replace("-", "-")
        html = f"중학수학3-2_2022개정_{code}_체험형_시범.html"; html_names.append(html)
        chapter = helper.make_chapter(code, slug, title, code, html, opening, concept, example, solution, practice, answer, summary)
        chapter["pages"][-2]["blocks"].append({"type":"activity","activity":{"id":slug+"-quiz","kind":"quiz","prompt":example,"options":[answer,"자료의 맥락과 무관하게 항상 평균만 사용한다.","상관관계만으로 원인을 증명한다."],"correct_index":0,"correct_feedback":answer,"incorrect_feedback":"정의와 자료의 맥락을 확인하세요.","hints":["자료에서 필요한 값을 찾아 계산하고 해석하세요."]}})
        chapters.append(chapter)
        if code == "9수04-04":
            interaction = "<label>조사 대상 학생 수 <input id='v' type='range' min='10' max='40' value='20'></label><p id='out' aria-live='polite'></p>"
            script = "const v=document.querySelector('#v'),o=document.querySelector('#out');function draw(){o.textContent=`대상 ${v.value}명 · 통학 시간(분)을 같은 요일에 기록하고 응답률과 누락 자료를 함께 점검하세요.`}v.addEventListener('input',draw);draw();"
        elif code == "9수04-08":
            interaction = "<p>다섯 수치 요약: 40, 55, 70, <output id='vout'>80</output>, 95</p><label>제3사분위수 <input id='v' type='range' min='70' max='90' value='80'></label><p id='out' aria-live='polite'></p>"
            script = "const v=document.querySelector('#v'),o=document.querySelector('#out');function draw(){document.querySelector('#vout').value=v.value;o.textContent=`중앙값 70 · 사분위 범위 ${+v.value-55} · 상자 안 가운데 절반의 폭`}v.addEventListener('input',draw);draw();"
        elif code == "9수04-09":
            interaction = "<label>산점도 점의 방향 <select id='v'><option value='양'>오른쪽 위</option><option value='음'>오른쪽 아래</option><option value='없음'>뚜렷한 방향 없음</option></select></label><p id='out' aria-live='polite'></p>"
            script = "const v=document.querySelector('#v'),o=document.querySelector('#out');function draw(){const t=v.value;o.textContent=`${t}의 상관관계입니다. 상관관계만으로 원인과 결과를 단정할 수 없습니다.`}v.addEventListener('change',draw);draw();"
        else:
            interaction = "<p>자료: 4, 5, 5, 6, <output id='vout'>30</output></p><label>마지막 자료 <input id='v' type='range' min='1' max='30' value='30'></label><p id='out' aria-live='polite'></p>"
            script = "const v=document.querySelector('#v'),o=document.querySelector('#out');function draw(){const a=[4,5,5,6,+v.value].sort((x,y)=>x-y),mean=a.reduce((x,y)=>x+y,0)/5;document.querySelector('#vout').value=v.value;o.textContent=`평균 ${mean.toFixed(1)} · 중앙값 ${a[2]} · 최빈값 5`}v.addEventListener('input',draw);draw();"
        (OUT/html).write_text(f'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>body{{font:17px/1.6 system-ui;max-width:46rem;margin:auto;padding:1rem}}label{{display:block;margin:1rem 0}}input{{width:100%;min-height:2.5rem}}strong{{color:#1d4ed8}}</style><main><h1>{title}</h1><p>{opening}</p>{interaction}<p>학년군 기준 후보 · 학기 배정 및 교사 검수 대기</p></main><script>{script}</script></html>''', encoding="utf-8")
    tags=["중학수학 3-2","2022 개정","학기 배정 후보","공식 학기 배열 아님","교사 검수 대기","저작권: 신규 집필 초안, 상업 교재 문장·문제·그림 미사용"]+["성취기준 후보: "+c for c in codes]
    book={"schema_version":2,"title":"중학수학 3-2 개념서 · 2022 개정 후보 시범","subtitle":"통계적 탐구와 자료 분포를 비교합니다","category":"concept_textbook_prototype","tags":tags,"curriculum_version":"2022","standard_codes":codes,"chapters":chapters}
    filename="중학수학3-2_2022개정_통계탐구와분포_BookData_V2_시범.json"
    (OUT/filename).write_text(json.dumps(book,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (OUT/"중학수학3-2_2022개정_학생용원고_시범.md").write_text("# 중학수학 3-2 후보 원고\n\n부분 초안이며 학기 배정·권리 결정·교사 검수 대기입니다.\n\n"+"\n".join("## "+d[1]+"\n기준 후보: "+d[0]+"\n\n"+d[2]+"\n\n핵심 개념: "+d[3]+"\n\n예제: "+d[4]+"\n풀이: "+d[5]+"\n\n연습: "+d[6]+"\n해설: "+d[7]+"\n" for d in DATA),encoding="utf-8")
    hwp=ROOT/"work/official-curriculum/2022_appendix8_math.hwp"; archive=ROOT/"work/official-curriculum/2022_math_standards_bundle.zip"
    manifest={"target":book["title"],"status":"candidate_partial_draft","semester_assignment":"editorial_candidate_not_officially_confirmed","standards":codes,"standard_source_url":"https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458","source_hwp_sha256":hashlib.sha256(hwp.read_bytes()).hexdigest().upper(),"source_archive_sha256":hashlib.sha256(archive.read_bytes()).hexdigest().upper(),"content_rights":"newly authored draft; publication rights decision pending","math_review":"examples arithmetically checked; teacher review pending","features":[{"standard":c,"html":n,"runtime":"standalone source asset; not app-integrated"} for c,n in zip(codes,html_names)]}
    (OUT/"중학수학3-2_2022개정_원고매니페스트.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (OUT/"README.md").write_text("# 중학수학 3-2 2022 개정 후보\n\n4개 모듈·24쪽 부분 초안, V2 퀴즈와 독립 HTML입니다. 학기 배정 후보이며 교사 검수·권리 결정·앱 통합 대기입니다.\n",encoding="utf-8")
    print("Built 4 modules, 24 pages, 4 activities and 4 HTML assets.")
if __name__ == "__main__": main()

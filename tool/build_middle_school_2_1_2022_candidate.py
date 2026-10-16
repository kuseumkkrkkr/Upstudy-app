"""Build an original 2022 middle-school 2-1 candidate; semester allocation is editorial."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중학수학2-1_2022개정_통합시범"
BOOK_FILE = "중학수학2-1_2022개정_공간과도형자료_BookData_V2_시범.json"
SPECS = [
    {
        "code": "9수03-07", "slug": "ms21-22-solids", "topic": "입체도형을 여러 방향에서 관찰하기",
        "html": "중학수학2-1_2022개정_입체도형관찰_체험형_시범.html", "kind": "solids",
        "opening": "종이컵과 공을 위·옆에서 보면 어떤 모양이 보일까요? 입체의 방향과 자른 위치가 관찰 결과에 어떤 영향을 주는지 예상해 보세요.",
        "concept": "기둥 모양 입체는 서로 평행하고 합동인 밑면과 옆면으로 이루어집니다. 원기둥은 원을 평행하게 옮긴 모양으로 볼 수 있습니다. 회전체는 평면도형을 한 직선 둘레로 회전할 때 생기는 입체입니다. 입체의 단면은 자르는 평면의 방향과 위치에 따라 달라집니다.",
        "example": "직사각형을 한 변을 축으로 한 바퀴 돌리면 어떤 입체가 생기나요? 그 입체의 밑면과 높이를 말해 보세요.",
        "solution": "직사각형의 한 변을 축으로 회전하면 원기둥이 생깁니다. 축과 평행한 변의 길이는 원기둥의 높이가 되고, 축에서 반대쪽 변까지의 거리는 밑면 원의 반지름이 됩니다.",
        "practice": "반지름 3 cm, 높이 5 cm인 원기둥을 축을 포함하는 평면으로 자르면 단면은 어떤 도형인가요? 단면의 가로와 세로 길이도 설명하세요.",
        "answer": "축을 포함하는 단면은 가로 6 cm, 세로 5 cm인 직사각형입니다. 지름은 반지름의 두 배인 6 cm이고 높이는 5 cm입니다.",
        "summary": ["회전체는 평면도형을 한 직선 둘레로 회전해 얻는다.", "단면의 모양은 자르는 평면의 방향과 위치로 결정된다.", "원기둥의 축을 포함하는 단면은 직사각형이다."],
        "quiz": {"id": "ms21-solids-section", "kind": "quiz", "prompt": "반지름 2, 높이 7인 원기둥을 축을 포함하는 평면으로 자른 단면은 무엇인가요?", "options": ["가로 4, 세로 7인 직사각형", "반지름 2인 원", "한 변의 길이가 7인 정사각형"], "correct_index": 0, "correct_feedback": "지름은 2×2=4이고 높이는 7입니다.", "incorrect_feedback": "축을 포함하면 원의 중심을 지나므로 단면의 가로는 지름입니다.", "hints": ["축을 포함하는 평면은 밑면 원의 중심을 지납니다.", "원기둥의 축을 포함한 단면은 직사각형입니다."]},
    },
    {
        "code": "9수03-09", "slug": "ms21-22-isosceles-proof", "topic": "이등변삼각형의 성질을 정당화하기",
        "html": "중학수학2-1_2022개정_이등변삼각형증명_체험형_시범.html", "kind": "isosceles",
        "opening": "두 변의 길이가 같은 삼각형에서 밑각도 같을까요? 그림을 여러 개 그려 추측한 뒤, 왜 항상 그런지 설명할 방법을 찾아보세요.",
        "concept": "삼각형 ABC에서 AB=AC이면 BC를 밑변이라고 하고 A를 꼭짓점이라고 합니다. 꼭짓점 A에서 ∠A를 이등분하는 선분을 그으면 두 작은 삼각형에서 AB=AC, ∠BAD=∠CAD, AD=AD입니다. 두 변과 그 끼인각이 각각 같으므로 두 삼각형은 합동이고, 대응하는 밑각 ∠B와 ∠C도 같습니다.",
        "example": "AB=AC인 삼각형 ABC에서 꼭짓점 A의 각을 이등분하는 선분 AD를 그었습니다. △ABD와 △ACD가 합동임을 설명하세요.",
        "solution": "AB=AC이고 ∠BAD=∠CAD이며 AD는 공통변입니다. 따라서 두 변과 그 끼인각이 각각 같아 SAS 합동입니다. 대응각이 같으므로 ∠B=∠C입니다.",
        "practice": "AB=AC인 삼각형에서 ∠B=52°입니다. ∠C와 ∠A를 구하고, 사용한 성질을 쓰세요.",
        "answer": "이등변삼각형의 밑각은 같으므로 ∠C=52°입니다. 삼각형의 내각의 합은 180°이므로 ∠A=180°−52°−52°=76°입니다.",
        "summary": ["같은 두 변에 마주 보는 두 각은 같다.", "꼭짓점에서 각을 이등분하면 합동인 두 삼각형을 만들 수 있다.", "추측한 성질은 합동 조건과 대응 관계로 정당화한다."],
        "quiz": {"id": "ms21-isosceles-angle", "kind": "quiz", "prompt": "이등변삼각형의 밑각 하나가 48°이면 꼭짓각은 몇 도인가요?", "options": ["48°", "84°", "96°"], "correct_index": 1, "correct_feedback": "밑각 두 개의 합은 96°이므로 꼭짓각은 84°입니다.", "incorrect_feedback": "삼각형의 내각의 합 180°에서 같은 밑각 두 개를 빼세요.", "hints": ["두 밑각은 같습니다.", "180°−48°−48°를 계산해 보세요."]},
    },
    {
        "code": "9수03-11", "slug": "ms21-22-quadrilateral-diagonals", "topic": "사각형의 대각선 성질로 관계 설명하기",
        "html": "중학수학2-1_2022개정_사각형대각선_체험형_시범.html", "kind": "quadrilaterals",
        "opening": "종이 사각형의 두 대각선을 그어 교점과 길이를 살펴보세요. 어떤 사각형에서 대각선이 서로를 이등분하고, 길이 또는 교각에는 어떤 차이가 있을까요?",
        "concept": "평행사변형의 두 대각선은 서로를 이등분합니다. 직사각형은 대각선의 길이도 같습니다. 마름모는 두 대각선이 수직으로 만나며, 정사각형은 직사각형과 마름모의 성질을 함께 가집니다. 성질을 적용할 때는 사각형의 정의와 주어진 조건을 확인합니다.",
        "example": "평행사변형 ABCD의 대각선 AC와 BD가 O에서 만납니다. AO=6 cm, BO=4 cm이면 AC와 BD의 길이를 구하세요.",
        "solution": "평행사변형의 대각선은 서로를 이등분하므로 AO=OC=6 cm, BO=OD=4 cm입니다. 따라서 AC=12 cm, BD=8 cm입니다.",
        "practice": "사각형의 두 대각선이 서로를 이등분하고 길이도 같습니다. 이 정보만으로 그 사각형이 직사각형이라고 결론 내릴 수 있나요? 이유를 설명하세요.",
        "answer": "대각선이 서로를 이등분하면 평행사변형입니다. 평행사변형에서 대각선 길이가 같으면 직사각형이므로 직사각형이라고 결론 내릴 수 있습니다. 마름모인 경우에는 정사각형일 수도 있습니다.",
        "summary": ["평행사변형의 대각선은 서로를 이등분한다.", "직사각형의 대각선은 길이가 같다.", "마름모의 대각선은 수직으로 만나며 서로를 이등분한다.", "정사각형은 직사각형과 마름모의 성질을 함께 만족한다."],
        "quiz": {"id": "ms21-quad-diagonals", "kind": "quiz", "prompt": "두 대각선이 서로를 이등분하고 길이도 같은 평행사변형은 어떤 사각형인가요?", "options": ["직사각형", "사다리꼴", "연꼴"], "correct_index": 0, "correct_feedback": "평행사변형에서 대각선의 길이가 같으면 직사각형입니다.", "incorrect_feedback": "먼저 대각선이 서로를 이등분하므로 평행사변형임을 확인하세요.", "hints": ["대각선이 서로를 이등분하는 평행사변형의 특별한 성질을 떠올리세요."]},
    },
    {
        "code": "9수04-03", "slug": "ms21-22-relative-frequency", "topic": "상대도수로 크기가 다른 집단 비교하기",
        "html": "중학수학2-1_2022개정_상대도수비교_체험형_시범.html", "kind": "relative-frequency",
        "opening": "A반에서 20명 중 12명이 버스를 타고, B반에서 60명 중 30명이 버스를 탔습니다. 이용 학생 수와 이용 비율 중 무엇으로 두 반을 비교하는 것이 알맞을까요?",
        "concept": "상대도수는 각 계급의 도수를 도수의 총합으로 나눈 값입니다. 집단마다 전체 인원수가 다르면 도수만으로는 분포를 공정하게 비교하기 어렵습니다. 상대도수는 각 집단 안에서 차지하는 비율을 나타내므로 크기가 다른 집단의 분포를 비교하는 데 쓸 수 있습니다.",
        "example": "A반 20명 중 12명, B반 60명 중 30명이 버스를 탑니다. 각 반의 버스 이용 상대도수를 구하세요.",
        "solution": "A반은 12/20=0.6, 즉 60%입니다. B반은 30/60=0.5, 즉 50%입니다. 이용 학생 수는 B반이 많지만 이용 비율은 A반이 높습니다.",
        "practice": "C집단 40명 중 18명, D집단 25명 중 10명이 도서관을 이용했습니다. 어느 집단의 이용 비율이 높으며 몇 퍼센트포인트 차이인가요?",
        "answer": "C집단은 18/40=0.45=45%, D집단은 10/25=0.4=40%입니다. C집단이 5퍼센트포인트 높습니다. 차이는 비율의 차이이므로 5%가 아니라 5퍼센트포인트라고 표현합니다.",
        "summary": ["상대도수는 도수를 전체 도수로 나눈 값이다.", "전체 크기가 다른 집단은 상대도수로 비교한다.", "비율 차이는 퍼센트포인트로 표현할 수 있다."],
        "quiz": {"id": "ms21-relative-frequency", "kind": "quiz", "prompt": "A집단 20명 중 12명, B집단 60명 중 30명이 참여했습니다. 참여율이 더 높은 집단은 어디인가요?", "options": ["A집단: 60%", "B집단: 50%", "두 집단이 같다"], "correct_index": 0, "correct_feedback": "12/20=0.6, 30/60=0.5이므로 A집단의 참여율이 높습니다.", "incorrect_feedback": "참여자 수가 아니라 각 집단 전체 인원으로 나눈 비율을 비교하세요.", "hints": ["A집단은 12÷20, B집단은 30÷60을 계산합니다.", "소수에 100을 곱하면 퍼센트입니다."]},
    },
]


def main() -> None:
    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms12_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)

    chapters = []
    for item in SPECS:
        ch = helper.make_chapter(
            item["code"], item["slug"], item["topic"], item["code"], item["html"],
            item["opening"], item["concept"], item["example"], item["solution"],
            item["practice"], item["answer"], item["summary"],
        )
        ch["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(ch)

    codes = [item["code"] for item in SPECS]
    tags = ["중학수학 2-1", "2022 개정", "학기 배정 후보", "공식 학기 배열 아님",
            "교사 검수 대기", "출처: 교육부 고시 제2022-33호 별책8 수학과 교육과정",
            "저작권: 신규 집필 초안, 상업 교재 문장·문제·그림 미사용"]
    book = {"schema_version": 2, "title": "중학수학 2-1 개념서 · 2022 개정 후보 시범",
            "subtitle": "입체와 도형의 성질을 근거로 설명하고 자료를 비율로 비교합니다",
            "category": "concept_textbook_prototype", "tags": tags + [f"성취기준 후보: {c}" for c in codes],
            "curriculum_version": "2022", "standard_codes": codes, "chapters": chapters}

    OUT.mkdir(parents=True, exist_ok=True)
    book_path = OUT / BOOK_FILE
    book_path.write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    html_files = []
    for item in SPECS:
        html_files.append(item["html"])
        content = make_html(item)
        (OUT / item["html"]).write_text(content, encoding="utf-8")

    manuscript = ["# 중학수학 2-1 개념서 · 2022 개정 후보 원고", "",
                  "> 상태: 신규 집필 초안. 학기 귀속과 상품 전 범위는 공식 원문만으로 확인되지 않았습니다.",
                  "> 기준 코드는 교육부 고시 제2022-33호 별책8에서 확인한 중학교 학년군 코드입니다.", ""]
    for item, chapter in zip(SPECS, chapters):
        manuscript.extend([f"## {item['topic']}", f"기준 후보: {item['code']}", ""])
        for pg in chapter["pages"]:
            manuscript.extend([f"### {pg['title']}", ""])
            for b in pg["blocks"]:
                if b.get("text"):
                    manuscript.extend([f"**{b['title']}** {b['text']}", ""])
                manuscript.extend([f"- {x}" for x in b.get("items", [])])
        manuscript.extend([f"체험 원본: `{item['html']}`", ""])
    (OUT / "중학수학2-1_2022개정_학생용원고_시범.md").write_text("\n".join(manuscript), encoding="utf-8")

    source_codes = {line.split("]", 1)[0].lstrip("[") for line in
                    (ROOT / "work/official-curriculum/2022_appendix8_math.txt").read_text(encoding="utf-8").splitlines()
                    if line.startswith("[9수")}
    missing = sorted(set(codes) - source_codes)
    if missing:
        raise ValueError(f"Official standards not found in extracted source: {missing}")
    import hashlib
    source_hwp = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
    source_zip = ROOT / "work/official-curriculum/2022_math_standards_bundle.zip"
    manifest = {"target": book["title"], "status": "candidate_partial_draft",
                "semester_assignment": "editorial_candidate_not_officially_confirmed",
                "standards": codes, "standard_source_url": "https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458",
                "source_hwp_sha256": hashlib.sha256(source_hwp.read_bytes()).hexdigest().upper(),
                "source_archive_sha256": hashlib.sha256(source_zip.read_bytes()).hexdigest().upper(),
                "content_rights": "newly authored draft; no commercial textbook content or external assets; publication rights decision pending",
                "math_review": "authored examples arithmetically checked; teacher review pending",
                "features": [{"standard": x["code"], "html": x["html"], "type": x["kind"],
                              "runtime": "standalone source asset; not app-integrated"} for x in SPECS]}
    (OUT / "중학수학2-1_2022개정_원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text(
        "# 중학수학 2-1 개념서 · 2022 개정 후보 시범\n\n"
        "4개 모듈·24쪽의 오리지널 초안과 V2 퀴즈, 독립 HTML 체험 파일 4개를 생성합니다. "
        "별책8 기준 코드는 학년군으로 제시되므로 학기 배정은 편집 후보입니다. 전 범위 교재가 아닙니다.\n\n"
        "교사 수학 검수, 학기 범위 대조, 프로젝트 권리 결정, 앱·학생 파일럿은 대기 상태입니다.\n\n"
        "재생성: `python tool/build_middle_school_2_1_2022_candidate.py`\n", encoding="utf-8")
    print(f"Built candidate: {len(chapters)} modules, {sum(len(x['pages']) for x in chapters)} pages, {len(html_files)} HTML assets, schema v2.")


def make_html(item: dict) -> str:
    """Render a self-contained exploratory source; its logic remains outside BookData."""
    title = item["topic"]
    common = """<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%(title)s</title><style>body{font:17px/1.6 system-ui,sans-serif;max-width:48rem;margin:auto;padding:1rem;color:#172033}label{display:block;margin:1rem 0 .25rem}input,select,button{min-height:2.7rem}input{width:100%%}svg{width:min(100%%,28rem);height:auto;display:block;margin:1rem auto}output,strong[aria-live]{color:#1d4ed8}button:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #b45309}</style></head><body><main><h1>%(title)s</h1><p>조건을 하나씩 바꾸고 관찰한 결과를 설명해 보세요.</p><section aria-label="직접 조작">%(body)s</section><p>성취기준 학년군 후보 · 학기 배정 및 교사 검수 대기</p></main><script>%(script)s</script></body></html>"""
    if item["kind"] == "solids":
        body = '<label for="solid">입체 모양</label><select id="solid"><option value="cylinder">원기둥</option><option value="cone">원뿔</option><option value="sphere">구</option></select><svg viewBox="0 0 240 160" role="img" aria-label="선택한 회전체의 단면 예시"><ellipse cx="120" cy="35" rx="55" ry="18" fill="none" stroke="currentColor"/><path d="M65 35v90 M175 35v90 M65 125a55 18 0 0 0 110 0" fill="none" stroke="currentColor"/><path id="cut" d="M65 80h110" stroke="#b45309" stroke-width="4"/></svg><p id="result" role="status" aria-live="polite"></p><button id="check">단면 관찰</button>'
        script = "const s=document.querySelector('#solid'),r=document.querySelector('#result'),c=document.querySelector('#cut');function draw(){if(s.value==='cylinder'){r.textContent='축에 수직인 단면은 원, 축을 포함하는 단면은 직사각형입니다.';c.setAttribute('d','M65 80h110')}else if(s.value==='cone'){r.textContent='축에 수직인 단면은 원, 축을 포함하는 단면은 삼각형입니다.';c.setAttribute('d','M65 80L120 25 175 80')}else{r.textContent='중심을 지나는 평면의 단면은 원입니다.';c.setAttribute('d','M65 80a55 55 0 1 0 110 0a55 55 0 1 0 -110 0')}}s.addEventListener('change',draw);document.querySelector('#check').addEventListener('click',draw);draw();"
    elif item["kind"] == "isosceles":
        body = '<label for="base">밑각 <output id="baseOut">50°</output></label><input id="base" type="range" min="10" max="85" value="50"><svg viewBox="0 0 240 170" role="img" aria-label="두 밑각이 같은 이등변삼각형"><path d="M35 140L120 25 205 140Z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M120 25L120 140" stroke="#b45309" stroke-dasharray="5 4"/></svg><p>꼭짓각: <strong id="apex" aria-live="polite"></strong></p><label for="guess">꼭짓각을 고르세요</label><select id="guess"><option>70</option><option>80</option><option>90</option></select><button id="check">답 확인</button><p id="feedback" role="status"></p>'
        script = "const b=document.querySelector('#base'),o=document.querySelector('#baseOut'),a=document.querySelector('#apex');function draw(){o.value=b.value+'°';a.textContent=(180-2*Number(b.value))+'°'}b.addEventListener('input',draw);document.querySelector('#check').addEventListener('click',()=>document.querySelector('#feedback').textContent=Number(document.querySelector('#guess').value)===180-2*Number(b.value)?'맞았습니다.':'두 밑각이 같다는 성질과 내각의 합을 확인하세요.');draw();"
    elif item["kind"] == "quadrilaterals":
        body = '<label for="shape">사각형</label><select id="shape"><option>평행사변형</option><option>직사각형</option><option>마름모</option><option>정사각형</option></select><svg viewBox="0 0 240 150" role="img" aria-label="사각형의 두 대각선"><path d="M45 35L190 35 195 115 40 115Z M45 35L195 115 M190 35L40 115" fill="none" stroke="currentColor"/><circle cx="117" cy="75" r="4" fill="#b45309"/></svg><p id="facts" role="status" aria-live="polite"></p><button id="check">성질 확인</button>'
        script = "const s=document.querySelector('#shape'),f=document.querySelector('#facts');function draw(){const v={평행사변형:'두 대각선은 서로를 이등분합니다.',직사각형:'두 대각선은 서로를 이등분하고 길이가 같습니다.',마름모:'두 대각선은 서로를 이등분하고 수직으로 만납니다.',정사각형:'두 대각선은 서로를 이등분하고 길이가 같으며 수직으로 만납니다.'};f.textContent=v[s.value]}s.addEventListener('change',draw);document.querySelector('#check').addEventListener('click',draw);draw();"
    else:
        body = '<label for="countA">A집단 전체 인원</label><input id="countA" type="number" min="1" value="20"><label for="hitA">A집단 해당 인원</label><input id="hitA" type="number" min="0" value="12"><label for="countB">B집단 전체 인원</label><input id="countB" type="number" min="1" value="60"><label for="hitB">B집단 해당 인원</label><input id="hitB" type="number" min="0" value="30"><button id="check">상대도수 비교</button><p id="result" role="status" aria-live="polite"></p>'
        script = "const ids=['countA','hitA','countB','hitB'];function draw(){const [a,x,b,y]=ids.map(i=>Number(document.getElementById(i).value));if(a<1||b<1||x<0||y<0||x>a||y>b){document.querySelector('#result').textContent='전체 인원과 해당 인원 범위를 확인하세요.';return}const ra=x/a,rb=y/b;document.querySelector('#result').textContent=`A ${(ra*100).toFixed(1)}%, B ${(rb*100).toFixed(1)}% · ${ra===rb?'같은 비율입니다.':ra>rb?'A의 상대도수가 높습니다.':'B의 상대도수가 높습니다.'}`}ids.forEach(i=>document.getElementById(i).addEventListener('input',draw));document.querySelector('#check').addEventListener('click',draw);draw();"
    return common % {"title": title, "body": body, "script": script}


if __name__ == "__main__":
    main()

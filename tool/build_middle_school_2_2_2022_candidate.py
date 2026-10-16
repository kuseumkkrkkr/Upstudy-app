"""Build an original 2022 middle-school 2-2 candidate; semester allocation is editorial."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중학수학2-2_2022개정_통합시범"
BOOK_FILE = "중학수학2-2_2022개정_측정과가능성_BookData_V2_시범.json"
SPECS = [
    {
        "code": "9수03-15", "slug": "ms22-22-pythagorean", "topic": "피타고라스 정리로 길이와 관계 구하기", "kind": "pythagorean",
        "html": "중학수학2-2_2022개정_피타고라스정리_체험형_시범.html",
        "opening": "정사각형의 대각선처럼 직접 재기 어려운 길이는 어떻게 구할 수 있을까요? 직각삼각형의 두 짧은 변과 빗변 사이 관계를 먼저 예상해 보세요.",
        "concept": "직각삼각형에서 직각을 낀 두 변의 길이를 a, b, 빗변의 길이를 c라 하면 a²+b²=c²입니다. 이 관계를 피타고라스 정리라고 합니다. 정리의 역에 따라 세 변의 길이가 a²+b²=c²를 만족하면 그 삼각형은 직각삼각형입니다.",
        "example": "직각삼각형의 두 직각변이 6 cm, 8 cm일 때 빗변의 길이를 구하세요.",
        "solution": "6²+8²=36+64=100=10²이므로 빗변은 10 cm입니다. 길이는 양수이므로 −10은 답이 될 수 없습니다.",
        "practice": "직각삼각형의 빗변이 13 cm이고 한 직각변이 5 cm입니다. 다른 직각변을 구하세요.",
        "answer": "다른 직각변을 a라 하면 a²+5²=13²입니다. a²=169−25=144이고 길이는 양수이므로 a=12 cm입니다.",
        "summary": ["직각삼각형에서 두 직각변 제곱의 합은 빗변 제곱과 같다.", "정리의 역으로 세 변이 주어진 삼각형의 직각 여부를 판별할 수 있다.", "길이는 양수이므로 제곱근의 양의 값을 취한다."],
        "quiz": {"id": "ms22-pythagorean-quiz", "kind": "quiz", "prompt": "직각변의 길이가 6 cm와 8 cm인 직각삼각형의 빗변은 얼마인가요?", "options": ["10 cm", "12 cm", "14 cm"], "correct_index": 0, "correct_feedback": "6²+8²=100=10²이므로 빗변은 10 cm입니다.", "incorrect_feedback": "두 직각변의 제곱을 더한 뒤 제곱근을 구하세요.", "hints": ["a²+b²=c²를 사용합니다.", "36+64=100입니다."]},
    },
    {
        "code": "9수03-17", "slug": "ms22-22-trig-ratio", "topic": "삼각비로 직접 재기 어려운 길이 추정하기", "kind": "trig",
        "html": "중학수학2-2_2022개정_삼각비비율_체험형_시범.html",
        "opening": "건물 높이를 직접 재지 않고 구하려면 어떤 길이와 각을 비교하면 좋을까요? 직각삼각형에서 한 예각과 변의 비율이 연결되는 모습을 살펴보세요.",
        "concept": "직각삼각형에서 예각 θ에 대해 sin θ는 맞은편 변/빗변, cos θ는 이웃한 직각변/빗변, tan θ는 맞은편 변/이웃한 직각변입니다. 같은 각을 가진 직각삼각형은 닮음이므로 대응하는 변의 비는 같습니다. 삼각비는 직접 측정하기 어려운 거리나 높이를 추정하는 데 활용할 수 있습니다.",
        "example": "직각삼각형에서 각 θ의 맞은편 변이 3, 이웃한 직각변이 4입니다. tan θ를 구하세요.",
        "solution": "tan θ는 맞은편 변을 이웃한 직각변으로 나눈 값이므로 3/4입니다. 두 변의 단위가 같다면 비에는 단위가 붙지 않습니다.",
        "practice": "수평 거리 20 m, 고도각 θ에 대해 tan θ=0.5라고 합니다. 건물 높이를 구하고, 실제 측정에서 확인할 조건을 하나 쓰세요.",
        "answer": "tan θ=높이/수평거리이므로 높이=20×0.5=10 m입니다. 관찰 지점의 눈높이, 지면의 수평 여부, 각도 측정 오차 등을 고려해야 합니다.",
        "summary": ["sin·cos·tan은 각에 대한 변의 비를 나타낸다.", "닮은 직각삼각형에서는 같은 각의 삼각비가 같다.", "거리·높이 추정은 기준 위치와 측정 조건을 확인해야 한다."],
        "quiz": {"id": "ms22-trig-ratio-quiz", "kind": "quiz", "prompt": "예각 θ의 맞은편 변이 3, 이웃한 직각변이 4일 때 tan θ는?", "options": ["3/4", "4/3", "3/5"], "correct_index": 0, "correct_feedback": "tan θ는 맞은편 변을 이웃한 직각변으로 나눈 3/4입니다.", "incorrect_feedback": "tan θ의 분자와 분모가 어떤 변인지 확인하세요.", "hints": ["sin은 맞은편/빗변, cos는 이웃/빗변입니다.", "tan은 맞은편/이웃한 직각변입니다."]},
    },
    {
        "code": "9수04-05", "slug": "ms22-22-counting", "topic": "합의 법칙과 곱의 법칙으로 경우 세기", "kind": "counting",
        "html": "중학수학2-2_2022개정_경우의수세기_체험형_시범.html",
        "opening": "상의 3가지와 바지 2가지가 있다면 옷차림은 몇 가지일까요? 선택을 한 번으로 끝내는 경우와 두 단계를 모두 거치는 경우를 나누어 보세요.",
        "concept": "서로 겹치지 않는 선택지 중 하나를 고르는 경우는 각 경우의 수를 더하는 합의 법칙을 쓸 수 있습니다. 첫 단계 선택 뒤 두 번째 단계를 이어서 고르면 각 단계의 선택 수를 곱하는 곱의 법칙을 쓸 수 있습니다. 복잡한 순열·조합 공식은 이 범위에서 사용하지 않습니다.",
        "example": "상의 3벌 중 하나와 바지 2벌 중 하나를 함께 고르는 옷차림은 몇 가지인가요?",
        "solution": "상의 선택마다 바지를 2가지로 고를 수 있으므로 3×2=6가지입니다. 두 단계를 모두 거치므로 곱의 법칙을 씁니다.",
        "practice": "음료 4종류 중 하나 또는 차 3종류 중 하나만 고릅니다. 서로 겹치지 않는 메뉴라면 선택 방법은 몇 가지인가요?",
        "answer": "음료와 차 중 하나만 고르므로 두 집합의 경우를 더해 4+3=7가지입니다. 두 메뉴를 함께 고르는 상황이 아니므로 곱하지 않습니다.",
        "summary": ["하나의 선택 경로 중 하나를 택하면 경우를 더한다.", "여러 단계를 차례로 모두 거치면 단계별 선택 수를 곱한다.", "무엇을 동시에 고르는지 상황을 문장이나 나무그림으로 확인한다."],
        "quiz": {"id": "ms22-counting-quiz", "kind": "quiz", "prompt": "모자 3종류와 가방 2종류에서 각각 하나씩 고르면 조합은 몇 가지인가요?", "options": ["5가지", "6가지", "9가지"], "correct_index": 1, "correct_feedback": "두 단계를 모두 선택하므로 3×2=6가지입니다.", "incorrect_feedback": "모자 하나마다 가능한 가방이 2개씩 있습니다.", "hints": ["선택 단계를 모두 거칩니다.", "각 단계의 선택 수를 곱해 보세요."]},
    },
    {
        "code": "9수04-06", "slug": "ms22-22-probability", "topic": "실험과 경우의 수로 확률 이해하기", "kind": "probability",
        "html": "중학수학2-2_2022개정_확률실험_체험형_시범.html",
        "opening": "주사위를 한 번 던져 짝수가 나올 가능성은 어떻게 나타낼까요? 가능한 결과와 조건에 맞는 결과를 구분하고, 반복 실험의 비율도 비교해 보세요.",
        "concept": "각 결과가 같은 가능성으로 일어나는 상황에서 어떤 사건의 확률은 그 사건에 속하는 경우의 수를 전체 경우의 수로 나눈 값입니다. 반복 실험에서 사건이 나타난 상대도수는 시행 횟수가 많아질수록 확률에 가까워지는 경향을 관찰할 수 있지만, 유한한 실험 결과가 이론적 확률과 반드시 같지는 않습니다.",
        "example": "공정한 주사위를 한 번 던질 때 4보다 큰 눈이 나올 확률을 구하세요.",
        "solution": "가능한 눈은 1부터 6까지 6가지이고, 4보다 큰 눈은 5와 6으로 2가지입니다. 따라서 확률은 2/6=1/3입니다.",
        "practice": "동전을 세 번 던질 때 앞면이 정확히 두 번 나오는 경우를 모두 쓰고 확률을 구하세요.",
        "answer": "앞면을 앞, 뒷면을 뒤로 쓰면 앞앞뒤, 앞뒤앞, 뒤앞앞의 3가지입니다. 전체 경우는 2×2×2=8가지이므로 확률은 3/8입니다.",
        "summary": ["확률은 같은 가능성의 결과를 가정할 때 유리한 경우/전체 경우로 구한다.", "실험에서 얻은 상대도수와 이론적 확률은 구분한다.", "시행 횟수가 적으면 상대도수의 변동이 클 수 있다."],
        "quiz": {"id": "ms22-probability-quiz", "kind": "quiz", "prompt": "공정한 주사위를 던져 4보다 큰 눈이 나올 확률은?", "options": ["1/6", "1/3", "1/2"], "correct_index": 1, "correct_feedback": "5와 6, 2가지가 유리하고 전체는 6가지이므로 2/6=1/3입니다.", "incorrect_feedback": "5와 6을 유리한 경우로 세고 전체 6가지로 나누세요.", "hints": ["4보다 큰 눈은 5와 6입니다.", "유리한 경우의 수를 가능한 전체 결과 수로 나눕니다."]},
    },
]


def make_html(item: dict) -> str:
    title = item["topic"]
    shell = """<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%(title)s</title><style>body{font:17px/1.6 system-ui,sans-serif;max-width:48rem;margin:auto;padding:1rem;color:#172033}label{display:block;margin:1rem 0 .25rem}input{width:100%%;min-height:2.5rem}button{min-height:2.75rem}svg{width:min(100%%,26rem);height:auto}output,strong[aria-live]{color:#1d4ed8}button:focus-visible,input:focus-visible{outline:3px solid #b45309}</style></head><body><main><h1>%(title)s</h1><p>값을 바꾸거나 실험을 반복하며 결과를 관찰하세요.</p>%(body)s<p>성취기준 학년군 후보 · 학기 배정 및 교사 검수 대기</p></main><script>%(script)s</script></body></html>"""
    if item["kind"] == "pythagorean":
        body = '<label for="a">첫 직각변 <output id="aOut">6</output></label><input id="a" type="range" min="1" max="12" value="6"><label for="b">둘째 직각변 <output id="bOut">8</output></label><input id="b" type="range" min="1" max="12" value="8"><svg viewBox="0 0 240 160" role="img" aria-label="직각삼각형 두 직각변과 빗변"><path d="M35 130L195 130 35 30Z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M35 113h17v17" fill="none" stroke="#b45309" stroke-width="2"/></svg><p>빗변: <strong id="c" aria-live="polite"></strong></p>'
        script = "const a=document.querySelector('#a'),b=document.querySelector('#b');function draw(){const x=+a.value,y=+b.value;document.querySelector('#aOut').value=x;document.querySelector('#bOut').value=y;document.querySelector('#c').textContent=Math.sqrt(x*x+y*y).toFixed(2)}a.addEventListener('input',draw);b.addEventListener('input',draw);draw();"
    elif item["kind"] == "trig":
        body = '<label for="opposite">맞은편 변 <output id="oppOut">3</output></label><input id="opposite" type="range" min="1" max="12" value="3"><label for="adjacent">이웃한 직각변 <output id="adjOut">4</output></label><input id="adjacent" type="range" min="1" max="12" value="4"><svg viewBox="0 0 220 150" role="img" aria-label="직각삼각형과 예각"><path d="M30 120L190 120 30 35Z" fill="none" stroke="currentColor" stroke-width="3"/><path d="M30 103h17v17" fill="none" stroke="#b45309"/></svg><p>tan θ = 맞은편/이웃한 직각변 = <strong id="ratio" aria-live="polite"></strong></p>'
        script = "const o=document.querySelector('#opposite'),a=document.querySelector('#adjacent');function draw(){document.querySelector('#oppOut').value=o.value;document.querySelector('#adjOut').value=a.value;document.querySelector('#ratio').textContent=(+o.value/+a.value).toFixed(3)}o.addEventListener('input',draw);a.addEventListener('input',draw);draw();"
    elif item["kind"] == "counting":
        body = '<label for="first">첫 단계 선택 수</label><input id="first" type="range" min="1" max="8" value="3"><output id="firstOut">3</output><label for="second">둘째 단계 선택 수</label><input id="second" type="range" min="1" max="8" value="2"><output id="secondOut">2</output><p>전체 조합: <strong id="total" aria-live="polite"></strong></p>'
        script = "const a=document.querySelector('#first'),b=document.querySelector('#second');function draw(){document.querySelector('#firstOut').value=a.value;document.querySelector('#secondOut').value=b.value;document.querySelector('#total').textContent=Number(a.value)*Number(b.value)+'가지'}a.addEventListener('input',draw);b.addEventListener('input',draw);draw();"
    else:
        body = '<button id="roll">주사위 굴리기</button><button id="reset">기록 초기화</button><p>시행 횟수: <strong id="trials" aria-live="polite">0</strong></p><p>짝수 결과 비율: <strong id="frequency" aria-live="polite">시행 전</strong></p><p id="last" role="status"></p>'
        script = "let n=0,even=0;const update=()=>{document.querySelector('#trials').textContent=n;document.querySelector('#frequency').textContent=n?(even+'/'+n+' = '+(even/n).toFixed(3)):'시행 전'};document.querySelector('#roll').addEventListener('click',()=>{const d=1+Math.floor(Math.random()*6);n++;if(d%2===0)even++;document.querySelector('#last').textContent='이번 결과: '+d+(d%2===0?' (짝수)':' (홀수)');update()});document.querySelector('#reset').addEventListener('click',()=>{n=0;even=0;document.querySelector('#last').textContent='';update()});"
    return shell % {"title": title, "body": body, "script": script}


def main() -> None:
    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms12_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)

    codes = [item["code"] for item in SPECS]
    source = (ROOT / "work/official-curriculum/2022_appendix8_math.txt").read_text(encoding="utf-8")
    missing = [code for code in codes if f"[{code}]" not in source]
    if missing:
        raise ValueError(f"Official standards not found in extracted source: {missing}")

    chapters = []
    for item in SPECS:
        ch = helper.make_chapter(item["code"], item["slug"], item["topic"], item["code"], item["html"],
                                 item["opening"], item["concept"], item["example"], item["solution"],
                                 item["practice"], item["answer"], item["summary"])
        ch["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        if item["kind"] == "probability":
            ch["pages"][-2]["blocks"].append({"type": "activity", "activity": {
                "id": "ms22-discrete-probability-experiment", "kind": "discreteExperiment",
                "prompt": "공정한 주사위를 반복해서 던져 짝수 눈의 상대도수가 어떻게 달라지는지 관찰하세요.",
                "hints": ["짝수 사건은 2, 4, 6입니다.", "시행 횟수와 짝수 눈의 누적 횟수로 상대도수를 계산합니다."],
                "experiment": {"outcomes": [
                    {"label": "1", "weight": 1, "success": False},
                    {"label": "2", "weight": 1, "success": True},
                    {"label": "3", "weight": 1, "success": False},
                    {"label": "4", "weight": 1, "success": True},
                    {"label": "5", "weight": 1, "success": False},
                    {"label": "6", "weight": 1, "success": True},
                ], "max_trials": 10000, "batch_sizes": [1]},
            }})
        chapters.append(ch)

    tags = ["중학수학 2-2", "2022 개정", "학기 배정 후보", "공식 학기 배열 아님", "교사 검수 대기",
            "출처: 교육부 고시 제2022-33호 별책8 수학과 교육과정",
            "저작권: 신규 집필 초안, 상업 교재 문장·문제·그림 미사용"]
    book = {"schema_version": 2, "title": "중학수학 2-2 개념서 · 2022 개정 후보 시범",
            "subtitle": "직각삼각형을 측정과 가능성 문제에 연결해 설명합니다",
            "category": "concept_textbook_prototype", "tags": tags + [f"성취기준 후보: {c}" for c in codes],
            "curriculum_version": "2022", "standard_codes": codes, "chapters": chapters}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for item in SPECS:
        (OUT / item["html"]).write_text(make_html(item), encoding="utf-8")

    student = ["# 중학수학 2-2 개념서 · 2022 개정 후보 원고", "",
               "> 오리지널 부분 초안. 학기 배정과 전 상품 범위는 공식 원문에 제시되지 않아 편집 후보로 표시합니다.",
               "> 공식 근거: 교육부 고시 제2022-33호 별책8 수학과 교육과정. 학년군 코드 직접 대조.", ""]
    for item, chapter in zip(SPECS, chapters):
        student.extend([f"## {item['topic']}", f"기준 후보: {item['code']}", ""])
        for pg in chapter["pages"]:
            student.extend([f"### {pg['title']}", ""])
            for block in pg["blocks"]:
                if block.get("text"):
                    student.extend([f"**{block['title']}** {block['text']}", ""])
                student.extend([f"- {x}" for x in block.get("items", [])])
        student.extend([f"체험 원본: `{item['html']}`", ""])
    (OUT / "중학수학2-2_2022개정_학생용원고_시범.md").write_text("\n".join(student), encoding="utf-8")

    source_hwp = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
    source_zip = ROOT / "work/official-curriculum/2022_math_standards_bundle.zip"
    book_hash = canonical_file_sha256(OUT / BOOK_FILE)
    manifest_path = OUT / "중학수학2-2_2022개정_원고매니페스트.json"
    try:
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        previous = {}
    validation_current = previous.get("bookdata_sha256") == book_hash
    activity_kinds = sorted({block["activity"]["kind"] for chapter in chapters
                             for page_item in chapter["pages"] for block in page_item["blocks"]
                             if block.get("type") == "activity"})
    manifest = {"target": book["title"], "status": "candidate_partial_draft",
                "semester_assignment": "editorial_candidate_not_officially_confirmed", "standards": codes,
                "bookdata_file": BOOK_FILE,
                "bookdata_sha256": book_hash,
                "activity_kinds": activity_kinds,
                "runtime_import_status": previous.get("runtime_import_status", "pending_current_hash_validation") if validation_current else "pending_current_hash_validation",
                "runtime_validator_head": previous.get("runtime_validator_head") if validation_current else None,
                "curriculum_review": "official_hwp_table_mapped; teacher_review_pending",
                "teacher_review": "pending",
                "standard_source_url": "https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458",
                "source_hwp_sha256": hashlib.sha256(source_hwp.read_bytes()).hexdigest().upper(),
                "source_archive_sha256": hashlib.sha256(source_zip.read_bytes()).hexdigest().upper(),
                "content_rights": "newly authored draft; publication rights decision pending",
                "publication_eligibility": "not_eligible",
                "math_review": "examples checked manually; independent teacher review pending",
                "features": [{"standard": x["code"], "html": x["html"], "type": x["kind"],
                              "runtime": ("native discreteExperiment covers dice outcomes and relative frequency; HTML remains a separate source reference with partial feature parity"
                                          if x["kind"] == "probability" else "standalone source asset; not app-integrated")} for x in SPECS]}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text("# 중학수학 2-2 개념서 · 2022 개정 후보 시범\n\n"
        "4개 모듈·24쪽의 오리지널 부분 초안입니다. V2 quiz 4개와 `discreteExperiment` 1개를 포함합니다. "
        "주사위 확률 실험은 원본 HTML의 시행·상대도수 기능을 네이티브로 부분 대응하며 HTML 파일은 근거 자산으로 보존합니다. "
        "성취기준은 학년군 코드이고 학기 배정은 편집 후보입니다. HTML/native 화면 parity, 교사 검수, 권리 결정, 앱 게시 승인은 대기입니다.\n\n"
        "재생성: `python tool/build_middle_school_2_2_2022_candidate.py`\n", encoding="utf-8")
    print(f"Built candidate: {len(chapters)} modules, {sum(len(x['pages']) for x in chapters)} pages, 4 HTML assets, schema v2.")


if __name__ == "__main__":
    main()

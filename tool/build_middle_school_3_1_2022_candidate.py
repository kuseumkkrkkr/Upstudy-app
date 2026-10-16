"""Build an original 2022 middle-school 3-1 candidate; semester allocation is editorial."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고/중학수학3-1_2022개정_통합시범"
BOOK_FILE = "중학수학3-1_2022개정_수와다항식함수_BookData_V2_시범.json"
SPECS = [
    {
        "code": "9수01-08", "slug": "ms31-22-square-root", "topic": "제곱근과 무리수의 크기 살펴보기", "kind": "sqrt",
        "html": "중학수학3-1_2022개정_제곱근수직선_체험형_시범.html",
        "opening": "정사각형의 넓이가 2일 때 한 변의 길이는 정수로 나타낼 수 있을까요? 수직선에서 √2의 위치를 찾아 보세요.",
        "concept": "0 이상의 수 a에 대해 제곱하여 a가 되는 수를 a의 제곱근이라고 합니다. a>0이면 제곱근은 두 개이고, 그중 양수인 제곱근을 √a로 나타냅니다. √2처럼 유리수가 아닌 실수가 무리수이며, 실수는 유리수와 무리수로 이루어집니다.",
        "example": "√2가 1과 2 사이임을 제곱을 이용해 설명하고, 1.4와 1.5 중 어느 쪽에 가까운지 확인하세요.",
        "solution": "1²=1<2<4=2²이므로 √2는 1과 2 사이입니다. 1.4²=1.96, 1.5²=2.25이므로 √2는 1.4와 1.5 사이이며 1.4에 더 가깝습니다.",
        "practice": "√10이 3과 4 사이임을 확인하고, 3.1과 3.2 중 어느 쪽이 √10에 더 가까운지 비교하세요.",
        "answer": "3²=9<10<16=4²이므로 3<√10<4입니다. 3.1²=9.61, 3.2²=10.24이므로 √10은 3.1과 3.2 사이이며 3.2에 더 가깝습니다.",
        "summary": ["양의 수의 제곱근은 서로 부호가 반대인 두 수다.", "√a는 a의 양의 제곱근을 나타낸다.", "연속한 제곱수 사이에 있는 수의 제곱근으로 위치를 좁힌다."],
        "quiz": {"id": "ms31-square-root-quiz", "kind": "quiz", "prompt": "√2의 위치에 대한 설명으로 옳은 것은 무엇인가요?", "options": ["1과 2 사이이며 1.4보다 크다", "2와 3 사이", "유리수이다"], "correct_index": 0, "correct_feedback": "1.4²=1.96<2이므로 √2>1.4이고, 2²=4>2이므로 √2<2입니다.", "incorrect_feedback": "제곱한 값 1.4²와 2²를 2와 비교하세요.", "hints": ["1.4²=1.96입니다.", "2²=4입니다."]},
    },
    {
        "code": "9수02-19", "slug": "ms31-22-polynomial-product", "topic": "다항식의 곱셈을 넓이로 설명하기", "kind": "poly-product",
        "html": "중학수학3-1_2022개정_다항식넓이모형_체험형_시범.html",
        "opening": "가로가 x+3, 세로가 x+2인 직사각형의 넓이를 두 방법으로 나타내 보세요. 작은 직사각형 네 개의 넓이와 곱셈식을 비교하세요.",
        "concept": "분배법칙에 따라 (x+a)(x+b)=x²+(a+b)x+ab입니다. 넓이 모형에서는 x×x, x×b, a×x, a×b인 네 부분의 넓이를 더해 같은 식을 얻습니다. 다항식의 곱셈과 인수분해는 서로 역관계입니다.",
        "example": "(x+3)(x+2)를 전개하세요.",
        "solution": "x²+2x+3x+6=x²+5x+6입니다. 가운데 항은 서로 다른 두 직사각형 넓이의 합입니다.",
        "practice": "(x+4)(x+1)을 전개하고 x=2를 대입해 곱의 값과 전개한 식의 값이 같은지 확인하세요.",
        "answer": "전개하면 x²+5x+4입니다. x=2일 때 원래 식은 6×3=18이고 전개식은 4+10+4=18이므로 같습니다.",
        "summary": ["분배법칙으로 각 항의 곱을 빠짐없이 더한다.", "넓이 모형의 네 부분이 전개의 네 곱에 대응한다.", "전개 전후에 수를 대입해 결과를 확인할 수 있다."],
        "quiz": {"id": "ms31-polynomial-product-quiz", "kind": "quiz", "prompt": "(x+3)(x+2)를 전개한 식은 무엇인가요?", "options": ["x²+5x+6", "x²+6x+5", "x²+6"], "correct_index": 0, "correct_feedback": "x²+2x+3x+6=x²+5x+6입니다.", "incorrect_feedback": "네 항의 곱을 적고 동류항 2x와 3x를 더하세요.", "hints": ["x×x, x×2, 3×x, 3×2를 각각 계산하세요."]},
    },
    {
        "code": "9수02-19", "slug": "ms31-22-factorization", "topic": "전개의 역으로 다항식 인수분해하기", "kind": "factorization",
        "html": "중학수학3-1_2022개정_인수분해짝찾기_체험형_시범.html",
        "opening": "x²+7x+12를 두 일차식의 곱으로 나타내려면 어떤 두 수를 찾아야 할까요? 합과 곱이라는 조건을 함께 살펴보세요.",
        "concept": "x²+(p+q)x+pq는 (x+p)(x+q)로 인수분해할 수 있습니다. x²+7x+12에서는 합이 7이고 곱이 12인 두 수 3, 4를 찾으므로 (x+3)(x+4)입니다. 전개해 원래 식과 같은지 확인합니다.",
        "example": "x²+7x+12를 인수분해하세요.",
        "solution": "합이 7이고 곱이 12인 두 수는 3과 4입니다. 따라서 x²+7x+12=(x+3)(x+4)입니다. 전개하면 x²+7x+12가 되어 확인됩니다.",
        "practice": "x²−x−12를 인수분해하고, 찾은 두 수가 합과 곱 조건을 만족하는지 확인하세요.",
        "answer": "곱이 −12이고 합이 −1인 두 수는 −4와 3입니다. 따라서 x²−x−12=(x−4)(x+3)입니다.",
        "summary": ["x²+(p+q)x+pq의 두 수는 합과 곱을 모두 만족한다.", "음수 상수항이면 두 수의 부호가 서로 다르다.", "전개해 원래 다항식과 같은지 확인한다."],
        "quiz": {"id": "ms31-factorization-quiz", "kind": "quiz", "prompt": "x²−x−12의 인수분해는 무엇인가요?", "options": ["(x−4)(x+3)", "(x−3)(x+4)", "(x−6)(x+2)"], "correct_index": 0, "correct_feedback": "−4+3=−1이고 −4×3=−12입니다.", "incorrect_feedback": "두 수의 합은 −1, 곱은 −12가 되어야 합니다.", "hints": ["곱이 음수이므로 부호는 서로 다릅니다.", "4와 3의 차이는 1입니다."]},
    },
    {
        "code": "9수02-22", "slug": "ms31-22-quadratic-function", "topic": "이차함수 그래프의 최댓값·최솟값 읽기", "kind": "quadratic",
        "html": "중학수학3-1_2022개정_이차함수꼭짓점_체험형_시범.html",
        "opening": "포물선의 꼭짓점이 바뀌면 그래프가 갖는 가장 큰 값이나 가장 작은 값은 어떻게 달라질까요? 꼭짓점과 그래프의 방향을 먼저 살펴보세요.",
        "concept": "y=a(x−h)²+k의 그래프 꼭짓점은 (h,k)입니다. a>0이면 위로 열려 최솟값 k를 갖고, a<0이면 아래로 열려 최댓값 k를 갖습니다. 정의역이 실수 전체일 때 반대쪽 방향으로는 값이 한없이 커지거나 작아져 극값이 없습니다.",
        "example": "y=−(x−2)²+5의 최댓값과 그때의 x를 구하세요.",
        "solution": "그래프는 아래로 열리고 꼭짓점은 (2,5)입니다. 따라서 최댓값은 5이고 x=2일 때 얻습니다.",
        "practice": "y=2(x+1)²−3의 최솟값과 그때의 x를 구하세요.",
        "answer": "계수 2가 양수이므로 그래프는 위로 열립니다. 꼭짓점은 (−1,−3)이므로 최솟값은 −3이며 x=−1일 때 얻습니다.",
        "summary": ["꼭짓점형에서 꼭짓점은 (h,k)이다.", "a의 부호로 위·아래로 열리는 방향을 판단한다.", "정의역이 실수 전체인지 확인하고 해당하는 한쪽 극값을 읽는다."],
        "quiz": {"id": "ms31-quadratic-function-quiz", "kind": "quiz", "prompt": "y=−(x−2)²+5의 최댓값은 얼마인가요?", "options": ["2", "5", "−5"], "correct_index": 1, "correct_feedback": "아래로 열린 포물선의 꼭짓점 y좌표 5가 최댓값입니다.", "incorrect_feedback": "꼭짓점의 y좌표와 그래프의 열리는 방향을 확인하세요.", "hints": ["꼭짓점은 (2,5)입니다.", "계수 −1이므로 아래로 열립니다."]},
    },
]


def make_html(item: dict) -> str:
    shell = """<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>%(title)s</title><style>body{font:17px/1.6 system-ui,sans-serif;max-width:48rem;margin:auto;padding:1rem;color:#172033}label{display:block;margin:1rem 0 .25rem}input{width:100%%;min-height:2.5rem}svg{width:min(100%%,26rem);height:auto}strong[aria-live]{color:#1d4ed8}</style></head><body><main><h1>%(title)s</h1><p>입력 값을 바꾸며 수식과 그림이 어떻게 연결되는지 확인하세요.</p>%(body)s<p>성취기준 학년군 후보 · 학기 배정 및 교사 검수 대기</p></main><script>%(script)s</script></body></html>"""
    if item["kind"] == "sqrt":
        body = '<label for="value">제곱근을 확인할 수 <output id="valueOut">2</output></label><input id="value" type="range" min="1" max="25" value="2"><svg viewBox="0 0 420 80" role="img" aria-label="수직선 위 제곱근 위치"><line x1="30" y1="40" x2="390" y2="40" stroke="currentColor"/><circle id="point" cx="157" cy="40" r="8" fill="#b45309"/></svg><p>√<span id="n"></span> ≈ <strong id="root" aria-live="polite"></strong></p>'
        script = "const s=document.querySelector('#value');function draw(){const n=+s.value,r=Math.sqrt(n);document.querySelector('#valueOut').value=n;document.querySelector('#n').textContent=n;document.querySelector('#root').textContent=r.toFixed(3);document.querySelector('#point').setAttribute('cx',30+r*60)}s.addEventListener('input',draw);draw();"
    elif item["kind"] == "poly-product":
        body = '<label for="a">상수 a <output id="aOut">3</output></label><input id="a" type="range" min="1" max="8" value="3"><label for="b">상수 b <output id="bOut">2</output></label><input id="b" type="range" min="1" max="8" value="2"><p>(x+a)(x+b) = <strong id="expression" aria-live="polite"></strong></p><svg viewBox="0 0 240 150" role="img" aria-label="x와 상수로 나눈 직사각형 넓이 모형"><rect x="25" y="25" width="110" height="90" fill="none" stroke="currentColor"/><path d="M80 25v90M25 70h110" stroke="#b45309"/></svg>'
        script = "const a=document.querySelector('#a'),b=document.querySelector('#b');function draw(){const x=+a.value,y=+b.value;document.querySelector('#aOut').value=x;document.querySelector('#bOut').value=y;document.querySelector('#expression').textContent=`x² + ${x+y}x + ${x*y}`}a.addEventListener('input',draw);b.addEventListener('input',draw);draw();"
    elif item["kind"] == "factorization":
        body = '<label for="p">첫 인수 상수 p <output id="pOut">3</output></label><input id="p" type="range" min="-8" max="8" value="3"><label for="q">둘째 인수 상수 q <output id="qOut">4</output></label><input id="q" type="range" min="-8" max="8" value="4"><p>전개식: <strong id="form" aria-live="polite"></strong></p>'
        script = "const p=document.querySelector('#p'),q=document.querySelector('#q');function draw(){const x=+p.value,y=+q.value;document.querySelector('#pOut').value=x;document.querySelector('#qOut').value=y;document.querySelector('#form').textContent=`x² + ${x+y}x + ${x*y}`}p.addEventListener('input',draw);q.addEventListener('input',draw);draw();"
    else:
        body = '<label for="h">꼭짓점의 x좌표 h <output id="hOut">2</output></label><input id="h" type="range" min="-5" max="5" value="2"><label for="k">꼭짓점의 y좌표 k <output id="kOut">5</output></label><input id="k" type="range" min="-5" max="8" value="5"><label for="sign">그래프 방향</label><select id="sign"><option value="-1">아래로 열림</option><option value="1">위로 열림</option></select><svg viewBox="0 0 260 170" role="img" aria-label="꼭짓점을 바꿀 수 있는 포물선"><path d="M35 40Q130 180 225 40" fill="none" stroke="currentColor" stroke-width="3"/><circle id="vertex" cx="130" cy="115" r="6" fill="#b45309"/></svg><p id="extreme" aria-live="polite"></p>'
        script = "const h=document.querySelector('#h'),k=document.querySelector('#k'),s=document.querySelector('#sign');function draw(){const hv=+h.value,kv=+k.value,down=s.value==='-1';document.querySelector('#hOut').value=hv;document.querySelector('#kOut').value=kv;document.querySelector('#vertex').setAttribute('cx',130+hv*12);document.querySelector('#vertex').setAttribute('cy',100-kv*8);document.querySelector('#extreme').textContent=down?`최댓값 ${kv} (x=${hv})`:`최솟값 ${kv} (x=${hv})`}h.addEventListener('input',draw);k.addEventListener('input',draw);s.addEventListener('change',draw);draw();"
    return shell % {"title": item["topic"], "body": body, "script": script}


def main() -> None:
    helper_path = Path(__file__).with_name("build_middle_school_1_2_2022_candidate.py")
    spec = importlib.util.spec_from_file_location("ms12_helpers", helper_path)
    helper = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(helper)
    codes = [item["code"] for item in SPECS]
    official_text = (ROOT / "work/official-curriculum/2022_appendix8_math.txt").read_text(encoding="utf-8")
    if any(f"[{code}]" not in official_text for code in codes):
        raise ValueError("One or more candidate standards are absent from the extracted official appendix")

    chapters = []
    for item in SPECS:
        chapter = helper.make_chapter(item["code"], item["slug"], item["topic"], item["code"], item["html"],
            item["opening"], item["concept"], item["example"], item["solution"], item["practice"], item["answer"], item["summary"])
        chapter["pages"][-2]["blocks"].append({"type": "activity", "activity": item["quiz"]})
        chapters.append(chapter)

    tags = ["중학수학 3-1", "2022 개정", "학기 배정 후보", "공식 학기 배열 아님", "교사 검수 대기",
            "출처: 교육부 고시 제2022-33호 별책8 수학과 교육과정",
            "저작권: 신규 집필 초안, 상업 교재 문장·문제·그림 미사용"]
    book = {"schema_version": 2, "title": "중학수학 3-1 개념서 · 2022 개정 후보 시범",
            "subtitle": "제곱근과 다항식, 이차함수를 식과 그래프로 연결합니다",
            "category": "concept_textbook_prototype", "tags": tags + [f"성취기준 후보: {c}" for c in codes],
            "curriculum_version": "2022", "standard_codes": codes, "chapters": chapters}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / BOOK_FILE).write_text(json.dumps(book, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for item in SPECS:
        (OUT / item["html"]).write_text(make_html(item), encoding="utf-8")

    student = ["# 중학수학 3-1 개념서 · 2022 개정 후보 원고", "",
               "> 오리지널 부분 초안. 학기 배정·전 범위 정렬은 공식 원문만으로 확인하지 못해 편집 후보로 둡니다.", ""]
    for item, chapter in zip(SPECS, chapters):
        student.extend([f"## {item['topic']}", f"기준 후보: {item['code']}", ""])
        for page in chapter["pages"]:
            student.extend([f"### {page['title']}", ""])
            for block in page["blocks"]:
                if block.get("text"):
                    student.extend([f"**{block['title']}** {block['text']}", ""])
                student.extend([f"- {x}" for x in block.get("items", [])])
        student.extend([f"체험 원본: `{item['html']}`", ""])
    (OUT / "중학수학3-1_2022개정_학생용원고_시범.md").write_text("\n".join(student), encoding="utf-8")

    src_hwp = ROOT / "work/official-curriculum/2022_appendix8_math.hwp"
    src_zip = ROOT / "work/official-curriculum/2022_math_standards_bundle.zip"
    manifest = {"target": book["title"], "status": "candidate_partial_draft",
        "semester_assignment": "editorial_candidate_not_officially_confirmed", "standards": codes,
        "standard_source_url": "https://www.moe.go.kr/boardCnts/viewRenew.do?boardID=141&boardSeq=93458",
        "source_hwp_sha256": hashlib.sha256(src_hwp.read_bytes()).hexdigest().upper(),
        "source_archive_sha256": hashlib.sha256(src_zip.read_bytes()).hexdigest().upper(),
        "content_rights": "newly authored draft; publication rights decision pending",
        "math_review": "worked examples checked arithmetically; teacher review pending",
        "features": [{"standard": x["code"], "html": x["html"], "type": x["kind"], "runtime": "standalone source asset; not app-integrated"} for x in SPECS]}
    (OUT / "중학수학3-1_2022개정_원고매니페스트.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (OUT / "README.md").write_text("# 중학수학 3-1 개념서 · 2022 개정 후보 시범\n\n"
        "4개 모듈·24쪽 오리지널 초안, V2 퀴즈 4개, 독립 HTML 체험 4개를 재생성합니다. "
        "기준 코드는 학년군 기준이며 학기 배정은 편집 후보입니다. 교사 검수·권리 결정·앱 통합은 대기입니다.\n\n"
        "재생성: `python tool/build_middle_school_3_1_2022_candidate.py`\n", encoding="utf-8")
    print(f"Built candidate: {len(chapters)} modules, {sum(len(x['pages']) for x in chapters)} pages, 4 HTML assets, schema v2.")


if __name__ == "__main__":
    main()

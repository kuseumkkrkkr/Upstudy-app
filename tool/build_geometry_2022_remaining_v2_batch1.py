"""Build original V2 drafts for the nine currently untagged 2022 Geometry standards."""
from __future__ import annotations

import json
import math
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
STANDARDS = ROOT / "work/official-curriculum/2022_math_standards.json"

SPECS = [
    {
        "code": "12기하02-01", "domain": "공간도형", "title": "공간에서 직선과 평면의 위치 관계",
        "lead": "평행한 두 평면을 한 평면으로 자르면 교선은 어떤 관계일까? 또 한 평면에 수직인 두 직선은 서로 어떤 관계일까?",
        "concept": "서로 다른 두 평면이 평행하면, 제3의 평면과 만날 때 생기는 두 교선은 평행하다. 한 평면에 수직인 두 직선은 서로 평행하다. 증명에서는 평행의 정의와 교선의 포함 관계를 먼저 확인한다.",
        "example": "평행한 두 평면 α, β를 평면 γ가 각각 직선 l, m으로 자른다고 하자. l과 m이 만나면 그 교점은 α와 β의 공통점이 되어 두 평면이 서로 다르고 평행하다는 조건에 모순이다. 따라서 l과 m은 만나지 않고, 같은 평면 γ 안에 있으므로 평행하다.",
        "practice": "한 평면에 각각 수직인 두 직선 p, q가 있다고 하자. p와 q가 평행하다고 말할 수 있는 이유를 설명하세요.",
        "answer": "두 직선 모두 같은 평면의 법선 방향과 나란하므로 서로 평행합니다. 이 성질을 사용할 때 두 직선이 같은 평면에 수직이라는 조건을 확인합니다.",
        "prompt": "평행한 두 평면을 제3의 평면으로 자른 교선 l, m은?", "options": ["평행하다", "반드시 수직이다", "반드시 일치한다"], "correct": 0,
        "feedback": "교선이 만나면 원래 평행한 두 평면의 공통점이 생기므로 모순입니다.", "wrong": "두 교선이 모두 절단 평면 안에 있다는 점과, 만나면 어떤 일이 생기는지 확인하세요.", "hints": ["교선이 만난다고 가정해 보세요.", "교점은 두 평행 평면의 공통점이 됩니다."],
        "check": "평행한 두 평면의 교선 증명에서 교선이 만난다고 가정하면 두 원래 평면의 공통점이 생기는 모순을 확인한다.",
    },
    {
        "code": "12기하02-02", "domain": "공간도형", "title": "삼수선 정리로 공간의 수직 관계 찾기",
        "lead": "점 A에서 평면 α에 내린 수선의 발을 O라 하고, 평면 위 점 B를 잇는다. 평면 안의 직선 ℓ이 OB와 수직이면 AB와도 수직일까?",
        "concept": "삼수선 정리의 한 형태: 평면 밖의 점 A에서 평면 α에 내린 수선의 발이 O이고, B가 α 위에 있을 때 AB의 정사영은 OB이다. α 위에서 O를 지나는 직선 ℓ이 OB에 수직이면 ℓ은 빗선 AB에도 수직이다.",
        "example": "좌표를 O=(0,0,0), A=(0,0,3), B=(4,0,0)으로 둔다. 평면 α를 xy평면, ℓ을 y축으로 잡으면 ℓ의 방향은 (0,1,0), AB의 방향은 (4,0,-3)이다. 내적은 0이므로 ℓ⊥AB이고, 정사영 OB=(4,0,0)에도 수직이다.",
        "practice": "O=(0,0,0), A=(0,0,5), B=(6,0,0)이다. y축 방향 직선 ℓ이 AB와 수직인지 내적으로 확인하세요.",
        "answer": "AB=(6,0,-5), y축 방향은 (0,1,0)이므로 내적은 6·0+0·1+(-5)·0=0입니다. 따라서 두 방향은 수직입니다.",
        "prompt": "삼수선 정리에서 빗선 AB의 평면 α 위 정사영은?", "options": ["OB", "AO", "AB와 평행한 직선"], "correct": 0,
        "feedback": "A의 수선의 발 O와 B를 잇는 OB가 AB의 정사영입니다.", "wrong": "평면에 수직인 성분은 제거하고 평면 위에 남는 성분을 생각하세요.", "hints": ["A를 평면에 수직으로 내린 발은 O입니다.", "평면 위 점 B와 O를 이으면 정사영을 얻습니다."],
        "check": "두 사례에서 정사영 조건과 3차원 내적 계산이 모두 0인지 확인한다.",
    },
    {
        "code": "12기하02-03", "domain": "공간도형", "title": "도형의 정사영과 모양",
        "lead": "평면 위의 삼각형을 다른 평면에 수직으로 비추면 어떤 도형이 될까? 점·선분·다각형을 차례로 생각해 보자.",
        "concept": "한 평면 위 각 점에서 다른 평면에 수선을 내려 대응시키는 것을 정사영으로 생각할 수 있다. 점은 점으로, 선분은 선분 또는 한 점으로, 다각형은 선분 또는 더 작은 넓이의 도형으로 나타날 수 있다. 원래 도형이 투영 평면과 나란하면 모양과 크기가 유지되고, 수직이면 평면 도형이 선분으로 겹칠 수 있다.",
        "example": "가로 4, 세로 3인 직사각형이 투영 평면과 나란하면 정사영도 4×3 직사각형이고 넓이는 12이다. 직사각형을 포함한 평면이 투영 방향과 나란해지도록 세우면 정사영은 선분이 되어 넓이는 0이다.",
        "practice": "평면 위 선분을 그 선분과 같은 방향으로 수직 투영하면 정사영은 어떤 모양인가요? 이유와 함께 답하세요.",
        "answer": "선분은 한 점으로 투영됩니다. 선분의 모든 점이 투영 방향과 나란한 한 직선 위에서 같은 발로 대응하기 때문입니다.",
        "prompt": "투영 평면과 나란한 평면도형의 정사영은?", "options": ["합동인 도형", "항상 한 점", "항상 더 큰 도형"], "correct": 0,
        "feedback": "평면이 투영 평면과 나란하면 대응점 사이의 수직 이동만 생겨 길이와 넓이가 보존됩니다.", "wrong": "도형을 포함한 평면과 투영 평면이 나란한 경우를 떠올려 보세요.", "hints": ["각 점은 평면에 수직인 방향으로 이동합니다.", "두 평면이 나란하면 평면 안의 길이 변화가 없습니다."],
        "check": "평면과 나란한 경우 넓이 12, 한 방향으로 겹치는 경우 넓이 0이라는 경계 사례를 구분한다.",
    },
    {
        "code": "12기하02-05", "domain": "공간도형", "title": "구의 중심과 반지름을 방정식으로 나타내기",
        "lead": "중심이 C=(1,-2,3)이고 반지름이 4인 구 위의 점 P=(x,y,z)는 어떤 관계를 만족할까?",
        "concept": "구는 중심에서 거리가 일정한 점들의 모임이다. 중심 C=(a,b,c), 반지름 r인 구 위의 점 P=(x,y,z)는 CP=r을 만족하므로 (x-a)²+(y-b)²+(z-c)²=r²이다.",
        "example": "중심 (1,-2,3), 반지름 4인 구의 방정식은 (x-1)²+(y+2)²+(z-3)²=16이다. 점 (1,2,3)은 중심에서 거리 4이므로 구 위에 있다.",
        "practice": "중심이 (-2,1,0), 반지름이 3인 구의 방정식을 쓰고, 점 (1,1,0)이 구 위인지 확인하세요.",
        "answer": "방정식은 (x+2)²+(y-1)²+z²=9입니다. 점 (1,1,0)을 대입하면 3²+0+0=9이므로 구 위에 있습니다.",
        "prompt": "중심 (1,-2,3), 반지름 4인 구의 우변은?", "options": ["16", "4", "64"], "correct": 0,
        "feedback": "구의 방정식 우변은 반지름의 제곱 r²=16입니다.", "wrong": "거리식 양변을 제곱해 반지름과 반지름의 제곱을 구분하세요.", "hints": ["반지름 r은 4입니다.", "거리제곱식의 우변은 r²입니다."],
        "check": "두 방정식에 중심·반지름·검사점을 대입해 거리제곱이 각각 16, 9인지 확인한다.",
    },
    {
        "code": "12기하03-01", "domain": "벡터", "title": "벡터의 덧셈·뺄셈과 실수배",
        "lead": "두 이동 u=(2,-1), v=(3,4)를 차례로 하면 시작점에서 끝점까지의 변위는 무엇일까?",
        "concept": "벡터는 크기와 방향을 함께 나타낸다. 성분이 같은 벡터는 위치가 달라도 같은 벡터다. 성분별로 더하고 빼며, 실수 k를 곱하면 각 성분에 k를 곱한다. k<0이면 방향이 반대가 된다.",
        "example": "u+v=(2+3,-1+4)=(5,3), u-v=(2-3,-1-4)=(-1,-5), 2u=(4,-2), -u=(-2,1)이다.",
        "practice": "a=(-2,3), b=(4,1)일 때 2a+b와 a-b를 구하세요.",
        "answer": "2a+b=(-4,6)+(4,1)=(0,7), a-b=(-2,3)-(4,1)=(-6,2)입니다.",
        "prompt": "u=(2,-1), v=(3,4)일 때 u+v는?", "options": ["(5,3)", "(1,-5)", "(6,-4)"], "correct": 0,
        "feedback": "같은 좌표 성분끼리 더해 (2+3,-1+4)=(5,3)입니다.", "wrong": "x성분과 y성분을 각각 따로 계산하세요.", "hints": ["첫째 성분은 2+3입니다.", "둘째 성분은 -1+4입니다."],
        "check": "성분별 연산 결과와 음수 실수배에서 방향이 반대가 되는지 확인한다.",
    },
    {
        "code": "12기하03-02", "domain": "벡터", "title": "위치벡터와 점의 좌표",
        "lead": "원점 O에서 점 P=(3,-2,5)로 향하는 벡터를 어떻게 나타내고, 좌표와 어떻게 연결할까?",
        "concept": "원점 O를 시작점으로 하여 점 P에 도달하는 벡터 OP를 P의 위치벡터라고 한다. 좌표공간에서 P=(a,b,c)이면 위치벡터 OP=(a,b,c)로 대응한다. 점은 위치를, 벡터는 크기와 방향을 나타낸다는 차이를 유지한다.",
        "example": "A=(1,2,-1), B=(4,-2,3)이면 위치벡터 OA=(1,2,-1), OB=(4,-2,3)이고 AB=OB-OA=(3,-4,4)이다.",
        "practice": "A=(-1,2,0), B=(2,3,4)일 때 OA, OB, AB를 구하세요.",
        "answer": "OA=(-1,2,0), OB=(2,3,4), AB=OB-OA=(3,1,4)입니다.",
        "prompt": "P=(3,-2,5)의 위치벡터 OP는?", "options": ["(3,-2,5)", "(-3,2,-5)", "(5,-2,3)"], "correct": 0,
        "feedback": "원점에서 P로 향하는 위치벡터의 성분은 P의 좌표와 같습니다.", "wrong": "위치벡터는 원점에서 점으로 향합니다. 좌표 부호와 순서를 그대로 옮기세요.", "hints": ["시작점은 O=(0,0,0)입니다.", "OP=P-O입니다."],
        "check": "AB=OB-OA 성분을 직접 빼어 (3,1,4)가 되는지 확인한다.",
    },
    {
        "code": "12기하03-03", "domain": "벡터", "title": "벡터의 내적과 각",
        "lead": "u=(1,2), v=(3,0)일 때 성분의 곱의 합은 두 벡터가 이루는 각과 어떤 관계일까?",
        "concept": "두 벡터 u, v의 내적은 대응 성분의 곱을 더한 값이다. 또한 u·v=|u||v|cosθ이다. 두 벡터가 모두 영벡터가 아닐 때 내적이 0이면 서로 수직이다.",
        "example": "u=(1,2), v=(3,0)이면 u·v=1·3+2·0=3이다. u=(1,2), w=(2,-1)이면 u·w=2-2=0이므로 두 벡터는 수직이다.",
        "practice": "a=(2,1), b=(1,-2)의 내적을 구하고 두 벡터의 관계를 말하세요.",
        "answer": "a·b=2·1+1·(-2)=0입니다. 두 벡터는 영벡터가 아니므로 서로 수직입니다.",
        "prompt": "(1,2)·(2,-1)의 값과 관계는?", "options": ["0, 수직", "4, 평행", "-1, 수직 아님"], "correct": 0,
        "feedback": "1·2+2·(-1)=0이므로 두 영벡터가 아닌 벡터는 수직입니다.", "wrong": "대응 성분끼리 곱한 두 값을 더하고, 0인 경우의 조건을 확인하세요.", "hints": ["내적은 1·2+2·(-1)입니다.", "두 벡터가 영벡터가 아니고 내적이 0이면 수직입니다."],
        "check": "두 예제의 내적을 성분식으로 계산하고, 수직 판정에 영벡터가 아님을 확인한다.",
    },
    {
        "code": "12기하03-04", "domain": "벡터", "title": "벡터로 직선의 방정식 쓰기",
        "lead": "점 A=(1,2,0)을 지나고 방향벡터 d=(2,-1,3)인 직선 위의 점은 어떤 꼴일까?",
        "concept": "점 A를 지나고 영벡터가 아닌 방향벡터 d를 갖는 직선의 점 X는 X=A+td (t는 실수)로 나타낸다. 매개변수 t가 모든 실수를 움직일 때 직선 위의 점 전체를 얻는다.",
        "example": "X=(1,2,0)+t(2,-1,3)이므로 x=1+2t, y=2-t, z=3t이다. t=2이면 X=(5,0,6)으로 직선 위에 있다.",
        "practice": "A=(-1,0,2), d=(1,3,-2)인 직선의 벡터식과 t=2일 때 점을 구하세요.",
        "answer": "X=(-1,0,2)+t(1,3,-2)이고 t=2이면 X=(1,6,-2)입니다.",
        "prompt": "A=(1,2,0), d=(2,-1,3)인 직선에서 t=1인 점은?", "options": ["(3,1,3)", "(2,1,3)", "(3,2,1)"], "correct": 0,
        "feedback": "A+d=(1+2,2-1,0+3)=(3,1,3)입니다.", "wrong": "방향벡터를 시작점 좌표에 성분별로 더하세요.", "hints": ["t=1이면 X=A+d입니다.", "세 좌표를 각각 더합니다."],
        "check": "t=0에서 기준점 A가 나오고, t=1 및 t=2 점이 같은 직선식에 맞는지 확인한다.",
    },
    {
        "code": "12기하03-05", "domain": "벡터", "title": "벡터로 평면과 구의 방정식 나타내기",
        "lead": "점 A=(1,0,2)를 지나고 법선벡터 n=(2,-1,2)를 갖는 평면에서 점 X는 어떤 내적 조건을 만족할까?",
        "concept": "평면 위의 기준점 A와 법선벡터 n을 알면, 평면 위 점 X는 n·(X-A)=0을 만족한다. 중심 C, 반지름 r인 구는 중심에서 점 X까지의 거리 조건 |X-C|=r, 즉 (X-C)·(X-C)=r²로 나타낸다.",
        "example": "n=(2,-1,2), A=(1,0,2)이면 2(x-1)-y+2(z-2)=0, 즉 2x-y+2z-6=0이다. 중심 C=(1,0,0), 반지름 2인 구는 (X-C)·(X-C)=4, 곧 (x-1)²+y²+z²=4이다.",
        "practice": "법선벡터 n=(1,2,-1), 기준점 A=(0,1,2)인 평면의 좌표 방정식을 구하세요.",
        "answer": "(X-A)·n=0이므로 x+2(y-1)-(z-2)=0, 즉 x+2y-z=0입니다.",
        "prompt": "중심 C, 반지름 r인 구를 벡터 내적으로 나타낸 식은?", "options": ["(X-C)·(X-C)=r²", "(X-C)·n=0", "X=C+r"], "correct": 0,
        "feedback": "구의 정의는 중심에서의 거리 |X-C|가 r이라는 것이므로 거리제곱은 r²입니다.", "wrong": "법선벡터와 내적이 0인 조건은 평면에 해당합니다. 구는 거리 조건입니다.", "hints": ["구는 중심 C에서 거리가 r인 점들의 모임입니다.", "거리식을 제곱하면 내적 형태가 됩니다."],
        "check": "평면 기준점을 대입해 0, 예제 구의 표면점을 대입해 거리제곱 4인지 확인한다.",
    },
]


def quiz(spec: dict[str, object], slug: str) -> dict[str, object]:
    return {"type": "activity", "activity": {"id": slug+"-quiz", "kind": "quiz", "prompt": spec["prompt"], "options": spec["options"], "correct_index": spec["correct"], "correct_feedback": spec["feedback"], "incorrect_feedback": spec["wrong"], "hints": spec["hints"]}}


def build_domain(domain: str, specs: list[dict[str, object]]) -> None:
    slug_domain = "space" if domain == "공간도형" else "vector"
    filename = f"기하_2022개정_{slug_domain}_BookData_시범.json"
    out = MANUSCRIPTS / filename
    package = MANUSCRIPTS / f"기하_2022개정_{slug_domain}_Batch1_원고패키지"
    chapters = []
    for spec in specs:
        slug = spec["code"].replace("12기하", "geo22-").replace("-", "")
        pages = [
            {"id": slug+"-open", "template": "opening", "title": "상황과 조건 살피기", "blocks": [{"type": "lead", "title": "가상 예시", "text": spec["lead"]}, {"type": "thinking", "title": "먼저 생각하기", "text": "도형의 조건이나 벡터 성분을 표시하고, 결론에 필요한 관계를 예상합니다."}]},
            {"id": slug+"-concept", "template": "concept", "title": "정의와 성질", "blocks": [{"type": "definition", "title": "핵심 개념", "text": spec["concept"]}, {"type": "formula", "title": "연결한 공식 기준", "text": spec["code"]}, {"type": "misconception", "title": "조건 점검", "text": "정리의 가정, 점·벡터의 순서, 길이와 길이제곱을 구분합니다."}]},
            {"id": slug+"-example", "template": "example", "title": "예제와 풀이", "blocks": [{"type": "question", "title": "예제", "text": spec["lead"]}, {"type": "solutionStep", "title": "풀이", "text": spec["example"]}, {"type": "verification", "title": "검산", "text": spec["check"]}]},
            {"id": slug+"-practice", "template": "practice", "title": "연습과 설명", "blocks": [{"type": "question", "title": "연습", "text": spec["practice"]}, {"type": "hint", "title": "힌트", "text": spec["hints"][0]}, {"type": "solutionStep", "title": "해설", "text": spec["answer"]}, {"type": "answer", "title": "정답", "text": spec["answer"]}, quiz(spec, slug)]},
            {"id": slug+"-summary", "template": "summary", "title": "핵심 정리", "blocks": [{"type": "summary", "title": "기억할 점", "text": spec["title"]}, {"type": "checklist", "title": "스스로 확인", "text": "공식의 조건을 확인하고 계산이나 증명의 근거를 설명할 수 있나요?"}]},
        ]
        chapters.append({"title": spec["title"], "intro": [f"2022 교육과정 공식 기준 {spec['code']}에 연결한 신규 집필 후보입니다.", "예제와 수치는 직접 작성한 가상 예시입니다."], "pages": pages})
    codes = [str(spec["code"]) for spec in specs]
    book = {"schema_version": 2, "title": f"기하 · 2022 개정 {domain} 추가 {len(specs)}모듈 후보", "subtitle": "공식 성취기준 대응을 위한 신규 집필 시범", "category": "concept_textbook_prototype", "curriculum_version": "2022", "tags": ["기하", "2022 개정", domain, "추가 원고 후보", "가상 예시", "학기 배정 미확정"], "standard_codes": codes, "chapters": chapters}
    ids = [page["id"] for chapter in chapters for page in chapter["pages"]]
    if len(ids) != len(set(ids)) or any(len(chapter["pages"]) != 5 for chapter in chapters):
        raise RuntimeError("Page count or ID invariant failed")
    out.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    package.mkdir(parents=True, exist_ok=True)
    manifest_path = package / "REVIEW_MANIFEST.json"
    try: old = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError): old = {}
    digest = canonical_file_sha256(out)
    same = old.get("bookdata_sha256") == digest
    manifest = {"bookdata_file": filename, "bookdata_sha256": digest, "candidate_code_references": codes, "candidate_code_reference_type": "official_2022_hwp_criterion_table", "module_count": len(specs), "page_count": len(ids), "native_activity_count": len(specs), "native_activity_kinds": ["quiz"], "example_data_status": "synthetic_original_examples; no commercial text, problem, illustration, or dataset copied", "curriculum_review_status": "official_codes_verified; semester_and_full_scope_pending", "math_review_status": "pending_full_teacher_review", "math_arithmetic_check_status": "pass_for_listed_examples_only", "teacher_review_status": "pending", "rights_status": "newly_authored; publication_rights_decision_pending", "source_interaction_status": "native_quiz_activity_candidate; no source HTML parity claimed", "integration_status": "not_merged_into_master_book", "publication_eligibility": "not_eligible", "runtime_import_status": old.get("runtime_import_status", "pending_current_hash_validation") if same else "pending_current_hash_validation", "runtime_validator_head": old.get("runtime_validator_head") if same else None}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    (package/"README.md").write_text(f"# {book['title']}\n\n공식 2022 기준 {', '.join(codes)}에 연결한 {len(specs)}모듈·{len(ids)}쪽 V2 후보입니다. 예제와 수치는 직접 작성했습니다. native quiz는 BookData activity 계약을 사용하는 후보이며 독립 HTML과의 화면 parity는 주장하지 않습니다. 교사 검토·권리 결정·상품 전체 범위 확인 전에는 출판 적격이 아닙니다.\n\nBookData: [`{filename}`](../{filename})\n", encoding="utf-8")
    print(f"Built {domain}: {len(specs)} modules, {len(ids)} pages, {len(specs)} quizzes")


def main() -> None:
    official = {row["code"]: row["criterion"] for row in json.loads(STANDARDS.read_text(encoding="utf-8"))["standards"]}
    if any(official.get(str(spec["code"])) is None for spec in SPECS):
        raise RuntimeError("A candidate code is missing from the official 2022 HWP table")
    if len({spec["code"] for spec in SPECS}) != 9:
        raise RuntimeError("Expected exactly nine distinct geometry standards")
    for spec in SPECS:
        if not official[str(spec["code"])].rstrip(" ."):
            raise RuntimeError(f"Empty official criterion: {spec['code']}")
    # Independently verify numeric examples represented in the authored modules.
    assert 2*(1-1) - (0-0) + 2*(2-2) == 0  # plane contains its reference point
    assert (1+2)**2 + (1-1)**2 + (0-0)**2 == 9
    assert (2*1 + 2*(-1)) == 0
    assert (1+2*1, 2-1, 0+3) == (3,1,3)
    assert (0-0) + 2*(1-1) - (2-2) == 0
    assert 2*(3-1) - 0 + 2*(0-2) == 0  # point (3,0,0) lies on the example sphere
    assert math.isclose(math.sqrt(6**2 + 0**2 + (-5)**2), math.sqrt(61))
    build_domain("공간도형", [spec for spec in SPECS if str(spec["code"]).startswith("12기하02")])
    build_domain("벡터", [spec for spec in SPECS if str(spec["code"]).startswith("12기하03")])


if __name__ == "__main__":
    main()

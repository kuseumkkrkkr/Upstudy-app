"""Supplement three 2015 Geometry space criteria with distinct proofs and applications."""
from __future__ import annotations

import json
import re
from pathlib import Path

from textbook_digest import canonical_file_sha256

ROOT = Path(__file__).resolve().parents[1]
MANUSCRIPTS = ROOT / "docs/advanced-generation-vault/07 Data/교재 원고"
OUT = MANUSCRIPTS / "기하_2015개정_공간관계삼수선정사영_보충_Batch4_BookData_V2_시범.json"
PACKAGE = MANUSCRIPTS / "기하_2015개정_공간관계삼수선정사영_보충_Batch4_원고패키지"
CURRICULUM = ROOT / "work/official-curriculum/2015_appendix8_math.txt"
PRIOR = MANUSCRIPTS / "기하_2015개정_이차곡선공간도형_Batch1_BookData_V2_시범.json"
CRITERIA = {
    "12기하03-01": ("공간에서 직선·평면의 위치 관계", "직선과 직선, 직선과 평면, 평면과 평면의 위치 관계에 대한 간단한 증명을 할 수 있다"),
    "12기하03-02": ("삼수선의 정리", "삼수선의 정리를 이해하고, 이를 활용할 수 있다"),
    "12기하03-03": ("정사영의 뜻과 길이", "정사영의 뜻을 알고, 이를 구할 수 있다"),
}


def verify_gap_evidence() -> None:
    official = CURRICULUM.read_text(encoding="utf-8")
    prior = json.loads(PRIOR.read_text(encoding="utf-8-sig"))
    for code, (title, criterion) in CRITERIA.items():
        if not re.search(rf"\[{re.escape(code)}\]\s*{re.escape(criterion)}", official):
            raise RuntimeError(f"Official criterion not verified: {code}")
        chapters = [chapter for chapter in prior.get("chapters", []) if chapter.get("title") == title]
        if len(chapters) != 1:
            raise RuntimeError(f"Expected one prior chapter for {code}, found {len(chapters)}")
        pages = chapters[0].get("pages", [])
        example = next((page for page in pages if page.get("template") == "example"), None)
        practice = next((page for page in pages if page.get("template") == "practice"), None)
        question = lambda p: " ".join(block.get("text", "") for block in (p or {}).get("blocks", []) if block.get("type") == "question")
        if not question(example) or question(example) != question(practice):
            raise RuntimeError(f"Prior example/practice changed for {code}; re-audit before supplementing")


def page(identifier: str, template: str, title: str, blocks: list[dict]) -> dict:
    return {"id": identifier, "template": template, "title": title, "blocks": blocks}


def module(slug: str, code: str, title: str, lead: str, concept: str, formula: str,
           question: str, solution: list[tuple[str, str]], practice: str,
           practice_solution: list[tuple[str, str]], quiz: dict) -> dict:
    return {
        "title": title,
        "intro": [f"공식 기준 {code}에 연결한 보충 후보입니다.", "기존 예제와 연습의 반복을 피하고 풀이 근거를 단계별로 보완합니다."],
        "pages": [
            page(slug+"-open", "opening", "핵심 질문", [
                {"type": "lead", "title": "생각할 문제", "text": lead},
                {"type": "thinking", "title": "먼저 확인", "text": "조건을 그림 또는 좌표로 나타내고 결론을 뒷받침할 근거를 찾습니다."},
            ]),
            page(slug+"-concept", "concept", "개념과 근거", [
                {"type": "definition", "title": title, "text": concept},
                {"type": "formula", "title": "핵심 관계", "text": formula},
                {"type": "misconception", "title": "조건 확인", "text": "그림에서 보이는 모양만으로 평행·수직·길이를 단정하지 말고 정의와 조건으로 확인합니다."},
            ]),
            page(slug+"-example", "example", "예제 풀이", [
                {"type": "question", "title": "예제", "text": question},
                *[{"type": "solutionStep", "title": step, "text": text} for step, text in solution],
                {"type": "verification", "title": "확인", "text": "결론을 원래 조건에 대입하고 증명에 필요한 가정이 모두 사용되었는지 확인합니다."},
            ]),
            page(slug+"-practice", "practice", "연습과 해설", [
                {"type": "question", "title": "연습", "text": practice},
                {"type": "hint", "title": "힌트", "text": "먼저 기준 정의나 정리를 표시하고, 수치·벡터 관계를 단계별로 계산합니다."},
                *[{"type": "solutionStep", "title": step, "text": text} for step, text in practice_solution],
                {"type": "answer", "title": "정리", "text": practice_solution[-1][1]},
                {"type": "activity", "activity": quiz},
            ]),
            page(slug+"-summary", "summary", "핵심 정리", [
                {"type": "summary", "title": title, "text": concept+" "+formula},
                {"type": "checklist", "title": "자기 점검", "items": ["정의 또는 정리를 분명히 말했다.", "계산·증명의 근거를 빠뜨리지 않았다.", "결론을 조건에 대입해 확인했다."]},
            ]),
        ],
    }


def main() -> None:
    verify_gap_evidence()
    modules = [
        module(
            "geo15-space-relations", "12기하03-01", "직선·평면의 위치 관계 증명",
            "방향벡터와 법선벡터, 교점 조건으로 직선이 평면과 평행함을 어떻게 보일까?",
            "평면 π의 법선벡터를 n이라 하자. 직선의 방향벡터 d가 d·n=0이면 직선의 방향은 평면과 평행하다. 직선 위 한 점이 π에 있지 않으면 직선은 π와 만나지 않아 π에 평행하다.",
            "d·n=0이고 직선 위 점이 π에 없으면 직선과 평면은 평행이다.",
            "평면 π: z=0에 대해 직선 ℓ: (x,y,z)=(2,1,1)+t(3,−2,0)이 π와 평행함을 증명하세요.",
            [("1단계 · 방향", "π의 법선벡터는 n=(0,0,1), ℓ의 방향벡터는 d=(3,−2,0)이다. d·n=0이므로 ℓ의 방향은 π와 평행하다."), ("2단계 · 교점", "ℓ 위의 모든 점은 z=1이다. π 위의 점은 z=0이므로 ℓ과 π는 만나지 않는다. 따라서 ℓ∥π이다.")],
            "두 직선 ℓ₁=(t,0,0), ℓ₂=(1,s,1)이 꼬인 위치임을 증명하세요.",
            [("1단계 · 방향 비교", "방향벡터는 (1,0,0), (0,1,0)으로 서로 평행하지 않다."), ("2단계 · 교점 확인", "교점이 있다면 z좌표가 0과 1로 같아야 하므로 모순이다. 두 직선은 만나지 않고 평행하지 않으므로 꼬인 위치이다.")],
            {"id": "geo15-rel-quiz", "kind": "quiz", "prompt": "d·n=0이고 직선 위 한 점이 평면에 속하지 않을 때 직선과 평면의 관계는?", "options": ["평행", "수직", "평면 위에 포함"], "correct_index": 0, "correct_feedback": "방향이 평면과 평행하고 직선 위 점은 평면 밖이므로 만나지 않습니다.", "incorrect_feedback": "법선벡터와 내적이 0이면 방향은 평면과 평행합니다. 점이 평면 밖이므로 직선 전체가 평면 위에 있지는 않습니다.", "hints": ["d·n=0이 의미하는 방향 관계를 확인하세요.", "직선 위 기준점이 평면 밖이면 교점이 없습니다."]},
        ),
        module(
            "geo15-three-perpendicular", "12기하03-02", "삼수선의 정리 좌표 적용",
            "평면 위 직선이 사선의 정사영과 수직이면 왜 사선에도 수직일까?",
            "평면 α에 수직인 선분 PH의 발을 H, 평면 위의 점을 A라 하자. 사선 PA의 정사영은 HA이다. 평면 위 직선 ℓ이 HA와 수직이면 ℓ은 사선 PA에도 수직이다.",
            "평면 성분과 수직 성분을 분리하면 내적 0을 확인할 수 있다.",
            "α: z=0, H=(0,0,0), A=(3,0,0), P=(0,0,4)이다. A를 지나고 y방향인 직선 ℓ이 PA와 수직임을 좌표와 삼수선 정리로 확인하세요.",
            [("1단계 · 정사영", "PH는 z축 방향으로 α에 수직이다. P의 수선의 발은 H이고, PA의 정사영은 HA로 x축 방향이다."), ("2단계 · 수직 확인", "ℓ의 방향벡터는 (0,1,0), AP의 방향벡터는 (−3,0,4)이다. 내적은 0이므로 ℓ⊥PA이며 삼수선 정리와 일치한다.")],
            "α: z=0, H=(0,0,0), A=(0,4,0), P=(0,0,3)이다. A를 지나고 x방향인 직선 m이 PA와 수직임을 정사영과 내적으로 설명하세요.",
            [("1단계 · 정사영", "PA의 정사영 HA는 y방향이고, m의 방향은 x방향이므로 m⊥HA이다."), ("2단계 · 사선과 비교", "AP=(0,−4,3), m의 방향벡터는 (1,0,0)이다. 내적이 0이므로 m⊥PA이다. 이는 삼수선 정리의 결론이다.")],
            {"id": "geo15-three-perp-quiz", "kind": "quiz", "prompt": "평면 위 직선 ℓ이 사선의 정사영에 수직일 때 삼수선 정리의 결론은?", "options": ["ℓ은 사선에도 수직", "ℓ은 사선과 평행", "ℓ은 평면에 수직"], "correct_index": 0, "correct_feedback": "정사영에 수직인 평면 위 직선은 삼수선 정리에 따라 사선에도 수직입니다.", "incorrect_feedback": "정사영에 대한 수직 관계를 사선으로 옮기는 것이 삼수선 정리입니다.", "hints": ["평면 위 직선과 사선의 정사영 관계를 확인하세요.", "정사영에 수직이면 사선에도 수직입니다."]},
        ),
        module(
            "geo15-projection-length", "12기하03-03", "정사영 길이와 역산",
            "선분의 실제 길이와 평면 위 그림의 길이는 각도에 따라 어떻게 달라질까?",
            "길이 L인 선분이 평면과 예각 θ를 이루면 그 선분의 정사영 길이는 L cosθ이다. 정사영 길이가 주어지면 L=정사영 길이/cosθ로 실제 길이를 구한다.",
            "정사영 길이 = 실제 길이 × cos(선분과 평면의 예각)",
            "길이 13인 선분이 평면과 30°를 이룬다. 정사영의 길이를 구하세요.",
            [("1단계 · 식 세우기", "정사영 길이는 13cos30°이다."), ("2단계 · 계산", "cos30°=√3/2이므로 정사영 길이는 13√3/2이다.")],
            "선분과 평면이 이루는 예각은 60°이고 정사영 길이는 6이다. 원래 선분 길이를 구하세요.",
            [("1단계 · 역산", "6=Lcos60°=L/2이므로 L=12이다."), ("2단계 · 확인", "12cos60°=6이므로 주어진 정사영 길이와 일치한다.")],
            {"id": "geo15-projection-quiz", "kind": "quiz", "prompt": "길이 8인 선분이 평면과 60°를 이룰 때 정사영 길이는?", "options": ["4", "8", "4√3"], "correct_index": 0, "correct_feedback": "8cos60°=4입니다.", "incorrect_feedback": "선분과 평면 사이 각도의 코사인을 실제 길이에 곱합니다.", "hints": ["정사영 길이는 Lcosθ입니다.", "cos60°=1/2입니다."]},
        ),
    ]
    pages = [p for item in modules for p in item["pages"]]
    assert len(modules) == 3 and len(pages) == 15
    assert len({p["id"] for p in pages}) == 15
    assert (3, -2, 0)[2] * 1 == 0
    assert (-3)*0 + 0*1 + 4*0 == 0
    assert 13*0.5*3**0.5 == 13*3**0.5/2
    assert 6/(0.5) == 12 and 8*0.5 == 4
    book = {
        "schema_version": 2, "title": "기하 · 공간의 위치 관계·삼수선·정사영 보충 Batch4",
        "subtitle": "2015 개정 기준 12기하03-01, 12기하03-02, 12기하03-03",
        "category": "concept_textbook_prototype", "curriculum_version": "2015",
        "standard_codes": list(CRITERIA), "tags": ["기하", "2015 개정", "공간도형 보충", "추가 원고 후보", *CRITERIA.keys()],
        "chapters": modules,
        "metadata": {"supplement_only": True, "publication_eligibility": "not_eligible", "teacher_review_status": "pending", "math_review_status": "independent_review_pending", "rights_status": "publication_decision_pending"},
    }
    OUT.write_text(json.dumps(book, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    PACKAGE.mkdir(parents=True, exist_ok=True)
    digest = canonical_file_sha256(OUT)
    manifest = {
        "bookdata_file": OUT.name, "bookdata_sha256": digest,
        "candidate_code_references": list(CRITERIA), "candidate_code_reference_type": "official_2015_appendix8_math_criteria_table",
        "module_count": 3, "page_count": 15, "native_activity_count": 3,
        "native_activity_kinds": ["quiz"], "native_graph_count": 0,
        "content_assertion_status": "coordinate_proofs_and_projection_calculations_checked; independent_review_pending",
        "teacher_review_status": "pending", "math_review_status": "independent_review_pending",
        "rights_status": "publication_decision_pending", "publication_eligibility": "not_eligible",
        "integration_status": "supplement_only; existing_space_candidates_preserved",
    }
    (PACKAGE / "REVIEW_MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = """# 기하 · 공간의 위치 관계·삼수선·정사영 보충 Batch4

## 기존 자료 대조

| 공식 기준 | 기존 예제와 연습 | 이번 보완 |
|---|---|---|
| 12기하03-01 | 같은 평행 직선 분류 문제 반복 | 직선-평면 평행 증명과 꼬인 위치 판별 |
| 12기하03-02 | 정리 문장 재진술 반복 | 좌표·정사영·내적으로 삼수선 적용 확인 |
| 12기하03-03 | 길이 10, 각 60° 문제 반복 | 정사영 계산 및 실제 길이 역산 |

3개 모듈·15쪽 후보에 단계별 풀이와 native quiz를 담았습니다. 계산 확인은 독립 수학·교사 검토를 대신하지 않습니다. 권리·검토 결정 전 게시 부적격입니다.

"""
    (PACKAGE / "README.md").write_text(readme+f"BookData: [`{OUT.name}`](../{OUT.name})\n", encoding="utf-8")
    print(f"Built {len(modules)} modules, {len(pages)} pages, 3 quizzes; sha256={digest}")


if __name__ == "__main__":
    main()

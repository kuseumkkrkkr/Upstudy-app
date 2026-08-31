from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable, TextIO


BASE_DIR = Path(__file__).resolve().parent / "k_alpha"


MIDDLE_GRADE_MIN = 7
MIDDLE_GRADE_MAX = 9


def _load_json(path: Path) -> dict[str, Any]:
    # 필요한 변수: 파일 경로 path.
    # 동작 원리: 대상 JSON을 UTF-8로 읽어 사전 객체로 반환해 후속 필터링에 사용한다.
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _save_json(path: Path, payload: dict[str, Any]) -> None:
    # 필요한 변수: 파일 경로 path, 저장할 객체 payload.
    # 동작 원리: UTF-8로 pretty print 형식으로 파일에 덮어쓰고 인코딩 문제를 방지한다.
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def _grade_range_overlaps(node: dict[str, Any], gmin: int, gmax: int) -> bool:
    # 필요한 변수: 노드 메타데이터와 중학교 최소/최대 학년.
    # 동작 원리: node.grade_min/grade_max와 목표 구간 [gmin,gmax]의 교집합 여부를 판정한다.
    nmin = int(node.get("grade_min", 1))
    nmax = int(node.get("grade_max", 9))
    return not (nmax < gmin or nmin > gmax)


def _has_middle_stage(node: dict[str, Any]) -> bool:
    # 필요한 변수: 개념 노드의 school_stage.
    # 동작 원리: school_stage에 '중1/중2/중3'가 존재하면 중학교 개념으로 간주한다.
    for stage in node.get("school_stage", []) or []:
        if stage in {"중1", "중2", "중3"}:
            return True
    return False


def _normalize_grade_bounds(node: dict[str, Any], gmin: int, gmax: int) -> tuple[int, int]:
    # 필요한 변수: 노드 학년 범위.
    # 동작 원리: 학습 데이터의 범위를 내부 중학교 구간으로 잘라서 저장 가능한 값으로 정규화한다.
    low = max(gmin, int(node.get("grade_min", gmin)))
    high = min(gmax, int(node.get("grade_max", gmax)))
    if low > high:
        low, high = gmax, gmax
    return low, high


def find_middle_nodes(nodes: Iterable[dict[str, Any]], gmin: int, gmax: int) -> set[str]:
    # 필요한 변수: 전체 노드 목록과 중학교 구간.
    # 동작 원리: 학교 단계 또는 학년 교집합 조건을 만족하는 노드의 node_id만 수집한다.
    target: set[str] = set()
    for node in nodes:
        if not isinstance(node, dict):
            continue
        if _has_middle_stage(node) or _grade_range_overlaps(node, gmin, gmax):
            node_id = node.get("node_id")
            if isinstance(node_id, str):
                target.add(node_id)
    return target


def rebuild_graph(
    graph: dict[str, Any],
    rules: dict[str, Any],
    templates: dict[str, Any],
    contract: dict[str, Any],
    gmin: int = MIDDLE_GRADE_MIN,
    gmax: int = MIDDLE_GRADE_MAX,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    # 필요한 변수: 각 지식 레이어와 목표 학년 구간.
    # 동작 원리: 개념-규칙-템플릿 간 종속성을 유지하면서 중학교 구간만 남기는 정규화 뷰를 만든다.
    selected_node_ids = find_middle_nodes(graph.get("nodes", []), gmin, gmax)

    filtered_nodes = []
    for node in graph.get("nodes", []):
        if not isinstance(node, dict):
            continue
        node_id = str(node.get("node_id", ""))
        if node_id not in selected_node_ids:
            continue
        node_min, node_max = _normalize_grade_bounds(node, gmin, gmax)
        cloned = dict(node)
        cloned["grade_min"] = node_min
        cloned["grade_max"] = node_max
        filtered_nodes.append(cloned)

    filtered_rule_ids: set[str] = set()
    filtered_rules = []
    for rule in rules.get("rules", []):
        if not isinstance(rule, dict):
            continue
        if str(rule.get("domain_node", "")) in selected_node_ids:
            filtered_rules.append(rule)
            rid = str(rule.get("rule_id"))
            if rid:
                filtered_rule_ids.add(rid)

    filtered_templates = []
    for template in templates.get("templates", []):
        if not isinstance(template, dict):
            continue
        tpl_rules = set(template.get("required_rules", []) or [])
        domain_ok = str(template.get("domain_node", "")) in selected_node_ids
        if not domain_ok:
            continue
        if tpl_rules and not (tpl_rules & filtered_rule_ids):
            continue

        new_tpl = dict(template)
        new_tpl["grade_min"], new_tpl["grade_max"] = _normalize_grade_bounds(
            {
                "grade_min": template.get("grade_min", gmin),
                "grade_max": template.get("grade_max", gmax),
            },
            gmin,
            gmax,
        )
        filtered_templates.append(new_tpl)

    filtered_contract = dict(contract)
    filtered_contract.setdefault("validation", {})
    v = filtered_contract["validation"]
    v["allowed_grade_codes"] = [str(i) for i in range(gmin, gmax + 1)]

    return (
        {"version": graph.get("version", ""), "nodes": filtered_nodes},
        {"version": rules.get("version", ""), "rules": filtered_rules},
        {"version": templates.get("version", ""), "templates": filtered_templates},
        filtered_contract,
    )


def _print_middle_concepts(graph: dict[str, Any], node_ids: set[str]) -> None:
    # 필요한 변수: 전체 그래프와 중학교 대상 노드 id 집합.
    # 동작 원리: 검색 결과를 사람이 읽기 쉬운 형태로 출력해 개념 목록을 확인하게 한다.
    print("[중학교 개념 검색 결과]")
    for node in graph.get("nodes", []):
        if not isinstance(node, dict):
            continue
        node_id = str(node.get("node_id", ""))
        if node_id in node_ids:
            print(f"- {node.get('node_id')} | {node.get('name_kr')} | grade={node.get('grade_min')}-{node.get('grade_max')}")


def main() -> int:
    # 필요한 변수: CLI 인자.
    # 동작 원리: 검색만 할지, 덮어쓰기까지 할지 결정하고 지식데이터를 정합적으로 재구성한다.
    parser = argparse.ArgumentParser(description="k_alpha 지식 데이터 중학교 레벨 재구성")
    parser.add_argument("--grade_min", type=int, default=MIDDLE_GRADE_MIN)
    parser.add_argument("--grade_max", type=int, default=MIDDLE_GRADE_MAX)
    parser.add_argument("--apply", action="store_true", help="필터링 결과를 k_alpha JSON에 덮어쓰기")
    args = parser.parse_args()

    graph = _load_json(BASE_DIR / "math_knowledge_graph.json")
    rules = _load_json(BASE_DIR / "math_rule_library.json")
    templates = _load_json(BASE_DIR / "math_template_pack.json")
    contract = _load_json(BASE_DIR / "validation_contract.json")

    selected_node_ids = find_middle_nodes(graph.get("nodes", []), args.grade_min, args.grade_max)
    _print_middle_concepts(graph, selected_node_ids)

    if not args.apply:
        print("DRY RUN: --apply 미지정. 파일 반영은 하지 않았습니다.")
        return 0

    n_graph, n_rules, n_templates, n_contract = rebuild_graph(
        graph,
        rules,
        templates,
        contract,
        gmin=max(1, min(9, args.grade_min)),
        gmax=max(1, min(9, args.grade_max)),
    )
    _save_json(BASE_DIR / "math_knowledge_graph.json", n_graph)
    _save_json(BASE_DIR / "math_rule_library.json", n_rules)
    _save_json(BASE_DIR / "math_template_pack.json", n_templates)
    _save_json(BASE_DIR / "validation_contract.json", n_contract)
    print(f"APPLY 완료: {len(n_graph['nodes'])} nodes, {len(n_rules['rules'])} rules, {len(n_templates['templates'])} templates")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

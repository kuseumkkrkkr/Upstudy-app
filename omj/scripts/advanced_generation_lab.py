from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable


NODE_TYPES = (
    "condition",
    "concept",
    "insight",
    "reasoning",
    "computation",
    "trap",
    "merge",
    "verification",
)
PIPELINE_VERSION = "2026-07-13-neutral-parameter-probe-v20"

NODE_LABELS = {
    "condition": "조건",
    "concept": "개념",
    "insight": "발상",
    "reasoning": "추론",
    "computation": "계산",
    "trap": "함정",
    "merge": "병합",
    "verification": "검증",
}


def _repo_root() -> Path:
    """필요 변수: 현재 스크립트 경로. 작동 원리: 프로젝트 루트를 절대 경로로 반환한다."""
    return Path(__file__).resolve().parents[2]


def _read_parameter_specs(root: Path) -> list[dict[str, Any]]:
    """필요 변수: Flutter 파라미터 원본. 작동 원리: UI 정의를 읽어 실험값과 문서의 불일치를 막는다."""
    source = (
        root / "s11_teacher" / "lib" / "pages" / "problem_editor_page.dart"
    ).read_text(encoding="utf-8")
    pattern = re.compile(
        r"_ParameterSpec\(\s*"
        r"id:\s*'(?P<id>[^']+)',\s*"
        r"label:\s*'(?P<label>[^']+)',\s*"
        r"group:\s*'(?P<group>[^']+)',\s*"
        r"defaultValue:\s*(?P<default>[\d.]+),\s*"
        r"min:\s*(?P<min>[\d.]+),\s*"
        r"max:\s*(?P<max>[\d.]+),\s*"
        r"description:\s*'(?P<description>[^']+)',\s*"
        r"lowExample:\s*'(?P<low>[^']+)',\s*"
        r"highExample:\s*'(?P<high>[^']+)',",
        re.DOTALL,
    )
    specs = []
    for match in pattern.finditer(source):
        item = match.groupdict()
        specs.append(
            {
                **item,
                "default": float(item["default"]),
                "min": float(item["min"]),
                "max": float(item["max"]),
            }
        )
    if len(specs) < 30:
        raise RuntimeError(f"파라미터 파싱 결과가 비정상입니다: {len(specs)}개")
    return specs


def _read_target_presets(root: Path) -> dict[str, dict[str, Any]]:
    """필요 변수: Flutter 고급 프리셋 원본. 작동 원리: 목표모드 실험이 실제 UI 값과 정확히 같도록 파싱한다."""
    source = (
        root / "s11_teacher" / "lib" / "pages" / "problem_editor_page.dart"
    ).read_text(encoding="utf-8")
    block_match = re.search(
        r"const _advancedPresets = <_AdvancedPreset>\[(?P<body>.*?)\n\];",
        source,
        re.DOTALL,
    )
    if block_match is None:
        raise RuntimeError("고급 목표 프리셋을 찾지 못했습니다.")
    preset_pattern = re.compile(
        r"_AdvancedPreset\(\s*label:\s*'(?P<label>[^']+)'.*?"
        r"solvesCount:\s*(?P<solves>\d+),\s*strategyLevel:\s*(?P<strategy>\d+),\s*"
        r"branchConditions:\s*(?P<branches>\d+),\s*metrics:\s*\{(?P<metrics>.*?)\},\s*\),",
        re.DOTALL,
    )
    id_map = {
        "3점형": "3-point",
        "4점형": "standard-4",
        "22번형": "22",
        "29번형": "29",
        "30번형": "30",
    }
    presets = {}
    for match in preset_pattern.finditer(block_match.group("body")):
        label = match.group("label")
        metrics = {
            metric_id: float(value)
            for metric_id, value in re.findall(
                r"'([^']+)'\s*:\s*([\d.]+)",
                match.group("metrics"),
            )
        }
        presets[id_map[label]] = {
            "solves_count": int(match.group("solves")),
            "strategy_level": int(match.group("strategy")),
            "branch_conditions": int(match.group("branches")),
            "metrics": metrics,
        }
    if set(presets) != set(id_map.values()):
        raise RuntimeError(f"고급 목표 프리셋 파싱 결과가 비정상입니다: {sorted(presets)}")
    return presets


def _flow_for_node(focus: str) -> list[dict[str, Any]]:
    """필요 변수: 집중 관찰할 노드 유형. 작동 원리: 유형별 역할을 비교할 유효 DAG 표본을 만든다."""
    if focus == "merge":
        return [
            _node("condition", "condition", ["case_a", "case_b"], "조건을 두 경우로 분기한다."),
            _node("case_a", "reasoning", ["merge"], "첫 번째 경우를 추론한다."),
            _node("case_b", "reasoning", ["merge"], "두 번째 경우를 추론한다."),
            _node("merge", "merge", ["verify"], "두 경우의 공통 결론을 병합한다."),
            _node("verify", "verification", [], "병합한 결론을 검증한다."),
        ]
    if focus == "verification":
        return [
            _node("condition", "condition", ["reason"], "문제의 조건을 정리한다."),
            _node("reason", "reasoning", ["focus"], "조건에서 답을 추론한다."),
            _node("focus", "verification", [], "정답 유일성과 조건 만족을 강하게 검증한다."),
        ]
    if focus == "condition":
        return [
            _node("focus", "condition", ["reason"], "명시 조건과 암묵 조건을 분리한다."),
            _node("reason", "reasoning", ["verify"], "정리한 조건으로 답을 추론한다."),
            _node("verify", "verification", [], "정답을 검증한다."),
        ]
    return [
        _node("condition", "condition", ["focus"], "문제의 조건을 정리한다."),
        _node("focus", focus, ["verify"], f"{NODE_LABELS[focus]} 기능을 풀이에 선명하게 반영한다."),
        _node("verify", "verification", [], "정답 유일성과 조건 만족을 검증한다."),
    ]


def _flow_for_parameter() -> list[dict[str, Any]]:
    """필요 변수: 없음. 작동 원리: API 필수 항목만 채운 무지시 레거시 노드로 노드 역할과 파라미터 효과를 분리한다."""
    return [
        {
            "node_id": "parameter_probe",
            "text": "",
            "hash_tags": ["#수열"],
            "branches": [],
            "teacher_instruction": "",
            "prompt_text": "",
        }
    ]


def _node(
    node_id: str,
    node_type: str,
    branches: list[str],
    instruction: str,
) -> dict[str, Any]:
    """필요 변수: 노드 식별자·유형·연결·지시. 작동 원리: 서버 요청 형식의 노드 한 개를 만든다."""
    return {
        "node_id": node_id,
        "node_type": node_type,
        "text": instruction,
        "hash_tags": ["#수열"],
        "branches": branches,
        "teacher_instruction": instruction,
        "prompt_text": instruction,
    }


def _parameter_tag(parameter_id: str) -> str:
    """필요 변수: 파라미터 ID. 작동 원리: 효과를 관찰하기 좋은 등록 교과 태그를 선택한다."""
    if parameter_id == "integral_steps":
        return "#정적분"
    if parameter_id == "derivative_steps":
        return "#도함수"
    if parameter_id in {"graph_depth", "graph_width", "hidden_information"}:
        return "#함수"
    return "#수열"


def _retag_flow(flow: list[dict[str, Any]], tag: str) -> list[dict[str, Any]]:
    """필요 변수: 노드 그래프와 실험 태그. 작동 원리: 모든 노드의 태그를 대상 파라미터에 맞춰 통일한다."""
    return [{**node, "hash_tags": [tag]} for node in flow]


def _coherent_metrics(
    spec: dict[str, Any],
    level: str,
    specs: list[dict[str, Any]],
    defaults: dict[str, float],
) -> dict[str, float]:
    """필요 변수: 관찰 파라미터·수준·전체 명세. 작동 원리: 상위 난이도 축과 하위 그룹을 같은 방향으로 맞춰 모순을 제거한다."""
    by_id = {item["id"]: item for item in specs}
    level_key = {"low": "min", "default": "default", "high": "max"}[level]
    group_to_parent = {
        "concept_layer": "concept",
        "reasoning_layer": "reasoning",
        "insight_layer": "insight",
        "information_layer": "information",
        "computation_layer": "calculation",
        "trap_layer": "trap",
        "compression_layer": "compression",
    }
    parent_to_group = {parent: group for group, parent in group_to_parent.items()}
    metrics = dict(defaults)
    metrics[spec["id"]] = float(spec[level_key])
    if spec["group"] == "difficulty" and spec["id"] in parent_to_group:
        child_group = parent_to_group[spec["id"]]
        for child in specs:
            if child["group"] == child_group:
                metrics[child["id"]] = float(child[level_key])
    elif spec["group"] in group_to_parent:
        parent_id = group_to_parent[spec["group"]]
        metrics[parent_id] = float(by_id[parent_id][level_key])
    return metrics


def _generation_controls(metrics: dict[str, float]) -> tuple[int, int, int]:
    """필요 변수: 일관화한 추론·분기 지표. 작동 원리: 별도 생성 제어값이 집중 지표와 반대 지시가 되지 않게 맞춘다."""
    reasoning = float(metrics.get("reasoning", 6))
    strategy_level = 1 if reasoning <= 3 else 3 if reasoning >= 8 else 2
    branch_conditions = max(0, min(5, round(float(metrics.get("branch_factor", 1)))))
    return 4, strategy_level, branch_conditions


def _build_plan(
    specs: list[dict[str, Any]],
    target_presets: dict[str, dict[str, Any]],
    repeats: int,
) -> list[dict[str, Any]]:
    """필요 변수: 33개 파라미터와 반복 수. 작동 원리: OFAT·노드 8종·목표모드 표본을 넓게 생성한다."""
    defaults = {spec["id"]: spec["default"] for spec in specs}
    plan: list[dict[str, Any]] = []
    for spec in specs:
        tag = _parameter_tag(spec["id"])
        for level in ("low", "default", "high"):
            coherent_metrics = _coherent_metrics(spec, level, specs, defaults)
            focus_ids = [
                key
                for key, value in coherent_metrics.items()
                if value != defaults.get(key)
            ]
            if spec["id"] not in focus_ids:
                focus_ids.append(spec["id"])
            solves_count, strategy_level, branch_conditions = _generation_controls(
                coherent_metrics
            )
            for repeat in range(repeats):
                plan.append(
                    {
                        "case_id": f"parameter-{spec['id']}-{level}-{repeat + 1}",
                        "kind": "parameter",
                        "key": spec["id"],
                        "level": level,
                        "repeat": repeat + 1,
                        "metrics": coherent_metrics,
                        "focus_metrics": {
                            key: coherent_metrics[key]
                            for key in focus_ids
                        },
                        "tag": tag,
                        "flow": _retag_flow(_flow_for_parameter(), tag),
                        "solves_count": solves_count,
                        "strategy_level": strategy_level,
                        "branch_conditions": branch_conditions,
                    }
                )
    for node_type in NODE_TYPES:
        for repeat in range(repeats):
            plan.append(
                {
                    "case_id": f"node-{node_type}-{repeat + 1}",
                    "kind": "node",
                    "key": node_type,
                    "level": "focused",
                    "repeat": repeat + 1,
                    "metrics": defaults,
                    "focus_metrics": {},
                    "tag": "#수열",
                    "flow": _flow_for_node(node_type),
                    "solves_count": 5 if node_type == "merge" else 4,
                    "strategy_level": 2,
                    "branch_conditions": 2 if node_type == "merge" else 1,
                }
            )
    for target, preset in target_presets.items():
        for repeat in range(repeats):
            plan.append(
                {
                    "case_id": f"target-{target}-{repeat + 1}",
                    "kind": "target",
                    "key": target,
                    "level": "target",
                    "repeat": repeat + 1,
                    "metrics": preset["metrics"],
                    "focus_metrics": {
                        key: value
                        for key, value in preset["metrics"].items()
                        if value != defaults.get(key)
                    },
                    "tag": "#함수",
                    "flow": _retag_flow(
                        _flow_for_node("merge" if target in {"29", "30"} else "reasoning"),
                        "#함수",
                    ),
                    "solves_count": preset["solves_count"],
                    "strategy_level": preset["strategy_level"],
                    "branch_conditions": preset["branch_conditions"],
                }
            )
    # 같은 파라미터만 연속 실행하지 않고 각 파라미터·노드·목표모드를 한 건씩 순환한다.
    # 장기 실행이 중단돼도 초반 표본이 전체 기능을 넓게 대표하도록 하기 위함이다.
    buckets: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for case in plan:
        buckets.setdefault((case["kind"], case["key"]), []).append(case)
    level_order = {"default": 0, "focused": 0, "target": 0, "low": 1, "high": 2}
    for bucket in buckets.values():
        bucket.sort(
            key=lambda case: (
                int(case.get("repeat", 1)),
                level_order.get(str(case.get("level")), 3),
            )
        )
    interleaved: list[dict[str, Any]] = []
    for index in range(max(len(bucket) for bucket in buckets.values())):
        for bucket in buckets.values():
            if index < len(bucket):
                interleaved.append(bucket[index])
    return interleaved


def _write_json(path: Path, value: Any) -> None:
    """필요 변수: 저장 경로와 JSON 값. 작동 원리: 모든 실험 파일을 UTF-8로 기록한다."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def _write_vault(
    vault: Path,
    specs: list[dict[str, Any]],
    plan: list[dict[str, Any]],
    model: str,
) -> None:
    """필요 변수: vault 경로·실험 계획·모델. 작동 원리: Obsidian 링크와 Canvas 그래프 자료를 생성한다."""
    (vault / ".obsidian").mkdir(parents=True, exist_ok=True)
    _write_json(vault / ".obsidian" / "app.json", {"showLineNumber": True, "newLinkFormat": "relative"})
    (vault / "00 Home.md").write_text(
        "# 고급 문제 생성 분석실\n\n"
        f"- 계획 표본: **{len(plan)}건**\n"
        f"- 반복 모델: [[01 Method/Model Selection|{model}]]\n"
        "- [[01 Method/Experiment Protocol|실험 프로토콜]]\n"
        "- [[08 Graphs/parameter-effects.canvas|노드·파라미터 그래프]]\n\n"
        "## 탐색\n\n- [[02 Nodes/Index|노드 8종]]\n- [[03 Parameters/Index|파라미터]]\n"
        "- [[04 Runs/Index|실행 기록]]\n- [[06 Findings/Pilot Findings|파일럿 발견]]\n",
        encoding="utf-8",
    )
    protocol = (
        "# Experiment Protocol\n\n"
        "## 표본\n\n"
        "- OFAT: 파라미터별 low/default/high × 반복\n"
        "- 노드: 8종 역할 집중 그래프 × 반복\n"
        "- 목표모드: 3점, 일반 4점, 22, 29, 30번 × 반복\n\n"
        "## 격리\n\n운영 quests.db와 codebases.db를 실행 폴더로 복제하고 환경변수로 격리한다.\n\n"
        "## 캐시\n\n동일 파라미터·수준의 반복 번호는 프롬프트에 넣지 않아 같은 request signature가 "
        "생성 코드베이스와 검증 seed를 재사용한다. 각 반복은 서로 다른 seed를 사용한다. "
        "SAM 제공자 prompt cache 적중은 보장하지 않으므로 결과에 캐시 적중으로 기록하지 않는다.\n\n"
        "## 측정\n\n성공률, 지연시간, 풀이 단계 수, 실제 분기 수, 문제·풀이 글자 수를 기록한다.\n"
    )
    (vault / "01 Method").mkdir(parents=True, exist_ok=True)
    (vault / "01 Method" / "Experiment Protocol.md").write_text(protocol, encoding="utf-8")
    (vault / "01 Method" / "Model Selection.md").write_text(
        "# Model Selection\n\n"
        f"반복 실험 모델: `{model}`\n\n"
        "반복 표본은 실측 속도를 우선하고, 운영 문제 생성 기본은 묘사 품질을 고려해 `gemini-3.5-flash`를 사용한다.\n",
        encoding="utf-8",
    )
    node_dir = vault / "02 Nodes"
    node_dir.mkdir(parents=True, exist_ok=True)
    (node_dir / "Index.md").write_text(
        "# 노드 8종\n\n" + "\n".join(f"- [[{node_type}|{NODE_LABELS[node_type]}]]" for node_type in NODE_TYPES),
        encoding="utf-8",
    )
    for node_type in NODE_TYPES:
        (node_dir / f"{node_type}.md").write_text(
            f"---\ntype: node\nnode_type: {node_type}\n---\n\n"
            f"# {NODE_LABELS[node_type]} 노드\n\n"
            f"관련 실험: `kind=node`, `key={node_type}`\n\n"
            "연결과 생성 결과의 변화는 실행 보고서에서 역링크로 확인한다.\n",
            encoding="utf-8",
        )
    parameter_dir = vault / "03 Parameters"
    parameter_dir.mkdir(parents=True, exist_ok=True)
    (parameter_dir / "Index.md").write_text(
        "# 파라미터\n\n" + "\n".join(f"- [[{spec['id']}|{spec['label']}]]" for spec in specs),
        encoding="utf-8",
    )
    for spec in specs:
        (parameter_dir / f"{spec['id']}.md").write_text(
            f"---\ntype: parameter\nparameter_id: {spec['id']}\ngroup: {spec['group']}\n---\n\n"
            f"# {spec['label']}\n\n{spec['description']}\n\n"
            f"- 범위: {spec['min']}~{spec['max']}\n- 기본값: {spec['default']}\n"
            f"- 낮은 값 예시: {spec['low']}\n- 높은 값 예시: {spec['high']}\n",
            encoding="utf-8",
        )
    (vault / "04 Runs").mkdir(parents=True, exist_ok=True)
    (vault / "04 Runs" / "Index.md").write_text("# 실행 기록\n\n실행별 보고서가 이 폴더에 추가됩니다.\n", encoding="utf-8")
    graph_nodes = []
    graph_edges = []
    for index, node_type in enumerate(NODE_TYPES):
        graph_nodes.append(
            {
                "id": f"node-{node_type}",
                "type": "file",
                "file": f"02 Nodes/{node_type}.md",
                "x": (index % 4) * 330,
                "y": (index // 4) * 230,
                "width": 280,
                "height": 180,
                "color": "4",
            }
        )
        if index:
            graph_edges.append(
                {
                    "id": f"edge-{index}",
                    "fromNode": f"node-{NODE_TYPES[index - 1]}",
                    "toNode": f"node-{node_type}",
                    "toEnd": "arrow",
                }
            )
    group_targets = {
        "difficulty": "reasoning",
        "concept_layer": "concept",
        "reasoning_layer": "reasoning",
        "insight_layer": "insight",
        "information_layer": "condition",
        "computation_layer": "computation",
        "trap_layer": "trap",
        "compression_layer": "condition",
        "student_simulator": "verification",
    }
    for index, spec in enumerate(specs):
        parameter_node_id = f"parameter-{spec['id']}"
        graph_nodes.append(
            {
                "id": parameter_node_id,
                "type": "file",
                "file": f"03 Parameters/{spec['id']}.md",
                "x": (index % 6) * 280,
                "y": 560 + (index // 6) * 210,
                "width": 240,
                "height": 150,
                "color": "3",
            }
        )
        graph_edges.append(
            {
                "id": f"parameter-edge-{spec['id']}",
                "fromNode": parameter_node_id,
                "toNode": f"node-{group_targets.get(spec['group'], 'reasoning')}",
                "toEnd": "arrow",
                "label": "영향",
            }
        )
    _write_json(vault / "08 Graphs" / "parameter-effects.canvas", {"nodes": graph_nodes, "edges": graph_edges})
    _write_json(vault / "07 Data" / "plan.json", plan)


def _append_jsonl(path: Path, value: dict[str, Any]) -> None:
    """필요 변수: 체크포인트 경로와 결과. 작동 원리: 중단 시에도 완료 케이스가 보존되도록 한 줄씩 기록한다."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(value, ensure_ascii=False) + "\n")


def _pipeline_provenance() -> dict[str, Any]:
    """필요 변수: 실행 환경의 모델 설정. 작동 원리: 성공·실패 결과에 동일한 파이프라인 출처를 기록한다."""
    return {
        "pipeline_version": PIPELINE_VERSION,
        "generator_model": os.getenv("CODEBASE_GEN_MODEL", "glm-4.7-flash"),
        "semantic_review_model": os.getenv(
            "CODEBASE_SEMANTIC_REVIEW_MODEL",
            "az-deepseek-v4-flash",
        ),
        "semantic_review_seeds": [123456, 789012, 345678],
        "max_generation_attempts": int(
            os.getenv("CODEBASE_GEN_MAX_ATTEMPTS", "3")
        ),
        "semantic_repair_attempts": int(
            os.getenv("CODEBASE_SEMANTIC_REPAIR_ATTEMPTS", "1")
        ),
        "codebase_max_tokens": int(os.getenv("CODEBASE_GEN_MAX_TOKENS", "6144")),
        "sam_request_timeout_seconds": float(
            os.getenv("SAM_REQUEST_TIMEOUT_SECONDS", "120")
        ),
        "sam_request_max_retries": int(os.getenv("SAM_REQUEST_MAX_RETRIES", "1")),
        "codebase_entry_regen_limit": int(
            os.getenv("CODEBASE_ENTRY_REGEN_LIMIT", "3")
        ),
    }


def _load_completed(path: Path) -> set[str]:
    """필요 변수: 기존 JSONL. 작동 원리: 재실행할 때 성공·실패와 관계없이 완료 케이스를 건너뛴다."""
    if not path.exists():
        return set()
    completed = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            completed.add(json.loads(line)["case_id"])
        except (KeyError, json.JSONDecodeError):
            continue
    return completed


def _run_case(
    server: Any,
    case: dict[str, Any],
    judge_model: str,
) -> dict[str, Any]:
    """필요 변수: 서버·실험 케이스·평가 모델. 작동 원리: 격리 생성 후 구조 지표와 기능 반영 점수를 추출한다."""
    payload = server.VariantFlowDraftRequest(
        flow_draft=case["flow"],
        prompt=(
            f"목표모드 실험 {case['kind']}/{case['key']}/{case['level']}: "
            "요청한 노드 기능과 파라미터 차이를 문제 문장과 풀이에 선명하게 묘사한다. "
            "정답은 유일해야 하며 고등학교 교육과정을 지킨다."
        ),
        tags=[case.get("tag", "#수열")],
        solves_count=case["solves_count"],
        strategy_level=case["strategy_level"],
        branch_conditions=case["branch_conditions"],
        advanced_metrics=case["metrics"],
        advanced_profile={
            "label": f"lab-{case['kind']}-{case['key']}",
            "intent": "요청값의 실제 반영 정도를 비교하는 격리 표본",
            "metrics": case["metrics"],
        },
    )
    started = time.perf_counter()
    response = server.generate_variant_from_flow_draft(payload, user_id="advanced_generation_lab")
    latency_ms = round((time.perf_counter() - started) * 1000, 2)
    record = {key: value for key, value in case.items() if key != "flow"}
    record.update(_pipeline_provenance())
    record["latency_ms"] = latency_ms
    record["success"] = bool(response.success)
    if not response.success:
        record["error"] = response.rejection.model_dump() if response.rejection else None
        return record
    quest = response.quest or {}
    data = quest.get("data") or {}
    solves = quest.get("solves") or []
    record.update(
        {
            "quest_id": (quest.get("header") or {}).get("quest_id"),
            "seed": data.get("seed"),
            "codebase_id": data.get("codebase_id"),
            "solve_count_actual": len(solves),
            "branch_count_actual": sum(len(step.get("branches") or []) for step in solves if isinstance(step, dict)),
            "quest_chars": len(json.dumps(data.get("quest_title"), ensure_ascii=False)),
            "solve_chars": len(json.dumps(solves, ensure_ascii=False)),
        }
    )
    from services.ai.sam_client import generate_json

    judge_prompt = (
        "다음은 고급 수학 문제 생성 실험 결과다. 요청한 노드/파라미터 기능이 실제 문제와 풀이에 얼마나 반영됐는지 평가하라. "
        "집중 평가 지표만 식별 가능한 하드 제약으로 채점하고, 전체 기준 지표 중 집중 평가에 없는 횟수는 "
        "문제에 문자 그대로 등장하지 않아도 감점하지 않는다. 노드 실험은 대상 노드 역할을 중심으로 채점한다. "
        "집중 지표나 대상 노드가 하나라도 어긋나면 focus_issues에 기록한다. "
        "본문 조건을 정답에 직접 대입하고 미지수를 독립적으로 풀어 모순·미결정·복수 정답·미정의 변수가 있으면 "
        "math_issues에 기록한다. 두 배열에는 실제 실패만 기록한다. 반드시 JSON 객체로 reflection_score(0~10), "
        "description_score(0~10), focus_issues(한국어 문자열 배열), math_issues(한국어 문자열 배열), "
        "evidence(한국어 문자열 배열)를 반환하라.\n"
        f"실험 종류={case['kind']}, 대상={case['key']}, 수준={case['level']}\n"
        f"집중 평가 지표={json.dumps(case.get('focus_metrics', {}), ensure_ascii=False)}\n"
        f"전체 기준 지표={json.dumps(case['metrics'], ensure_ascii=False)}\n"
        f"생성 결과={json.dumps({'data': data, 'solves': solves}, ensure_ascii=False)[:14000]}"
    )
    judge_started = time.perf_counter()
    try:
        judge = generate_json(
            model=judge_model,
            prompt=judge_prompt,
            temperature=0.1,
            max_tokens=900,
        )
        focus_issues = judge.get("focus_issues")
        math_issues = judge.get("math_issues")
        judge["focus_issues"] = focus_issues if isinstance(focus_issues, list) else ["평가 형식 오류"]
        judge["math_issues"] = math_issues if isinstance(math_issues, list) else ["평가 형식 오류"]
        judge["focus_constraints_valid"] = not judge["focus_issues"]
        judge["math_valid"] = not judge["math_issues"]
        judge["mismatch"] = judge["focus_issues"] + judge["math_issues"]
        record["judge"] = judge
    except Exception as exc:
        record["judge_error"] = str(exc)
    record["judge_latency_ms"] = round((time.perf_counter() - judge_started) * 1000, 2)
    return record


def _run_case_process(
    root: Path,
    run_data: Path,
    case: dict[str, Any],
    judge_model: str,
    timeout_seconds: int,
) -> dict[str, Any]:
    """필요 변수: 단일 케이스와 제한 시간. 작동 원리: 별도 프로세스에서 실행해 정체 케이스만 안전하게 종료한다."""
    case_path = run_data / "worker-case.json"
    _write_json(case_path, case)
    started = time.perf_counter()
    command = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--worker-case-file",
        str(case_path),
        "--worker-judge-model",
        judge_model,
    ]
    process = subprocess.Popen(
        command,
        cwd=root,
        env=os.environ.copy(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/PID", str(process.pid), "/T", "/F"],
                capture_output=True,
                check=False,
            )
        else:
            process.kill()
        stdout, stderr = process.communicate()
        stdout_tail = "\n".join(stdout.splitlines()[-18:])
        stderr_tail = "\n".join(stderr.splitlines()[-8:])
        debug_tail = f"[stdout]\n{stdout_tail}\n[stderr]\n{stderr_tail}"[-3000:]
        return {
            **{key: value for key, value in case.items() if key != "flow"},
            **_pipeline_provenance(),
            "success": False,
            "latency_ms": round((time.perf_counter() - started) * 1000, 2),
            "error": {
                "reason_code": "case_timeout",
                "reason_message": f"{timeout_seconds}초 초과",
                "stage_log_tail": debug_tail,
            },
        }
    result_lines = [line for line in stdout.splitlines() if line.startswith("LAB_RESULT ")]
    if result_lines:
        return json.loads(result_lines[-1].removeprefix("LAB_RESULT "))
    return {
        **{key: value for key, value in case.items() if key != "flow"},
        **_pipeline_provenance(),
        "success": False,
        "latency_ms": round((time.perf_counter() - started) * 1000, 2),
        "error": {
            "reason_code": "worker_failed",
            "reason_message": (stderr or stdout)[-2000:],
        },
    }


def _write_summary(vault: Path, run_id: str, results_path: Path, model: str) -> None:
    """필요 변수: 실행 결과 JSONL. 작동 원리: 성공률과 그룹별 평균을 Obsidian 실행 문서와 CSV로 요약한다."""
    raw_rows = [
        json.loads(line)
        for line in results_path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    # 비정상 중복 실행이 있었더라도 같은 case_id는 마지막 체크포인트 하나만 분석한다.
    rows_by_case = {row["case_id"]: row for row in raw_rows}
    rows = list(rows_by_case.values())
    groups: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        groups[(row["kind"], row["key"], row["level"])].append(row)
    summary_rows = []
    for key, items in sorted(groups.items()):
        successes = [item for item in items if item.get("success")]
        unique_codebases = {
            item.get("codebase_id")
            for item in successes
            if item.get("codebase_id") is not None
        }
        summary_rows.append(
            {
                "kind": key[0],
                "key": key[1],
                "level": key[2],
                "samples": len(items),
                "success_rate": round(len(successes) / len(items), 4),
                "latency_ms_mean": round(sum(item["latency_ms"] for item in items) / len(items), 2),
                "solve_count_mean": round(sum(item.get("solve_count_actual", 0) for item in successes) / max(1, len(successes)), 2),
                "branch_count_mean": round(sum(item.get("branch_count_actual", 0) for item in successes) / max(1, len(successes)), 2),
                "reflection_score_mean": round(
                    sum(float((item.get("judge") or {}).get("reflection_score", 0)) for item in successes)
                    / max(1, len(successes)),
                    2,
                ),
                "focus_valid_rate": round(
                    sum((item.get("judge") or {}).get("focus_constraints_valid") is True for item in successes)
                    / max(1, len(successes)),
                    4,
                ),
                "math_valid_rate": round(
                    sum((item.get("judge") or {}).get("math_valid") is True for item in successes)
                    / max(1, len(successes)),
                    4,
                ),
                "codebase_reuse_rate": round(
                    1 - (len(unique_codebases) / len(successes))
                    if successes
                    else 0.0,
                    4,
                ),
            }
        )
    csv_path = vault / "07 Data" / f"summary-{run_id}.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)
    _write_effect_canvas(vault, run_id, summary_rows)
    markdown = [
        "---",
        "type: generation-run",
        f"run_id: {run_id}",
        f"model: {model}",
        f"samples: {len(rows)}",
        "---",
        "",
        f"# 실행 {run_id}",
        "",
        f"- 모델: `{model}`",
        f"- 완료 표본: {len(rows)}",
        f"- 성공: {sum(1 for row in rows if row.get('success'))}",
        f"- 데이터: [[../07 Data/summary-{run_id}.csv|요약 CSV]]",
        f"- 측정 그래프: [[../08 Graphs/effects-{run_id}.canvas|효과 Canvas]]",
        "",
        "## 그룹 요약",
        "",
        "|종류|대상|수준|표본|성공률|평균 지연(ms)|평균 풀이|평균 분기|반영 점수|집중 제약 유효|수학 유효|코드베이스 재사용|",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in summary_rows:
        markdown.append(
            f"|{row['kind']}|{row['key']}|{row['level']}|{row['samples']}|{row['success_rate']}|"
            f"{row['latency_ms_mean']}|{row['solve_count_mean']}|{row['branch_count_mean']}|"
            f"{row['reflection_score_mean']}|{row['focus_valid_rate']}|{row['math_valid_rate']}|"
            f"{row['codebase_reuse_rate']}|"
        )
    (vault / "04 Runs" / f"{run_id}.md").write_text("\n".join(markdown) + "\n", encoding="utf-8")


def _write_effect_canvas(
    vault: Path,
    run_id: str,
    summary_rows: list[dict[str, Any]],
) -> None:
    """필요 변수: 실행별 그룹 요약. 작동 원리: 성공률·반영 점수를 실제 측정값 노드와 연결선으로 시각화한다."""
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    rows_by_key: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in summary_rows:
        rows_by_key[(row["kind"], row["key"])].append(row)
    for index, ((kind, key), rows) in enumerate(sorted(rows_by_key.items())):
        x = (index % 5) * 430
        y = (index // 5) * 330
        anchor_id = f"anchor-{kind}-{key}"
        nodes.append(
            {
                "id": anchor_id,
                "type": "text",
                "text": f"# {kind}: {key}\n표본 {sum(row['samples'] for row in rows)}건",
                "x": x,
                "y": y,
                "width": 220,
                "height": 100,
                "color": "4" if kind == "node" else "3",
            }
        )
        for level_index, row in enumerate(sorted(rows, key=lambda item: item["level"])):
            result_id = f"result-{kind}-{key}-{row['level']}"
            score = row["reflection_score_mean"]
            color = "2" if score >= 7 else "5" if score >= 4 else "1"
            nodes.append(
                {
                    "id": result_id,
                    "type": "text",
                    "text": (
                        f"**{row['level']}**\n반영 {score}/10\n"
                        f"성공률 {row['success_rate'] * 100:.0f}%\n지연 {row['latency_ms_mean']:.0f}ms"
                    ),
                    "x": x + 250,
                    "y": y + level_index * 105,
                    "width": 160,
                    "height": 90,
                    "color": color,
                }
            )
            edges.append(
                {
                    "id": f"edge-{result_id}",
                    "fromNode": anchor_id,
                    "toNode": result_id,
                    "toEnd": "arrow",
                    "label": "측정",
                }
            )
    _write_json(vault / "08 Graphs" / f"effects-{run_id}.canvas", {"nodes": nodes, "edges": edges})


def main() -> int:
    """필요 변수: CLI 실행 모드·반복 수·제한·모델. 작동 원리: 계획 생성, DB 격리, 체크포인트 실행, 문서화를 순서대로 수행한다."""
    parser = argparse.ArgumentParser(description="고급 문제 생성 장기 표본 분석실")
    parser.add_argument("--run-id", default=datetime.now().strftime("%Y%m%d-%H%M%S"))
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--limit", type=int, default=0, help="0이면 전체 계획 실행")
    parser.add_argument("--model", default="glm-4.7-flash")
    parser.add_argument("--judge-model", default="az-deepseek-v4-flash")
    parser.add_argument("--case-timeout-seconds", type=int, default=180)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--worker-case-file", default="", help=argparse.SUPPRESS)
    parser.add_argument("--worker-judge-model", default="az-deepseek-v4-flash", help=argparse.SUPPRESS)
    args = parser.parse_args()

    root = _repo_root()
    if args.worker_case_file:
        sys.path.insert(0, str(root / "omj"))
        os.chdir(root / "omj")
        import server

        case = json.loads(Path(args.worker_case_file).read_text(encoding="utf-8"))
        record = _run_case(server, case, args.worker_judge_model)
        print("LAB_RESULT " + json.dumps(record, ensure_ascii=False), flush=True)
        return 0

    vault = root / "docs" / "advanced-generation-vault"
    specs = _read_parameter_specs(root)
    target_presets = _read_target_presets(root)
    plan = _build_plan(specs, target_presets, max(1, args.repeats))
    _write_vault(vault, specs, plan, args.model)
    if args.prepare_only:
        print(json.dumps({"vault": str(vault), "planned": len(plan)}, ensure_ascii=False))
        return 0

    run_data = vault / "07 Data" / "runs" / args.run_id
    run_data.mkdir(parents=True, exist_ok=True)
    quest_db = run_data / "quests.db"
    codebase_db = run_data / "codebases.db"
    if not quest_db.exists():
        shutil.copy2(root / "omj" / "quests.db", quest_db)
    if not codebase_db.exists():
        shutil.copy2(root / "omj" / "codebases.db", codebase_db)
    os.environ["QUEST_DB_PATH"] = str(quest_db)
    os.environ["CODEBASE_DB_PATH"] = str(codebase_db)
    os.environ["CODEBASE_GEN_MODEL"] = args.model
    os.environ["SAM_PROBLEM_MODEL"] = args.model
    os.environ["CODEBASE_GEN_MAX_ATTEMPTS"] = "1"
    os.environ["CODEBASE_SEMANTIC_REPAIR_ATTEMPTS"] = "0"
    os.environ["CODEBASE_GEN_MAX_TOKENS"] = "4096"
    os.environ["SAM_REQUEST_TIMEOUT_SECONDS"] = "60"
    os.environ["SAM_REQUEST_MAX_RETRIES"] = "1"
    os.environ["CODEBASE_ENTRY_REGEN_LIMIT"] = "1"
    os.environ.setdefault("RUNTIME_SEED_BACKFILL_ENABLED", "0")
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")
    results_path = run_data / "results.jsonl"
    completed = _load_completed(results_path)
    remaining = [case for case in plan if case["case_id"] not in completed]
    if args.limit > 0 and len(remaining) > args.limit:
        # 제한 실행도 앞부분에 치우치지 않도록 전체 계획에서 같은 간격으로 표본을 뽑는다.
        stride = len(remaining) / args.limit
        remaining = [remaining[int(index * stride)] for index in range(args.limit)]
    for index, case in enumerate(remaining, start=1):
        record = _run_case_process(
            root,
            run_data,
            case,
            args.judge_model,
            max(30, args.case_timeout_seconds),
        )
        _append_jsonl(results_path, record)
        _write_summary(vault, args.run_id, results_path, args.model)
        print(
            json.dumps(
                {
                    "progress": f"{index}/{len(remaining)}",
                    "case_id": case["case_id"],
                    "success": record["success"],
                    "latency_ms": record["latency_ms"],
                },
                ensure_ascii=False,
            ),
            flush=True,
        )
    if results_path.exists():
        _write_summary(vault, args.run_id, results_path, args.model)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

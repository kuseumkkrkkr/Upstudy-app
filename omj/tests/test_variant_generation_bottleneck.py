import time
import importlib
import importlib.util
import tempfile
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import server
import generater.codebase_runner as codebase_runner
import storage.storage as storage_mod
from generater import codebase_gen, codebase_repair
_MAKE_SPEC = importlib.util.spec_from_file_location(
    "generater_make_test_module",
    ROOT / "generater" / "make.py",
)
make_module = importlib.util.module_from_spec(_MAKE_SPEC)
assert _MAKE_SPEC and _MAKE_SPEC.loader
_MAKE_SPEC.loader.exec_module(make_module)
from generater.codebase_runner import (
    hard_cancel_process_pool,
    run_codebase_batch,
    shutdown_process_pool,
    warmup_sympy_pool,
)


def test_run_codebase_batch_uses_batch_timeout():
    warmup_sympy_pool()
    entry = {
        "code": """
import time

def generate_problem(seed=None):
    time.sleep(5)
    return {"answer": seed}
""".strip()
    }

    started = time.perf_counter()
    results = run_codebase_batch(
        entry,
        [1, 2, 3, 4],
        timeout_seconds=0.5,
    )
    elapsed = time.perf_counter() - started
    shutdown_process_pool(wait=False)

    assert elapsed < 2.0
    assert len(results) == 4
    assert all("timeout" in item.get("_error", "") for item in results)


def test_external_cancel_does_not_shutdown_pool_while_another_operation_is_active(monkeypatch):
    class FakePool:
        def __init__(self):
            self.shutdown_called = False
            self._processes = {}

        def shutdown(self, *args, **kwargs):
            self.shutdown_called = True

    fake_pool = FakePool()
    monkeypatch.setattr(codebase_runner, "_pool_executor", fake_pool)
    monkeypatch.setattr(codebase_runner, "_active_pool_ops", 1)

    cancelled = hard_cancel_process_pool()

    assert cancelled is False
    assert fake_pool.shutdown_called is False
    assert codebase_runner._pool_executor is fake_pool


def test_isolated_cancel_can_shutdown_only_current_pool(monkeypatch):
    class FakePool:
        def __init__(self):
            self.shutdown_called = False
            self._processes = {}

        def shutdown(self, *args, **kwargs):
            self.shutdown_called = True

    fake_pool = FakePool()
    monkeypatch.setattr(codebase_runner, "_pool_executor", fake_pool)
    monkeypatch.setattr(codebase_runner, "_active_pool_ops", 1)

    cancelled = hard_cancel_process_pool(isolate_current=True)

    assert cancelled is True
    assert fake_pool.shutdown_called is True
    assert codebase_runner._pool_executor is None


def test_variant_runtime_params_fall_back_to_nearest_cached_codebase(monkeypatch):
    monkeypatch.setattr(
        server,
        "list_codebase_stats",
        lambda: [
            {
                "id": 1,
                "tags": ["#a", "#b"],
                "solves_count": 4,
                "strategy_level": 2,
                "branch_conditions": 1,
                "cached_seeds": 30,
                "status": "ok",
            },
            {
                "id": 2,
                "tags": ["#a", "#b", "#c"],
                "solves_count": 6,
                "strategy_level": 3,
                "branch_conditions": 2,
                "cached_seeds": 12,
                "status": "ok",
            },
        ],
    )

    solves, strategy, branches, fallback = server._resolve_cached_variant_runtime_params(
        tags=["#a", "#b", "#c", "#d", "#e"],
        solves_count=8,
        strategy_level=3,
        branch_conditions=3,
    )

    assert (solves, strategy, branches) == (6, 3, 2)
    assert fallback is not None
    assert fallback["codebase_id"] == 2
    assert fallback["reason"] == "nearest_cached_codebase"


def test_variant_runtime_params_keep_exact_cached_codebase(monkeypatch):
    monkeypatch.setattr(
        server,
        "list_codebase_stats",
        lambda: [
            {
                "id": 1,
                "tags": ["#a"],
                "solves_count": 8,
                "strategy_level": 3,
                "branch_conditions": 3,
                "cached_seeds": 1,
                "status": "ok",
            }
        ],
    )

    solves, strategy, branches, fallback = server._resolve_cached_variant_runtime_params(
        tags=["#a"],
        solves_count=8,
        strategy_level=3,
        branch_conditions=3,
    )

    assert (solves, strategy, branches) == (8, 3, 3)
    assert fallback is None


def test_repair_prompt_omits_full_original_generation_prompt():
    original_prompt = "\n".join(
        [
            "- 입력 hash_tags: [\"#a\", \"#b\"]",
            "- root_flows(solves 길이): 6",
            "- branch_conditions: 2",
            "- main_huddle 은 3 으로 설정한다.",
            "verbose rule " * 500,
        ]
    )
    code_text = "def generate_problem(seed=None):\n    return {}\n" * 300

    prompt = codebase_repair._build_repair_prompt(
        prompt=original_prompt,
        code_text=code_text,
        error_message="ValueError: solves must not be empty." * 200,
    )

    assert "원본 프롬프트" not in prompt
    assert "verbose rule" not in prompt
    assert "- 입력 hash_tags:" in prompt
    assert "truncated" in prompt
    assert len(prompt) < 7000


def test_repair_agent_uses_compact_token_budget(monkeypatch):
    calls = {}

    monkeypatch.setattr(codebase_repair, "is_sam_configured", lambda: True)

    def fake_chat_completion_text(**kwargs):
        calls.update(kwargs)
        return "def generate_problem(seed=None):\n    return {'solves': [1]}\n"

    monkeypatch.setattr(
        codebase_repair,
        "chat_completion_text",
        fake_chat_completion_text,
    )

    codebase_repair.repair_codebase(
        prompt="- 입력 hash_tags: [\"#a\"]\n" + ("x" * 5000),
        code_text="def generate_problem(seed=None):\n    raise ValueError()\n",
        error_message="boom",
    )

    assert calls["max_tokens"] == 4096
    assert len(calls["prompt"]) < 5000


def test_runtime_seed_limits_default_to_smaller_budget():
    assert make_module._parse_seed_limits("32,32") == [32, 32]
    assert make_module._parse_seed_limits("1000,0,bad,12") == [100, 12]


def test_variant_generation_context_promotes_advanced_metrics():
    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "trap_node",
                "text": "정의역 조건을 먼저 확인한다.",
                "hash_tags": ["#함수", "#미분"],
                "branches": ["case_a", "case_b"],
                "teacher_instruction": "정의역을 놓치면 다른 정수 답이 나오게 만든다.",
            }
        ],
        prompt="함정이 강한 수능 22번형 문항",
        tags=["#함수", "#미분"],
        advanced_metrics={
            "trap": 9,
            "condition_density": 8,
            "algebra_steps": 7,
            "top_rate": 35,
        },
        advanced_profile={
            "expected_number": "22",
            "label": "킬러",
            "intent": "정의역 함정과 조건 압축을 평가한다.",
        },
    )

    context = server._build_variant_generation_context(payload, ["#함수", "#미분"])
    signature = server._build_variant_request_signature(
        tags=["#함수", "#미분"],
        solves_count=payload.solves_count,
        strategy_level=payload.strategy_level,
        branch_conditions=payload.branch_conditions,
        generation_context=context,
    )

    assert context["metrics"]["trap"] == 9
    assert context["requested_params"] == {
        "solves_count": payload.solves_count,
        "strategy_level": payload.strategy_level,
        "branch_conditions": payload.branch_conditions,
    }
    assert any(item["id"] == "trap" for item in context["dominant_metrics"])
    assert any("정의역" in example for example in context["examples"])
    assert context["node_directives"][0]["node_id"] == "trap_node"
    assert len(signature) == 64


def test_variant_generation_context_preserves_canvas_node_design():
    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "condition_node",
                "text": "함수의 정의역과 극값 조건을 먼저 정리한다.",
                "hash_tags": ["#함수"],
                "branches": ["insight_node"],
                "teacher_instruction": "정의역 조건을 조건 노드에서 반드시 먼저 드러낸다.",
            },
            {
                "node_id": "insight_node",
                "text": "역추적으로 계수를 복원한다.",
                "hash_tags": ["#미분"],
                "branches": ["verify_node"],
                "prompt_text": "정답에서 역방향으로 식을 설계한다.",
            },
        ],
        prompt="캔버스 설계 기반 문제",
        tags=["#함수", "#미분"],
        advanced_metrics={"graph_depth": 8, "branch_factor": 2},
        advanced_profile={"expected_number": "30번", "label": "고급 캔버스"},
    )

    context = server._build_variant_generation_context(payload, ["#함수", "#미분"])

    assert context["expected_number"] == "30번"
    assert context["profile_label"] == "고급 캔버스"
    assert context["node_directives"][0]["node_id"] == "condition_node"
    assert context["node_directives"][0]["branches"] == ["insight_node"]
    assert "정의역 조건" in context["node_directives"][0]["instruction"]
    assert context["node_directives"][1]["branches"] == ["verify_node"]


def test_variant_request_signature_changes_with_parameter_values():
    base_payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "trap_node",
                "text": "정의역 함정을 조절한다.",
                "hash_tags": ["#함수"],
            }
        ],
        prompt="같은 캔버스에서 파라미터만 바꾼다.",
        tags=["#함수"],
        advanced_metrics={"trap": 1, "algebra_steps": 3},
    )
    high_payload = server.VariantFlowDraftRequest(
        flow_draft=[node.model_dump() for node in base_payload.flow_draft],
        prompt=base_payload.prompt,
        tags=["#함수"],
        advanced_metrics={"trap": 9, "algebra_steps": 12},
    )

    base_context = server._build_variant_generation_context(base_payload, ["#함수"])
    high_context = server._build_variant_generation_context(high_payload, ["#함수"])
    base_signature = server._build_variant_request_signature(
        tags=["#함수"],
        solves_count=base_payload.solves_count,
        strategy_level=base_payload.strategy_level,
        branch_conditions=base_payload.branch_conditions,
        generation_context=base_context,
    )
    high_signature = server._build_variant_request_signature(
        tags=["#함수"],
        solves_count=high_payload.solves_count,
        strategy_level=high_payload.strategy_level,
        branch_conditions=high_payload.branch_conditions,
        generation_context=high_context,
    )

    assert base_signature != high_signature
    assert any("함정은 줄이고" in example for example in base_context["examples"])
    assert any("정의역" in example for example in high_context["examples"])


def test_flow_draft_endpoint_inserts_single_tray_item(monkeypatch):
    tray_calls = []

    def fake_generate_variant_quest(**kwargs):
        return {
            "header": {"quest_id": "q-dummy-flow"},
            "data": {"quest_title": "더미 문제", "quest_answer": "1"},
            "solves": [],
            "info": {"hash_tag": kwargs["tags"]},
        }

    def fake_insert_variant_tray_item(**kwargs):
        tray_calls.append(kwargs)
        return {"id": len(tray_calls), "quest_id": "q-dummy-flow"}

    monkeypatch.setattr(
        server,
        "_generate_variant_quest",
        fake_generate_variant_quest,
    )
    monkeypatch.setattr(
        server,
        "_insert_variant_tray_item",
        fake_insert_variant_tray_item,
    )

    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "condition_node",
                "text": "조건을 먼저 정리한다.",
                "hash_tags": ["#함수"],
            }
        ],
        prompt="더미 검증",
        tags=["#함수"],
        advanced_metrics={"reasoning": 8},
    )

    response = server.generate_variant_from_flow_draft(
        payload,
        user_id="teacher-dummy",
    )

    assert response.success is True
    assert response.quest is not None
    assert response.quest["header"]["quest_id"] == "q-dummy-flow"
    assert len(tray_calls) == 1
    assert tray_calls[0]["user_id"] == "teacher-dummy"
    assert tray_calls[0]["source_variant_mode"] == "flow_draft"


def test_flow_draft_endpoint_preserves_zero_branch_parameter(monkeypatch):
    captured_kwargs = {}

    def fake_generate_variant_quest(**kwargs):
        captured_kwargs.update(kwargs)
        return {
            "header": {"quest_id": "q-zero-branch"},
            "data": {"quest_title": "더미 문제", "quest_answer": "1"},
            "solves": [],
            "info": {"hash_tag": kwargs["tags"]},
        }

    monkeypatch.setattr(
        server,
        "_generate_variant_quest",
        fake_generate_variant_quest,
    )
    monkeypatch.setattr(
        server,
        "_insert_variant_tray_item",
        lambda **kwargs: {"id": 1, "quest_id": "q-zero-branch"},
    )

    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "linear_node",
                "text": "한 줄 계산으로 끝나는 문항",
                "hash_tags": ["#함수"],
            }
        ],
        prompt="분기 없는 캔버스 문항",
        tags=["#함수"],
        solves_count=2,
        strategy_level=1,
        branch_conditions=0,
    )

    response = server.generate_variant_from_flow_draft(
        payload,
        user_id="teacher-dummy",
    )

    assert response.success is True
    assert captured_kwargs["branch_conditions"] == 0
    assert captured_kwargs["generation_context"]["requested_params"][
        "branch_conditions"
    ] == 0


def test_store_data_persists_advanced_generation_metadata(monkeypatch):
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = str(Path(tmpdir) / "quests.db")
        monkeypatch.setattr(storage_mod, "DB_PATH", db_path)

        stored = storage_mod.store_data(
            {
                "header": {"quest_id": "q-advanced-meta", "quest_model": []},
                "info": {
                    "main": 3,
                    "sub": [],
                    "hash_tag": ["#함수"],
                    "flow_rate": 2,
                    "difficulty": 12,
                    "main_huddle": 2,
                },
                "data": {
                    "quest_title": "x+1=2일 때 x의 값은?",
                    "quest_answer": "1",
                    "codebase_id": 11,
                    "seed": 22,
                    "advanced_generation_context": {
                        "requested_params": {
                            "solves_count": 2,
                            "strategy_level": 1,
                            "branch_conditions": 0,
                        },
                        "node_directives": [
                            {
                                "node_id": "condition_node",
                                "instruction": "조건을 먼저 정리한다.",
                            }
                        ],
                    },
                    "variant_request_signature": "signature-1234",
                },
                "solves": [
                    {
                        "flow": "양변에서 1을 뺀다.",
                        "hash_tag": ["#함수"],
                        "hint_riddle": "이항한다.",
                        "answer_riddle": "x=1",
                        "enter_huddle": 0,
                        "branches": [],
                    }
                ],
            }
        )

        assert stored is True
        quest = storage_mod.get_quest("q-advanced-meta")
        meta = quest["data"]["meta"]
        assert meta["advanced_generation_context"]["requested_params"][
            "solves_count"
        ] == 2
        assert meta["advanced_generation_context"]["node_directives"][0][
            "node_id"
        ] == "condition_node"
        assert meta["variant_request_signature"] == "signature-1234"


def test_cached_seed_order_changes_with_request_signature():
    seeds = [101, 202, 303, 404, 505, 606, 707, 808]

    orders = {
        tuple(
            make_module._order_seed_candidates(
                seeds,
                f"signature-{idx}",
                entry_id=7,
                code_hash="abc",
            )
        )
        for idx in range(6)
    }

    assert len(orders) > 1
    for order in orders:
        assert sorted(order) == seeds


def test_variant_generation_context_uses_low_metric_examples():
    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "algebra_node",
                "text": "계산량 중심으로 풀이한다.",
                "hash_tags": ["#함수"],
                "branches": [],
                "teacher_instruction": "함정은 줄이고 계산 단계를 늘린다.",
            }
        ],
        prompt="계산량 중심 문항",
        tags=["#함수"],
        advanced_metrics={
            "trap": 1,
            "trap_count": 0,
            "algebra_steps": 14,
        },
    )

    context = server._build_variant_generation_context(payload, ["#함수"])

    assert any("함정은 줄이고" in example for example in context["examples"])
    assert not any("빠뜨리면 다른 정수 답" in example for example in context["examples"])


def test_variant_generation_context_uses_value_sensitive_directives():
    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "direct_node",
                "text": "단일 흐름으로 계산한다.",
                "hash_tags": ["#함수"],
            }
        ],
        prompt="낮은 분기 지표 문항",
        tags=["#함수"],
        advanced_metrics={
            "branch_factor": 0,
            "trap": 1,
        },
    )

    context = server._build_variant_generation_context(payload, ["#함수"])
    directives = {
        item["id"]: item["directive"]
        for item in context["dominant_metrics"]
    }

    assert "단일 풀이 흐름" in directives["branch_factor"]
    assert "오답 유발 조건을 최소화" in directives["trap"]
    assert not any(
        "케이스 분류를 만든다" in directive
        for directive in directives.values()
    )


def test_variant_generation_context_uses_branch_example_from_two_cases():
    payload = server.VariantFlowDraftRequest(
        flow_draft=[
            {
                "node_id": "branch_node",
                "text": "두 경우를 비교한다.",
                "hash_tags": ["#함수"],
            }
        ],
        prompt="분기형 문항",
        tags=["#함수"],
        advanced_metrics={"branch_factor": 2},
    )

    context = server._build_variant_generation_context(payload, ["#함수"])

    assert any("두 케이스" in example for example in context["examples"])


def test_advanced_context_filters_generic_codebases():
    filtered = make_module._filter_advanced_context_codebases(
        [
            {"name": "CB-001", "tags": ["#함수"]},
            {"name": "variant:abcdef1234567890", "tags": ["#함수"]},
        ],
        generation_context={"node_directives": [{"node_id": "n1"}]},
        request_signature="abcdef1234567890ffff",
    )

    assert [entry["name"] for entry in filtered] == ["variant:abcdef1234567890"]


def test_advanced_variant_generation_keeps_requested_runtime_params(monkeypatch):
    captured = {}

    def fake_make(
        hash_tags,
        solves_count,
        strategy_level,
        branch_conditions,
        *args,
        **kwargs,
    ):
        captured.update(
            {
                "hash_tags": hash_tags,
                "solves_count": solves_count,
                "strategy_level": strategy_level,
                "branch_conditions": branch_conditions,
                "generation_context": kwargs.get("generation_context"),
                "request_signature": kwargs.get("request_signature"),
            }
        )
        return {
            "header": {"quest_id": "q-runtime-params"},
            "info": {"hash_tag": hash_tags},
            "data": {"quest_title": "더미", "quest_answer": "1"},
            "solves": [],
        }

    monkeypatch.setattr(server, "make", fake_make)
    monkeypatch.setattr(server, "store_data", lambda data: True)

    context = {"node_directives": [{"node_id": "n1"}], "metrics": {"trap": 1}}
    server._generate_variant_quest(
        tags=["#함수"],
        solves_count=2,
        strategy_level=1,
        branch_conditions=0,
        seed_override=None,
        reference_quest_id=None,
        generation_context=context,
        request_signature="runtime-param-signature",
    )

    assert captured["solves_count"] == 2
    assert captured["strategy_level"] == 1
    assert captured["branch_conditions"] == 0
    assert captured["generation_context"] == context
    assert captured["request_signature"] == "runtime-param-signature"


def test_codebase_text_extractor_accepts_prefaced_code_fence():
    raw = """
다음은 생성 코드입니다.

```python
import random

def generate_problem(seed=None):
    return {"quest_title": "q", "quest_answer": "1", "solves": []}
```
"""

    extracted = codebase_gen._extract_code_text(raw)

    assert extracted.startswith("import random")
    assert "다음은 생성 코드" not in extracted
    assert "def generate_problem" in extracted


def test_repair_text_extractor_accepts_prefaced_code_fence():
    raw = """
수정했습니다.

```python
def generate_problem(seed=None):
    return {"quest_title": "q", "quest_answer": "1", "solves": []}
```
"""

    extracted = codebase_repair._extract_code_text(raw)

    assert extracted.startswith("def generate_problem")
    assert "수정했습니다" not in extracted


def test_codebase_progress_bar_is_ascii(capsys):
    codebase_gen._print_progress(1, 3, "testing")

    output = capsys.readouterr().out
    assert "#" in output
    assert "█" not in output
    output.encode("cp949")


def test_codebase_generation_prompt_includes_advanced_context():
    prompt = codebase_gen._build_generation_prompt(
        hash_tags=["#함수", "#미분"],
        solves_count=6,
        branch_conditions=2,
        main_huddle=3,
        generation_context={
            "expected_number": "22",
            "metrics": {"trap": 9, "condition_density": 8},
            "dominant_metrics": [
                {
                    "id": "trap",
                    "label": "함정 강도",
                    "value": 9,
                    "directive": "정의역을 놓치면 오답이 되게 한다.",
                }
            ],
            "node_directives": [
                {
                    "node_id": "n1",
                    "tags": ["#함수"],
                    "instruction": "정의역 조건을 먼저 확인하게 한다.",
                }
            ],
            "examples": ["예: 정의역을 빠뜨리면 다른 정수 답이 나온다."],
        },
    )

    assert "고급 생성 파라미터 반영 지시" in prompt
    assert '"trap": 9' in prompt
    assert "정의역을 놓치면 오답" in prompt

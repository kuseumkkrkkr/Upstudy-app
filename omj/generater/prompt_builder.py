import json
import textwrap
from typing import Any, Dict, List, Optional


def _format_reference(reference_quest: Optional[Dict[str, Any]]) -> str:
    if not reference_quest:
        return ""

    data = reference_quest.get("data", {})
    info = reference_quest.get("info", {})
    solves = reference_quest.get("solves", [])

    def _format_content(value: Any) -> str:
        if value is None:
            return "null"
        if isinstance(value, (dict, list)):
            return json.dumps(value, ensure_ascii=False)
        wrapped = {"blocks": [{"type": "text", "content": str(value)}]}
        return json.dumps(wrapped, ensure_ascii=False)

    def _format_step(step: Dict[str, Any], depth: int) -> List[str]:
        indent = "  " * depth
        lines = [
            f"{indent}- flow: {_format_content(step.get('flow'))}",
            f"{indent}  hint_riddle: {_format_content(step.get('hint_riddle'))}",
            f"{indent}  answer_riddle: {_format_content(step.get('answer_riddle'))}",
            f"{indent}  enter_huddle: {step.get('enter_huddle', '')}",
        ]
        for branch in step.get("branches") or []:
            lines.append(f"{indent}  branch:")
            lines.extend(_format_step(branch, depth + 2))
        return lines

    lines: List[str] = []
    for idx, step in enumerate(solves, start=1):
        lines.append(f"{idx}.")
        lines.extend(_format_step(step, 1))

    solves_text = "\n".join(lines) if lines else "없음"

    reference_block = f"""
[참고 문제]
quest_title: {_format_content(data.get("quest_title"))}
quest_answer: {_format_content(data.get("quest_answer"))}
main_huddle: {info.get("main_huddle", "")}
solves:
{solves_text}
"""
    return textwrap.dedent(reference_block).strip()


def build_prompt(
    hash_tags: List[str],
    solves_count: int,
    strategy_level: int,
    branch_conditions: int,
    reference_quest: Optional[Dict[str, Any]] = None,
) -> str:
    tags_json = json.dumps(hash_tags, ensure_ascii=False)
    reference_block = _format_reference(reference_quest)

    prompt = f"""
수학 문제를 생성하고 JSON으로만 응답해.
- hash_tags: {tags_json}
- root_flows: {solves_count} (기본 흐름의 개수)
- branch_conditions: {branch_conditions} (분기해야 하는 조건/레인 수)
- strategy_level(main_huddle): {strategy_level} (1=직관적, 2=단계적 연결, 3=다중 조건/연립 방정식 등 고난도. 값이 높을수록 enter_huddle도 높게 배치)

[분기 설계 규칙]
- solves 배열 길이는 root_flows 값과 동일하게 유지.
- 분기가 필요할 때는 해당 solve의 branches 배열에 조건별 세부 흐름을 넣어라.
- branch_conditions 만큼의 레인을 branches로 표현하고, 각 레인은 최소 '조건 해석'과 '조건 풀이' 두 단계를 포함한다.
- 분기 이후에는 조건을 비교/중합하는 흐름을 포함해 다시 메인 풀이로 이어지도록 한다.
- 모든 flow/branch에 hint_riddle, answer_riddle, enter_huddle를 채워라.

[출력 포맷]
{{
  "quest_title": {{
    "blocks": [
      {{ "type": "text", "content": "문제 본문" }},
      {{ "type": "latex", "content": "f(x)=x^2" }}
    ]
  }},
  "quest_answer": {{
    "blocks": [
      {{ "type": "latex", "content": "3" }}
    ]
  }},
  "quest_model": ["pix2text"] 또는 ["gemini-vision"],
  "main_huddle": {strategy_level},
  "primary_hash_tag": "가장 대표 해시태그",
  "quest_image": null,
  "solves": [
    {{
      "flow": {{
        "blocks": [
          {{ "type": "text", "content": "메인 흐름 설명" }}
        ]
      }},
      "hint_riddle": {{
        "blocks": [
          {{ "type": "text", "content": "힌트" }}
        ]
      }},
      "answer_riddle": {{
        "blocks": [
          {{ "type": "text", "content": "정답 풀이" }}
        ]
      }},
      "enter_huddle": 0~10,
      "branches": [
        {{
          "flow": {{
            "blocks": [
              {{ "type": "text", "content": "조건별 흐름" }}
            ]
          }},
          "hint_riddle": {{
            "blocks": [
              {{ "type": "text", "content": "힌트" }}
            ]
          }},
          "answer_riddle": {{
            "blocks": [
              {{ "type": "text", "content": "풀이" }}
            ]
          }},
          "enter_huddle": 0~10,
          "branches": []
        }}
      ]
    }}
  ]
}}

JSON 포맷을 그대로 지키고 코드블록 없이 출력해.
"""

    if reference_block:
        prompt += f"\n{reference_block}\n"

    return textwrap.dedent(prompt).strip()

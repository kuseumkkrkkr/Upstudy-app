# 문제 생성 단건 시도 리포트

## 측정 개요

- 측정 시각: 2026-07-06 23:48:36 +09:00
- 측정 서버: `http://127.0.0.1:8012`
- 실제 운영 중인 `8000` 서버는 건드리지 않음
- 주기 seed validator: OFF
- runtime backfill: ON, 성공 후 seed 4개 비동기 추가
- process pool warmup: ON
- cached seed fast path: ON, 최대 500 ms 대기
- 더미 quest 및 테스트 seed/log는 측정 후 원복 완료
- 태그: `#기울기`

## 요청

```json
{
  "hash_tags": ["기울기"],
  "solves_count": 3,
  "strategy_level": 1,
  "branch_conditions": 0,
  "strict_tags": true,
  "request_id": "codex_fastpath_slope_20260706234836336"
}
```

## 응답 시간

| 항목 | 값 |
|---|---:|
| `POST /quests/generate` 응답 완료 | 264.80 ms |
| POST 응답 내 quest 포함 | true |
| 상태 polling | 0회 |
| 관측 end-to-end | 264.80 ms |
| 최종 상태 | `done` |

생성 결과:

| 항목 | 값 |
|---|---|
| quest_id | `002/260706/234836524491` |
| codebase_id | `40` |
| seed | `958574447` |

정리 결과:

| 항목 | 값 |
|---|---:|
| quest_header 잔여 | 0 |
| 테스트 seed log 잔여 | 0 |
| 테스트 신규 seed cache 잔여 | 0 |

## Backfill 로그

요청에 사용된 cached seed 1개가 통과한 뒤, 같은 codebase에서 valid seed 4개가 비동기로 추가 생성되는 것을 확인했다.

| source | seed | status |
|---|---:|---|
| `runtime_cached` | 958574447 | success |
| `runtime_backfill` | 984521145 | success |
| `runtime_backfill` | 783206765 | success |
| `runtime_backfill` | 315022447 | success |
| `runtime_backfill` | 4152571 | success |

위 backfill seed 4개는 테스트 후 cache/log/stat 변경을 원복했다. 실제 운영에서는 이 seed들이 남아 다음 요청의 선택 폭이 늘어난다.

## 시도된 코드베이스

| 항목 | 값 |
|---|---|
| id | 40 |
| name | `CB-040` |
| tags | `["#기울기"]` |
| mode | `unified` |
| difficulty | 15 |
| tier | `None` |
| solves_count | 3 |
| strategy_level | 1 |
| branch_conditions | 0 |
| code_hash | `6d7ef23da3fb78189ed8940787c6b67a7da72868b76a39c7402aac60f587ac47` |
| code length | 1969 |
| cached seeds | 1 |
| created_at | `2026-05-04 11:16:16` |

DB 원문 UTF-8 확인:

| 필드 | U+FFFD 치환문자 수 |
|---|---:|
| prompt | 0 |
| code | 0 |
| tags | 0 |

### Prompt

```text
수학/과학 문제를 무한히 생성하는 단일 Python 스크립트를 작성하라.
- 입력 hash_tags: ["#기울기"]
- root_flows(solves 길이): 3
- branch_conditions: 0
- 답 변수는 정수 k ( -20 ~ 20, 0 제외 ) 한 개만 사용한다.
- random.Random(seed) 로 모든 난수를 생성해 동일 seed 시 동일 문제를 재현한다.
- k 를 기준으로 역방향으로 공식을 설계하여 quest_answer 가 항상 k 가 되도록 한다.
- 외부 라이브러리, 파일/네트워크 접근 금지. 표준 라이브러리만 사용.
- generate_problem(seed=None) 하나만 공개하고, 호출 시 아래 JSON 스키마를 그대로 반환한다.
- 모든 수식 문자열은 $...$ 로 감싼다.
- main_huddle 은 1 으로 설정한다.
- primary_hash_tag 는 hash_tags 중 대표 1개를 선택한다.
- 분기가 필요 없으면 branches 는 빈 리스트로 둔다.

반환 스키마(키/구조를 변경하지 말 것):
{
  "quest_title": "문제 본문 수식 $...$안에 ",
  "quest_answer": "정답값 $...$",
  "main_huddle": 1,
  "primary_hash_tag": "hash_tags 중 가장 대표적인 태그 1개",
  "quest_image": null,
  "solves": [
    {
      "flow": "요약 텍스트와 수식 $...$",
      "hash_tag": ["hash_tags 중 현재 solves에 가장 부합하는 1개 선택"],
      "hint_riddle": "힌트 텍스트와 수식 $...$",
      "answer_riddle": "상세 풀이 설명 텍스트와 수식 $...$",
      "enter_huddle": 0,
      "branches": [
        {
          "flow": "...",
          "hash_tag": ["hash_tags 중 선택"],
          "hint_riddle": "...",
          "answer_riddle": "...",
          "enter_huddle": 0,
          "branches": []
        }
      ]
    }
  ]
}

오직 순수 Python 코드만 반환하고 마크다운 코드펜스는 넣지 말라.
```

### Code

```python
import random

def generate_problem(seed=None):
    rng = random.Random(seed)
    
    # 1. 정답 k 설정 (-20 ~ 20, 0 제외)
    k = rng.choice([i for i in range(-20, 21) if i != 0])
    
    # 2. 역방향 설계를 통한 문제 구성
    # 점 A(x1, y1)와 점 B(x2, y2)를 설정하여 기울기가 k가 되도록 함
    x1 = rng.randint(-10, 10)
    y1 = rng.randint(-10, 10)
    
    # x의 변화량 dx 설정 (분모가 0이 되지 않도록 1~5 사이의 정수 선택)
    dx = rng.randint(1, 5)
    x2 = x1 + dx
    
    # 기울기 공식 m = (y2 - y1) / (x2 - x1) -> y2 = y1 + k * dx
    dy = k * dx
    y2 = y1 + dy
    
    # 3. JSON 스키마에 따른 결과 반환
    problem = {
        "quest_title": f"좌표평면 위에서 두 점 $A({x1}, {y1})$와 $B({x2}, {y2})$를 지나는 직선의 기울기를 구하시오.",
        "quest_answer": f"정답값 ${k}$",
        "main_huddle": 1,
        "primary_hash_tag": "#기울기",
        "quest_image": None,
        "solves": [
            {
                "flow": f"두 점 $A({x1}, {y1})$와 $B({x2}, {y2})$의 좌표 정보를 확인합니다.",
                "hash_tag": ["#기울기"],
                "hint_riddle": "기울기를 구하기 위해 각 점의 $x$좌표와 $y$좌표를 먼저 정리해 보세요.",
                "answer_riddle": f"첫 번째 점은 $A({x1}, {y1})$, 두 번째 점은 $B({x2}, {y2})$입니다.",
                "enter_huddle": 0,
                "branches": []
            },
            {
                "flow": "기울기의 정의인 $m = \\frac{y_2 - y_1}{x_2 - x_1}$ 공식을 적용합니다.",
                "hash_tag": ["#기울기"],
                "hint_riddle": "$y$의 변화량을 $x$의 변화량으로 나눈 값이 기울기입니다.",
                "answer_riddle": f"공식에 좌표를 대입하면 $\\frac{{{y2} - ({y1})}}{{{x2} - ({x1})}}$가 됩니다.",
                "enter_huddle": 0,
                "branches": []
            },
            {
                "flow": "분수식을 계산하여 정수 $k$의 값을 도출합니다.",
                "hash_tag": ["#기울기"],
                "hint_riddle": "분자와 분모를 각각 계산한 뒤 나눗셈을 완료하세요.",
                "answer_riddle": f"분자는 ${dy}$이고 분모는 ${dx}$이므로, 계산 결과 기울기 $m = \\frac{{{dy}}}{{{dx}}} = {k}$입니다.",
                "enter_huddle": 0,
                "branches": []
            }
        ]
    }
    
    return problem
```

## 추가 단축 가능성

이번 변경으로 cached seed hit 경로는 `691.85 ms`에서 `264.80 ms`로 줄었다. seed cache hit 자체는 정상이고, 성공 후 backfill도 요청 응답을 막지 않았다. 남은 병목은 주로 프로세스풀 실행과 저장/직렬화 비용이다.

1. 실제 process pool warmup
   - 적용함.
   - 서버 startup 때 dummy codebase를 process pool에 실행해 worker를 미리 띄운다.
   - 유저 요청에서 첫 spawn 비용을 맞지 않게 하는 목적이다.

2. `POST /quests/generate` fast path
   - 적용함.
   - generation task를 만들고 최대 500 ms만 `shield`로 기다린다.
   - 그 안에 끝나면 POST 응답에 `quest`를 바로 포함한다.
   - timeout이면 task는 취소하지 않고 기존처럼 `queued`를 반환한다.

3. Flutter polling 간격
   - 적용함.
   - POST에 quest가 없는 경우 처음 2초는 200 ms 간격, 이후 700 ms 간격으로 polling한다.
   - fast path가 실패한 500~2000 ms 구간에서 체감 지연을 줄인다.

4. cached seed inline 실행
   - 아직 미적용.
   - 가장 공격적인 방법은 validated cached codebase만 `run_codebase_inline()`으로 실행하는 것이다.
   - 프로세스 격리와 timeout 안전성을 줄이는 대신 프로세스풀 IPC 비용을 없앨 수 있다.
   - 대량 사용자 환경에서는 관리자 검증 완료 codebase에만 한정하는 조건이 필요하다.

현 상태에서 추가 단축은 가능하지만, inline 실행은 안전성 손상이 크다. 당장은 process 격리와 timeout을 유지한 현재 구조가 균형이 낫다.

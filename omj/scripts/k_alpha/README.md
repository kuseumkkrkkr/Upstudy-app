# K-울프럼알파 (초1~중3 범위) 모듈 사용 가이드

## 폴더 구성

- `math_knowledge_graph.json`: 학습 개념 노드(초1~중3 범위만)
- `math_rule_library.json`: 규칙 레벨 DSL 변환용 룰
- `math_template_pack.json`: 문제 템플릿/제약/정답식
- `validation_contract.json`: 채점 공용 검증 정책
- `Upstudy-app/omj/scripts` 모듈
  - `k_wolfram_alpha_dsl.py`: K-울프럼알파 DSL 객체
  - `k_wolfram_alpha_knowledge_search.py`: 지식 DB 검색 엔진
  - `k_wolfram_alpha_engine.py`: 템플릿 기반 문제 생성기
  - `k_wolfram_alpha_grader.py`: 정답 채점 엔진(채점 선행용)
  - `k_wolfram_alpha_loop.py`: 생성-채점 연속 루프
  - `k_wolfram_handwriting_guard.py`: Vercel OCR 오인식 커버 가드
  - `k_wolfram_handwriting_probability.py`: 이산확률 사전 기반 OCR 텍스트 후보 선택

## 실행 예시

```powershell
python Upstudy-app/omj/scripts/k_wolfram_alpha_loop.py
```

성공 시 `Upstudy-app/omj/scripts/k_alpha_loop_result.json`이 저장됩니다.

200문항 연속검증(100문항 x 2회 제출) 예시:
```powershell
python -c "from pathlib import Path; import sys; sys.path.append('Upstudy-app/omj/scripts'); from k_wolfram_alpha_loop import run_continuous_generation_grading; r=run_continuous_generation_grading(case_count=100, repeat_per_case=2); print(r['metadata'])"
```

## 채점 우선 테스트

`k_wolfram_alpha_loop.py`는 문제 생성 직후 `k_wolfram_alpha_grader.py`로 정답 검증을 수행한 뒤
정답·오답 케이스를 통과/실패/리뷰로 분리합니다.

## 손글씨 인식 커버(요약)

`select_formula_text`는 다중 OCR 후보(예: Vercel/Texteller)의 정규화 문자열을 결합하고,
`build_retry_plan`은 신뢰도 및 후보 일치도가 낮은 경우 재시도/수동검토 플로우를 반환합니다.

`k_wolfram_handwriting_probability.resolve_with_discrete_prior`는 문자 수준 이산확률 가중치로 후보 문자열을 재점수화해 Vercel 오인식에 대한 보수적 자동결정 규칙을 제공합니다.

## 전용 DSL 스펙

- `k_alpha/k_alpha_dsl_schema.json`  
  - `school_grade_code`와 step/rule 구조를 고정해 초1~중3 범위 생성·채점 데이터가 단일 형식으로 교환되게 구성
- `k_wolfram_alpha_dsl.py`는 위 스펙의 객체화/직렬화를 담당

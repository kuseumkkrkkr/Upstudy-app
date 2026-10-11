# 채점·레벨테스트 재검증 메모 (2026-10-11)

기준 checkout: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`
기준 브랜치/HEAD: `hotfix` / `118fc612a3592fb33f0b310b1ea5c8dc54a8efb6`

## 채점 경로 — 코드 기준 통과, Canary 쓰기 검증은 보류

- `POST /analysis/solve/variant-grade`는 서버 측 문제 원본으로 채점하고 사용자·문제·판정 자료에 바인딩된 `grade_receipt_v2`를 발급한다.
- `POST /rating/submit`은 같은 사용자에 유효한 서명 영수증이 있어야 레이팅을 반영한다. 판정 결과를 클라이언트가 임의로 바꾸거나, 사용자·문제·답안이 달라지면 거부하는 계약이 구현되어 있다.
- Canary 프록시도 variant-grade 경로에서 정식 서버로 위임하며, rating 요청에서 해당 영수증을 전달하도록 되어 있다.
- 확인 검사: `tests/test_vercel_grading_receipts.py` + `tests/test_vercel_level_test_v2.py` **10 passed**; `omj/tests/test_grade_receipt_contract.py` **14 passed**.
- 이 turn에서는 Canary에 제출·레이팅 쓰기를 보내지 않았다. 실제 계정 데이터 반영과 앱 화면에서의 end-to-end 경로는 아직 검증하지 않았다.

## AI 역할 분리·관대한 채점

- 필기 인식은 TexTeller OCR 경로(필기 획에서 수식 추출)가 맡는다. 인식 실패 시 Qwen은 OCR 전사 보조로만 사용한다.
- 채팅·자유 텍스트 채점은 Kiln을 사용한다. 채점 요청에는 필기 이미지를 넘기지 않고 OCR 수식 텍스트와 풀이 맥락만 전달한다.
- 채점 프롬프트는 동치 표기, 문맥상 OCR 오인식, 타당한 부분 풀이, 오류 전파를 학생에게 유리하게 처리하고 명백한 개념 오류만 오답 처리하도록 되어 있다.
- 확인 검사: `omj/tests/test_analysis_service_prompt.py` + `tests/test_kiln_tutor.py` **6 passed**.
- 단, OCR 인식 이미지 자체를 이용한 이번 turn의 실제 추론은 수행하지 않았다. 이전의 Kiln 실추론은 synthetic OCR 텍스트 입력 검증이지 이미지 인식 검증이 아니다.

## 레벨테스트 — 문항 풀 확인과 레벨 배정은 별개

- 재확인: 제공 원본과 hotfix 사본 SHA-256이 모두 `90F5CC3C811D43857DE3821E47242141B6DCA7DE17C137217315AA25CBDE6E3`이다. 두 SQLite 파일 모두 읽기 전용 `integrity_check=ok`, 776개 문항이다. DB에는 `question(quest_title, quest_answer, solves_json)`만 있고 difficulty/tag 메타데이터는 없다.
- seed 회귀를 보강해 SQL migration의 문항 수, 고유 ID, 연속 순번 `1..776`을 원본 문항 수와 대조한다. 원본의 모든 문항·답안 존재 및 풀이 JSON 형식도 검사하며, seed/V2 테스트 **6 passed**.
- 기존 확인 기록상 Canary 통계도 776개 / 트랙 9개다. 이는 live Supabase의 전체 title/answer/solves 및 metadata가 SQLite·SQL seed와 행별로 일치한다는 증명은 아니다.
- V2 제출 경로는 응답 수·정답률·태그·트랙을 계산하지만 `placement` 또는 `rating` 값을 반환하거나 갱신하지 않는다. 테스트도 이를 명시적으로 확인한다.
- 따라서 현재 승인된 코드·데이터만으로 실제 배정 등급 결과를 검증할 수 없다. 점수→등급 경계와 레이팅 갱신 정책이 연결되지 않았으므로, 임의 점수 경계나 등급을 만들어 결과를 주장하지 않는다.
- 다음 필요한 근거: 승인된 배정 정책(점수/응답 패턴에서 등급·레벨로 가는 결정 규칙) 또는 해당 정책을 구현한 정식 서비스 계약. 운영 DB에는 쓰기 요청을 보내지 않았다.

## 모바일 시험·Computer Use

- 모바일 확대/페이지 맞춤 및 문항 이동·재검토 UI의 자동 검사와 조사 문서는 존재한다. 이는 로컬 위젯/골든 검사이지 실제 Canary 브라우저에서의 통과 근거가 아니다.
- 현재 in-app browser의 Canary 탭은 Computer Use에서 `AXWebArea`와 `Enable accessibility`만 노출했다. 문서화된 조작·캡처 기능을 확인할 수 없어 로그인 후 문제 풀이, 즉시/일괄 채점, 결과 화면을 실제 조작 검증하지 않았다.
- 따라서 자동 검사 결과와 배포본 사용자 여정 검증을 혼동하지 않는다.

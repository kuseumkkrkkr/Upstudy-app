# 채점 경로·레벨테스트 현재 확인 (2026-10-11)

## 범위와 기준

- D: `Upstudy-hotfix`, `hotfix` 브랜치에서 읽기 전용 소스·DB 확인 및 집중 자동 검사를 수행했다.
- 작업 시작 가드 통과: HEAD `d0c6e8ca229734c1c7cc6e5d398e6c9021f48798`.
- 실제 Canary에 응시 제출·채점 제출·레이팅 쓰기 요청은 보내지 않았다.

## 확인 결과

| 항목 | 관찰 | 판정 |
|---|---|---|
| 문제별 즉시 채점 | 설정 기본값·저장/재로딩 및 객관식 즉시 결과·Flow 분석 테스트 통과 | 로컬 자동검사 통과, 실제 브라우저 미검증 |
| 전체 풀이 후 일괄 채점 | 설정, 확인 후 서버 채점, 전용 `BatchGradingReportPage` 결과 테스트 통과 | 로컬 자동검사 통과, 실제 브라우저 미검증 |
| 모바일 시험 풀이 | 확대/페이지 맞춤 테스트 통과. 문항별 재검토·미응답 점프는 조사 문서 기준 미구현 상태 | 부분 개선, 남은 UX 격차 있음 |
| 제공 레벨테스트 DB | 원본과 hotfix DB가 모두 4,411,392 bytes, SHA-256 `90F5CC3C811D43857DE3821E47242141B6DCA7DE17C137217315AA25CBDE6EE3` | 동일 파일 확인 |
| hotfix DB 무결성 | `PRAGMA integrity_check` = `ok`; `question` 행 = 776 | 로컬 DB 검사 통과 |
| Canary 문항 통계 | `GET /level-tests/placement/stats` HTTP 200; `pool_count=776`, 트랙 9개, 일반 25문항, 빠른 검사 10문항 | 현 배포에서 문항 풀 수 확인. 전체 항목 동일성·응시 결과는 미확인 |
| 실제 브라우저 | Computer Use tab에서 Canary URL `/#/level_test` 확인. 화면 접근성 트리는 `Enable accessibility` 버튼만 노출 | 로그인·문항 풀이·채점 UI 검증 불가 |

## 확인된 서버 권위 간극

- `POST /analysis/solve/variant-grade`는 서버 문제 원본으로 답과 풀이 순서를 계산한다.
- 별도 `POST /rating/submit`은 `RatingSubmitRequest.is_correct`와 `step_correctness`를 받아 그대로 `apply_rating_update`에 전달한다.
- 두 요청 사이에 서버 grade receipt 검증 또는 하나의 서버 권위 트랜잭션이 보이지 않는다. 따라서 grade endpoint의 정답 판정 테스트만으로 레이팅이 변조 불가능하다고 결론내릴 수 없다.
- 데이터 경계도 다르다. Canary의 variant grader는 `api/index.py`의 결정적 marketplace/UI fixture 질문 원장을 사용하고, 평점 전달은 별도 Lightning OMJ 서버로 프록시한다. OMJ의 grader와 rating endpoint는 `get_quest` 및 OMJ 저장소를 사용한다. 두 원장이 같은 `quest_id`의 정답·Flow를 갖는다는 증거는 없다.
- Vercel proxy는 브라우저 `Authorization`, `Content-Type`, `X-Idempotency-Key`만 전달하며 서버 판정 영수증은 만들지 않는다. Flutter의 두 rating 호출자(간편 풀이·시험지)는 현재 원답/선택값이 아니라 정오답 boolean과 단계 결과만 제출한다.
- 다음 수정 전제: canary marketplace 문제의 정식 저장소와 OMJ의 동일 문제 ID·정답·Flow 일치 여부를 테스트 계정/fixture로 검증한다. 이후 공통 서버 권위 grader/receipt 계약과 멱등한 rating 반영을 함께 적용하고, 임의 정오답·단계 결과 제출 거부 테스트를 둔다. 확인 전 DB 마이그레이션이나 라이브 데이터 변경은 하지 않는다.

## 검사 결과

- Flutter 집중 검사: 16 passed (`grading_mode_settings`, `mobile_quick_batch_mode`, `variant_grade_response_contract`, `objective_grade_flow`, `mobile_quick_batch_submission`, `batch_grading_report_page`, `exam_paper_mobile_focus`, `placement_exam_flow`).
- OMJ 서버 테스트: 10 passed (`test_variant_grade_contract`, `test_rating_service_contract`, `test_rating_access`).
- Canary 프록시·레벨테스트 시드 테스트: 6 passed (`test_rating_tags_proxy`, `test_level_test_seed_integrity`).
- 배포·alias 변경 없음. Computer Use 실제 제출 및 배치 결과 확인 없음.

## 추가 범위 확인

- `tests/test_vercel_level_test_v2.py`도 2 passed. 다만 이 통합 테스트의 776문항은 인메모리로 만든 `n + 1` 샘플이며, 승인 SQLite의 776개 실제 문항을 시작·제출하지 않는다. 이 테스트는 세션·중복 제출·10/25문항 계약을 검증하는 것이지 실제 문항 성취도의 증거는 아니다.
- OMJ placement store/API 테스트 5건은 현재 로컬 환경에서 실패했다. `test_level_test_analysis_api.py`는 이미 없는 `academy_repo.DB_PATH`를 참조하는 오래된 테스트이고, 나머지는 PostgreSQL 연결 풀이 10초 후 `PoolTimeout`을 냈다. 테스트용 PostgreSQL 연결이 설정되지 않은 상태로 보이며 운영 DB에 연결을 시도하거나 URL을 출력하지 않았다.
- Computer Use에서 `Enter`로 Flutter 접근성을 켠 뒤 실제 Canary 기존 결과 화면을 읽었다. 표시값은 `22/25`, `88%`, `60분 00초`, 채점 완료이며, “배정 기준이 연결되지 않아 배정은 보류됩니다”라고 안내한다. 이 결과는 이번 작업에서 제출한 것이 아니며 저장 데이터를 변경하지 않았다.
- 기존 `문항별 결과 보기` 조작 뒤 접근성 트리가 학생 홈으로 바뀌어 상세 화면 도달을 확인하지 못했다. 이 버튼의 목적지도 실제 화면 검증 미통과로 남긴다.
- 새 V2 API 결과는 정답 수·정답률·난이도·태그 분석만 저장하며 배정 등급/Levelity 전이를 갱신하지 않는다. 2026-10-10 보정 실험은 임의 배정 비율을 사용해 제품 경계를 승인하지 않았으므로, 22/25에서 어떤 등급도 추정·표시하지 않는다.

## 2026-10-11 후속 수정·재검수

- 결과 화면의 `문항별 결과 보기`는 상세 데이터를 열지 않고 `Navigator.pop()`만 실행했다. 제출 흐름이 `pushReplacement`인 실제 코드와도 맞지 않는 목적지였다. 로컬 hotfix에서 이를 `학생 홈으로`로 명확히 바꾸고 홈 route로 직접 이동하게 수정했다.
- `test/level_test_result_page_test.dart`: 7 passed. 새 검사는 결과 화면의 두 번째 홈 액션이 실제 학생 홈으로 이동하는지 확인한다.
- 이 변경은 로컬 소스만 수정했으며 Vercel에 배포하지 않았다. Canary의 실제 UI는 아직 이전 배포 상태다.
- 채점 경로 재확인: Canary `api/index.py /analysis/solve/variant-grade`는 marketplace fixture 원장을 직접 채점하고, `/rating/submit`은 별도 OMJ로 프록시한다. OMJ `/rating/submit`은 `is_correct`와 `step_correctness`를 클라이언트 요청에서 그대로 받아 rating ledger에 넘긴다. 이 두 경로 사이에 서명된 grade receipt나 서버 측 동일 문제 원장 확인은 없다.
- 따라서 자동 테스트의 정답 판정은 채점 함수만 검증하며, rating ledger가 같은 정답 판정을 반영한다고 입증하지 않는다. 데이터 원장 일치·클라이언트 위조 거부·한 번의 서버 권위 반영은 여전히 미검증이며, 현재 상태를 안전한 실제 채점→레이팅 경로라고 판정하지 않는다.

## 2026-10-11 실제 Canary 응시 후속 확인

- 사용자가 테스트 계정으로 실제 응시를 허용한 상태에서 Computer Use로 `/#/level_test`를 진행하고 마지막 문항까지 제출했다.
- Canary 결과 화면: 25/25 정답(100%), 풀이 시간 32분 12초, 분석 상태 `채점 완료`.
- 결과에 강점/보완 태그 진단은 표시되지만 “점수에 따른 코스 배정 기준이 연결되지 않아 배정은 보류됩니다”라는 안내가 그대로 표시된다. 따라서 실제 점수 채점은 확인했으나 레벨 배치 결과는 생성되지 않았다.
- 이 Canary UI는 아직 배포 전 로컬 Flutter 수정과 다른 이전 번들이다. 현재 작업 트리는 다수의 기존 변경으로 dirty 상태이며, 이번 응시 후 배포하지 않았다.
- Vercel의 `aiflow-ocr-canary` Production 환경변수 이름 `LIGHTNING_WAKE_URL` 존재를 확인했다. 값은 Secret으로 저장되어 편집 화면에서도 읽을 수 없고 Copy to Clipboard도 비활성 상태였다. 값은 확인·복사·공유하지 않았으며, `aiflow-web-canary`에 추측 URL을 입력하지 않았다. URL만 연결하는 작업은 이 값의 소유자가 다시 입력하거나 비밀이 아닌 구성 변수로 재등록해야 계속할 수 있다.

## 현재 소스 회귀검사 및 배포 설정 확인

- 현 hotfix 소스의 Flutter 집중 회귀검사: 19 passed (`grading_mode_settings`, `mobile_quick_batch_mode`, `mobile_quick_batch_submission`, `batch_grading_report_page`, `quick_submission_race`, `variant_grade_response_contract`, `placement_exam_flow`).
- Vercel/레벨테스트 프록시 Python 집중검사: 16 passed (`test_vercel_grading_receipts`, `test_vercel_level_test_v2`, `test_level_test_seed_integrity`, `test_rating_tags_proxy`).
- Computer Use로 배포된 학생 설정 화면에서 `문제별 즉시 채점` 토글이 기본 켜짐인 것을 확인했다. 이는 기존 Canary 번들에 해당 설정이 이미 있음을 증명하지만, Flutter 로컬 수정과 배포 번들이 동일하다는 증거는 아니다.
- 설정 확인 시각 기준 `aiflow-web-canary` Production 변수 목록에는 `LIGHTNING_WAKE_URL`이 없었고 `aiflow-ocr-canary`에는 같은 이름이 Secret으로 존재했다. 원본 값은 읽거나 전송할 수 없으므로 URL 연결은 대기 상태다.
- `POST /rating/submit`은 Vercel에서 인증한 뒤 Lightning의 canonical rating endpoint로 본문을 전달한다. 브라우저 사용자의 실제 rating mutation은 이번 레벨테스트 응시에서 발생하지 않았으며, 라이브 grade receipt 검증·rating ledger 반영은 별도로 확인되지 않았다. 로컬 Vercel 수신증명 테스트 통과만으로 이를 완료 처리하지 않는다.

## 별도 후보 빌드 검증

- `hotfix` HEAD `af9b7956cbab1528055e7b44bae47081d25447d8`에서 Flutter Web release 빌드가 성공했다. 출력은 `D:\AIFlowBuildTemp\upstudy-hotfix-candidate-20261011-01`이며 기존 `public` 산출물은 덮지 않았다.
- 후보 `main.dart.js` SHA-256: `FC04A51E65406020B9674E19BDCC19AF207A1885F7ADF24C630CBDB1D4603CF7`.
- Computer Use로 후보에서 레벨테스트 시작 화면과 설정 화면을 열어 화면 렌더링을 확인했다. 설정에서 `문제별 즉시 채점`은 기본 켜짐으로 보였다. 제출 API는 호출하지 않았다.
- 빌드 로그에는 CupertinoIcons font asset 누락 경고가 있었으나 빌드 결과는 성공했다. 렌더 화면에서 핵심 내비게이션과 설정은 표시됐다. 아이콘 회귀 영향은 전체 화면 검수 전까지 미확인이다.
- 현재 worktree는 다수의 미커밋 변경을 포함하고 기존 `public/main.dart.js`도 변경 상태다. 따라서 이 후보는 dirty source 빌드이며, 정식 배포에는 사용하지 않았고 canary alias도 바꾸지 않았다.
- Vercel 공유 변수 검색에서 `LIGHTNING_WAKE_URL` 공유 항목은 없었다. OCR 프로젝트 Secret 값이 읽기 불가하여 URL 연결은 미완료다.

## 2026-10-11 후속 소스·DB 대조

- 사용자 제공 `Math-textbook/07 Data/레벨테스트/leveltest_final_expanded.db`를 read-only로 열어 확인했다. SQLite `question` 테이블은 776행이며 `quest_title`, `quest_answer`, `solves_json`이 모두 비어 있지 않다. 원본 파일은 수정하지 않았다.
- 현재 Canary 확장 DB loader는 Supabase `level_test_question_bank`에서 `difficulty_tier`, `tags`, `solves`를 읽는다. 제출 라우트는 결과/태그 분석을 계산하고 `level_test.v2` 사용자 저장소 키에 저장하지만 `apply_level_test_placement`나 rating API를 호출하지 않는다.
- 제품 OMJ `/level-tests/placement/{session_id}/submit`은 별도 PostgreSQL placement 세션/문항 저장소를 사용하며 `apply_level_test_placement`를 호출한다. 이 계약은 Vercel 확장 문항 세션과 공유되지 않으므로 현재 Canary 레벨테스트 완료가 사용자 레이팅 또는 Levelity를 갱신한다는 증거가 없다.
- 제공 SQLite에는 `difficulty_tier`가 없다. 별도 확장-bank SQL/행에는 1–5 tier가 있지만 기존 연속 `placement_rating` 보정값이 없다는 기존 민감도 조사와 일치한다. 임의 환산표를 추가하지 않으며 실제 등급 배정은 미검증으로 유지한다.
- 확인 근거: `api/index.py`의 `_load_level_test_question_bank`(1187행), `/level-tests/placement/{session_id}/submit`(1489행), OMJ `rating_service.apply_level_test_placement`(446행), `omj/app/api/routes/level_test/router.py`(470행). 배포·DB 쓰기 없음.
- 2026-10-11 현 소스 재검사: Python receipt/proxy/V2/OMJ rating 계약 38 passed(7 deprecation warnings, 2 subtests); Flutter 채점 설정·일괄 제출·race·Flow·레벨테스트·모바일 시험지 19 passed.
- Computer Use: 배포 Canary 설정에서 `문제별 즉시 채점`이 켜짐으로 표시됨. 홈에서 문제 세트와 시험지 시트를 열었으나 둘 다 보유 자료실로 안내되어, 실제 Canary 계정에서 채점할 문항/시험지는 찾지 못했다. 이 브라우저 확인은 레이팅 저장 여부를 증명하지 않는다.
- 실제 배포 DB 읽기 전용 GET `https://aiflow-web-canary.vercel.app/level-tests/placement/stats`: HTTP 200, `pool_count=776`, 본시험 25문항, 빠른검사 10문항, 9개 트랙, 4개 난이도 구간. 제공된 SQLite 행 수와 일치한다.
- 별도 Flutter 후보 빌드(`FC04A51E…`)를 로컬에서 렌더링해 설정 및 인증이 필요한 시험지 진입 상태를 캡처했다. 후보는 dirty hotfix 소스 기반이며 Canary 배포·실제 채점에 사용하지 않았다. 후보 미리보기 서버와 탭은 종료했다.

## 2026-10-12 모바일 화면 후속 검증

- 모바일 시험지의 최초 표시가 A4 전체 맞춤이라 문항 글자가 지나치게 작아지는 문제를 수정했다. 뷰포트가 600px 이하인 세로 화면에서는 첫 문항을 읽기 배율로 중앙에 보여주고, `page-fit` 도구로 전체 페이지 보기로 전환할 수 있게 했다. 첫 클릭의 다음 문항 포커스 동작은 보존했다.
- `exam_paper_mobile_focus_test.dart`에서 기본 문항 포커스, 전체 페이지 맞춤, 다음 문항 포커스의 390×844 캡처를 갱신하고 테스트 통과를 확인했다. 세 화면 모두 로컬 Flutter golden이며 배포 화면 캡처는 아니다.
- 변경 화면 `exam_paper_page.dart` 및 회귀 테스트 `exam_paper_mobile_focus_test.dart`의 `flutter analyze` 결과: 오류 없음. 채점/레이팅·레벨테스트·모바일 시험지 집중 Flutter 테스트 19건 통과.
- Flutter Web release 후보-02 빌드 성공, 산출물 `D:\AIFlowBuildTemp\upstudy-hotfix-candidate-20261011-02\main.dart.js`, SHA-256 `AB7E6F38F1347F4B763964CA1197EFCFCA678F27BA801DB1EDB0D110CC5BDCF1`. 로컬 HTTP 서버 `127.0.0.1:8890`에서 Computer Use로 실제 설정 화면이 렌더링되는 것을 확인했다. 제출·레이팅 쓰기는 수행하지 않았다.
- 현재 checkout은 `hotfix` 브랜치에서 origin 대비 13커밋 앞서며 1,194개 경로가 미커밋/미추적 상태다. `public/main.dart.js`도 기존 변경 상태여서 후보-02를 배포하거나 `public`을 갱신하지 않았다. 따라서 Canary alias·사용자가 보는 앱은 이번 변경으로 바뀌지 않았다.

## 2026-10-12 채점 연결 설정 재확인

- `vercel env ls production`으로 `aiflow-web-canary`의 변수 이름과 대상만 확인했다(값은 출력하지 않음). Production에 `KILN_API_KEY`, `OMJ_JWT_SECRET`, Supabase 변수 등은 있으나 `LIGHTNING_WAKE_URL`, `OCR_QUEUE_BASE_URL`, `STUDENT_UI_TEST_CONTENT`는 없다.
- Canary의 `/analysis/solve/variant-grade`와 `/analysis/solve`는 현재 `proxy_lightning_app`으로 요청을 전달한다. `LIGHTNING_WAKE_URL`이 비어 있으면 프록시가 503으로 중단되므로, Canary에서 채점·필기 분석을 실제 실행할 수 있는 배포 설정이 확인되지 않았다. `KILN_API_KEY`가 Vercel Production에 등록됐다는 사실만으로 Lightning/OMJ 실행 환경에도 키가 전달됐다고 볼 수 없다.
- 모델 책임은 분리돼 있다. `variant-grade`는 canonical question의 정답·풀이 순서를 서버 코드로 비교하는 결정적 로직이고, 필기 분석 경로는 Lightning의 손글씨 인식 뒤 Kiln의 텍스트 채점 provider를 선택한다. 다만 Lightning-hosted API에 도달할 연결 URL이 없어 런타임 호출은 확인되지 않았다.
- 레벨테스트 V2 최종 제출은 776문항 중 세션 문항의 정오답·태그별 정확도를 계산하고 사용자별 `level_test.v2` 결과를 원자적으로 저장하지만, 현재 결과에는 배정 등급/레이팅 호출이 없다. 신규 DB에 검증 가능한 연속 `placement_rating`이 없으므로 기존 OMJ 배치 추정기에 tier 숫자를 임의 대입하지 않았다.
- 2026-10-12 재검증: Vercel 프록시·V2·태그 테스트 5건 통과, OMJ 수신증명·레이팅·variant-grade 테스트 7건 통과, Flutter 채점/일괄/레이스/레벨테스트/모바일 시험 집중 테스트 19건 통과. 첫 합동 unittest 호출은 OMJ 테스트의 모듈 루트가 달라 import 오류가 있었으며, 올바른 `omj` 작업 디렉터리에서 다시 실행해 7건 모두 통과했다.
- 실제 사용자용 Canary 배포·채점은 계속 미검증이다. 다음 검증에 필요한 연결 URL은 Vercel Secret의 숨김값에서 읽을 수 없다. 이를 복사하거나 재구성하지 않았고 비밀값을 로그에 남기지 않았다.
- 2026-10-12 Vercel alias 재확인: `https://aiflow-web-canary.vercel.app`은 Production `READY` 배포 `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS` (`aiflow-web-canary-46rpnu2uo-cw20208021-9200s-projects.vercel.app`)를 가리킨다. 생성 시각은 2026-10-11 18:53 KST이며 CLI 응답에는 Git commit SHA가 포함되지 않았다.
- 이 alias에서 `/health`는 HTTP 200(`aiflow-ocr-queue`), `/level-tests/placement/stats`는 776문항·25문항 본시험·10문항 빠른 검사·9개 트랙을 반환했다. Computer Use로 실제 Canary의 `/#/settings`를 캡처했으며 `문제별 즉시 채점` 토글이 켜져 표시된다. 이 UI·health 응답은 실제 풀이 채점·레이팅 반영을 증명하지 않는다.
- 배포 `main.dart.js`를 내려받아 SHA-256을 비교했다. Canary와 로컬 `public/main.dart.js`는 모두 `BC03458BB806B11561A2857EC7CAB0A75C0BBDBC2BA5574F45674E3A54D89931`로 동일하며, 이번 Flutter 후보-02는 `AB7E6F38F1347F4B763964CA1197EFCFCA678F27BA801DB1EDB0D110CC5BDCF1`로 다르다. 현재 Canary에는 모바일 확대 수정 후보가 배포되지 않았다. 보존한 공개 번들 스냅샷은 `D:\AIFlowBuildTemp\canary-dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS-main.dart.js`이다.
- 모바일 시험 UX 비교 근거: College Board의 공식 [Bluebook 테스트 도구](https://blog.collegeboard.org/whats-bluebook)와 [앱 기능 소개](https://bluebook.collegeboard.org/test-admin/new-updated-features)는 질문 탐색 메뉴, 다시 볼 문항 표시, 타이머, 질문 확대/이동 및 화면 내 도구를 제공한다. Bluebook은 휴대전화용 레이아웃 기준이 아닌 디지털 시험의 상호작용 참고로만 사용했다.
- 현 시험지 Flutter에는 문항 목록/상태, 다시 보기 flag, 남은 시간 숨김, 문항 확대·페이지 맞춤이 이미 구현돼 있다(`exam_paper_state_ui.dart`). 추가 변경은 첫 진입을 문항 확대 상태로 설정하고 전체 맞춤 선택을 유지하는 데 한정했다. `exam_paper_mobile_focus_test.dart`는 390×844에서 타이머 토글·두 문항 목록·다시 보기 수·문항 선택 후 확대를 검증한다.

# 학생 채점·시험·레벨테스트 진행 기록 (2026-10-11)

## 이번 회차 변경

- 대상 저장소: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`, `hotfix` 브랜치.
- 레벨테스트 라우터와 레이팅 서비스의 문항 수가 달랐다. 라우터는 25개 답안을 요구하지만 `apply_level_test_placement`가 50개를 요구해 정상 제출도 실패하는 계약 충돌을 확인했다.
- 레이팅 함수는 정확히 25개 답안일 때 추정치를 적용하도록 바꿨다. 24개·26개는 거절한다. 추정기 보정 표본은 50개 기준이므로 25개 입력의 confidence는 0.5로 유지한다. 점수 확실성을 1.0으로 부풀리지 않는다.
- 모바일 시험 화면은 기존 별도 타이머와 우측 도구막대가 겹쳐 실제 390×844 캡처에서 `60:00`이 가려졌다. 타이머 텍스트를 도구막대 안으로 옮기고, 표시/숨김 버튼을 추가했다. 문항 확대·페이지 맞춤은 더보기 메뉴로 이동했다. 숨김 상태에서도 카운트다운은 계속된다.

## 함수·변수 설명

| 항목 | 역할 | 입력/상태 | 실패·복귀 |
|---|---|---|---|
| `apply_level_test_placement` | 완료된 25문항으로 초기 레이팅·태그 추정치를 계산하고 원자적으로 저장 | `user_id`, `session_id`, 서버 채점된 `answers` | 답안 수가 25가 아니거나 쓸 수 있는 표본이 없으면 예외; 기존 멱등 제출 키 유지 |
| `_timerVisible` | 모바일 상단 도구막대에서 남은 시간 문자열을 표시할지 결정 | 화면 메모리의 `bool`, 기본 `true` | 숨겨도 시험 타이머 상태는 변경하지 않으며 화면을 벗어나면 폐기 |
| `PopupMenuButton<_CompactExamViewAction>` | 좁은 화면에서 `문항 확대`, `페이지 맞춤` 선택 | `focusQuestion` 또는 `fitPage` | 두 동작은 기존 구현에 위임 |

## 검증 증거

- `test_rating_service_contract.py`: 7개 통과. 25개 허용, 24/26개 거절, 기존 멱등·태그 계약 확인.
- Flutter 집중 테스트: 9개 통과 (`exam_paper_mobile_focus`, grading mode, objective grade, mobile quick batch, batch report).
- 실제 Canary Computer Use 레벨테스트: 25/25 정답, 12분 56초로 서버 채점 완료. 결과 화면은 정답률·태그를 표시했지만 레벨 배정은 “기준이 연결되지 않아 보류”라고 명시했다. 이를 배정 성공으로 간주하지 않는다.
- 원본 `leveltest_final_expanded.db`와 저장소 사본은 같은 SHA-256 `90F5CC3C811D43857DE3821E47242141B6DCA7DE17C137217315AA25CBDE6EE3`. 사본은 SQLite `integrity_check=ok`, 776문항, 제목·답 비어 있음 및 잘못된 JSON 0건.
- Canary `/level-tests/placement/stats` 읽기 응답: 문항 풀 776, 본 시험 25문항, 빠른 검사 10문항. 이것은 배포 Supabase 데이터의 건수 증거이며 원본 DB와 배포 행의 전체 내용 해시 비교는 아니다.
- 모바일 캡처(Flutter 390×844):
  - 문제 재현 전: `test/goldens/exam-paper-mobile-timer-before-390x844.png`
  - 수정 후 타이머 표시: `test/goldens/exam-paper-mobile-timer-after-390x844.png`
  - 수정 후 문항 확대: `test/goldens/exam-paper-mobile-focus-after-timer-390x844.png`

## 조사 근거와 반영 범위

- College Board Bluebook은 시험 타이머를 숨길 수 있고, 모듈 안에서 문항 이동 및 답안 검토를 제공한다. [타이머 동작](https://bluebook.collegeboard.org/help-center/how-do-breaks-and-timing-work-bluebook), [문항 이동·검토](https://bluebook.collegeboard.org/students/sat-school-day)
- Khan Academy 설명은 풀이 중 단계별 힌트와 제출 후 rationale를 구분한다. [연습 피드백 방식](https://blog.khanacademy.org/how-should-people-practice-on-khan-academy/)
- 이번 이식은 숨길 수 있는 타이머와 저빈도 보기 도구의 메뉴화를 반영했다. 기존 문항 목록·다시 볼 표시·정답 즉시 피드백/Flow 결과 동작은 유지했다.

## 미완료 및 주의

- 라이브 Canary V2 레벨테스트는 서버 채점 후 결과를 `canary_user_kv`에 저장하지만 현재 레이팅/레벨리티를 갱신하지 않는다. 실제 배정 기준과 정답을 포함한 새 배정 계약을 연결하기 전에는 숫자 컷을 임의로 만들지 않는다.
- Canary 코드에서는 `/analysis/solve/variant-grade`와 `/analysis/solve`를 Lightning canonical 서비스로 전달하도록 변경했다. Lightning은 채점 증명 v2에 전체 canonical `quest_json` SHA-256을 넣고, `/rating/submit` 및 batch 반영 때 같은 PostgreSQL 문항 digest를 재검증한다. 다른 내용·태그·정답인 경우에는 거부한다. 이 코드는 아직 배포되지 않았고, live PostgreSQL 반영 경로는 미검증이므로 안전 완료 판정은 보류한다.
- 비동기 OCR 결과는 Vercel이 서명하기 전 요청에 포함된 `quest_json`과 `quest_id`가 일치하는지 검사한다. 영수증 v2에 그 문항 해시를 넣고 Lightning이 DB 원본 해시와 비교한다. 문항 원본이 없거나 다르면 레이팅만 거부되고 풀이 채점 결과는 유지되도록 설계했다. 실제 OCR worker의 payload가 canonical JSON과 동일한지는 통합 환경에서 확인해야 한다.
- PostgreSQL 라우트 단위 계약은 임시 테스트 의존성으로 수집·실행 가능했으며, 현재는 실제 DB 쓰기 없이 합성 canonical 문항으로만 영수증·레이팅 계약을 검증했다. 별도 테스트 DB에서의 실저장·멱등성 검증은 미완료다.
- 모바일 변경은 로컬 Flutter 위젯 테스트/캡처까지만 검증했다. 이번 변경은 Canary에 배포하지 않았고, HTML 원문과의 추가 브라우저 캡처 비교도 미완료다.

## 재개 검증 (2026-10-11)

- D: `hotfix` 가드레일을 재확인했다. 현재 기준은 `d0c6e8ca229734c1c7cc6e5d398e6c9021f48798`이며, 기존 미커밋 작업은 그대로 보존했다.
- Flutter 집중 회귀 테스트 15개 통과: 즉시/일괄 채점, 전용 결과 화면, Flow, 모바일 시험 문항 이동·타이머, 레벨테스트 이동·제출.
- Python 집중 테스트 19개 및 2개 하위검증 통과: 영수증 계약, 레이팅 서비스, Vercel 채점 영수증, V2 레벨테스트, 정적 DB seed 무결성. 임시 실행 의존성만 사용했고 저장소 의존성 파일은 바꾸지 않았다.
- Canary `/health/level-test`는 `ok`였지만 확인 항목은 이전 `level_test_template` 계열 스키마이며 `expanded-v1` Supabase 문항은행의 준비 상태 증거는 아니다. `/level-tests/placement/stats`는 인증 토큰 없이 조회할 수 없었고 `Bearer token required`로 거절됐다.
- 로그인된 Canary UI에서 중학교 1학년 A형을 선택하면 25문항·60분 진단이 열리고 실제 문항이 표시됐다. 첫 문항은 제공된 확장 DB의 동형 문항(정답 키 60)과 대조됐다. 이는 단일 문항 확인이며, 배포된 776개 전체 행의 내용 동등성 검증은 아니다.
- 새 브라우저 세션은 시작 후 답안을 입력하거나 제출하지 않고 나왔다. 기존 결과 화면은 25/25·채점 완료였고 “배정 기준 미연결”을 명시했다. 완료 결과를 새 진단으로 덮어쓰지 않았다.
- 안전성 회귀 수정을 구현했다: Vercel의 두 직접 풀이 경로는 Lightning으로 프록시하며, Lightning은 OCR 요청의 `quest_json`도 DB 원본으로 대체한다. 영수증 v2는 문항 JSON SHA-256을 묶고 Lightning이 레이팅 반영 직전 canonical DB 문항으로 검증한다. 집중 Python 검사는 25개 통과(+하위검증 2개). 이는 합성 문항 테스트이지 실제 DB 쓰기 검증은 아니다.
- 기존 Vercel UI 테스트 문항 및 카탈로그 생성 문항은 Lightning DB에 없는 경우 canonical 채점에서 `404`를 받는다. 실제 제품 문제는 Lightning의 canonical 저장소에 있어야 평점이 반영된다. Canary 데모 문항에서 제품 레이팅을 허용할지는 별도 문제 계약 없이는 확장하지 않는다.
- 이번 재개에서는 Canary 배포를 하지 않았다. 실제 레벨리티 배정은 검증된 컷오프·반복 사용자 분포가 없어 여전히 미구현/미검증이다. 추정 분위수나 단일 정답률로 배정했다고 표시하지 않는다.

## 다음 작업

1. 후보 빌드에서 즉시·일괄 채점과 OCR 필기 풀이를 실제 Canary 브라우저로 검증하고, `quest_json` digest가 Lightning canonical 문제와 일치하는지 확인한다.
2. 분리된 테스트 PostgreSQL에서 단일·batch 영수증 제출, 변조·동일 ID 다른 문항 거절, 중복 제출 멱등성을 실제 트랜잭션으로 검증한다.
3. 레벨테스트의 근거 있는 배정 계약을 확정하기 전까지 Canary V2의 보류 상태를 유지한다. 최신 776문항 DB와 배포 Supabase 행을 내용 수준에서 대조한다.
4. 빌드·Canary 배포 및 실제 브라우저 검증은 명시된 hotfix 가드 이후에만 진행한다. 이 회차는 배포하지 않았다.

## 홈 화면 추가 요청 검수 (2026-10-11)

- 요청 범위: 홈에서만 상단바 제거, 대시보드 제목 없이 직각 타일을 연결하고, 히어로를 캐릭터가 반응하는 요소로 교체.
- 현재 D: hotfix 작업본에 해당 화면 변경이 이미 반영돼 있음을 확인했다. HTML 원본의 상단바·대시보드 제목은 유지되며, 홈 앱 예외로 취급한다.
- 기존 캐릭터 탭/응원 문구 상태 전이와 390×844·1280×900 캡처 테스트 통과. 이번 회차에 제목 제거 및 학습 그리드-대시보드 경계가 맞닿는지 회귀 assertion을 추가했다.
- 캡처: `test/goldens/home-home-headerless-dashboard-contiguous-20261011-390x844.png` 및 `test/goldens/home-home-studymate-headerless-dashboard-20261011-390x844.png`; 비교 전 단계는 `design/student/audits/evidence/2026-10-07-home-dashboard-heading-03/`에 보존.
- 홈 UI 변경은 이번 회차에 별도 배포하지 않았다. 기존 작업본의 광범위한 미커밋 변경을 분리하지 않은 상태에서 전체 배포에 포함하지 않는다.

## 채점 경로 추가 검증 (2026-10-11)

- `/rating/submit` 계약 테스트를 보강해 서명된 증명이 가리키는 canonical 문항 객체가 레이팅 저장 함수로 그대로 전달되는지 확인했다.
- 일괄 반영은 모든 항목의 증명을 검증한 뒤 저장 함수를 호출하며, 뒤쪽 항목이 변조되면 저장 호출이 0회인 것을 테스트했다.
- Flutter 채점·모바일 시험 집중 회귀 15개, Python 채점 증명·레이팅·Vercel 프록시·레벨테스트 DB seed 회귀 27개 통과.
- 이 검사는 모의 저장 함수 기반 계약 검사다. 실제 PostgreSQL 저장·동시접속 검증은 아니다. `TEST_DATABASE_URL`, `OMJ_TEST_DATABASE_URL`, `RATING_TEST_DATABASE_URL`가 없고, `psql`·`postgres` 실행 파일과 PostgreSQL 서비스가 확인되지 않았다. 운영 DB에 쓰지 않았다.
- Vercel/Lightning 변경은 아직 배포되지 않았다. live OCR worker의 canonical payload 동등성, 실DB receipt-to-rating 트랜잭션, Canary에서의 실제 새 빌드 채점은 미검증이다.
- Flutter web release 빌드는 별도 `build/goal-validation-20261011-01` 폴더에서 성공했다. `main.dart.js` 크기 6,987,461 bytes, SHA-256 `39037597F3B3B6E93CC92006B8C6A47DDE0919CA4A66DA44F9BD785A020CE9FB`; `public` 정적 파일은 덮어쓰지 않았다. 빌드 경고: CupertinoIcons 글꼴 번들이 발견되지 않았다.
- 전체 `flutter analyze --no-pub`는 342개 항목으로 종료 코드 1. 채점·시험·레벨테스트 관련 범위 분석은 오류 0, 경고 14, 정보 2였고 미사용 레벨테스트 UI·구형 리포트 요소가 남아 있다. 전체 분석의 342개 항목은 이 회차에서 일괄 수정하지 않았다.

## 새 레벨테스트의 배치 연결 조사 (2026-10-11)

- `api/index.py`의 `expanded-v1` 제출은 25/10문항 정답률·난이도별·태그별 요약을 계산하고 `canary_user_kv`에 저장하지만 `apply_level_test_placement` 또는 rating 저장 경로는 호출하지 않는다. 현재 결과는 실제 Levelity/OVR 배정이 아니다.
- 확장 DB/SQL의 레벨테스트 행은 `difficulty_tier`, `tags`, `solves`를 제공하나 기존 placement 추정기가 사용하는 고정 `placement_rating`은 없다. 기존 98문항 bank의 티어별 안정해시 레이팅(1000~1675)은 구형 배정방식이며, 새 문항에 검증 없이 재사용하지 않는다.
- 따라서 확장 DB의 티어만으로 OVR을 숫자화하거나 Prime/Powerful/Insane/Plain/Cheer Up 컷을 만들지 않았다. 최신 DB row count 776과 샘플 1문항 확인은 이전 기록대로이며, 전체 배포 row 내용 동등성과 실제 레벨 배치는 아직 미검증이다.

## 재개 검증 및 모바일 시험 UX 근거 (2026-10-11)

- 모바일 시험 UI 코드에서 문항 목록/바로 이동, 다시 볼 문항 표시, 문항 확대, 남은 시간 표시 전환이 존재함을 확인했다. 관련 위젯 테스트에서 타이머 만료 자동 제출, 문항 간 답안 유지, 필기/이동 모드, 마지막 답안표 제출을 검증했다.
- 즉시 채점 기본 설정, 모바일 일괄 채점 제출, 서버 결과 전용 페이지, Flow 분석 경로를 다루는 Flutter 테스트 9개가 통과했다.
- 레벨테스트 응시 흐름·시간 표시·결과 페이지 테스트 13개가 통과했다. 서버 레벨테스트 V2·채점 영수증·rating service 계약 테스트 21개가 통과했다. 경고 7개는 deprecated FastAPI/Starlette lifecycle 관련이다.
- `mobile_solve_view_test.dart` 내 HTML 간편풀이 Flow 골든 테스트가 매우 느려 전체 파일은 통과 판정을 보류했다. 코드에서 시간표시가 주기 갱신되는 점을 확인해 해당 테스트의 전체 `pumpAndSettle`을 200ms 고정 프레임으로 바꿨다. 단독 재실행에서는 폰트·첫 프레임·골든 캡처·Flow 드래그·답 선택 단계까지 진행됐지만 80초 안에 테스트 프로세스가 종료되지 않아 중단했다. 정확한 지연 원인은 아직 확인되지 않았으며 파일 전체를 합격으로 처리하지 않는다.
- 모바일 학습 UX 비교 근거로 Brilliant 공식 도움말은 단계형 대화형 문제, 힌트 제공, 진도 동기화와 재시도를 점수·성적과 구별하는 학습 원칙을 설명한다. 이는 이 앱의 문항 단위 진행, 힌트·해설, 작성 답안 유지, 재검토 동작을 우선하는 근거로만 사용하며, 타사 점수 체계를 복제하지 않는다. [Interactive learning and progress sync](https://brilliant.org/help/using-brilliant/can-i-download-brilliant-lessons-or-use-them-offline/) · [Skills Check is not a grade](https://brilliant.org/help/schools-and-educators/assignment-and-progress-reporting-guide/)
- 이번 확인 중 Computer Use가 Edge URL을 판별하지 못해 두 번의 연속 새 세션에서 브라우저 화면 수집 전에 중단됐다. 이 목표의 실제 브라우저 검수는 미완료다. 후보 빌드와 Canary UI 상호작용도 아직 확인하지 않았다.

## 원본 레벨테스트 DB 기반 오프라인 응시 검증 (2026-10-11)

- 사용자가 제공한 `Math-textbook/07 Data/레벨테스트/leveltest_final_expanded.db`와 hotfix의 `data/content/leveltest-expanded-v1/leveltest_final_expanded.db` SHA-256이 모두 `90F5CC3C811D43857DE3821E47242141B6DCA7DE17C137217315AA25CBDE6EE3`로 일치한다.
- hotfix DB 776행과 보존된 감사 레코드 776개를 대조했다. 문항 ID 파싱 오류 0, 제목·정답·풀이 누락 0. 9개 트랙×4개 폼(각 25문항, S형 10문항)을 시험하는 로컬 통합 테스트를 추가했다.
- 실제 제공 DB를 읽기 전용으로 로드해 모든 36개 폼의 출제 문항 수와 부모 문항 중복 여부를 검사하고, 기하 C형 테스트 세션을 메모리 저장소에서 시작→25/25 테스트 답안 제출→정답률·난이도/태그 분석 결과 재생까지 확인했다. 해당 Python 테스트 2개 통과.
- 이 검사는 실제 제공 문항을 사용하지만 Supabase/운영 DB가 아닌 메모리 저장소를 사용한다. 결과는 진단 통계이며 `placement`/`rating` 필드를 만들지 않는다. 원본 승인 문서가 구형 OVR 배정 방식 재사용을 금지하고, 신규 Levelity 배치 파라미터를 만들 실제 학생 응답 분포가 없어 실제 등급 배정 검증은 미완료다.
- 기존 readiness가 구형 placement 테이블만 확인하던 문제를 수정했다. active `expanded-v1` bank의 776행, 버전, 1~776 순번, 고유 ID도 읽기 전용으로 확인하고, 불일치 시 readiness를 `unavailable`로 내린다. 테스트는 정상 행과 누락 행을 모두 검사한다.
- 채점 영수증·rating 계약, 승인 DB seed 무결성, V2 원본 DB 전폼 출제/응시·진단, readiness 검사를 포함한 Python 회귀 테스트 24개가 통과했다. 7개 경고는 기존 FastAPI/Starlette lifecycle deprecation이다.
- readiness 수정과 이 DB 기반 검사는 아직 Canary에 배포되지 않았다. live Supabase 테이블의 전체 행·콘텐츠 대조, 실제 저장소 기반 응시/등급 배정, Computer Use 브라우저 검증도 미완료다.

## 활성 목표 집중 회귀 재실행 (2026-10-11)

- D: `hotfix @ d0c6e8ca229734c1c7cc6e5d398e6c9021f48798` 가드 통과를 확인했다.
- Python 회귀: expanded-v1 전폼·seed 무결성·Vercel 채점 증명·rating 계약 29개 통과. 테스트 전용 JWT 비밀값을 HS256 권고 길이에 맞춰 조정했고, 경고는 기존 FastAPI/Starlette deprecation 7개다. 이 결과는 모의 저장소/계약 검증이며 실DB 채점 증명을 대신하지 않는다.
- Flutter 회귀: 문제별 기본 채점/Flow, batch 설정·전용 결과, 모바일 시험 조작 및 일괄 결과 9개 통과. 레벨테스트 화면·세션 12개 통과.
- 코드 재확인 결과 expanded-v1 제출은 진단 요약을 세션 결과에 저장하지만 placement rating이나 배치 레벨을 갱신하지 않는다. `rating_service.apply_level_test_placement`는 구형 PostgreSQL 문제 저장소와 기존 rating 추정 로직을 사용하므로 새 승인 데이터 경로에 연결하지 않았다.
- 미완료: Supabase 전체 행/풀이 내용 parity, 허용된 격리 테스트 DB에서의 실제 채점 저장, 새 데이터 기반 레벨 배치·Levelity 검증, Canary 새 빌드의 Computer Use 실제 브라우저 여정. 운영 DB에는 쓰지 않았고 배포하지 않았다.

## Canary 레벨테스트 읽기 전용 상태 확인 (2026-10-12)

- `vercel inspect https://aiflow-web-canary.vercel.app --format=json`: alias는 `dpl_aHUZqtSxzhzgWFyvAfEmB1zz2aNJ` (`READY`, production, 생성 2026-10-10)을 가리킨다.
- Canary `/level-tests/placement/stats`: 776문항, 9트랙, 난이도 tier 2/3/4/5 분포 128/270/270/108을 반환했다. 응답에는 placement rating/배정 레벨이 없다.
- Canary `/health/level-test`: status `ok`지만 확인 목록은 구형 5개 테이블뿐이며 `expanded_v1_question_bank` 검사가 없다. 따라서 776개 통계는 확인됐지만 앱이 서빙하는 행 전체의 원본 SQLite 내용 일치나 새 readiness 코드 배포는 증명하지 못한다.
- Vercel production에 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`가 등록된 사실은 CLI의 이름 목록으로만 확인했다. production 비밀값을 가져와 직접 조회하려는 시도는 실행 전 도구 정책에서 거부됐다. 비밀값은 출력·저장되지 않았고 DB 변경도 없었다.
- 이번 확인은 HTTP GET과 배포 메타데이터 조회만 수행했다. 별도 테스트 DB는 없으며 Canary/운영 DB에 테스트 응시를 쓰지 않았다.

## 레벨테스트 결과 복구 멱등성 보완 (2026-10-12)

- 관찰: 정답 결과를 세션에 원자 커밋한 뒤 `result.{session_id}` 또는 `latest_result` upsert가 실패하면, 재시도에서 커밋된 세션 결과는 응답하지만 파생 결과 키를 복구하지 않아 상태 조회가 이전 결과를 유지할 수 있었다.
- 수정: 재시도와 신규 제출 모두 `_persist_level_test_v2_result`를 사용한다. 세션별 결과를 먼저 복구하고, 서버 `completed_at` 순서가 최신일 때만 상태 조회용 `latest_result`를 갱신한다. 완료 시각은 JS 정밀도 문제를 피하도록 epoch 나노초 십진 문자열로 저장한다.
- 검증: 두 저장 지점 각각에서 일시 실패를 주입한 뒤 동일 제출 재시도, 완료 상태 조회, 중복 커밋 없음 확인. 확장 DB·seed·채점 영수증·rating 계약을 포함한 Python 회귀 32개 통과, 기존 FastAPI/Starlette deprecation 경고 7개.
- 범위: 메모리 저장소의 재시도 계약 검사이며 실제 Supabase/Postgres 또는 Canary 수정분을 검증하지 않는다. 실제 브라우저, 결과의 Levelity/배치 적용, 실DB 동시성 검증은 미완료; 배포하지 않았다.

## Vercel OCR 결과 → Lightning 레이팅 경로 교차 검증 (2026-10-12)

- `get_ocr_job`이 완료된 테스트 OCR 행에서 동일 canonical question digest의 서명 proof를 발급하고, 그 proof를 Lightning `submit_rating` 핸들러가 받아 검증 후 canonical 문제·사용자·submission ID로 저장 함수를 호출하는 교차 서비스 검사를 추가했다.
- 테스트는 메모리 OCR 행과 저장 함수 대역을 사용하며 OCR inference·실제 PostgreSQL은 실행하지 않는다. focused receipt 계약 테스트 14개, 통합 Python 회귀 32개 통과.
- 사용자 데이터/운영 DB 쓰기, Canary 배포 없음.

## 목표 회귀 재검사와 Canary 상태 갱신 (2026-10-11)

- Flutter 채점 설정·객관식 즉시 채점/Flow·일괄 결과 및 Flow·모바일 일괄 제출 회귀 8개 통과.
- Flutter 레벨테스트 이동·제출/타이머와 모바일 시험 결과 화면 회귀 15개 통과.
- 한 번의 더 넓은 묶음 실행은 `mobile_solve_view_test.dart`의 필기 제출 단계에서 출력이 멈췄고, 실행이 종료되지 않아 중단했다. 그 묶음은 통과로 계산하지 않는다.
- Canary 공개 GET 재확인: `/level-tests/placement/stats`는 776문항·9개 트랙 및 난이도 분포를 반환했다. `/health/level-test`는 여전히 구형 테이블 5개만 검사한다. 776 카운트는 전체 Supabase 행 내용이 제공 SQLite와 같다는 증거가 아니다.
- Computer Use Edge 캡처를 다시 요청했으나 브라우저 URL을 충분한 신뢰도로 판별할 수 없다는 동일한 안전 차단으로 중단됐다. UI에서 시험 응시·제출·결과 배치를 직접 검증하지 않았다.
- 배포/DB 쓰기 없음. 실제 OCR→PostgreSQL 채점 반영, 레벨 배정, 실제 브라우저 여정은 계속 미완료다.

## 모바일 필기 회귀 정체 원인 분리 (2026-10-11)

- `모바일 필기 풀이를 충분히 작성하고 제출하면 채점 화면으로 이동한다`는 단독 실행 시 통과했다.
- `mobile_solve_view_test.dart` 전체 및 HTML 간편풀이 Flow 조립 테스트의 단독 재실행은 같은 구간에서 출력이 멈춰 완료되지 않았다. 이를 앱 오류 또는 테스트 통과로 단정하지 않는다. 다음 재개 시 Flow 테스트 단계별 계측으로 멈춤 위치를 먼저 찾는다.
- 홈 히어로 확인: 이미 직각 학습 메이트 카드와 캐릭터 탭 반응/응원 문구 전이가 구현돼 있고 관련 캡처 테스트가 있다. 이번 회차에는 홈 코드를 중복 수정하지 않았다.

## 모바일 빠른 풀이 회귀 정체 해결 (2026-10-11)

- 원인 1: HTML Flow 테스트는 본문 종료 후 실제 영속 저장소를 지우는 `clearToken()` teardown을 기다리고 있었다. 테스트 세션 전용 `setTokenForTest`/`clearTokenForTest`로 바꿔 브라우저·보안 저장소 의존성을 제거했다.
- 원인 2: 단답형 테스트는 이미 HTML 빠른 풀이 화면으로 바뀐 구현에서 예전 `mobile-flow-node-source-*` 키를 찾고 있었다. 현 화면의 `html-quick-flow-node-*` 키로 맞추고, 주기 타이머를 끝까지 진행할 수 있는 `pumpAndSettle` 대신 200ms 고정 pump를 사용했다.
- 검증: `flutter test test/mobile_solve_view_test.dart --timeout 60s` 7개 전체 통과. 이는 앱 화면 상호작용의 위젯 테스트이며, Canary 브라우저의 실제 채점 서버 응답 검증은 아니다.

## 채점·시험·레벨테스트 통합 집중검사 (2026-10-11)

- `mobile_solve_view_test`, 채점 모드/객관식 Flow/일괄 결과·취소/일괄 제출, 레벨테스트 타이머·세션·결과 화면을 한 번에 실행해 30개 통과.
- 검증 대상은 기본 즉시 채점 설정, 풀이 Flow, batch 모드 설정·제출 확인·전용 결과 페이지, 모바일 답안 제출, 레벨테스트 제한 시간·세션 연결·결과 레이아웃이다.
- 라이브 OCR inference, PostgreSQL 쓰기, Canary 브라우저 실응시/배치, 배포 동일성은 이 Flutter 테스트로 증명되지 않는다.

## 안전한 실DB 검증 환경 재확인 (2026-10-11)

- 재확인한 테스트 접속변수 이름은 없고 `psql`·`postgres` 실행 파일 및 PostgreSQL 서비스도 발견되지 않았다. Docker CLI는 있으나 Docker Desktop Linux Engine pipe에 연결하지 못했다.
- 따라서 격리 PostgreSQL 저장·멱등성 검증은 이번에도 실행하지 않았다. 운영 Supabase에 시험 데이터를 쓰거나 production 비밀값을 조회하지 않았다.
- 채점 영수증/레이팅/레벨테스트 V2/seed focused Python 테스트는 현재 코드에서 다시 실행해 32개 통과, 기존 FastAPI/Starlette deprecation 경고 7개를 확인했다.

## Computer Use 및 Lightning 채점 범위 재검증 (2026-10-11)

- 커밋 `1ed82be`에서 Lightning/TexTeller를 필기 수식 인식 전용으로 제한했다. 인식 실패 시 Qwen 등 다른 모델로 이미지를 넘기지 않고 빈 OCR 결과와 경고를 반환하며, 텍스트 풀이 채점은 Kiln만 사용한다.
- 채점 프롬프트는 획이 비슷한 문자·숫자, 동치 표기, 생략 단계와 타당한 대안 풀이를 더 관대하게 인정하도록 강화했다.
- Python OCR·채점 focused 검사 20개 통과. Flutter 즉시/일괄 모드, batch 결과·Flow, 제출 경쟁과 레벨테스트 흐름 검사 9개 통과.
- `html_quick_result_test.dart`의 오답 390×844 케이스 단독은 통과했으나 전체 파일은 두 번째 케이스에서 90초 이상 정지해 중단했다. 전체 파일 검증으로 계산하지 않으며 원인은 미확정이다.
- Canary GET: `/health` 200, `/health/level-test` status `ok` 및 `expanded_v1_question_bank=true`; `/level-tests/placement/stats`는 25문항 본시험, 10문항 빠른 검사, 776문항 풀, 9개 트랙을 반환했다.
- Computer Use에서 Canary의 기존 결과 화면을 직접 확인했다. 표시된 저장 결과는 25/25, 12분 56초였으나 화면에 코스 배정 기준이 연결되지 않아 배정 보류라고 명시돼 있다. 이 값은 이번 회차에서 새 응시해 산출한 결과가 아니다.
- 같은 Canary 테스트 계정에서 새 25문항 A형 응시 세션을 열어 실제 문항과 필기 UI까지 확인했다. 기존 25/25 결과를 덮어쓰지 않도록 답안 제출 전 멈췄으며, 이 세션은 채점·배정 검증으로 계산하지 않는다.
- 현재 Vercel `expanded-v1` 제출 계약은 정답률·난이도·태그 요약을 저장하지만 rating/Levelity/코스 배정을 계산하지 않는다. 새 문항 DB에는 `difficulty_tier`만 있고 기존 rating 추정기의 `placement_rating` 또는 보정 표본 연결이 없다. 기준을 임의로 만들어 배정하지 않았다.
- 미완료: 실제 안전한 테스트 환경의 필기 이미지→TexTeller→Kiln 채점 응답, V2 결과→rating/Levelity/코스 배정 계약과 calibration, 새 Canary 응시의 제출 검증, 전체 결과 위젯 테스트 원인 확인, 새 빌드 배포 및 동일성 확인.
- 운영 DB 쓰기 없음. 이번 회차의 신규 배포 없음.

## API 일원화 재개 — OCR / 채점 2단계 연결 (2026-10-12)

- 변경 위치: D: `hotfix` worktree, HEAD `1b1ccbbca155b2c3200688d30b0502ae877b39bb`; 기존 광범위 미커밋 변경은 보존했고 커밋·배포·실DB 변경은 하지 않았다.
- Flutter 채점 제출은 같은 Vercel origin의 `/api/ocr/jobs`를 기본 사용한다. 큐 등록은 `mode=ocr`이며, `submission_id`를 레이팅 on/off와 무관하게 포함해 동일 요청 재시도 키를 안정화했다. 채점에는 문항 ID와 필기 이미지가 필수이고 누락 시 legacy `/analysis/solve`로 조용히 되돌아가지 않는다.
- Lightning worker는 기존 `mode=ocr`만 선점한다. Vercel의 `/api/ocr/jobs/{id}/grade`가 사용자 소유권이 확인된 OCR 완료 결과를 임대·선점한 뒤 canonical Vercel 문항은행과 Kiln 텍스트 API로 채점한다. 결과는 Supabase 행에 저장되어 같은 제출 키 재시도에서 캐시 결과를 돌려준다. 제출 이미지 payload는 OCR 완료 시 SQL에서 제거하고 문제·정답 정보는 클라이언트가 보낸 `quest_json`을 신뢰하지 않는다.
- 새 migration `deploy/vercel/supabase_ocr_grading.sql`은 기존 큐 행을 삭제하지 않고 기존 진행 중 solve 행을 명시적 실패 이력으로 보존한다. DB에 실제 적용하지 않았다. 운영/격리 Supabase에서 RPC·정책·동시성 실행 검증도 아직 없다.
- 집중 검사: Python 22개 통과(큐 인증/멱등성/grade-result 캐시·Kiln 호출 계약·SQL 정적 안전성·문항 스냅샷), `dart analyze` API 2파일은 exit 0(기존 info 4건), `flutter test test/api_cache_test.dart --no-pub` 8개 통과, Python compile 통과. 앱 호출 파일까지 포함한 `flutter analyze`는 기존 미사용 함수 warning 2건으로 exit 1(스타일 info 5건 추가). 변경 파일 범위의 `git diff --check`는 통과했으나 전체 worktree 검사는 기존 `test/personal_schedule_mobile_test.dart:211` EOF 공백 때문에 실패한다. 첫 Flutter test 실행은 Dart 테스트 로더가 정지해 종료했고 `--no-pub` 재실행에서 정상 완료했다.
- 다음 작업: 레이팅/약점/이어풀기/대결 랭킹의 Vercel 저장소 이관과 기존 데이터 보존 계약을 이어간다. `api/index.py`의 `/analysis/solve`, `/rating/*`, `/weakness/tags`, `/continue/strokes`, `/arena/rankings` Lightning 프록시는 여전히 남아 있다. 이를 전체 일원화 완료로 표시하지 않는다. SQL migration 적용, 격리 DB 동시성, 실사용자 필기 OCR→Kiln 응답은 별도 승인된 환경에서 확인한다.

## API 일원화 재개 — Rating API Vercel/Supabase 소유로 이전 (2026-10-12)

- `GET /rating/user`, `GET /rating/tags`, `POST /rating/submit`을 Vercel 경로로 전환했다. 제출은 사용자·canonical 문항 SHA-256·정오·풀이 결과·submission ID에 결합된 서버 grade receipt를 확인하며, 사용자 전달 점수/태그만으로 레이팅을 올릴 수 없다.
- `deploy/vercel/supabase_rating.sql` 초안은 평점/태그/제출 테이블과 service-role 전용 RPC를 정의한다. 사용자 행 잠금, submission composite key, 동일 요청 저장 응답 재사용, 다른 문항에 재사용 시 conflict를 포함한다. service_role에는 delete 권한을 주지 않으며 RLS를 켠다.
- OMJ 알고리즘을 대조해 canonical 문제의 문제 태그만 반영하고 p80 흐름 percentile 인덱스를 맞췄다. Lightning 경로 중복 `/rating/tags` 라우트를 삭제했다. README는 레거시 DB 내보내기·검증 전 migration/data cutover를 금지하도록 정정했다.
- 집중 검사: rating API·receipt Python 테스트 11개 통과, `api/index.py` py_compile 통과. 전체 인증 대시보드 테스트 묶음은 2개 실패했으며 현재 `_FakeAuthDataApi` fixture가 마켓플레이스의 `canary_user_kv` 요청을 지원하지 않는 별도 계약 불일치다. 이번 회차에는 그 fixture나 마켓플레이스 동작을 변경하지 않았다.
- Supabase SQL 적용/구문 실행·동시성·기존 PostgreSQL 데이터 export는 미검증이다. 로컬 DB 연결 및 Supabase 프로젝트 접근이 준비되지 않아 migration 또는 기존 사용자 데이터 변경은 하지 않았다.
- 남은 Lightning 제품 프록시: `/weakness/tags`, `/continue/strokes`, `/arena/rankings`, legacy `/analysis/solve`. API 전체 일원화 완료가 아니며 배포/커밋도 하지 않았다.
- 다음 회차 외부 상태 확인: `SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`는 이 환경에 없고 `DATABASE_URL`의 host는 loopback이다. 현재 venv에 psycopg가 없어 read-only 접속은 시도하지 못했다. 기존 데이터 cutover가 필요한 이유는 계속 유효하다.
- 데이터 보존 준비: `tools/migrate_rating_to_supabase.py`를 추가했다. hotfix checkout에서만 허용하고 `--apply`를 요구한다. source는 read-only이며, 목적지에는 누락된 행만 추가한다. 키가 같은 기존 행은 모든 필드가 동일할 때만 유지하고, 충돌은 전체 트랜잭션을 중단한다. 목적지 전용 행은 삭제하지 않는다. 실제 복사 완료를 뜻하지 않는다.
- 추가 검증: rating·grade receipt·rating migration tool 계약 테스트 14개 통과, API/도구 py_compile 통과, 범위 diff check 통과. PostgreSQL SQL 파서/실서버 실행은 아직 불가하다.

## 레거시 SQLite 사용자 상태 읽기 전용 조사 및 보존 경로 (2026-10-12)

- 기본 `QUEST_DB_PATH`인 `omj/quests.db`를 SQLite `mode=ro`로 열어 테이블명·스키마·건수·형식만 확인했다. 현재 파일에는 `continue_session` 2행, `user_weakness_tags` 36행이 있고, continuation stroke JSON 2/2가 배열이며 약점 행 검사상 잘못된 count/tag/time은 0행이다. 사용자 ID와 개별 풀이 내용은 출력하지 않았다.
- 같은 파일에는 SQLite fallback `user_rating` 11행도 있으나 앱 rating 서비스는 `PostgresRatingStore`를 사용한다. 이 SQLite rating 행을 authoritative PostgreSQL rating 원장과 합치지 않았고, migration 도구도 별도로 두었다.
- `deploy/vercel/supabase_student_state.sql`과 `tools/migrate_student_state_sqlite_to_supabase.py`를 추가했다. 둘 다 목적지 테이블이 비어 있지 않으면 거부하고, source SQLite read-only·D: hotfix 가드·단일 destination transaction·건수+SHA-256 검증을 요구한다. 실제 DB 연결·쓰기·라우트 cutover는 하지 않았다.
- 이어풀기 완료 방지에는 solve history/exam score sheet 계약도 필요하다. 따라서 `/continue/strokes`는 아직 프록시이며, 현재 Vercel 경로에 같은 완료 검증이 있는지 확인하기 전에 라우트를 전환하지 않는다.

## 약점 태그 조회 및 OCR 채점 저장 경로 Vercel 이전 (2026-10-12)

- `GET /weakness/tags`를 Lightning 프록시에서 인증 사용자 기준 `user_weakness_tags` Supabase 조회로 바꿨다. 빈 테이블은 실제 빈 결과로 처리하고 저장소 미구성·오류는 503으로 반환한다.
- OCR 채점 결과의 `in_panic` 단계 번호를 Vercel canonical 문제의 풀이 단계·태그에 매핑한다. 클라이언트가 보낸 태그는 신뢰하지 않으며 원본 SQLite 저장소와 동일하게 단계별 태그 반복은 카운트에 반영한다.
- `/api/ocr/jobs/{id}/grade`가 `complete_ocr_solve_grade_with_weakness`를 호출하도록 바꿨다. `ocr_jobs` 사용자/임대 소유권을 잠금 확인하고, 결과 저장과 약점 카운터 upsert를 한 트랜잭션으로 처리한다. 이미 완료된 동일 결과 재호출은 카운터를 다시 늘리지 않는다.
- `supabase_student_state.sql`에 해당 service-role 전용 RPC를 추가하고 적용 순서를 문서화했다. DB에는 적용하지 않았다. SQLite에 존재하는 기존 36개 약점 행은 별도 단일 transaction 이관 도구를 먼저 실행해야 보존된다.
- 검증: rating·receipt·OCR queue·SQL 계약 및 두 migration 도구 테스트 30개 통과, Python compile 및 변경 범위 diff-check 통과. PostgreSQL 실행·Data API live 연결·alias 배포는 미검증.
- 남은 제품 프록시: `/continue/strokes`, `/arena/rankings`, `/analysis/solve`. 전체 API 일원화 완료 아님.

## legacy solve 프록시 차단 (2026-10-12)

- `/analysis/solve`가 Lightning으로 요청을 전달하지 않도록 폐기 응답 `410`으로 변경했다. Flutter 채점 제출은 문항 ID와 필기 이미지가 있을 때만 Vercel OCR 큐를 이용하며, OCR 큐 주소가 비어 있으면 503 설정 오류를 보여준다. 레거시 채점 경로로의 fallback은 제거했다.
- OCR/채점 focused Python 검사는 9개 통과했다. `test_vercel_auth.py`와 함께 실행했을 때 기존 테스트 fixture가 마켓플레이스 `canary_user_kv` 조회를 지원하지 않아 2개 실패했다. 이는 이전 회차와 동일한 fixture 불일치이며 이번 변경으로 수정하지 않았다.
- 이어풀기·랭킹의 완료 방지와 범위 계약은 여전히 Vercel로 이관되지 않았다. Lightning 제품 프록시는 현재 `/continue/strokes`, `/arena/rankings` 두 개가 남아 있으며, 분석 엔드포인트는 410으로 차단된다.
- 사용자 데이터 이관, Supabase SQL 적용, 커밋, 배포는 하지 않았다.

## 이어풀기 전환을 위한 풀이 이력 보존 도구 (2026-10-12)

- 기존 PostgreSQL `solve_history` 행을 Vercel `canary_user_kv`에 `solve_history.legacy.<id>` 키로 보존하는 단일 transaction migration 도구를 추가했다. source read-only, 대상 키에 같은 행 있으면 재실행 가능, 값이 다르면 덮어쓰지 않고 중단, invalid JSON 거부 및 SHA-256 비교를 포함한다.
- 이어풀기 전환 전에 이 이력의 source writer를 정지하고 전체 이관·검증해야 한다. 완료 exam score sheet의 데이터 출처/문항 수 계약은 별도로 포팅해야 하므로 `/continue/strokes`는 아직 Lightning 프록시다.
- migration tool 테스트 5개 통과, compile/diff-check 통과. DB 이관·Vercel API cutover는 실행하지 않았다.

## 대결 랭킹 Vercel API 계약 및 데이터 보존 준비 (2026-10-12)

- `/arena/rankings`의 Lightning 프록시를 인증 사용자 전달을 포함한 Vercel endpoint로 전환하고 `get_arena_rankings_page` RPC 계약을 추가했다. 반환 규격은 기존 items/total/my_rank/my_profile/query/scope/페이지 정보이며 storage 미구성은 503으로 닫는다. SQL은 전역 rank, 내 등급/친구 scope, 프로필 표시명 검색을 계산한다.
- `supabase_arena_rankings.sql`과 PostgreSQL `arena_rating`→Supabase 빈 테이블 원자 복사 도구를 추가했다. 아직 SQL 적용과 원장 이관은 하지 않았으며, Vercel 코드 배포 전 source writer를 정지한 마지막 비교/스냅샷이 필요하다.
- 실제 arena 매치 결과 쓰기 경로는 이 Vercel leaderboard table에 아직 연결되지 않았다. 랭킹 API 코드만으로 arena API 전체 이전을 완료했다고 보지 않으며, 이 쓰기 경로 검수 전 deploy는 금지한다.
- 랭킹 endpoint·migration·OCR·solve-history focused suite와 auth 통합을 묶어 38개 통과. `test_vercel_auth.py` 메모리 fake를 새 Vercel RPC와 사용자 상태 테이블 계약에 맞게 수정했다. Python compile/diff-check 통과. `psql`·`pglast`는 현재 환경에 없어서 SQL은 static contract만 확인했고 실제 PostgreSQL 실행은 안 했다.

## 이어풀기 Vercel API 전환 및 OCR 채점 원자 기록 (2026-10-12)

- `GET/POST /continue/strokes`를 Lightning proxy 대신 인증 사용자별 Supabase guarded RPC로 전환했다. 1MB 제한, 소유자 전달, 7일 TTL, 완료/허용 플래그, 재개 대상 일치 응답을 유지한다.
- OCR 채점 payload에 시험 ID·문제 순번·총 문항 수를 보존하고, Vercel은 소유한 canonical 시험과 문항 ID/순번을 제출 전 검증한다. Flutter도 시험 ID를 채점 요청에 포함한다.
- grade finalize RPC에서 grade 결과·solve history·exam score sheet·weakness 카운터를 한 transaction에 반영한다. 문제 풀이 정답 1건 또는 시험 내 정답 1건만으로 완료 오판하지 않으며, 시험의 모든 문제 인덱스가 정답인 경우에만 이어풀기 row를 제거한다.
- README와 이 원장을 갱신했다. API contract/SQL static suite **58개 통과**. SQL은 static 검사만 했으며 실제 PostgreSQL 구문 실행은 불가했다. 실제 DB migration·legacy state/history 복사·RLS·동시성은 미검증.
- 남은 주요 항목: Supabase schema 적용 및 안전한 기존 상태/rating/history/arena 원장 이관, 경기 결과 writer를 Vercel 랭킹 원장에 연결, 실제 DB 동시성/RLS, OCR→Kiln 실사용/브라우저 검증. 운영 데이터 쓰기·커밋·배포는 하지 않았다.
- 추가 경계 수정: 실제 참조가 없는 범용 `/api/app/*` Lightning 프록시, 전달 함수, `LIGHTNING_APP_URL` 기반 라우팅 코드를 삭제했다. 레거시 `/analysis/solve`는 410 폐기 응답만 남고 OCR job 등록에서만 worker wake가 일어난다. 관련 endpoint/proxy 금지 회귀검사를 갱신했다.
- 재검증: API/SQL 계약 회귀 **71개 통과**, Python compile 및 변경 파일 `git diff --check` 통과, Flutter 시험 제출 파일 `dart analyze` 통과. 현재 `TARGET_SUPABASE_DATABASE_URL`, Supabase service role, rating/arena/history source DB 환경변수 모두 미설정이며 PostgreSQL 실행 도구도 없어 데이터 이전 및 실제 SQL 실행은 불가능했다.

## 기존 평점 행 병합 안전성 보강 및 Supabase 읽기 전용 재확인 (2026-10-12)

- `tools/migrate_rating_to_supabase.py`는 이제 빈 목적지를 요구하지 않는다. 고정 allowlist의 세 테이블 키로 임시 staging을 만들고, 같은 키의 기존 행 전체가 source와 같을 때만 idempotent하게 건너뛴다. 값 충돌은 실패, 추가 source 행만 삽입, destination-only 데이터는 보존한다. 단일 transaction에서 source 건수와 대상 매칭 건수를 비교한다.
- SQL은 정적 계약 테스트만 추가/실행한다. 실제 PostgreSQL 연결 또는 migration 실행은 하지 않았다.
- Supabase Production UI의 read-only 확인 결과: `user_rating` 11행, `user_tag_rating` 61행, `rating_submission` 5행, `arena_rating` 0행, `canary_user_kv` 내 solve history 12행. continuation/exam score sheet 키는 0행이다. 기존 평점행이 있으므로 빈 DB 전제는 불가능했고, 이번 안전 병합은 그 전제만 제거한다.
- 현재 live schema는 `arena_rating`, `rating_submission`, `user_rating`, `user_tag_rating`의 RLS가 꺼져 있고 정책도 없으며, `canary_user_kv`, `canary_users`, `ocr_jobs`는 RLS가 켜져 있으나 정책은 없다. 신규 student-state 테이블과 일부 RPC는 아직 없다. SQL 적용/정책 검증 미완료다.
- 로컬 `DATABASE_URL`은 loopback으로 설정되어 있지만 연결은 timeout이며 PostgreSQL 서비스도 확인되지 않았다. Vercel production env는 이름만 보이고, env pull은 비밀값을 `[SENSITIVE]`로 마스킹하여 DB 연결정보로 쓸 수 없었다. production DB 변경·데이터 migration·배포·커밋은 없다.
- 다음 작업: production에 적용할 SQL을 현재 schema와 대조해 순서/하위호환/RLS 영향 검토, Supabase 프로젝트의 분리된 test DB나 별도 승인된 접근 경로 확보, source ledger와 기존 목적지 행의 충돌 없는 대조. 대결 결과 writer는 여전히 미연결이며 OCR→Kiln 실사용/브라우저 QA도 미완료.

## 대결 요약의 실제 레이팅 연결 및 레거시 봇 보상 복구 (2026-10-12)

- `/arena/summary`가 기존처럼 고정 1500점만 반환하지 않고 `get_arena_rankings_page`의 인증 사용자 `my_profile`을 사용하도록 변경했다. 테이블에 행이 없는 사용자는 명시적 초기 프로필을 받으며, 저장소/RPC 오류는 503, 잘못된 응답은 502로 닫는다.
- `tools/migrate_arena_rankings_to_supabase.py`도 빈 테이블 전제를 제거했다. `(user_id, queue_type)` 키의 동일 행은 건너뛰고, 값 충돌은 중단하며, 누락 행만 삽입한다. destination-only 행은 보존하고 source 행의 매칭을 검증한다.
- 기존 `omj/arena/service.py::_finish_practice`와 `PostgresArenaRepository.save_result()`에서 봇 승리 +20, 패배 -10, 무승부 0 및 중복 경기 방지가 실제로 저장되는 것을 확인했다. 따라서 이전의 “랭킹 미반영” 변경은 근거가 부족해 철회하고 레거시 동작을 복구한다.
- `supabase_arena_rankings.sql`에 서버 생성 매치, 행 잠금 답안 제출, 결과/레이팅 원장 RPC를 추가했다. 결과 원장에는 점수·결과·레이팅만 저장하며 답안은 기존 사용자 KV에 임시 보관되고 결과 확인 ACK 이후 제거한다. RPC 재시도는 동일 결과를 반환하고 다른 본문 충돌은 거부한다.
- 검증: arena API/RPC·migration Python 테스트 **25개 통과**, `api/index.py` compile 통과, Flutter `arena_result_page_test.dart` 통과. arena 변경 파일 범위 `git diff --check` 통과. 저장 실패 시 아직 영속화되지 않은 레이팅 보상을 UI에 반환하지 않는 테스트도 포함한다.
- 제한: 실제 PostgreSQL에서 이 SQL을 실행하거나 동시성 검증한 것은 아니다. 전체 working tree의 `git diff --check`는 기존 `test/personal_schedule_mobile_test.dart`의 EOF 빈 줄 때문에 경고/실패했으나 이번 작업 파일은 통과했다. SQL 적용, 데이터 migration, 배포·커밋은 하지 않는다.
- 목표 재개 후 경계 재검증: Flutter `ApiContract`는 제품 API와 OCR 큐 모두를 Vercel origin에 기본 연결하며, Lightning worker에는 `/health`, `/wake` 외 HTTP route가 없음을 정적 검사로 고정했다. 구형 채점 프록시 퇴역 및 OCR 큐 관련 회귀를 포함한 Python 73개 테스트가 통과했고 API/worker Python compile도 통과했다. 이 검증은 runtime의 Lightning/Supabase 연결이나 production schema 적용 증거는 아니다.
- 2026-10-12 추가 확인: Vercel CLI 세션은 `aiflow-web-canary`에 연결되고 Production의 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` 이름이 설정되어 있음을 값 노출 없이 확인했다. Supabase CLI는 프로젝트가 link되지 않았고 `psql`/원본 DB URL도 없어 실제 schema 조회·SQL 실행·migration은 진행할 수 없었다. Vercel env 실행 명령은 PowerShell 인자 전달 문제로 커맨드를 실행하지 못했고 임시 조회 스크립트는 제거했다. Production에 쓰기 요청은 전혀 보내지 않았다.
- 추가 보안 정리: Vercel용 OCR 큐·채점·카나리 인증의 `SECURITY DEFINER` 함수 `search_path`를 `pg_catalog,public`으로 고정해 시스템 카탈로그 우선 해석을 보장했다. SQL 계약 검사를 추가했고 전체 관련 Python suite **74개 통과**, compile 및 작업 파일 diff 검사 통과. 실제 DB lint/runtime 검증은 미실행이다.
- Flutter 계약 재확인: 이어풀기 계약, 대결 제출/결과/라우트/모바일 매치, 랭킹 쿼리, 레이팅 상세 테스트 **24개 통과**. 기존 `continue_strokes_recovery_ui_test.dart`는 `pumpAndSettle()`에서 종료되지 않고 기본 뷰포트에서 재시도 액션이 화면 밖 좌표로 잡혀 이번 검증 묶음에서 제외했다. 이 사용자 미커밋 테스트 파일은 변경하지 않았다.
- Level Test 경계: Level Test Vercel endpoint/seed 및 Lightning OCR-only boundary 테스트 **10개 통과**. 구형 레벨테스트 경로가 Lightning에 fall through하지 않음을 확인했다.
- SQL 검증 환경 재확인: 이 checkout에는 Supabase local config/migrations가 없고 Docker Desktop daemon이 응답하지 않아 `supabase db lint --local`도 실행 불가다. Production에 SQL을 적용하지 않았으며, 적용 전 실제 PostgreSQL lint가 남아 있다.

## API 일원화 재개 — 코스 순서 및 canonical 채점 계약 (2026-10-12)

- Vercel `POST /courses/enrollments/reorder`를 추가했다. 요청은 로그인 사용자가 소유한 코스의 완전한 순열만 허용하며, 누락·추가·중복은 저장하지 않는다. 순서는 기존 구매/진도 JSON을 덮지 않도록 사용자별 `canary_user_kv.course_enrollment_order` 별도 키에 저장하고, `/courses/enrolled`에서 적용한다.
- 채점 테스트가 현재 Vercel route가 아닌 폐기된 비동기/`_user_id` 호출 계약을 사용 중인 점을 확인했다. 이를 실제 `VariantGradeRequest` 및 인증 사용자 계약으로 정리했고, 상품 문항의 `correct_choice_index`도 채점기가 인식하도록 수정했다. 잘못된 객관식 정답 인덱스는 오답으로 조용히 처리하지 않고 503으로 닫는다.
- 검증: 집중 migration/OCR/arena/course-order 묶음 **45개 통과**. 마켓플레이스 배정·채점 및 코스 정렬 검사는 **18개 통과**. `api/index.py` compile 및 변경 파일 diff-check 통과.
- 제한: SQLite/테스트 계약만 검증했으며 운영 DB 변경, 실제 PostgreSQL 동시성, 로그인 상태 브라우저 채점, 배포/커밋은 수행하지 않았다. DB 연결과 SQL runtime 검증은 별도 접근이 필요하다.

## 소셜 제품 API의 미지원 WebSocket 호출 제거 (2026-10-12)

- 현재 Vercel에는 `/ws/social` WebSocket route가 없고, 학생 친구 화면만 해당 주소로 인증 토큰을 query에 넣어 재연결을 반복했다. 친구 화면은 이미 REST API를 4초 간격으로 폴링하며, 개인 대화는 REST API를 3초 간격으로 자체 갱신한다.
- Vercel 중앙 API 경로를 유지하도록 친구 화면의 WebSocket 연결·이벤트 핸들러를 제거하고, REST polling을 유일한 서버 갱신 경로로 남겼다. 미사용 `SocialWebSocketService`와 `ApiPaths.socialWs` 참조도 제거했다. 친구/대화 API 자체와 메시지 허브의 로컬 사용은 유지했다.
- 회귀 계약 검사 5개 통과. Flutter mobile suite에서 대화 탭 케이스 1개 통과 후 친구 찾기 요청 케이스가 79초 넘게 정지해 해당 프로세스를 중단했다. 따라서 해당 Flutter suite 전체는 통과로 계산하지 않는다. analyzer는 새 오류 대신 기존 unused/info 항목을 보고했으며, 새로 미사용이 된 쪽지 helper는 제거했다.
- 운영 데이터·DB·배포·커밋 변경 없음. 남은 종료 조건에는 운영 PostgreSQL SQL/RLS/동시성 검증, source ledger 안전 이관, 실제 OCR→채점 통합 사용 검증과 배포 전 확인이 여전히 포함된다.

## 학생 상태 데이터 migration의 기존 목적지 보존 (2026-10-12)

- `migrate_student_state_sqlite_to_supabase.py`가 목적지 테이블이 비어 있지 않으면 중단하던 단순 복사 정책을 안전 병합으로 교체했다. 기존 동일 키·동일 값은 멱등적으로 유지, 동일 키·다른 값은 중단, destination-only 행은 그대로 보존하고 source에서 없는 행만 삽입한다.
- 목적지의 두 테이블을 단일 serializable transaction 내에서 `SHARE ROW EXCLUSIVE` 잠금하고, allowlist 테이블만 임시 staging에 적재한다. 전체 non-key payload를 `IS DISTINCT FROM`으로 충돌 검사한 뒤 삽입하고 source 행 수가 전부 같은 값으로 매칭될 때만 커밋한다. source는 read-only이며 explicit SQLite read transaction을 사용한다.
- README 절차와 테스트를 갱신했다. 학생 상태·rating·풀이 이력·arena migration 및 OCR SQL 계약 **27개 통과**, Python compile 및 diff-check 통과.
- 실제 Supabase schema/권한/동시성 실행은 미검증이고 migration을 실행하지 않았다. 따라서 기존 사용자 SQLite/PostgreSQL 데이터를 실제 Supabase에 이관했다고 주장하지 않는다.
- PostgreSQL 런타임 lint를 재시도했으나 이 checkout에는 `supabase/config.toml`이 없고 local Postgres `127.0.0.1:54322` 연결이 `ECONNREFUSED`라 실행하지 못했다. 이 차단은 Production SQL Editor의 승인된 테스트 스키마 또는 별도 격리 PostgreSQL 접근이 있어야 해소된다.

## Supabase SQL UUID/text 컬럼 호환 수정 (2026-10-12)

- SQL type audit에서 `canary_users.user_id`와 `canary_user_kv.user_id`가 `uuid`인 반면 몇몇 Vercel RPC 인자는 호환성상 `text`인 것을 확인했다. 이로 인해 arena ranking의 profile/friend lookup 및 student-state의 solve-history/score-sheet 읽기·기록이 실제 PostgreSQL에서 `uuid = text` 또는 text→uuid 대입 오류를 낼 수 있었다.
- student-state RPC의 KV 조회·삽입에 `p_user_id::uuid`를 명시하고, arena leaderboard의 친구 KV 조회와 UUID profile join에도 캐스팅을 고정했다. 레거시 rating/arena_rating·OCR job·별도 student-state 테이블은 기존 `text` user ID 계약 그대로 뒀다.
- SQL contract, rating API, arena API/summary, 이관 도구 테스트 **41개 통과**, Python compile 및 변경 파일 diff-check 통과.
- SQL은 여전히 local PostgreSQL 런타임에서 실행되지 않았다. `supabase db lint --local`은 설정 파일이 없고 `127.0.0.1:54322` 연결이 거부되어 실패했다. 운영 SQL 수정·적용이나 데이터 변경/배포는 하지 않았다.

## 학생 상태 원본 UUID 적합성 및 계정 사전조건 검증 (2026-10-12)

- D: `omj/quests.db`를 SQLite read-only로 조회하고 사용자 ID 원문은 출력하지 않았다. `user_weakness_tags`는 사용자 3명, `continue_session`은 2명으로 집계됐으며 두 테이블의 distinct ID는 모두 UUID 형식이었다.
- 이관 도구는 source의 두 테이블에서 사용자 ID 집합을 먼저 읽어 UUID 형식을 검증한다. 목적지 transaction 안에서 상태 테이블 잠금 뒤 `canary_users` 계정 행도 쓰기 잠금하고 source 사용자 전원이 대상 계정에 존재하는지 확인한다. 없거나 ID 형식이 잘못되면 데이터 쓰기 전에 중단해 UUID FK 없는 상태 테이블에 접근 불가능한 사용자 데이터를 남기지 않는다.
- README에 동일 UUID 대상 계정 선행조건을 문서화하고 검사 추가. 학생 상태·rating·history·arena migration 및 SQL 계약 **31개 통과**, Python compile/diff-check 통과.
- 대상 `canary_users` 계정 일치 수는 Supabase 연결이 없어 확인하지 않았고 migration은 실행하지 않았다. source 사용자 수만으로 대상 계정 보존을 완료했다고 볼 수 없다.

## 풀이 이력 migration의 UUID 및 대상 계정 검증 (2026-10-12)

- `migrate_solve_history_to_supabase.py`가 source `user_id`를 UUID로 검증·정규화하지 않고 text 파라미터로 UUID형 `canary_user_kv.user_id`에 전달하고, 같은 사용자 계정이 목적지에 있는지 사전 확인하지 않는 것을 발견했다.
- 이관 시작 전 source의 distinct 사용자 ID를 전부 UUID로 검증하고, destination transaction에서 `canary_users`와 `canary_user_kv`를 잠근 뒤 모든 ID가 일치하는 계정 행을 갖는지 확인한다. 이후 UUID adapter로 insert/readback하며 기존 deterministic key의 동일 값은 재실행에서 유지하고, 충돌은 rollback한다. 새 데이터 검증 실패는 write 전에 중단한다.
- README와 단위 테스트를 갱신했다. 풀이 이력·학생 상태·rating/arena migration 및 continuation 계약 검사 **29개 통과**, Python compile/diff-check 통과.
- 운영 source PostgreSQL과 Supabase 대상에 접근하지 않아 풀이 이력 사용자 UUID·계정 일치 및 복사 검증은 미실행이다. DB 쓰기와 배포 없음.

## 대결 마지막 답안과 레이팅 원장 원자화 (2026-10-12)

- 확인 결과 `/arena/matches/{id}/result` GET이 `complete_arena_practice_result`를 처음 호출해 레이팅을 기록하고 있었다. 완료된 답안 제출 직후 사용자가 화면을 닫거나 결과 GET을 호출하지 않으면 랭킹이 누락될 수 있고, GET의 부수효과에 의존했다.
- `submit_arena_practice_answer` SQL RPC가 마지막 답안을 저장한 같은 DB transaction에서 `complete_arena_practice_result`를 호출하도록 연결했다. 최종 답안·경기 finished state·+20/−10/0 결과 원장 및 rating row가 함께 commit/rollback되고, 답안 재시도와 결과 GET은 동일 match idempotency key를 사용한다.
- SQL contract, 결과 노출/ACK, arena ranking API/summary, auth 및 migration 검사 **37개 통과**, 변경 SQL diff-check 통과. PostgreSQL runtime/concurrency는 아직 검증하지 않았다.
- UI 결과 조회는 저장된 멱등 영수증을 읽는 재호출 경로로 남아 이전 경기 복구를 지원한다. SQL 적용, 운영 데이터 이관·쓰기, 배포 없음.

## Vercel 아레나 REST 경로 정리 (2026-10-12)

- 아레나 화면이 미구현 `/ws/arena`에 먼저 연결한 뒤 실패 시에만 Vercel REST 폴링으로 전환하던 호출을 확인했다. 배포 앱은 이제 시작부터 Vercel REST 상태조회·폴링과 멱등 답안 제출만 사용한다. WebSocket 구현체와 연결 메서드는 제거하고 테스트 전용 이벤트 소스 인터페이스만 남겼다.
- `/arena/matches/{id}/chat` Flutter 호출은 Vercel에 대응 route가 없고 현재 Vercel queue도 solo bot practice만 지원하므로, 연결되지 않은 팀 채팅 버튼/UI와 API 메서드를 제거했다. 실제 팀전/채팅 백엔드 기능을 구현한 것은 아니다.
- Python arena API/SQL 계약 테스트 **17개 통과**. Flutter analyzer는 arena 기존 info/warning 37건을 보고했고 새 compile error는 출력하지 않았지만, exit code는 경고 때문에 1이었다. Flutter widget test는 기존처럼 30초간 로딩만 보여 중단했으므로 통과로 계산하지 않는다.
- 정적 검색에서 `/ws/arena`, 미지원 arena chat API 호출 참조가 남지 않음을 확인했다. 사용하지 않는 `ApiContract.webSocketUri`와 Flutter `web_socket_channel` 직접 의존성도 제거했다. 데이터베이스 SQL 런타임 검증·배포·커밋 없음.
- Lightning OCR 경계·Vercel OCR 큐·채점 SQL 계약 검사 **18개 추가 통과**. Lightning 추론 API 권한이나 실제 OCR→채점 네트워크 플로우는 별도 실환경 확인 전까지 미검증이다.
- API 중앙화 소스 회귀 검사에 아레나 미지원 WS/채팅 경계를 추가했고, product centralization·Lightning OCR·arena result/SQL 검사 **23개 통과**.
- 이어 API 중앙화, Lightning OCR, Vercel OCR queue/grading, arena rankings/result/SQL, rating·student-state·solve-history migration 및 continue proxy를 합쳐 **81개 통과**. `SUPABASE_ACCESS_TOKEN`의 Management API project-list 응답은 빈 목록이었고 이전 참조 프로젝트 상세 조회는 HTTP 403이었다. 이 실행 환경에서는 Supabase SQL 배포 권한을 확인하지 못해 운영 SQL migration은 계속 미실행이다.

## Lightning OCR worker의 Vercel 전용 API 경계 강화 (2026-10-12)

- Lightning worker에서 Supabase service-role/RPC 직접 접근과 범용 `analysis_service` import를 제거했다. 이제 Lightning은 TexTeller handwriting OCR만 실행하며, Vercel 내부 HTTPS API로 작업을 선점·완료·실패 처리한다. DB credential과 채점/제품 로직은 Vercel에만 둔다.
- Vercel은 worker 전용 secret을 상수시간 비교하고, claim 시 필기 이미지와 정규화된 획 좌표만 전달한다. callback 결과도 OCR 필드 allowlist·크기 제한을 적용하고 기존 lease RPC의 멱등 처리를 유지한다. Lightning wake 인증과 Vercel callback 인증은 별도 secret이다.
- Flutter의 `OCR_QUEUE_BASE_URL` 덮어쓰기를 제거했다. OCR 큐 주소도 `ApiContract.baseUrl`의 Vercel origin(`/api/ocr`)에 고정하여 Flutter 빌드 설정으로 Lightning 또는 별도 호스트를 직접 지정할 수 없게 했다.
- 사용되지 않는 레거시 `analysisOcr` 경로 상수도 제거했다. Flutter/lib·test·배포 설정에서 `/analysis/ocr`, Lightning 공개 주소, 구 큐 override가 남지 않는 것을 검색으로 확인했다.
- Flutter 큐 응답 사용처를 확인했다. OCR 결과는 이후 Vercel 채점 결과를 기존 `SolveAnalysisResponse`로 역직렬화하며, `debug`는 선택 필드다. 이번 OCR-only 결과 축소는 해당 응답 계약을 변경하지 않는다.
- 중앙 API/Lightning 경계, OCR 큐·채점 SQL, rating·student-state/history migration, arena 및 회귀 테스트 **95개 통과**. Python compileall과 변경 파일 diff-check 통과. Lightning 환경 예제에는 Supabase/JWT/Kiln 자격 증명이 없음을 확인했다.
- 배포·커밋·운영 DB 변경은 하지 않았다. Vercel `VERCEL_OCR_WORKER_SECRET` 및 Lightning의 같은 worker secret, `VERCEL_API_BASE_URL` 실제 배포 설정과 OCR→채점의 배포본 네트워크 동작은 아직 검증되지 않았다. Supabase Management API 권한도 이전과 같이 확인 불가 상태다.
- Flutter widget test는 `build/unit_test_assets` 경로를 직접 준비한 뒤에도 디렉터리 확인 권한 오류로 실행되지 않았다. `dart analyze lib/shared/services/api/api_contract.dart`는 통과했다. Flutter CLI에는 `test --build-dir` 옵션이 없어 다른 드라이브로 우회하지 않았고, 관련 Python 계약 테스트는 고정된 Vercel OCR origin 검사까지 포함해 모두 통과했다(전체 95개, 후속 변경분 집중 27개).
- Vercel CLI의 `aiflow-web-canary` Production 변수명만 읽기 전용으로 확인했다. 기존 Supabase/JWT/Kiln 변수는 있으나 `LIGHTNING_WAKE_URL`, `LIGHTNING_WAKE_SECRET`, `VERCEL_OCR_WORKER_SECRET`은 없었다. 값은 조회하지 않았고 env 쓰기·재배포는 하지 않았다. 따라서 현재 배포본의 Lightning OCR 연결은 미구성 상태로 취급한다.
- 이 구성 누락 상태에서 OCR 요청이 payload를 DB에 적재한 채 202를 반환하고 Flutter를 장시간 대기시키는 동작을 확인했다. Vercel은 제출 전에 HTTPS wake URL 및 wake/callback secrets를 검사하고 하나라도 없거나 URL이 malformed/HTTP면 `503 ocr_worker_unavailable`로 거절해 이미지 데이터가 큐에 쌓이지 않도록 했다. 누락·HTTP·malformed URL·각 secret 누락의 fail-fast를 검증했다.
- 관련 회귀 범위 전체 **100개 통과**, Python compileall과 변경 파일 diff-check 통과. Production 설정 자체는 변경하지 않아 OCR 실행 복구는 세 변수가 안전하게 설정된 뒤 별도 검증해야 한다.
- 추가 환경 확인: 로컬 `psql`/`postgres`/`pg_ctl`이 없고 `127.0.0.1:5432` 및 `:54322`가 닫혀 있다. Docker CLI는 있으나 Docker Desktop Linux engine pipe가 없어 격리 PostgreSQL을 시작할 수 없었다. 따라서 실제 PostgreSQL 함수 실행/동시성 검증은 미실행이다.
- Flutter test 출력 경로도 재확인했다. 기존 `build/unit_test_assets`는 2026-09-11 생성된 폴더이나 Windows가 ACL 조회와 listing을 `Access denied`로 거부한다. 이 폴더 권한을 바꾸거나 삭제하지 않았다. 실제 빌드 임시물은 `build/temp`에 남아 있고 2,169개·1,454,145,221 bytes였으며 삭제/이동하지 않았다.

## 대결 답안 RPC 멱등성 계약 재검증 (2026-10-12)

- `submit_arena_practice_answer`는 사용자별 `arena.active_match` 행을 `FOR UPDATE`로 잠그고 match·문항·완료 상태를 확인한 뒤 답안을 저장한다. 같은 idempotency key와 fingerprint는 저장된 응답을 재생하며, 같은 키에 다른 fingerprint를 보내면 충돌로 거절한다.
- 마지막 답안 저장과 `complete_arena_practice_result` 호출은 하나의 PostgreSQL 함수 호출 안에 있어 DB transaction으로 원자화된다. 함수 실행 권한은 service role로 제한된다. answer/rating SQL contract 및 API 경계 집중 검사 **21개 통과**(third-party deprecation warning 1개).
- 이는 SQL 소스 계약 검사이지 PostgreSQL 동시 실행 증거가 아니다. 실제 DB runtime 부재, Supabase SQL 권한 미확인, Lightning OCR Production 환경변수 누락은 미해결이다. 운영 DB 변경·배포·커밋 없음.

## 제품 API 경계 재검색 및 회귀 검사 (2026-10-12)

- `lib`, `api`, `services`, Lightning 배포 코드와 관련 테스트에서 Lightning 공개 URL/일반 앱 프록시/Flutter OCR origin override의 제품 호출 참조를 재검색했다. 남은 `/analysis/solve*`는 Vercel FastAPI 경로이며, Lightning 사용은 Vercel OCR 제출 후 Studio를 깨우고 Vercel 내부 OCR 작업 API로 claim/complete/fail하는 인프라 경로뿐이다. Worker는 OCR 전용 route와 TexTeller 실행 경계 테스트 대상이다.
- OCR queue/grading, API centralization, Lightning worker 경계, rating/arena SQL 계약, 학생 상태·풀이 이력·rating/arena migration 도구 집중 회귀 검사 **83개 통과**(3개 dependency deprecation warning). 첫 시도에서 존재하지 않는 테스트 파일명을 지정해 pytest가 테스트 수집 전에 종료됐고, 실제 파일 목록을 확인해 유효한 suite로 재실행했다.
- 실제 배포 Production OCR 변수는 앞선 이름 조회에서 누락된 상태다. SQL migration 권한/runtime, OCR 배포본 네트워크 실행은 여전히 검증되지 않았다. 운영 설정·DB·배포·커밋은 변경하지 않았다.

## Vercel health 식별자 정정 및 배포 상태 확인 (2026-10-12)

- Canary의 읽기 전용 `GET /health`는 HTTP 200을 반환했지만 payload가 `service: aiflow-ocr-queue`로 잘못 표시됐다. 코드 경로는 Vercel의 `api/index.py`이며 Lightning worker와 분리돼 있으므로 `aiflow-student-api`로 정정하고 `/health` 및 `/health/ready` 응답의 서비스 식별자를 테스트에 고정했다.
- Canary `GET /health/ready`는 HTTP 200이며 레벨테스트 테이블·문항 bank 확인 결과만 포함한다. 이 응답은 모든 제품 API나 OCR worker의 end-to-end 준비 상태를 증명하지 않는다. 로컬 집중 검사 **10개 통과**(Starlette deprecation warning 1개), diff-check 통과.
- 코드는 미배포 상태이므로 라이브 `/health`의 이전 이름은 의도된 현 배포 증거다. 배포는 하지 않았다.

## PostgreSQL 및 PL/pgSQL 스크립트 파싱 (2026-10-12)

- `supabase db lint --help`에서 linked DB 검사 옵션을 확인했으나 CLI는 `Cannot find project ref. Have you run supabase link?`로 종료했고 프로젝트 연결 파일이 없어 원격 DB lint는 수행하지 않았다. DB 쓰기나 link 설정은 하지 않았다.
- 작업본 `deploy/vercel/*.sql` 6개 전부 PostgreSQL parser `pglast 8.5`의 `parse_sql`로 파싱 성공했다. 스크립트 안 PL/pgSQL 함수 21개도 `parse_plpgsql` 통과했다.
- 이는 문법 파싱 근거일 뿐 schema/type/function resolution, PostgreSQL 실행·동시성, Supabase 대상 migration 성공을 증명하지 않는다. parser 임시 환경/cache는 D: worktree의 `build/uv-cache`에 두었다. SQL 계약 테스트는 별도로 유지한다.
- SQL parser 검사 후 API 중앙화, Lightning OCR 전용 worker, OCR/채점, rating/arena/학생 상태·풀이 이력 migration, expanded level-test를 함께 실행해 **89개 통과**(의존성 deprecation warning 3개). 테스트 파일 diff-check 통과.

## Supabase 대시보드 상태 확인 (2026-10-12)

- 현재 로그인된 Supabase 브라우저 세션에서 project `aybqetiydxafeuzudltb`의 overview를 읽기 전용으로 확인했다. dashboard는 `Healthy`, `main PRODUCTION`, GitHub integration `kuseumkkrkkr/Upstudy-app`을 표시했다. 어떠한 SQL도 실행하거나 설정을 변경하지 않았다.
- dashboard의 Advisor는 59개 이슈를 표시했고, 초기 화면에 `academy_group_member`, `member_event_log`, `attendance_log`, `finance_ledger` 등 public schema의 RLS disabled 경고 일부가 노출됐다. 이들은 범위 외 기존 데이터에 영향이 있으므로 이번 API/마이그레이션 작업에서 정책을 임의 변경하지 않는다. 대상 rating/student-state/arena 테이블의 실제 RLS 정책은 아직 확인하지 않았다.
- CLI `supabase projects list`는 project ref를 찾지 못하고 빈 목록을 반환했다. 브라우저 세션은 있으나 CLI link/auth와 DB connection credentials는 미확인이라 원격 lint·migration 검증은 여전히 불가하다.
- Table Editor는 기존 `public.level_test_question_bank`를 열어 `question_id`, `version`, `question_index`, `quest_title`, `quest_answer` 열과 776 records를 표시했다. 이 DB에 문항 데이터가 이미 있으므로 원격 migration 작업 전 사전/사후 count와 content digest가 필요하다. UI 조회만 했고 수정하지 않았다.
- Security Advisor의 초기 11개 목록에서 RLS disabled로 확인된 공개 테이블에 `user_problem_history`가 포함됐다. 현 Vercel source scan에서는 해당 테이블을 읽고 쓰지 않으며 새 solve history는 user-scoped `canary_user_kv`에 저장한다. 이 legacy finding을 이번 API migration에서 임의 변경하지 않았고, 목표 대상 신설 테이블의 실제 remote RLS 상태는 확인하지 않았다.

## 임시 PostgreSQL-WASM에서 SQL 함수 실행 검증 (2026-10-12)

- Supabase SQL 6개를 PGlite `0.5.8` 메모리 DB에 적용했다. `anon`, `authenticated`, `service_role` 역할은 임시로 생성했고, PGlite 미지원인 `pgcrypto` extension 선언과 `pg_cron` 정리 job만 실행본에서 제외했다. 저장소 SQL 원본은 변경하지 않았다.
- `apply_rating_submission`: 최초 반영 후 동일 제출 재생과 다른 quest ID 충돌을 실행하고 receipt/tag attempt/recent count가 각각 한 번만 증가함을 확인했다.
- continuation RPC: 강제 종료 저장·조회와 완료 기록 이후 continuation 제거를 실행 확인했다. arena RPC: 10문항 제출 후 마지막 답안이 1개 결과·rating 영수증을 남기고 재시도에서 같은 응답/동일 rating을 유지했다.
- OCR grading RPC: grade finalization·canonical weakness count·solve history를 실행하고 재시도 중복 증가가 없음을 확인했다. 잘못된 시험 메타데이터에서 grade/history/weakness/score sheet 쓰기가 전부 rollback되는 것도 확인했다.
- 이는 단일 PGlite 데이터베이스에서의 SQL body 실행 증거이며, Supabase/PostgreSQL 실제 런타임·extension/cron 동작·여러 연결 동시성·원격 데이터와 계정 보존을 대체하지 않는다. 운영 SQL·사용자 데이터·배포는 변경하지 않았다.
- 같은 PGlite schema에서 `canary_user_kv`, `user_rating`, `user_tag_rating`, `rating_submission`, `user_weakness_tags`, `continue_session`, `arena_rating`, `arena_match_result`, `ocr_jobs` 9개 테이블의 RLS 활성과 `anon` SELECT 차단을 확인했고, rating/arena RPC의 anon/service_role 실행 권한을 확인했다. **PASS**. 이는 배포된 Supabase의 실정책을 읽은 결과가 아니라 migration SQL이 만드는 권한 결과다.

## API 기본 주소 문서 정합성 및 회귀 검사 (2026-10-12)

- 루트 `README.md`가 Flutter API 기본값을 `http://localhost:8000`으로 잘못 표기하고 과거 auth 흐름을 설명하는 것을 확인했다. 문서를 중앙 `ApiContract` 기본 Vercel canary, 명시적인 로컬 개발 override, `API_PATH_PREFIX`/auth path override, Lightning TexTeller OCR 전용 경계로 갱신했다.
- README의 기본 API 주소와 Lightning 경계에 대한 회귀 검사를 추가했다. API centralization·worker·OCR/grading·rating·arena·migration·level-test 통합 suite **90개 통과**(3 dependency deprecation warnings); 변경 파일 diff-check 통과.
- 이번 문서/테스트 변경은 배포·API 계약 변경·사용자 데이터 변경을 하지 않았다.

## SQLite 학생 상태 원본 이관 기준선 (2026-10-12)

- `omj/quests.db`를 SQLite read-only/`query_only`로 열어 전체 행을 키 순으로 정규화하고 사용자 ID·필기 값은 출력하지 않은 SHA-256 기준선을 만들었다.
- `user_weakness_tags`: **36행, 사용자 3명**, SHA-256 `3949120957567ef5d46330ee8c9fb6a3baf01edc2227a8c4e7e9591989f31f43`.
- `continue_session`: **2행, 사용자 2명**, SHA-256 `0ad0bda058a6ea389e977c4df40f76b5f67cafc699aa04949161161c373286e0`.
- 해당 사용자 ID들이 Production `canary_users`에 있고 값이 일치하는지는 확인되지 않았다. 이 수치와 digest는 source baseline일 뿐 migration 또는 destination preservation 증거가 아니다. source·target 모두 변경하지 않았다.

## Vercel Production OCR 설정 재확인 (2026-10-12)

- `vercel env ls production`을 다시 실행해 이름만 조회했다. 프로젝트 `aiflow-web-canary`에 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `OMJ_JWT_SECRET`, `KILN_API_KEY` 등은 있으나 OCR worker 연결에 필요한 `LIGHTNING_WAKE_URL`, `LIGHTNING_WAKE_SECRET`, `VERCEL_OCR_WORKER_SECRET`은 여전히 없다.
- 값은 출력하지 않았고 Vercel 변수 변경·재배포는 하지 않았다. 운영 OCR은 코드상 fail-fast를 유지하지만 live OCR 복구/채점 E2E는 이 설정 없이는 검증 불가다.

## 평점·대결 원본 데이터 이관 코드 재검토 (2026-10-12)

- `tools/migrate_rating_to_supabase.py` 및 `tools/migrate_arena_rankings_to_supabase.py`는 `--apply` 없이는 접속하지 않고, `hotfix` 체크아웃만 허용한다. 원본 연결은 transaction read-only + repeatable-read, 대상 연결은 단일 serializable transaction이다.
- 이관 대상은 명시된 열 allowlist뿐이다. 대상의 같은 키·다른 값은 충돌로 처리해 전체 transaction을 롤백하며, 같은 행은 유지하고 누락 행만 `ON CONFLICT DO NOTHING`으로 삽입한다. 원본 count/digest와 대상 일치 행 count를 비교한다. 목적지 전용 행을 삭제하거나 갱신하지 않는다.
- 원격 실행은 하지 않았다. 테스트 계정 매핑·원본/대상 전체 count 및 digest 일치, Supabase 실제 동시성은 미검증이다.
- 현재 소스에서 평점·대결·학생 상태·풀이 이력 migration 및 Lightning OCR-only 경계에 직접 해당하는 6개 테스트 파일 **35개 통과**. 이는 migration 프로그램의 회귀 확인이며 실제 원격 데이터 보존을 증명하지 않는다.
- 작업 브랜치 `hotfix`, HEAD `1b1ccbbca155b2c3200688d30b0502ae877b39bb`; 변경은 문서/테스트/이전 작업 상태를 보존한다. 이 검증에서는 커밋·DB 변경·배포가 없었다.

## Flutter API 및 Lightning 런타임 경계 재검사 (2026-10-12)

- `lib/shared/services/api/api_contract.dart`는 기본 제품 API를 Vercel Canary로 두고, OCR queue도 같은 origin의 `/api/ocr`를 사용한다. Flutter 소스 검색에서 Lightning origin 직접 호출은 확인되지 않았다.
- 배포 worker `deploy/lightning/worker_app.py`는 TexTeller OCR 함수만 가져오고 Vercel의 OCR claim/complete/fail endpoint로만 통신한다. `mode != ocr` 및 OCR 외 payload 필드를 거부하며, 별도 product API route는 `/health`, `/wake` 외에 없다. Vercel `/analysis/solve`는 retired proxy로 410을 반환한다.
- 위 계약을 고정하는 `test/api_contract_test.dart`를 추가했다. `dart format --output=none --set-exit-if-changed` 통과, `dart analyze test/api_contract_test.dart`도 `No issues found`.
- Flutter 실행 테스트는 저장소의 `build/unit_test_assets`에 대한 Windows `Access denied`로 실행되지 않았다(일반/`--no-test-assets` 모두 동일). 디렉터리 권한 변경이나 삭제는 하지 않았다. 따라서 새 Dart 테스트는 아직 runtime 검증되지 않았다.
- API 중앙화·worker boundary·OCR queue·rating·arena summary/rankings·continuation 관련 Python 회귀 테스트 **41개 통과**(기존 deprecation 및 짧은 테스트 키 경고).

## SQLite 풀이 이력 스냅샷과 활성 PostgreSQL 원본 구분 (2026-10-12)

- `omj/quests.db`는 Git 추적 파일이며 SQLite read-only/`query_only` 확인에서 `solve_history` 33행(problem, 3개 user ID, created_at 2026-04-24~2026-07-08), JSON object 33개가 확인됐다. 정규화 전체 row SHA-256은 `72d2a711eac7819073a162cfada770eb8c641dbe2e88cdb9c28f792ccf06004c`. 3개 source ID 중 1개는 UUID가 아니다.
- 현재 `omj/storage/solve_history.py`는 `infra.db.postgres_compat.connect()`로 활성 PostgreSQL에 쓰고, `omj/rating_service.py`도 `PostgresRatingStore`를 사용한다. Vercel 이관 도구가 PostgreSQL `solve_history`를 대상으로 하는 것은 현재 writer와 일치한다. Git 추적 SQLite DB는 과거/local snapshot으로 분류하며 PostgreSQL 이관 원본이라고 단정하지 않는다.
- 별도 SQLite rating 집계에는 `user_rating` 11행, `user_tag_rating`/`rating_submission`은 각각 0행이 확인됐다. 이는 Supabase UI에서 앞서 확인한 rating 11행/태그 61행/제출 5행과 source type·내용 대조가 끝나지 않았다는 뜻이며, 수치만 같다고 같은 사용자/기록으로 취급하지 않는다.
- 같은 SQLite 원본의 레거시 `user_tag_stats`는 150행이다. 런타임 `omj/rating_service.py`는 `PostgresRatingStore`를 사용하고 `omj/storage/postgres_rating_store.py`의 테이블 계약은 `user_tag_rating`이므로 SQLite `user_tag_stats`는 별도 fallback 데이터로 분리해 둔다. 활성 계정·최근 writer 확인 전에는 이를 authoritative tag rating으로 승격하지 않는다.
- SQLite solve history의 3개 source identity 중 2개 UUID는 `users` 테이블과 맞아 32/33행이 로컬 계정에 연결되고, 나머지 1행은 UUID가 아닌 orphan identity다. 로컬 계정 일치만으로 Supabase 계정 소유권이 증명되지는 않는다.
- SQLite rating 집계에는 `user_rating` 11행과 `user_tag_stats` 150행이 있고, SQLite `user_tag_rating`/`rating_submission`은 각각 0행이다. PostgreSQL active table 계약은 `user_rating`/`user_tag_rating`이므로 SQLite 집계를 해당 원장으로 합치지 않는다.
- SQLite와 active PostgreSQL의 lineage/중복을 실제 DB에서 대조하고 비-UUID legacy identity의 계정 연결을 확인하기 전에는 SQLite snapshot을 Supabase에 추가하지 않는다. 이는 불필요한 재수입·사용자 귀속 오류를 막는 source hold이며, 현 active writer용 PostgreSQL migration을 대체하지 않는다. 원본/대상 모두 변경하지 않았다.
- Vercel `env run`으로 계정 ID를 읽기 전용 대조하려 했으나, child process에 `SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`가 전달되지 않아 HTTP 요청 전에 실패했다. 확인한 로컬 `.env`에는 `COMETAPI_KEY`만 있고 수정 시각도 2026-08-29 그대로였다. Vercel은 Sensitive/Secret 값을 로컬에서 읽을 수 없도록 할 수 있으므로 이 probe만으로 런타임 설정 누락을 단정하지 않는다. Supabase 데이터는 조회되지 않았다. 실패 traceback이 로컬 UUID 문자열 2개를 도구 출력에 포함했으므로 식별자를 문서·로그에 복사하지 않는다. 임시 probe 스크립트는 제거했다.
- 위 source hold 및 worker 경계 변경 후 중앙 API·worker·OCR/grading·rating·arena·continuation·4종 migration·level-test focused suite **82개 통과**(29개 기존 deprecation/짧은 테스트 JWT key 경고). 실행은 로컬 테스트/fixture이며 실제 Supabase 동시성과 원격 데이터 검증은 포함하지 않는다.

## Flutter 네트워크 목적지 재검색 (2026-10-12)

- `lib/**/*.dart`의 URL/네트워크 호출을 다시 검색했다. 하드코딩된 HTTP 주소는 OSM 타일, Unsplash 이미지, JSXGraph CDN, 그래프 참고 링크뿐이다. 제품 API origin을 가리키는 하드코딩 주소나 Lightning/Supabase 직접 호출은 발견되지 않았다.
- HTTP 호출처는 auth/API service 및 API client에 한정되고 `ApiContract.uri`/`ApiContract.ocrQueueBaseUrl`을 사용한다. `exam_preview_page.dart`의 URL 파싱은 API origin이 아니라 서버가 준 문서 URL 열기 경로다. 이 정적 검색은 런타임 프록시/redirect 검사나 배포 번들 검증을 대체하지 않는다.

## 레거시 풀이 이력 사용자 ID 명시 매핑 및 회귀검증 (2026-10-12)

- 활성 PostgreSQL 풀이 이력 도구에서 UUID가 아닌 legacy user ID를 조용히 제외하거나 다른 계정으로 추정 연결하지 않도록 명시적 1:1 매핑 옵션 `SOURCE_SOLVE_HISTORY_USER_ID_MAP_JSON`을 추가했다. 매핑은 환경변수에서만 읽고, 로그·명령 인자·저장소에 ID 값을 출력/기록하지 않는다.
- 대상 UUID 유효성, source에 없는 키, malformed JSON, UUID identity 재할당, 여러 source 계정의 단일 대상 계정 병합을 거부한다. 최종 매핑 대상은 기존 `canary_users.user_id`와 대조한다.
- 관련 focused suite를 재실행했다: `py_compile` 성공, API 중앙화·Lightning OCR 경계·OCR/채점·평점·대결·continuation·4개 데이터 migration·레벨테스트의 **88개 테스트 통과**. 기존 dependency deprecation 및 짧은 테스트 JWT 키 경고 29개가 남아 있다. 변경 파일 `git diff --check` 통과.
- 이 검증은 migration 코드/fixture만 확인했다. Supabase 계정 매핑·원격 행 수와 digest·다중 연결 동시성은 미검증이며 원본/대상 DB와 배포는 변경하지 않았다.
- 추가 정적 검색에서 Lightning 호출은 Vercel OCR 큐의 worker wake/Studio 재개와 OCR worker 구현으로 한정됐다. `/analysis/solve/variant-grade`는 Vercel 측 canonical 채점 경로로 남고, 구 `/analysis/solve`는 퇴역 경로(410)다. Flutter의 Lightning 직접 호출이나 일반 제품 API 프록시 호출은 검색 결과에서 확인되지 않았다. 이는 소스 정적 검색 결과이며 실제 배포 네트워크 동작 검증은 아니다.

## Flutter 채점 API 경로 계약 연결 (2026-10-12)

- `ApiClient.gradeVariantSolve`가 중앙 `ApiPaths.analysisVariantGrade` 대신 경로 문자열을 직접 사용하던 부분을 계약 상수 참조로 바꿨다. `test/api_contract_test.dart`에도 채점 경로와 Vercel origin 검사를 추가했다. 요청 경로/본문/응답 동작은 바꾸지 않았다.
- Dart formatter 검사 통과(변경 없음), 대상 Dart 분석에서 오류 0건(기존 info lint 4건). 새 Flutter 테스트 실행은 `build/unit_test_assets` 접근 거부로 시작되지 않았다. 해당 디렉터리는 권한/내용을 변경하지 않았다.
- Flutter test runner 대신 임시 순수-Dart probe를 `dart run`으로 실행해 Vercel 기본 origin, grading API path, auth path의 resolved origin을 검증했다. **PASS**. probe 파일은 실행 후 제거했다. 이는 API URI 실행 확인일 뿐 Flutter widget/runtime test를 대체하지 않는다.
- Python API/worker/마이그레이션 focused suite의 88개 통과 결과는 이전 코드 검증에 해당하며, 이번 Dart 연결 변경에 대한 Flutter runtime 증거로 간주하지 않는다.

## Flutter 직접 backend 접근 회귀 방지 (2026-10-12)

- Flutter `lib/**/*.dart`의 직접 API/URL 참조를 정적으로 검색했다. OSM·Unsplash·JSXGraph CDN·그래프 출처 URL만 확인됐고, Lightning·OCR backend·Supabase 직접 호출은 발견되지 않았다.
- 이 경계를 자동화하기 위해 Flutter 소스에서 Lightning host, OCR Canary host, Supabase REST origin/SDK 직접 참조를 차단하는 Python 회귀검사를 추가했다. centralization·worker API boundary 3개 테스트 파일 **11개 통과**(기존 FastAPI `on_event` deprecation warning 2개).
- 이는 소스 정적 회귀검사다. 현재 Vercel alias는 최신 hotfix 빌드라는 Git source SHA 증거가 없으며 Flutter test runner는 `build/unit_test_assets` 접근 오류로 실행 불가하다.
- Flutter 채점이 `ApiPaths.analysisVariantGrade`만 사용하고 퇴역 경로 `ApiPaths.analysisSolve`를 호출하지 않는 검사도 추가했다. centralization·Lightning worker/OCR·Vercel OCR queue/grading receipt/rating/arena/continuation 관련 focused suite **51개 통과**(기존 deprecation/테스트 JWT 키 경고 29개).
- 위 변경 상태에서 SQL contract·4종 migration·레벨테스트까지 포함한 전체 focused suite를 다시 실행해 **97개 통과**, 기존 deprecation/짧은 테스트 JWT key 경고 29개를 확인했다. 배포·원격 DB 쓰기는 없었다.

## Flutter 테스트 asset 경로 차단 원인 추가 확인 (2026-10-12)

- 로컬 Flutter SDK의 `flutter test --help`에는 테스트 산출물 경로 옵션이 없다. SDK `test.dart`는 native asset manifest가 반환되면 `<project>/build/unit_test_assets`를 직접 확인/생성하는 고정 경로를 사용한다. `--no-test-assets`도 native asset 경로 사용 자체를 끄지 않는다.
- 현재 이 고정 D: 경로에서 접근 거부가 재현된다. 폴더 권한·내용은 변경하지 않았고, 빌드 경로를 C:로 돌리거나 프로젝트를 복제하지 않았다. 따라서 Flutter test runner 검증은 차단으로 남는다.

## 원격 CLI 연결 재확인 (2026-10-12)

- `supabase projects list`는 `Cannot find project ref. Have you run supabase link?`와 빈 목록을 반환했다. 원격 DB 연결이나 데이터 조회가 되지 않았다.
- 2026-10-12 재확인에서도 `supabase projects list --output json`은 같은 안내와 `[]`를 반환했고 checkout에는 `supabase/` project config가 없다. 현재 관리 중인 Vercel Supabase ref를 코드/환경 출력에서 확인할 수 없어 임의로 프로젝트를 link하지 않았다.
- `vercel env ls production`은 민감한 값은 출력하지 않고 변수 이름만 확인했다. `SUPABASE_URL`, service-role key, `OMJ_JWT_SECRET`, `KILN_API_KEY`는 존재하지만 `LIGHTNING_WAKE_URL`, `LIGHTNING_WAKE_SECRET`, `VERCEL_OCR_WORKER_SECRET`은 없다. Production 환경변수는 변경하지 않았다.
- computer-use `list_apps` 결과에는 대상 브라우저 창이 없어 인증된 Supabase dashboard를 확인할 수 없었다. 로그인/SQL 실행/원격 쓰기를 시도하지 않았다.
- 2026-10-12 computer-use app inventory에서도 실행 중인 Edge/Chrome/Firefox 창이 없어 이미 로그인된 Supabase dashboard에 접근할 수 없었다. 대시보드 실행·로그인 자동화는 하지 않았다.
- 2026-10-12 Codex 내장 브라우저에는 Supabase에 로그인되어 있었고 프로젝트 `aybqetiydxafeuzudltb`가 `Healthy`, `main PRODUCTION`, GitHub `kuseumkkrkkr/Upstudy-app`으로 표시됐다. Vercel `aiflow-web-canary` Production 변수 목록에는 `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `OMJ_JWT_SECRET`, `KILN_API_KEY`가 있으나 값은 열지 않았다. OCR worker 환경변수 3개는 목록에 없었다.
- `SUPABASE_URL`을 공개하거나 reveal하지 않아 Production Vercel이 이 Supabase project ref를 실제 사용 중인지 아직 일치 검증되지 않았다. 내장 Supabase SQL editor에서 쿼리/마이그레이션을 실행하지 않았고, DB·Vercel 상태 변경도 없었다. 대시보드 인증 세션은 CLI에 연결되지 않아 `supabase projects list`는 계속 빈 목록이다.
- 따라서 실제 Supabase 데이터 소유권·count/digest·RLS·동시성 및 Production OCR 연동은 아직 검증되지 않았다. 사용자 데이터 보존을 입증하기 전까지 데이터 migration과 배포는 계속 보류한다.
- `vercel env run -e production -- <command>`는 문서대로 구분자를 전달해도 Python child에서 Supabase/OMJ/OCR 환경변수 존재가 모두 `false`였다. `.env`는 사전 기록과 같은 103 bytes, 수정시각 2026-08-29, 변수명 `COMETAPI_KEY`만 유지됐고 내용 변경은 없었다. Secret 값은 출력·저장하지 않았다. CLI child를 통한 DB 사전검증은 여전히 불가하다.
- Vercel CLI 공식 문서는 `env run`이 값을 파일에 쓰지 않고 child에 전달한다고 명시한다. 실제 child에서 위 key들이 보이지 않은 관찰과 로컬 문서 동작 간 차이가 남아 있다. production secret 값은 반환하지 않으며, 설정 누락/런타임 오작동 어느 쪽인지 이 probe만으로 단정하지 않는다.
- PostgreSQL 동시성 검사용 기존 runtime도 확인했다. `psql`/`pg_isready` 미설치, PostgreSQL Windows service/listener 없음, Docker CLI는 있으나 Docker Desktop Linux engine pipe가 없어 컨테이너 접근 불가. 새 DB/컨테이너는 만들지 않았다.
- 현재 alias `https://aiflow-web-canary.vercel.app`은 Ready deployment `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS`를 가리키고 `/health/ready`는 HTTP 200, `status=ok` 및 레벨테스트 readiness checks를 반환했다. deployment metadata에 Git source SHA가 없어 이 응답으로 현재 `hotfix` 작업 소스와의 일치 여부를 증명할 수 없다. 배포/alias 변경 없음.
- 2026-10-12 `vercel inspect https://aiflow-web-canary.vercel.app --json`도 같은 `READY` 배포 `dpl_21dPQZ955gTxpcwWGgBxsgwcHXZS`와 두 Canary alias를 반환했다. 현재 변경본과 배포본의 동일성을 입증할 Git source SHA는 응답에 없었다. 이번 inspect는 조회 전용이며 배포·alias 변경은 하지 않았다.
- 로컬 SQLite 학생상태 스냅샷은 read-only 집계에서 3개 distinct user ID가 모두 UUID 형식이었다. 이는 기존 기록의 오래된 스냅샷 메타데이터일 뿐, active PostgreSQL 원본이나 Production `canary_users` 계정 소유권을 증명하지 않는다.

## 평점·대결 이관의 사용자 소유권 매핑 보강 (2026-10-12)

- 평점·대결 migration이 원본 `user_id`를 그대로 적재하고 Production `public.canary_users`에 실제 계정이 있는지 확인하지 않던 위험을 수정했다. 존재하지 않는 계정 ID를 넣으면 사용자가 기록에 접근하지 못할 수 있다.
- 공통 `tools/user_identity_migration.py`가 원본 UUID는 동일 UUID만 허용하고, legacy ID는 환경변수 `SOURCE_RATING_USER_ID_MAP_JSON` 또는 `SOURCE_ARENA_USER_ID_MAP_JSON`의 명시적 1:1 매핑만 허용한다. 누락/미지 키, UUID 재할당, 여러 원본 계정의 한 대상 계정 병합을 거부한다.
- 각 migration은 repeatable-read 원본 snapshot에서 관련 사용자 ID 집합을 모으고, 대상 transaction에서 `canary_users`를 잠근 채 모든 매핑 계정의 존재를 staging/write 전에 검사한다. source/destination digest를 분리해 출력하며 매핑 값은 출력하지 않는다. 풀이 이력 migration도 공통 identity 검사 로직을 사용한다.
- `py_compile` 및 관련 API·worker·grading·rating·arena·continuation·migration·SQL contract·level-test focused suite **112개 통과**. 기존 deprecation 및 짧은 테스트 JWT 키 경고 29개가 남았다.
- 로컬 테스트는 migration 로직을 검증할 뿐이다. Production 계정 매핑, 원본/대상 행 수·digest, RLS, PostgreSQL 다중 연결 동시성은 Supabase CLI 연결 및 로컬 PostgreSQL runtime 부재로 미검증이다. DB/배포는 변경하지 않았다.
- 2026-10-12 재검증: identity·4종 migration·Vercel API/SQL contract·OCR queue/worker 경계·채점·평점·대결·continuation·level-test를 포함한 21개 focused test 파일 **130개 통과**. FastAPI deprecated startup hook 및 테스트용 짧은 JWT 키 경고 33건은 남았다. Production 데이터·실제 다중 연결 동시성 및 배포 동작 검증으로 확대 해석하지 않는다.

## Lightning OCR worker 목적지 검증 (2026-10-12)

- Lightning worker는 이전에 `VERCEL_API_BASE_URL`이 HTTPS인지와 secret 존재 여부만 확인해, 잘못 설정되면 OCR 이미지와 worker secret을 임의의 HTTPS host로 전송할 수 있었다.
- 표준 라이브러리 URL parser로 HTTPS `.vercel.app` 호스트의 루트 URL만 허용하고, 사용자정보·비표준 포트·경로·query·fragment 및 비-Vercel host를 거부하도록 `_client()` 경계 검증을 강화했다. secret은 오류 메시지에 포함하지 않는다.
- Lightning worker API boundary와 관련 Vercel OCR/채점·rating·arena·continuation·migration·level-test focused suite **107개 통과**, `py_compile` 및 변경 파일 `git diff --check` 통과. 의도적인 테스트 실패는 mock된 `_client` 대신 원본 함수를 검증하도록 수정 후 통과했다.
- Vercel OCR destination의 소스 코드 안전성만 검증했다. 실제 Lightning Studio 설정, secret, OCR roundtrip, DB/동시성 및 배포는 확인하거나 변경하지 않았다.

## 평점 제출 멱등키 본문 바인딩 (2026-10-12)

- `/rating/submit`의 저장 입력 전체(인증 사용자 ID와 서버 검증된 문항·결과·입력값)를 정규 JSON으로 만들고 SHA-256 fingerprint를 생성해 Vercel RPC에 전달한다. 클라이언트 grade receipt 원문은 저장 payload/fingerprint에 넣지 않는다.
- `rating_submission`에 nullable fingerprint를 추가해 기존 행과 결과를 보존하고, 새 `apply_rating_submission_v2`는 같은 user/submission key와 같은 fingerprint만 이전 응답으로 재생한다. 문항 ID 또는 fingerprint가 다르면 기존 rating을 바꾸지 않고 conflict를 반환한다.
- fingerprint가 없는 legacy 행은 기존 응답/데이터 호환을 위해 문항 ID가 같으면 저장 응답을 재생한다. 원래 본문이 기록되지 않아 이 행에 대해서만 변경된 본문 여부를 역으로 판별할 수 없다. 이 경로도 rating을 다시 적용하지 않는다.
- 이전 9-인자 RPC의 service_role 권한은 존재할 때 조건부 회수하고, 새 RPC만 service_role에 부여한다. DB 테이블/행을 삭제하거나 갱신하는 migration은 아니다.
- API·SQL contract 테스트 및 Lightning/centralization 동반 suite **24개 통과**, Python compile과 `git diff --check` 통과. 실제 PostgreSQL에서 migration 재실행·RPC signature resolution·동시 호출은 runtime 미설치로 검증하지 않았다. DB와 배포는 변경하지 않았다.
- fingerprint 경로와 앞선 API/SQL/worker/migration 검사를 모두 포함한 재실행에서 21개 focused test 파일 **130개 통과**, Python compile 및 `git diff --check` 통과(기존 deprecation·테스트용 짧은 JWT 경고 33건). 이 결과는 mock/계약 검증이며 실제 PostgreSQL RPC resolution·다중 연결 동시성은 증명하지 않는다.
- 이어풀기와 채점 완료가 문제별 동일 advisory lock을 공유하는 구현을 재확인하고, lock key와 grade write 이전 획득을 고정하는 SQL 계약 테스트를 추가했다. 개별 SQL 계약 **6개 통과**, 전체 focused suite **131개 통과**(기존 경고 33건). 실제 PostgreSQL 다중 연결 실행은 미검증이다.

## Vercel → Lightning wake 목적지 제한 (2026-10-12)

- Vercel OCR 접수 코드가 `LIGHTNING_WAKE_URL`의 HTTPS 여부만 검사한 뒤 `LIGHTNING_WAKE_SECRET`을 전송할 수 있던 경계를 확인했다.
- URL 검증을 Lightning의 HTTPS `/wake` endpoint로 한정했다. Lightning 공식 포트 공개 URL 예시의 `*.cloudspaces.litng.ai`와 `*.lightning.ai`만 허용한다. 사용자정보·비표준 포트·query/fragment·다른 경로·위장 도메인은 거부하고 런타임 wake 직전에도 재검사한다. HTTP redirect도 따르지 않아 wake secret이 다른 호스트로 전달되지 않게 했다. 잘못된 환경 설정은 큐 저장 전에 `503 ocr_worker_unavailable`로 중단된다.
- OCR queue, 제품 API centralization, Lightning worker boundary, OCR-grading/arena SQL contract focused tests **49개 통과**. `py_compile` 통과. 기존 deprecation 및 테스트 JWT key 경고 37건.
- mock 기반 소스/경계 검증이며 실제 Lightning 공개 wake URL, secret, OCR roundtrip, Supabase/PostgreSQL 동시성은 미검증이다. 배포·환경변수·DB는 변경하지 않았다.

## Flutter → Vercel 경로 존재성 재감사 (2026-10-12)

- FastAPI의 실제 등록 route와 Flutter `ApiContract.uri/url`, `_get/_post`의 정적 경로를 대조했다. Flutter 직접 backend origin 우회는 검색되지 않았으나, Vercel route 누락은 별도 문제로 확인됐다.
- 학생 흐름에서 `/ox_quiz/generate`는 레벨테스트·약점 복습 화면이 호출하지만 `api/index.py`에 route가 없다. `/quests/generate/status`는 빠른 문제 생성 화면이 polling하지만 route가 없다. `listQuestTray/createQuestTrayItem`도 API client에는 있으나 현재 호출자는 발견되지 않았다.
- `/academy/*`, `/exam-editor/*`, `/habit/*` 미등록 경로도 함께 나왔으나 교사/관리자·legacy 호출 여부를 아직 분류하지 않았으므로 이번 변경 범위로 섣불리 이식하지 않았다. 특히 OX quiz의 과거 저장소는 OMJ SQLite와 연결되어 있어 원본 데이터·보존 경로를 확인하지 않고 Vercel에서 빈/임시 결과로 대체하지 않는다.
- 다음 작업은 OX quiz 데이터 원장과 사용자 소유성/보존 경로를 확인한 후 Vercel API로 안전하게 이관하고, 동기 문제 생성과 status polling 계약을 일치시키는 것이다. 이번 항목은 route-inventory 관찰이며 누락 API 기능은 미해결 상태다.

## OX 복습 bank의 Vercel 경로 및 additive 이관 준비 (2026-10-12)

- `omj/quests.db`를 SQLite `mode=ro`로 열어 OX 질문 39개·14개 태그·작성자 UUID 형식을 확인했다. read-only migration dry-run digest는 `5167efa9ae760a1ec26a40eec36801c186cc30419b12cd0f7d6406ae504f7e8b`이다. 원본 DB를 변경하지 않았다.
- `supabase_ox_quiz.sql`을 추가했다. source ID unique, 사용자 FK, RLS 및 service_role 전용 접근으로 기존 행과 사용자 귀속을 보존한다. migration tool은 source read-only, 명시적 `--apply`, hotfix/D: 가드, creator UUID 매핑과 `canary_users` 존재 검사, serializable transaction, 충돌 거부·재실행 검증·digest 보고를 포함한다. 기존/대상 행 삭제는 없다.
- Vercel에 인증된 `GET /ox_quiz` 및 `POST /ox_quiz/generate`를 추가해 이관된 persistent bank를 읽고, 요청 태그·행 응답을 검증한다. 작성자 UUID는 학생 응답에 노출하지 않는다. 임의/더미 문항을 생성하거나 원장을 덮어쓰지 않는다.
- API, SQL contract, migration, identity mapping 테스트 **33개 통과**, Python compile/diff-check 통과. 실제 source dry-run은 39행을 보고했으며 `applied:false`였다.
- SQL 적용과 실제 Postgres copy는 수행하지 않았다. 따라서 배포 API에서 이 route가 동작하는 것은 아직 검증되지 않았다. OX 문항 on-demand 생성과 `/quests/generate/status` polling 경로는 미해결이다.

## 동기식 문제 생성 polling 계약 정리 (2026-10-12)

- Vercel `/quests/generate`는 동기 응답으로 `quest`를 반환하지만 Flutter 화면이 존재하지 않는 `/quests/generate/status`를 초당 요청하고 있었다. 화면의 polling을 제거하고 동기 응답이 누락되면 즉시 `502`로 처리하도록 바꿨다. `fetchQuestGenerateStatus` API method는 다른 계약 호환을 위해 남겼으나 현재 lib 호출자는 없다.
- Flutter formatter는 변경 없이 통과, 두 Dart 파일 분석은 error 없이 기존 info lint 4건. 변경 파일 diff-check 통과.
- `tests/` 전체 **209개 통과**, 82개 기존 deprecation/test-key warnings. 전체 worktree `git diff --check`은 별도 기존 변경 파일 `test/personal_schedule_mobile_test.dart:211`의 EOF 공백 1건으로 실패했으며 해당 무관 파일은 수정하지 않았다.
- OX SQL 및 SQLite→Postgres migration은 여전히 코드 초안/dry-run 상태다. Supabase 실제 적용·copy·Vercel 실행은 미검증이고 배포하지 않았다.

## OX additive SQL 실행성 재검증 (2026-10-12)

- `supabase_ox_quiz.sql`에 명시적 transaction 경계를 추가해 테이블·인덱스·RLS·권한 부여가 중간 실패 시 부분 적용되지 않게 했다.
- 로컬 PGlite(PostgreSQL 18.3)에서 최소 `canary_users` 참조 스키마를 구성하고 migration 전체를 실행했다. FK, 중복 source ID의 conflict-safe 재실행, RLS 활성 상태까지 확인했다. **PGlite 단일 연결 검증**이며 Supabase 운영 DB·동시성·실제 RLS role 구성을 증명하지 않는다.
- 관련 API/SQL/migration/centralization/Lightning worker 경계 테스트 **25개 통과**. 실제 Supabase 적용, SQLite 39행 copy, Flutter live 호출은 아직 미실행이다.
- 의미상 잔여 차이도 확인했다. 과거 `/ox_quiz/generate`는 bank 용량이 부족하면 AI 또는 더미 문항을 생성·저장했으나 Vercel route는 이관된 bank에서 조회만 한다. 더미 fallback은 재도입하지 않았고, 실제 생성 provider/저장 의미는 아직 포팅되지 않아 기존 API 행위와 완전 동등하지 않다.

## 저장 RPC 실제 SQL 실행 회귀검사 (2026-10-12)

- PGlite PostgreSQL 18.3에 canary 사용자/KV 및 OCR 행 구조를 최소 구성하고 `supabase_student_state.sql`, `supabase_rating.sql`, `supabase_arena_rankings.sql` 전체를 순서대로 실행했다. 세 migration 모두 SQL 실행 성공.
- rating RPC를 같은 사용자·submission·본문으로 두 번 실행해 동일 결과와 단일 receipt/attempt를 확인했다. 같은 submission ID에 다른 fingerprint는 `conflict`로 반환됐다.
- arena 결과 RPC 중복 실행은 replay로 반환됐고 승리 카운트/레이팅은 한 번만 반영됐다. continuation stroke도 guarded save 후 read RPC에서 복구됐다. 전체 **PASS**.
- 이 검증은 단일 로컬 PGlite 연결의 transaction/RPC 실행 확인이다. PostgreSQL 여러 연결의 경합·Supabase 실제 권한/RLS·실사용 데이터 migration은 입증하지 않는다. 배포와 원격 DB 변경은 없었다.

## OX 생성 계약의 Vercel 복구 (2026-10-12)

- 과거 `/ox_quiz/generate`의 빈 태그 보충·저장 동작을 Vercel에 복원했다. Vercel이 기존 Kiln 텍스트 설정으로 태그별 부족분을 생성하고 저장한 뒤 결과를 돌려준다. 더미 fallback은 두지 않고 생성 실패를 오류로 반환한다. Flutter 요청/응답 경로는 그대로다.
- `insert_ox_quiz_questions` RPC는 태그별 advisory transaction lock 아래에서 기존 중복 문구를 대소문자 무시로 확인하고 50개 상한을 적용해 INSERT한다. 같은 생성 결과 재전송은 중복 행을 만들지 않는다. SQL table/RPC 모두 transaction 안에서 적용된다.
- 태그 대소문자 무시 검색과 PostgREST LIKE 와일드카드 escape도 이전 SQLite 조회와 맞췄다. 전체 `tests/` **211개 통과**, Python compile/diff-check 통과. PGlite에서 RPC 삽입·재실행·중복 방지와 50개 상한을 확인했다.
- Kiln 실인증 호출과 Supabase 원격 함수 적용은 수행하지 않았다. PGlite 단일 연결 검사는 advisory lock 기반 다중 연결 경합을 입증하지 않는다. source SQLite 39행은 아직 이관되지 않았고 배포도 하지 않았다.

## OCR → Kiln 채점 원자성 PGlite 실행검사 (2026-10-12)

- `supabase_ocr_grading.sql` 전체를 명시적 `BEGIN/COMMIT`으로 감싸 queue schema 위에서 한 번에 적용되도록 했다.
- 최소 `ocr_jobs` 원본 테이블에 실제 grading migration을 실행하고, OCR 완료 RPC의 민감 payload scrub, worker lease claim, 활성 lease 중 재claim 차단, 결과 완료 후 cached replay 응답을 PGlite에서 확인했다. **PASS**.
- 이 실행은 단일 로컬 연결·최소 stub 기반이다. 실제 Supabase 테이블/RLS, Lightning TexTeller 실호출, Kiln 인증 호출, 다중 worker 동시 claim, Production DB 반영은 확인하지 않았다.
- `supabase_student_state.sql`의 grade-finalization RPC도 추가 실행했다. 하나의 완료에서 grade result, `solve_history.ocr.*`, 반복 약점 count, 완전 정답 문제의 continuation 삭제가 반영되고, 동일 결과 재호출은 변화 없이 성공·다른 결과 재호출은 거부됨을 확인했다. 이 또한 PGlite 단일 연결 기준이다.
- 시험 경로에서는 두 problem 결과가 score sheet에 합쳐지고, 첫 문제 정답 뒤 continuation은 유지되며 모든 시험 문항 정답 반영 뒤에만 삭제되는 것을 실행 확인했다. 실제 여러 연결의 동시 점수 반영은 미검증이다.
- OCR queue/grading·채점 receipt·student-state migration·rating API·arena SQL·continuation 회귀를 묶은 focused suite **61개 통과**, 기존 test JWT/deprecation warning 35건.
- Vercel의 `_wake_lightning` caller가 `/api/ocr/jobs`의 `create_ocr_job`뿐이고 Studio 시작 호출은 OCR wake 경유뿐인지 AST 회귀검사를 추가했다. Flutter/API centralization 및 Lightning boundary test와 함께 전체 suite **212개 통과**, 기존 warning 82건.

## 대결 결과 임시 답안 만료 파기 보강 (2026-10-12)

- 현 Flutter 결과 화면은 5분 뒤 답안을 UI 메모리에서만 가리고, 서버 파기 ACK는 페이지 이탈 때만 보냈다. 앱이 열린 채 만료되는 경우 서버 `arena.active_match`의 답안이 남을 수 있었다.
- 5분 만료 콜백에서 소유자 ID가 바인딩된 결과 ACK도 전송하도록 보강했다. 페이지 이탈 ACK와 같은 one-shot guard를 공유해 중복 요청을 막고, 원본 borrowed fixture/map은 변경하지 않는다.
- 전체 Python `tests/` **212개 통과**, 변경 Dart 파일 formatter 통과. Flutter 위젯 테스트는 실행 전에 `build/unit_test_assets` 접근 거부로 중단됐다. 해당 디렉터리에 `icacls` 접근 거부를 확인했으며 ACL 수정·삭제·C: 우회는 하지 않았다. `dart analyze`는 오류는 없었으나 해당 대형 화면에 기존 경고/정보성 lint가 있어 종료 코드 1을 반환했다. 따라서 변경 위젯 테스트의 런타임 통과는 미확인이다.
- 원격 Supabase, 다중 연결 동시성, 배포 및 alias 변경은 없었다. ACK 요청 실패 시 서버에 답안이 남을 수 있는 장애 시나리오는 별도 만료 정리 경로가 구현·검증될 때까지 잔여 위험이다.

## 대결 답안 서버 만료 정리 경로 (2026-10-12)

- ACK 유실 시 답안이 남는 위험을 줄이기 위해 `purge_expired_arena_answers()`를 추가했다. `arena.active_match`에서 `updated_at`이 5분 이상 지난 종료 경기만 고르고, 답안 필드만 비우며 점수·문항과 멱등 응답 메타데이터는 보존한다. 스냅샷 value 비교로 새 경기 덮어쓰기를 막고, malformed JSON 행은 건너뛴다.
- `canary_user_kv`의 arena key/update time 부분 인덱스, service_role 전용 RPC, Supabase pg_cron 매분 스케줄 SQL을 추가했다. cron migration은 이름 중복으로 중복 등록하지 않는다.
- 로컬 PGlite PostgreSQL 18.3에서 ranking SQL 전체 migration 후 4종 상태(만료 종료·미만료 종료·미완료·malformed)를 넣어 실행했다. 만료 종료만 1회 파기, 재실행 0건, 점수 보존, 미만료·미완료 보존, malformed 행 격리를 확인했다. 전체 Python suite **213개 통과**, SQL 계약 **4개 통과**. PGlite 단일 연결 검증이며 실제 pg_cron 스케줄, Supabase 권한·다중 연결은 확인하지 않았다.
- 읽기 전용 DB 연결 가능 여부를 재확인했다. `DATABASE_URL`은 `127.0.0.1:5432/omj`를 가리키지만 연결 시간 초과, Docker daemon은 정지 상태였고 source/target migration 전용 DSN은 설정되지 않았다. 원본 건수 조회·실DB 복사와 원격 변경은 실행되지 않았다.
- 새 cron SQL의 실제 Supabase 반영, ACK 유실을 포함한 live 사용자 여정, DB 다중 연결 경합, 배포는 미검증이다. Flutter 위젯 테스트도 기존 `build/unit_test_assets` ACL 거부 상태로 미실행이다.

## 학생 상태 source dry-run 및 보존 기준선 (2026-10-12)

- `migrate_student_state_sqlite_to_supabase.py`에 명시적 `--dry-run`을 추가했다. D: `omj/quests.db`를 SQLite read-only/query-only로 열고, 허용된 약점·이어풀기 테이블을 UUID/JSON 검증 후 테이블별 행 수·고유 계정 수·SHA-256만 출력한다. 이 경로는 PostgreSQL 대상 연결을 하지 않는다. 실제 쓰기는 `--apply` 명시가 여전히 필수다.
- 실제 원본 dry-run: `user_weakness_tags` 36행/3계정, SHA-256 `3949120957567ef5d46330ee8c9fb6a3baf01edc2227a8c4e7e9591989f31f43`; `continue_session` 2행/2계정, SHA-256 `0ad0bda058a6ea389e977c4df40f76b5f67cafc699aa04949161161c373286e0`. OX 콘텐츠 dry-run은 39행, SHA-256 `5167efa9ae760a1ec26a40eec36801c186cc30419b12cd0f7d6406ae504f7e8b`; 세 dry-run 모두 `applied:false`/대상 접속 없음. 원문/계정 ID는 출력하지 않았다.
- dry-run 도구 회귀와 OX migration tests **14개 통과**. 원본 SQLite 파일 전후 바이트가 동일한 것을 unit test로 검사했다. 실제 source table dry-run도 read-only URI로 실행했다.
- 현재 코드의 전체 Python suite **215개 통과**, 기존 warning 82건. migration tool `py_compile`과 대상 파일 `git diff --check`도 통과했다.
- 대상 Supabase DSN은 여전히 설정되지 않았고 local OMJ PostgreSQL도 접속 시간 초과다. rating/arena/solve_history는 PostgreSQL source endpoint가 없어 행 수·digest를 아직 확보하지 못했다. 어떠한 DB도 수정·배포하지 않았다.

## active goal 재개: current-state regression pass (2026-10-12)

- 현재 가드 확인: `D:\AIFlow-Workspace\Projects\Aiflow\Upstudy-hotfix`, `hotfix`, HEAD `1b1ccbbca155b2c3200688d30b0502ae877b39bb`; 변경이 다수 존재하므로 보존했다. 빌드 임시 경로는 `build\temp`다.
- 저장소 `.venv`로 API centralization, Lightning OCR-only boundary, OCR queue/grading SQL, rating, arena ranking, continuation, migration 도구 focused suite를 재실행해 **86개 통과**했다.
- 전체 `pytest -q`는 저장소 루트의 `omj/tests`까지 자동 수집해 33개 collection error로 중단됐다. OMJ 테스트 환경에 `app`/`auth` import 경로, Pillow, psycopg가 없고 `test_simulation/run_legacy_test.py`에는 IndentationError가 있었다. 이는 변경 관련 focused suite 실패가 아니며 이번 범위에서 무관한 환경·legacy 파일을 수정하지 않았다.
- Lightning worker는 `/health`, `/wake`만 제공하며 TexTeller OCR 입력을 Vercel `/internal/ocr/*` 경로로 claim/complete/fail한다. Vercel의 `_wake_lightning`은 OCR job 생성만 호출하는 AST 계약 검사가 통과했다.
- 원격 source/target DB 접속·실제 데이터 이관·다중 연결 경합은 여전히 미검증이다. 코드상 단일 Vercel 경로 및 로컬 SQL 계약 검증만 확인됐으며, 배포나 DB 변경은 하지 않았다.
- 학생 API 사용처를 추가 대조한 결과 Flutter 복습 경로가 `/habit/problem` 조회와 `/habit/problem/replay`를 호출하지만 Vercel `api/index.py`에는 두 route가 없다. 기존 OMJ 구현은 `user_habit`의 retry_count/tags/title과 `problem_payload` 원장을 사용하므로 단순 `solve_history` 응답으로 대체하면 정보·재풀이 의미가 달라진다. canonical question snapshot은 codebase_id/seed가 있는 3,111개 행과 중복 pair 0개로 확인됐지만, 이전 user_habit 원본 PostgreSQL은 접속 불가라 안전한 copy 전에는 실제 복습 이력을 대체하지 않는다. 다음 작업은 해당 사용자별 이력의 additive migration과 인증 Vercel GET/replay route, Flutter 응답 계약 테스트다.
- 재현 가능한 실제 Vercel snapshot에서 codebase_id/seed 조회는 `curated/marketplace-original-v59/t5-10`을 반환했고, 기존 테스트 외에 API centralization/Lightning boundary/question-bank **18개 통과**를 확인했다. 작업 범위 Python suite `pytest -q tests`: **215개 통과, 3 warnings**. 루트 전체 `pytest -q`는 OMJ 테스트 환경 별도 의존성/legacy collection 문제로 사용할 수 없음을 구분했다.

## Vercel 문제 복습 API 및 legacy habit 이관 준비 (2026-10-12)

- Flutter 호출 경로였던 `GET /habit/problem`과 `POST /habit/problem/replay`를 Vercel에 연결했다. 목록은 인증 사용자 KV의 legacy `user_habit` 요약과 Vercel `solve_history`를 합치고, 원본 retry_count를 baseline으로 삼아 baseline 시각 이후 풀이만 추가 시도로 계산한다. 재풀이 코드는 기존 body/response 형태를 유지하며 canonical snapshot에서 고유한 codebase_id/seed가 확인된 문제만 반환한다.
- `get_question_by_codebase_seed`는 read-only canonical SQLite에 exact pair를 조회하고 2개 이상 발견되면 거부한다. 현재 snapshot 3,111행에는 pair 중복이 0개였다.
- `tools/migrate_user_habits_to_supabase.py`를 추가했다. source PostgreSQL은 repeatable-read/read-only, target은 serializable; user ID mapping과 destination 계정을 검증하고 안정 해시 키로만 추가 복사한다. 기존 target value 불일치·검증 digest 차이는 transaction 전체를 중단하며 source/target 행 삭제는 없다. 테이블 전체 write-lock은 쓰지 않고 대상 계정만 `FOR KEY SHARE`로 잠근다.
- Flutter `ApiPaths`의 habit 경로를 중앙 상수로 옮기고 Flutter contract test에 동일 Vercel origin 검사를 추가했다. `dart analyze test/api_contract_test.dart`는 문제 없음, 변경 Dart 파일 formatter 확인 통과.
- API 병합·인증·잘못된 seed·snapshot 재조회·변경되지 않는 캐시 반환·이관 행 validation/determinism 및 API 경계 tests 포함 `tests/` 전체 **232개 통과, 3 warnings**. 대상 파일 `git diff --check` 통과.
- Flutter `test/api_contract_test.dart` 런타임 검사는 Flutter가 기존 `build/unit_test_assets` 접근 거부로 중단해 실행되지 않았다. ACL 변경이나 빌드 경로 우회는 하지 않았다.
- `migrate_user_habits_to_supabase --dry-run`은 현재 `SOURCE_USER_HABIT_DATABASE_URL is required`로 중단됐다. DB 접속을 시도하지 않았다. 따라서 원본 habit 행 수/digest, identity mapping 실제값, target copy, live API 호출은 미검증이고 배포/DB 변경도 하지 않았다.

## active goal 재개: Vercel 연결 자격 구성 read-only 확인 (2026-10-12)

- 현재 guarded hotfix checkout에서 Vercel Production 환경변수의 **이름만** 조회했다. `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `KILN_API_KEY`, `OMJ_JWT_SECRET`, `CORS_ALLOW_ORIGINS`, `STUDENT_STORE_DEMO`가 있고 값은 출력하지 않았다. source Postgres DSN과 direct target DB DSN은 Vercel 목록에 없다.
- 전체 `tests/`를 재실행해 **232 passed, 82 warnings**를 확인했다. warnings는 기존 FastAPI/httpx deprecation과 테스트 전용 짧은 JWT 키다.
- `migrate_student_state_sqlite_to_supabase.py --dry-run`을 재실행해 약점 36행/3계정, 이어풀기 2행/2계정의 기존 SHA-256을 확인했다. 대상 연결/쓰기 없이 로컬 SQLite를 읽기 전용으로 검사했다. `migrate_user_habits_to_supabase.py --dry-run`은 `SOURCE_USER_HABIT_DATABASE_URL is required`로 종료되어 source 연결을 시도하지 않았다.
- Supabase REST count 조회를 `vercel env run`으로 시도했으나 CLI argument parsing이 command를 시작하지 않았다. 임시 스크립트는 `build/temp`에서 제거했다. Production 테이블의 실시간 행 수는 이번 실행에서 확인되지 않았다.
- 현재 확인된 병목은 source Postgres DSN/사용자 ID mapping과 target direct Postgres 연결이 제공되지 않은 점이다. Production 환경변수나 DB, 배포는 변경하지 않았다.

## 로컬 SQLite 원본의 사용자 상태 존재성 재확인 (2026-10-12)

- D: `omj/quests.db`와 `omj/data/postgres_migration_backups/20260718-200114/quests.db`를 각각 SQLite `mode=ro` + `query_only`로 열고, 사용자 ID/본문은 출력하지 않은 채 테이블 행 수와 정렬된 전체 행 SHA-256만 비교했다. 관련 테이블들의 count/hash가 두 파일에서 동일했다.
- 실제 로컬 source snapshot에는 `user_rating` 11행, legacy `user_tag_stats` 150행, `solve_history` 33행(그중 `compressed=1` 21행), `rating_submission` 0행, `user_habit` 0행, `user_weakness_tags` 36행, `continue_session` 2행이 있다. Rating 사용자는 11명이며 UUID 형식은 10개로 확인되어 나머지 identity는 매핑 검증이 필요하다. ID 값은 기록하지 않았다.
- 이로써 앞선 “rating/solve_history 원본 행 수 없음”은 **PostgreSQL endpoint 기준**으로만 맞고, 현재 D: SQLite snapshot을 별도 원본 후보로 조사할 수 있음을 확인했다. 다만 실제 운영 source of truth인지, 최근 변경분이 있는지, 대상 Supabase 계정과 연결되는지는 아직 입증되지 않아 copy/apply에는 사용하지 않았다.
- 다음 구현 작업은 SQLite `user_rating`/`user_tag_stats`와 압축 상태를 포함한 `solve_history`에 대한 명시적 read-only dry-run 및 source selection을 기존 additive migration 도구에 추가하는 것이다. target Postgres credential이 확인될 때까지 적용은 금지한다.
- 보존 파일의 시각 범위도 집계했다: rating/tag는 2026-07-12, solve history는 2026-07-08, weakness는 2026-07-03, continuation은 2026-05-16이 최신이다. 따라서 이 SQLite pair는 복구용 기준선 후보일 뿐 현재 운영 source-of-truth로 입증되지 않았다. 수량·해시가 백업과 일치해도 7월 이후 데이터가 없다는 뜻은 아니므로 이 자료를 Production에 적용하지 않는다.

## Supabase 로그인 후 Production 프로젝트 읽기 전용 확인 (2026-10-12)

- 사용자가 로그인 완료를 알려준 뒤, 브라우저에서 조직 `ufovxgogonbzovlzbhvo`의 프로젝트 1개를 확인했다. 프로젝트 ref는 `aybqetiydxafeuzudltb`, `main` / `PRODUCTION`, GitHub 연결 표시 `kuseumkkrkkr/Upstudy-app`이다. 이 값은 대시보드 UI에서 관찰했으며, 여전히 Vercel 프로젝트 설정과 동일 대상인지 교차검증이 필요하다.
- Supabase Database > Migrations 화면은 “Run your first migration” 상태여서 migration 이력이 표시되지 않았다. 이 화면만으로 DB에 수동 적용된 schema/object가 없는 것은 입증되지 않는다.
- Table Editor의 `public.level_test_question_bank`에 `expanded-v1` 문항이 있고 UI가 776 records를 표시했다. 첫 화면의 question_id/question_index 일부만 확인했다. SQLite 입력 DB와 row/hash 일치, API가 해당 테이블을 사용하는지, 권한/RLS는 검증하지 않았다.
- 메타데이터 SELECT에서 public schema 61 rows를 확인했으며 첫 결과 행에 `arena_match`, `arena_match_question`, `arena_participant`, `arena_rating`, `arena_submission`, `arena_tag_xp_ledger`가 나타났다. 개별 테이블 row count를 모두 추출하지 않았다. 이후 필터 쿼리 실행 시 Supabase가 데이터 제거 경고를 표시해 취소했고, 그 쿼리는 실행하지 않았다.
- 사용자 데이터·schema·환경변수·배포를 변경하지 않았다. 현재 Production Postgres direct credential/원본 endpoint는 아직 제공되지 않았고, 브라우저 로그인만으로 CLI 인증/접속이 확보됐다고 보지 않는다. 따라서 DB migration/copy 및 실다중연결 테스트는 계속 미검증이다.

## Supabase live schema 조사 오류 정정 (2026-10-13)

- 앞선 Table Editor 조사는 가로로 잘린 화면을 전체 컬럼으로 오인했다. 실제 `information_schema.columns` SELECT에서 `arena_rating` 컬럼 11개를 확인했다. 세 컬럼뿐이라는 주장은 잘못됐으며 그 판단으로 추가했던 컬럼·제약 보강 및 테스트를 제거했다.
- 별도 UI 확인에서 `public.level_test_question_bank`는 776 records로 표시됐고 `question_id`, `version`, `question_index`와 `expanded-v1` 행 일부를 보았다. `level_test_question_bank`는 Table Editor에서 데이터 API 노출 표시가 있었지만, 이 turn에서 RLS 상태를 확정하지 않았다.
- 당시 12개 focused tests는 잘못된 schema 가정의 증거가 될 수 없다. 아래 실제 PostgreSQL 적용 및 사후검사가 최신 근거다.

## 제품 API 저장소 실제 반영 (2026-10-13)

- 실제 Supabase PostgreSQL 17.6에서 8개 SQL migration을 하나의 트랜잭션으로 실행했다. 먼저 동일 본문 + 마지막 ROLLBACK으로 검증하고 19계정/132 KV 유지 및 새 RPC 부재를 확인한 뒤 COMMIT했다. 적용 bundle SHA-256: `30a09db951e48f447f9b878b87677910c3ee73d686bbcdd04f8bef5f29bdd16f`; rollback bundle: `98624be155bca251a8825d375199a7b2445873df01d555be3cd2cbe25bce6ee2`.
- 기존 PostgreSQL `users`의 학생 26명을 UUID·PBKDF2 hash/salt·계정 필드 그대로 `canary_users`에 복구했다. 교사 계정은 이동하지 않았다. 개인 KV 27행 + 실제 풀이 이력 17행을 충돌 검사 후 복사했다. 최종 계정 45, KV 176, copied history 17이다.
- 원본 rating 11행, tag rating 61행, 제출 원장 5행, 풀이 이력 17행은 모두 변경되지 않았다. 기존 19계정과 비휘발성 개인 KV도 보존 비교를 통과했다. 레벨테스트 문항 776개 유지.
- `aiflow_api_cutover_20261012` private schema에 원본 11테이블 snapshot을 보존하고 RLS 및 anon/authenticated/service_role 접근 차단을 적용했다. 사용자 요청에 따른 만료 경기 답안만 minute cron이 제거했다. snapshot에도 경기 답안을 남기지 않도록 별도 제한 UPDATE했다. 이 UPDATE는 위 bundle 적용 후 수행했으며 최신 generator는 동일 정리를 포함한다. 새로 생성하는 bundle은 위 적용 hash와 다르다.
- 실제 RPC smoke: 레이팅 동일 요청 replay/다른 본문 conflict, 경기 결과 1회 반영, 소유권 검사, OCR lease 중복 차단, 채점·약점·이어풀기 원자성, OX 중복 삽입 및 RLS/함수 실행권한을 검증했다. smoke QA 데이터는 SAVEPOINT rollback으로 남기지 않았다. 여러 DB 연결/200 동시 세션 부하 검증은 아직 하지 않았다.
- `supabase_product_api_postflight.sql` 결과의 모든 보존·권한 flag true, 검사 대상 public table 중 RLS 없는 테이블 0개. 로컬 API 테스트는 **232 passed / 82 existing warnings**.
- 7월 SQLite snapshot은 최신 원본으로 간주하지 않고 적용하지 않았다. 약점·이어풀기·OX의 최신 legacy source 추가 확인은 미완료다.

## Lightning 실행 코드 및 남은 연결 조건 (2026-10-13)

- 사용자 승인 범위인 기존 CPU-4 Studio를 재개했다. 새 유료 추론 앱/GPU 배포는 하지 않았다. remote worker 원본을 `.before-unification-20261013.bak`로 보존한 뒤 D:의 OCR-only worker와 정확히 일치하도록 교체했다. LF 기준 SHA-256 `ff0c8aa239f19cdeb2a6ad6b298bf430c6cce10b4a2a52f72b28073046c43a9b`.
- remote Python 실행에서 TexTeller import 성공, traceback 없이 종료를 확인했다. 이 실행은 uvicorn 서버 시작이나 실제 이미지 인식 성공을 뜻하지 않는다. remote `start.sh`는 D: 파일과 동일하며 기존 `on_start.sh`도 이 worker를 8000 포트로 실행하도록 구성돼 있다.
- remote `omj/.env`에는 SAM 키만 있었다. Vercel Production 환경변수 목록에는 OCR callback/wake 인증키가 없다. 새 OCR 전용 연결 설정 및 canary 중앙화 코드 배포 승인을 요청했다. 아직 Vercel 배포/alias 변경 및 실제 OCR 왕복 검증은 하지 않았으므로 **일원화 완료로 판정하지 않는다**.
- 실제 화면 증거: `evidence/2026-10-13-api-unification/supabase-postflight.png`, `supabase-preservation.png`. 추가 bundle 계약 테스트 2개 + arena SQL 계약 4개 통과. 생성기 최신 apply hash는 `84009eaae8fe27e9bb6ed4ab6181ebfdb60880a285a7410c2c60c19b3f2a3bd3`이며 재적용하지 않았다.

| 책임 단위 | 입력·결과 | 상태·실패 처리 |
|---|---|---|
| `prepare_product_api_cutover.bundle` | rollback 여부 → 8개 migration/backup/smoke SQL 문자열 | 파일/DB 변경 없음; 검증 SQL의 QA 쓰기는 savepoint rollback |
| `prepare_product_api_cutover.main` | CLI `--rollback` → D: build/temp SQL·hash | D: 루트/hotfix가 아니면 실패; DB 실행하지 않음 |
| `FILES` / `SOURCE_TABLES` | 고정 migration 파일명 8개 / snapshot 테이블명 11개 | 코드 소유 상수, 계정 값·키 포함 안 함 |
| `supabase_legacy_student_accounts.sql` | 기존 DB 학생·KV·풀이 → 동일 UUID 및 원본 내용의 additive 복사 | identity/key 충돌 또는 검증 실패 시 전체 transaction 실패 |
| `supabase_product_api_postflight.sql` | 현재 DB와 보호 snapshot → count·보존/권한 flag | 읽기 전용; missing schema/table은 오류로 표시 |

### 다음 작업 지시서

1. 사용자가 canary 배포와 제한된 OCR 연결키 설정을 승인하면 Vercel·기존 CPU-4 Studio만 설정한다. 기존 OCR 프로젝트 secret 공유 또는 새 유료 앱 배포로 대체하지 않는다.
2. Vercel 중앙화 변경과 현재 미커밋 앱 변경을 구분해 검수한 후보를 배포한다. 현재 코드가 포함되지 않은 live `/health/ready` 200을 일원화 근거로 쓰지 않는다.
3. 실제 필기 이미지 OCR → Vercel 채점 → 이력/약점/레이팅 갱신을 사용자 테스트 계정으로 검증한다. 여러 DB 연결의 replay/충돌 및 200 세션 검사는 별도 진행한다.
4. 최신 legacy 약점·이어풀기·OX 원본을 확인한 뒤 소유자 UUID와 기존 행 충돌을 검증한다. 7월 SQLite로 현재 데이터를 덮어쓰지 않는다.

# Vercel + Supabase + Lightning AI 카나리 배포

학생 앱의 공개 API 진입점은 Vercel이다. 제품 API 경로는 Vercel이 소유하고 Supabase에 저장한다.
Lightning 공개 앱은 TexTeller 필기 OCR 작업만 처리한다. 단, migration 적용·데이터 cutover·실DB
동시성 검증이 미완료이므로 코드 경로 정리를 전체 서비스 전환 완료로 간주하지 않는다.

레이팅·약점·이어풀기·랭킹 API는 Vercel 라우트로 전환됐고, 제품 동작에 필요한 채점 결과·시험 점수표·약점·이어풀기 삭제는
Vercel Supabase transaction RPC에서 처리한다. 기존 사용자 데이터 이관, migration 적용, arena 결과 writer 연결,
실DB 동시성 및 브라우저 검증 전에는 운영 cutover/배포 완료로 보지 않는다.

## 1. Supabase

SQL Editor에서 `supabase_ocr_queue.sql`, `supabase_ocr_grading.sql`, `supabase_auth.sql`을 각각 한 번 실행한다. 테이블은 RLS가 켜져 있고
`anon`/`authenticated` 직접 접근 권한이 없다. Supabase service role key는 Vercel에만 Secret으로 둔다.
SQL이 `delete_expired_ocr_jobs()`를 매시간 호출하는 `aiflow-ocr-cleanup` Cron도 함께 등록한다.

레이팅 API를 전환하려면 기존 PostgreSQL 원장의 사용자·태그·제출 행을 먼저 안전하게 내보내고 검증해야 한다. 그 뒤에만
`supabase_rating.sql`을 적용하고 보존한 데이터를 이식한다. 이 SQL은 destination schema만 만들며 기존 데이터 복사·삭제는 하지 않는다.
평점 쓰기는 `apply_rating_submission_v2` RPC를 사용하고, 사용자·제출 입력의 SHA-256 지문이 같은 재시도만 저장된 응답을 재생한다.
신규 지문이 있는 제출 ID에 다른 입력이 오면 `409` 충돌이며, 구 RPC는 service_role 실행 권한까지 회수한다.
지문이 없는 기존 행은 문항 ID가 같을 때 저장 응답만 재생하고 rating 상태는 다시 반영하지 않는다. 구 요청 본문 지문은 복원할 수 없다.
현재 로컬 PostgreSQL 연결과 Supabase 프로젝트 연결은 읽기 검증되지 않았으므로 migration 적용이나 data cutover를 완료로 간주하지 않는다.
연결이 준비되면 저장소 루트에서 OMJ Python requirements를 설치하고 `SOURCE_RATING_DATABASE_URL`,
`TARGET_SUPABASE_DATABASE_URL`을 환경에 직접 설정한 뒤 `python tools/migrate_rating_to_supabase.py --apply`를 실행한다.
이 도구는 D:의 `hotfix` checkout만 허용하고 source를 read-only로 연다. 단일 transaction에서 source 행을 staging하고,
키가 같은 destination 행의 전체 값이 같으면 유지하고 다르면 중단하며, 없는 행만 삽입한다. destination-only 행은 보존한다.
source 행 수와 staging 행이 목적지에서 값까지 동일하게 조회되는지 확인한다. source writer를 멈추고 최종 대조를 마치기 전에는
라우트 전환/배포를 완료로 표시하지 않는다. 연결 문자열을 명령 인자로 전달하지 않는다.

평점 source에 UUID가 아닌 과거 user ID가 있으면 `SOURCE_RATING_USER_ID_MAP_JSON`에 source ID에서 기존
`canary_users.user_id` UUID로의 일대일 매핑을 제공한다. UUID는 동일 UUID로만 허용하며 모든 대상 계정은 실제 `canary_users`에 있어야 한다.
도구는 source 세 테이블의 전체 user set을 먼저 확인하고 대상 계정 행을 잠근 뒤 매핑을 검증한다. 매핑은 환경에만 두며,
원본/대상 digest를 각각 출력한다. 매핑 누락·계정 누락·계정 병합은 쓰기 전에 전체 transaction을 중단한다.

이어풀기 완료 차단에 필요한 기존 풀이 이력은 `SOURCE_SOLVE_HISTORY_DATABASE_URL`과
`TARGET_SUPABASE_DATABASE_URL`을 설정하고 `python tools/migrate_solve_history_to_supabase.py --apply`로
기존 PostgreSQL에서 Vercel의 `canary_user_kv`로 복사한다. source는 read-only이며 `solve_history.legacy.<id>` 결정형 키를 사용해
같은 행의 재실행은 멱등적이고 충돌 데이터는 덮어쓰지 않는다. UUID source ID는 동일 UUID로 보존한다. 비-UUID source ID가 있으면
`SOURCE_SOLVE_HISTORY_USER_ID_MAP_JSON` 환경변수에 source ID→기존 `canary_users.user_id` UUID의 일대일 매핑을 제공한다.
매핑은 명령 인자나 저장소에 기록하지 않는다. 매핑 없는 ID, 존재하지 않는 대상 계정, 서로 다른 source 계정의 UUID 병합은 복사 전에 거부한다.
source user set을 확인하고 대상 계정·KV 테이블을 잠근 뒤에만 복사한다. 원본 풀이 이력이 계속 바뀌지 않도록 source writer를 정지한 상태에서 실행하고,
보고된 행 수와 SHA-256을 확인하기 전에는 `/continue/strokes`의 운영 cutover를 완료로 표시하지 않는다.
현재 소스 라우트는 Vercel Supabase RPC를 호출하지만, 이 도구는 실제 DB 접속/복사/검증을 하지 않았다.

대결 랭킹은 `supabase_arena_rankings.sql` 적용 후 기존 PostgreSQL `arena_rating`을
`SOURCE_ARENA_DATABASE_URL`, `TARGET_SUPABASE_DATABASE_URL`을 설정해
`python tools/migrate_arena_rankings_to_supabase.py --apply`로 옮긴다. source는 read-only이고, 단일 transaction은
같은 키/값 행을 건너뛰고 누락 행만 넣으며 충돌 시 중단한다. destination-only 행은 삭제하지 않고 source 건수·SHA-256도 기록한다.
배포 시점에는 구형 arena rating writer를 정지한 최종 스냅샷이 필요하다.
UUID가 아닌 source user ID는 `SOURCE_ARENA_USER_ID_MAP_JSON`에 `canary_users.user_id`로의 명시적 일대일 매핑이 필요하다.
UUID는 변경할 수 없고, 목적지 계정 존재 여부를 확인한 뒤에만 데이터를 staging한다. 로그에는 매핑값을 출력하지 않는다.
랭킹 RPC는 전역 순위·내 등급·친구 범위·이름 검색·페이지를 계산하며 `/arena/summary`도 같은 RPC의 내 프로필을 사용한다.
Vercel 봇전은 과거 핵심 서비스와 동일하게 승리 +20, 패배 -10, 무승부 0을 저장한다. 결과 원장은 점수와
레이팅 영수증만 보관하고 답안 원문은 저장하지 않는다. 결과 확정 RPC는 match별 멱등 키와 트랜잭션 잠금으로
중복 차감/가산을 막는다. `supabase_arena_rankings.sql`은 연습 경기 생성·답안 제출·결과 확정 RPC도 포함한다.
이 SQL 및 기존 rating 데이터 migration이 적용되고 실DB 동시성 검증이 끝나기 전까지 운영 cutover/배포 완료로 보지 않는다.
경기 답안 원문은 종료 결과 화면에서만 최대 5분간 보여준다. `supabase_arena_result_cleanup_cron.sql`도 적용하면
앱 이탈 ACK가 유실된 경우에도 매분 만료된 `arena.active_match`의 제출 답안만 서버에서 비운다. 결과·레이팅 영수증과 문항 데이터는 이 정리 작업에서 삭제하지 않는다.

레거시 QUEST SQLite에서 사용하던 이어풀기·약점 기록은 `supabase_student_state.sql`을 `supabase_ocr_grading.sql` 이후 적용해 목적지 테이블을 만든 뒤
`SOURCE_QUEST_DB_PATH`(기본값 `omj/quests.db`)와 `TARGET_SUPABASE_DATABASE_URL`을 설정해
먼저 `python tools/migrate_student_state_sqlite_to_supabase.py --dry-run`으로 행 수·익명 사용자 수·SHA-256을 확인한 뒤
`python tools/migrate_student_state_sqlite_to_supabase.py --apply`로 옮긴다. 원본은 SQLite read-only,
목적지는 단일 serializable transaction에서 테이블 잠금 후 같은 키·같은 값은 건너뛰고, 같은 키의 값 충돌은 중단하며, 없는 행만 삽입한다.
목적지 전용 행은 보존하고 source 행 전체의 값 일치 검증 후에만 커밋한다. 모든 source user ID가 UUID이며 같은 UUID의 `canary_users` 계정이 이미 존재해야 한다.
계정이 누락되면 아무 상태도 복사하지 않고 중단한다. source writer를 정지하고 최종 스냅샷을 복사한다.
채점 완료와 약점 카운터는 같은 `complete_ocr_solve_grade_with_weakness` RPC에서 반영된다. 이전 로컬 SQLite 데이터와 별도 PostgreSQL rating 원장은 서로 다른 출처이므로 합쳤다고 간주하지 않는다.

S11 학생 데모/API를 함께 사용할 때는 `omj/migrations/postgres/010_student_demo_services_store.sql`을
SQL Editor에서 추가 실행한다. 이 migration은 수학 내신 계획의 optimistic version과 canary 전용
포인트 상점의 지갑 잠금·멱등 주문·차감 원장을 생성한다. 학원·과외 데이터는 서버에 저장하지 않고
Flutter fixture만 사용한다.

`canary_users`에는 기존 앱과 호환되는 PBKDF2 비밀번호 해시만 저장한다. 카나리 종료 시
`select public.delete_all_canary_users();`로 가입 정보를 전부 파기할 수 있다.

## 2. Lightning AI — 필기 OCR 전용

이 저장소를 Studio에 clone한 뒤 `omj/requirements.txt`를 설치한다. `lightning.env.example`의
Vercel API 주소·전용 worker secret·OCR 설정만 Studio Secret에 넣고 OCR worker를 실행한다.
Lightning에는 Supabase service role, JWT 서명키, Kiln/SAM 채점 키를 두지 않는다. 제품 FastAPI 전체 앱을 실행하지 않는다.

```bash
python -m pip install -r omj/requirements.txt
bash deploy/lightning/start.sh
```

`deploy/lightning/on_start.sh`의 내용을 Studio 홈의 `.lightning_studio/on_start.sh`로 등록하면
Studio가 자동 시작될 때 worker도 함께 복구된다. 공개 포트는 8000이며 Auto start를 활성화한다.

공개 포트 URL 끝에 `/wake`를 붙인 값을 Vercel의 `LIGHTNING_WAKE_URL`로 사용한다. Vercel과
Lightning에는 서로 다른 두 secret을 설정한다: Vercel→worker wake용 `LIGHTNING_WAKE_SECRET`,
worker→Vercel OCR 큐 callback용 `VERCEL_OCR_WORKER_SECRET`. 워커는 `/internal/ocr/*`만 호출하고,
Vercel이 입력을 필기 이미지·획 데이터로 제한하며 큐의 DB 접근을 전담한다. `/health`가 200인지 먼저
확인한다. Worker는 `VERCEL_API_BASE_URL`이 HTTPS `.vercel.app` 호스트의 루트 URL일 때만 시작해
OCR 이미지와 callback secret이 임의 호스트로 전송되지 않게 한다. 첫 호출은 Studio/모델 콜드 스타트 때문에
수 분 걸릴 수 있다.

Vercel은 `LIGHTNING_WAKE_URL`을 HTTPS `/wake`로 제한하며 Lightning 공개 호스트(`*.lightning.ai` 또는
`*.cloudspaces.litng.ai`)만 허용한다. 리다이렉트는 따르지 않는다. URL이 이 조건과 맞지 않거나 필수 secret이
없으면 이미지가 저장되기 전에 OCR 요청을 `503`으로 거절한다.

레벨테스트·약점 복습의 OX API는 Vercel에서 Kiln 텍스트 생성과 Supabase `ox_quiz_questions` 원장을 사용한다.
`POST /ox_quiz/generate`는 태그별 최대 50개까지 부족분을 생성·저장한 뒤 결과를 반환하며, 생성 실패 시 더미 문제로
대체하지 않는다. `KILN_API_KEY`가 필요하고 `KILN_OX_QUIZ_MODEL`은 생략 시 `KILN_CHAT_MODEL`을 사용한다.
additive SQL을 적용한 뒤 SQLite 원본은 먼저 dry-run으로 행 수와 digest를 기록한다. 실제 복사는 대상 사용자
소유권 검증을 포함하며 `--apply`가 필요하다. 원본 DB는 read-only로 연다.

```bash
python tools/migrate_ox_quiz_to_supabase.py --source omj/quests.db
python tools/migrate_ox_quiz_to_supabase.py --source omj/quests.db --apply
```

두 번째 명령은 `TARGET_SUPABASE_DATABASE_URL`과 destination `public.canary_users`의 creator 계정이
준비된 뒤에만 실행한다. SQL 적용·실제 데이터 복사는 아직 수행하지 않았다.

### 레벨테스트 초기 문제·템플릿 데이터

레벨테스트 시작 API는 Vercel이 제공하고, 데이터는 Supabase PostgreSQL의
`problem_payload`, `level_test_template`, `level_test_template_item`을 사용한다. 새 Supabase
프로젝트에 이 테이블의 기본 문제와 템플릿이 없으면, 앱 공개 전에 아래 데이터 준비 작업을 실행한다.
이 작업은 Lightning API를 배포하거나 실행하는 절차가 아니다. UPSERT 방식이므로 재실행할 수 있다.

```bash
cd /teamspace/studios/this_studio/aiflow-worker/omj
python scripts/seed_level_test_static_db.py --db /tmp/aiflow-level-test-static.db
python scripts/migrate_level_test_to_postgres.py --source /tmp/aiflow-level-test-static.db
```

첫 명령은 검수된 정적 문제 98개와 50문항짜리 템플릿 5개를 만들고 무결성을 검증한다.
둘째 명령은 `DATABASE_URL`을 사용해 이를 Supabase PostgreSQL에 넣는다.
완료 뒤 Vercel의 `POST /level-tests/placement/start`가 문항을 반환하는지 확인한다. 생성한
`/tmp` 파일은 이관 뒤 보관할 필요가 없으며 Git에 추가하지 않는다.

## 3. Vercel

Vercel에서 이 저장소의 `hotfix` 브랜치와 저장소 루트를 선택한다. Framework Preset은 `Other`로 두고
`vercel.env.example`의 값을 Project Environment Variables에 등록한 뒤 배포한다.

현재 일반 문항 ID 조회와 결정형 문항 채점은 `data/content/question-bank-v1.sqlite`의
읽기 전용 Vercel 스냅샷을 기준으로 한다. 이 파일에는 `quest_header`, `quest_info`,
`quest_data`, `solve_step`만 있으며 사용자·평점·제출 데이터는 포함되지 않는다. 현재
스냅샷은 `omj/quests.db`의 SHA-256 `ab32a63dac62b316b2a301f2b83f86d83dd699b730ffc41acda76c861c932fca`
에서 추출한 3,111개 문항과 12,392개 풀이 단계다. Vercel은 첫 조회에서 번들 DB의 SHA-256과
문항 수를 검증한다.

원본 문항 DB가 승인된 변경으로 바뀌면 `python tools/export_vercel_question_bank.py --force`로
콘텐츠 테이블만 재수출하고, `api/question_bank.py`의 체크섬·문항 수 및 관련 계약 테스트를
함께 갱신한다. 이 스냅샷 이관만으로 평점·약점·이어풀기·랭킹 저장소 이관이 완료된 것은 아니다. 레이팅 API 코드 경로와 migration 초안은 있지만,
2026-10-13 실제 Supabase에 8개 중앙화 SQL을 적용했고 PostgreSQL 학생 26명 및 개인 KV/풀이 44행을 충돌 없이 복구했다.
기존 rating/tag/제출 원장과 계정 보존 검사는 통과했다. 다만 여러 연결 동시성, 최신 legacy 약점/OX source,
Vercel 배포 및 실제 OCR 왕복 검증 전에는 제품 전환 완료로 볼 수 없다.

### 문제 복습 이력

Flutter 복습센터의 `GET /habit/problem`과 `POST /habit/problem/replay`는 Vercel이 제공한다.
복습 목록은 사용자별 `problem_habit.legacy.*` 이관 행과 이관 이후 `solve_history.*` 풀이를
합치며, `codebase_id`와 `seed`가 canonical question snapshot에서 유일하게 확인되는 문항만 다시 연다.
기존 retry count·태그·제목은 `user_habit`에서 추가 복사하고 원본은 삭제하지 않는다.

원본 PostgreSQL 연결은 migration 프로세스에서만 설정한다. ID가 UUID가 아닌 계정은 명시적인
`SOURCE_USER_HABIT_USER_ID_MAP_JSON` 매핑이 필요하며, destination 계정이 모두 있어야 복사할 수 있다.
읽기 전용 사전 확인은 `SOURCE_USER_HABIT_DATABASE_URL`만 설정한 뒤 실행한다.

```powershell
python tools/migrate_user_habits_to_supabase.py --dry-run
python tools/migrate_user_habits_to_supabase.py --apply
```

두 번째 명령은 `TARGET_SUPABASE_DATABASE_URL`도 요구한다. 복사는 serializable transaction,
deterministic key, existing-row equality 및 SHA-256 검증을 사용하고, 충돌 시 전체를 rollback한다.
2026-10-13 실제 source `user_habit`은 0행으로 확인했다. source/target이 같은 Supabase인 학생 계정·개인 KV·풀이 이력은
`supabase_legacy_student_accounts.sql`로 복구했다. 7월 로컬 SQLite는 최신 원본이 아니므로 적용하지 않았다.

```text
GET https://YOUR-PROJECT.vercel.app/health
POST https://YOUR-PROJECT.vercel.app/auth/register
POST https://YOUR-PROJECT.vercel.app/auth/login
GET https://YOUR-PROJECT.vercel.app/auth/me
GET https://YOUR-PROJECT.vercel.app/arena/summary
GET https://YOUR-PROJECT.vercel.app/arena/rankings?queue_type=duel_exam
POST https://YOUR-PROJECT.vercel.app/api/ocr/jobs
GET https://YOUR-PROJECT.vercel.app/api/ocr/jobs/{job_id}
```

`SUPABASE_SERVICE_ROLE_KEY`, `OMJ_JWT_SECRET`, `LIGHTNING_WAKE_SECRET`,
`VERCEL_OCR_WORKER_SECRET`은 앱 빌드 값이나 Git에 넣지 않는다. Supabase service role은 Vercel에만
둔다. Lightning worker는 Vercel 내부 OCR API를 통해서만 작업을 claim/complete/fail한다.
콜드 스타트는 Vercel이 `LIGHTNING_API_AUTH`로 기존 Studio를 `cpu-4`에서만 재개한다. GPU 머신 이름은
코드에 허용하지 않아 wake 요청으로 유료 GPU를 시작할 수 없다.

대결장 요약·랭킹은 카나리 UI가 404 없이 열리기 위한 초기 계약만 제공한다. Vercel 함수는
실시간 WebSocket 매칭 서버가 아니므로 두 큐는 `coming_soon` 상태이며, 실제 매칭은 별도 상시
Arena 서버를 연결하기 전까지 활성화하지 않는다.

## 4. Flutter 앱

앱 API 기본 주소는 Vercel이다. `API_BASE_URL`을 Lightning 공개 URL로 지정하지 않는다. OCR 큐도
같은 Vercel origin의 `/api/ocr` 아래에서 등록·조회하고, Vercel이 승인된 OCR 작업만 Lightning에
전달한다.

```powershell
flutter build apk `
  --dart-define=API_BASE_URL=https://YOUR-VERCEL-PROJECT.vercel.app
```

학생서비스/포인트 상점 데모를 canary에서만 보이게 하려면 웹 빌드에 아래 define을 추가한다.

```powershell
flutter build web --release `
  --dart-define=STUDENT_SERVICES_DEMO=true `
  --dart-define=STUDENT_STORE_DEMO=true `
  --dart-define=OSM_TILE_URL=https://tile.openstreetmap.org/{z}/{x}/{y}.png
```

두 flag를 생략하면 서비스·상점 메뉴와 전역 검색 결과는 숨겨진다. 상점 API는
`STUDENT_STORE_DEMO=true` 환경변수일 때만 노출하며, 구독 버튼은 결제 UI 확인만 수행한다.

OCR 큐는 `API_BASE_URL/api/ocr`을 사용해 제품 API와 같은 Vercel origin에 고정한다. 큐는 `mode=ocr`만
받고 Lightning은 TexTeller 추론만 수행한다. OCR이 끝나면 Vercel은 canonical question bank와 Kiln을 사용해 채점하고,
한 DB RPC에서 채점 결과·풀이 이력·시험 점수표·약점 카운터를 저장하며 모든 문항 정답 완료 시 이어풀기를 제거한다. grade RPC migration,
단일 실제 PostgreSQL 연결의 SAVEPOINT smoke는 통과했다. 여러 연결 동시성, Kiln 인증 호출, 실제 브라우저 사용자 여정은 아직 별도 검증 대상이다.

### 실제 DB 적용 근거와 재검사

`tools/prepare_product_api_cutover.py --rollback`은 private snapshot과 SQL smoke를 포함하되 마지막에 rollback하는 사전검사 SQL을 만든다.
옵션 없이 실행하면 commit bundle을 D: `build/temp`에 만든다. 이미 적용된 DB에 무조건 재실행하지 말고
`supabase_product_api_postflight.sql`로 계정·원장 보존, RLS, RPC를 읽기 전용 확인한다.
적용 hash/후속 경기 답안 snapshot 정리/미검증 범위는 `design/student/audits/2026-10-11-active-goal-progress.md`에 기록했다.

## 운영 경계

- Vercel 요청 제한을 고려해 큐 JSON은 기본 4MB를 넘기지 못한다.
- 큐 선점은 PostgreSQL `FOR UPDATE SKIP LOCKED`이며 최대 3회 재시도한다.
- 완료 시 원본 payload는 즉시 비우고 결과 행도 기본 24시간 후 삭제한다.
- 이 구성은 20명 미만 카나리용이다. 2,000 동접 운영 구성은 별도 상시 worker와 정식 메시지 큐가 필요하다.

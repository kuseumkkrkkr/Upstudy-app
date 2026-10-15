# 내부 콘텐츠 관리

현재 코드 구현과 실제 서비스 활성화는 별개다. 기본값은 비활성/접근 거부다.

## 활성화 순서

1. 기존 가입 규칙으로 관리자용 `admin` 계정을 생성한다. 영문·숫자 포함 8~20자 비밀번호가 필요하며 인증 규칙을 우회하지 않는다.
2. Supabase SQL Editor에서 `supabase_content_admin.sql`을 검토·실행한다. 기존 계정·콘텐츠·학생 기록을 삭제하거나 승격하지 않는 추가 마이그레이션이다.
3. 계정 소유자를 확인한 **정확한 user_id UUID**로 `canary_content_admins(user_id,active)`에 한 행을 등록한다. 아이디 문자열만 믿고 임의 기존 계정을 승격하지 않는다.
4. 암호학적으로 무작위인 32바이트 이상 전용 API 키를 생성한다. Vercel에는 원문이 아닌 SHA-256을 `CONTENT_ADMIN_API_KEY_SHA256`로 설정한다. 원문은 승인된 관리자에게만 전달한다. Supabase/service role/JWT/OCR 키를 재사용하지 않는다.
5. Vercel에서 `CONTENT_ADMIN_ENABLED=true`를 설정하고 검증된 hotfix 후보를 배포한다. `/admin`에서 admin 로그인 **및** 전용 API 키를 입력한다.
6. 실제 DB 두 연결의 생성/충돌/재시도·보관/복원·다른 학생 거부를 검증한다. mock 테스트는 DB 동시성 증거가 아니다.

API 키·Bearer는 탭 메모리에만 존재한다. 새로고침·연결 해제로 제거된다. URL·브라우저 저장소·Flutter 번들에 넣지 않는다. 관리자 로그인도 기존 `/auth/login`을 재사용한다. 계정의 admin 권한은 JWT role이 아닌 별도 DB membership을 매 요청 검사하고, 쓰기 트랜잭션에서도 재검사한다.

## API

모든 `/admin/api` 요청: `Authorization: Bearer ...`와 `X-Admin-Api-Key: ...`가 모두 필수다. 모든 쓰기에는 `X-Idempotency-Key`(1~160자)를 추가한다. 응답이 불명확하면 동일 요청/키로 재시도한다.

| 경로 | 입력/결과 |
|---|---|
| GET `/admin/api/content` | 원본+저장 카탈로그, version, archived |
| PUT `/admin/api/content/{id}` | `id,kind,title,description,grade_band,difficulty,problem_ids,version` |
| DELETE `/admin/api/content/{id}?version=N` | 영구 삭제가 아닌 보관. 학생 보유/진도 유지 |
| POST `/admin/api/content/{id}/restore?version=N` | 원본 그대로 공개 목록에 복원 |

종류는 `course`, `exam`, `problem_set`. 등록 문항은 기존 canonical question snapshot에서 검증한다. 가격은 무료로 고정한다. 공개한 문항·종류 변경은 새 ID로 등록해야 기존 답안 의미가 보존된다. 코스는 문항당 하나의 기존 `problem_solve` 모듈을 생성한다. 시험·문제집도 원본 문항을 사용하며 샘플 생성기로 바꾸지 않는다. 학생 목록에서는 보관 자료를 숨기되 기존 보유자의 상세·문항 조회는 유지한다. 콘텐츠 모드 활성화 후 DB 오류는 503으로 표시하고 번들 원본으로 조용히 되돌리지 않는다.

## 책임/변수

| 코드 | 입력·반환 / 상태·실패 |
|---|---|
| `content_admin.install` | 기존 앱/DB factory/인증/원장/문항 조회를 받아 관리자 경로 등록 |
| `admin` dependency | JWT 사용자+전용 키 → 검증 user_id; 미설정503, 비관리자/잘못된 키403 |
| `catalogue` / `_effective_catalog` | 번들 원장+DB override → 표시 목록; 보관 숨김 또는 보유자용 포함 |
| `admin_write_content` SQL | actor/id/payload/expected version/archive/key → 새 version; 동일 키 재생, 다른 본문·버전409 |
| `_loadOwnedExams` | 현재 사용자 보유 API → 책가방 상태; 계정 epoch/scope 검증, 오류를 빈 목록으로 숨기지 않음 |
| `_loadManagedMaterials(kind)` | 선택 종류의 실제 저장소 → 자료 행/열기 콜백; 시험지는 교재·북마크 장애와 독립 조회 |
| More `_entries` | 현재 학습/도구/내 메뉴와 demo flag → 표시 항목; shrinkWrap+최대 화면 높이로 크기 결정 |

`_ownedExams`는 화면/계정 수명, API 출처 시험지 목록이다. `_ownedExamsFailed`는 조회 실패 표시용 boolean이며 서버에 저장하지 않는다. `version`은 DB 콘텐츠별 양의 정수(미저장 원본0), 낙관적 잠금 단위다. admin.js `pending`은 응답 불명 쓰기의 키/요청 지문이며 탭 메모리에만 보존된다. `token`/`apiKey`는 같은 탭 수명의 비밀값으로 로그 출력 금지다.

## 현재 검증 범위

API 단위/회귀와 Flutter 위젯 검사는 실행 원장에 기록한다. 실제 관리자 계정/전용 키 설정, Supabase migration 적용, 실제 PostgreSQL 동시성, 배포본 권한 검사는 별도 통과 전까지 미검증이다. 일반 사용자 로그인 실패를 관리자 권한으로 우회하지 않는다.

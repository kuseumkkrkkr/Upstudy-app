# 기능·알고리즘·엔드포인트 보존 명세

리디자인은 표현 계층만 교체합니다. `lib/services`, `lib/models`, 요청 payload, 응답 파싱, 상태 전이, 라우팅 인자, 스트리밍 및 폴링 주기는 명시적인 별도 승인 없이 수정하지 않습니다.

## 고정 라우트

- `/`, `/login`, `/register`, `/dashboard`
- `/course-builder`, `/courses`, `/exam-builder`, `/problem-editor`
- `/textbook-builder`, `/teacher/documents`, `/teacher/operations`
- `/teacher/social`, `/teacher/store`, `/groups`, `/academy/dashboard`
- 동적 `/group/detail`: `groupId`, `groupName`, `academyId` 인자를 그대로 전달

## 문항 제작 스튜디오 필수 흐름

- 생성 태그/코스 해시태그/문항 트레이 초기 로드
- 직접 제작, flow draft 변형, prompt note 변형, 객관식 변환
- 문제 DB 검색과 필터, 교재·시험지 소스 선택
- 변형 채점, 트레이 저장, 취소 및 오류 복구
- 관련 계약: `/quests/generation-tags`, `/courses/hash-tags`, `/quests/tray`, `/quests/variants/*`, `/exam-editor/problems/search`, `/analysis/solve/variant-grade`

## 시험지 제작 스튜디오 필수 흐름

- 시험지 생성/저장/재진입, 문제 검색, 트레이 가져오기
- 문항 선택·정렬·제외, AI 자동 배치, 소스 토글
- 배포 상태 폴링, PDF URL 생성과 열기
- 관련 계약: `/exam-editor/papers`, `/exam-editor/problems/search`, `/exam-editor/tray/import`, `/exam-editor/arrange/ai`, `/exam-editor/source/toggle`, `/exam-editor/papers/{paperId}/deploy`, `/exams/{examId}`, `/exams/{examId}/pdf`

## 전면 교사용 페이지 필수 도메인

- 인증/프로필: `/auth/*`, `/user/storage/*`
- 코스: `/courses/*`, `/courses/v2/*`
- 교재/문서: `/textbooks/*`, `/teacher/documents`
- 학원 운영: `/academy/groups`, `/academy/assignments`, `/academy/attendance`, `/academy/consult`, `/academy/snapshots`, `/academy/timetable/*`, `/academy/tuition`
- 그룹/소셜/채팅: `/social/friends/*`, `/social/friend-requests/*`, `/social/messages`, `/social/conversations`, `/social/study-groups/*`, `/ws/social`
- 분석/학습: `/analysis/*`, `/rating/*`, `/weakness/tags`, `/habit/problem*`, `/history/solve`
- 상점/AI: `/teacher/store/*`, `/serverchat/*`, `/quests/generate*`, `/csat/cubic`, `/ox_quiz*`

## 구현 단계 회귀 방지 규칙

1. 화면별 기존 `ApiClient.instance` 호출 집합을 변경 전후 비교합니다.
2. `ApiContract`, `ApiPaths`, `ApiClient`, 서비스/모델 파일은 UI 커밋과 분리합니다.
3. `Navigator` 목적지와 반환 타입(`bool`, `Map`, 모델)을 그대로 유지합니다.
4. 비동기 경계의 `mounted`, busy, cancel, polling, stream 종료 로직을 유지합니다.
5. 모바일에서 모달을 풀 페이스 route/sheet로 바꾸더라도 반환값과 호출 시점은 동일하게 유지합니다.
6. 2,000명 이상 동시 사용을 고려해 리디자인 과정에서 추가 API 호출, 중복 폴링, N+1 요청을 만들지 않습니다.

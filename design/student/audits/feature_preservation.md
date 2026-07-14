# 학생 앱 기능 보존 감사

## 원칙

이 HTML은 구현물이 아니라 리디자인 검토용 시안이다. UI를 간결하게 바꾸더라도 아래 상태·알고리즘·연결 계약을 생략할 수 없도록 각 화면 하단에 메서드와 엔드포인트를 표시한다. 시안 자체에서는 어떤 API도 호출하지 않는다.

## 화면 범위

| 영역 | 시안 화면 | 보존 대상 |
|---|---|---|
| 진입·계정 | 랜딩 맥락, 로그인, 회원가입, 프로필, 설정 | 일반·카카오 로그인, 토큰 검증, 아이디 중복 검사, 단계별 가입 데이터, 계정 수정·삭제·로그아웃 |
| 학생 홈 | 학생 홈, 홈 내 오늘 할 일 모달, 일정 | OVR, 평점 변화, 50문항 이전 추정 상태, 활동 배지, 출석, 날짜별 과제·상세·제출, 개인 일정 동기화, 일일 퀘스트, 공지·소셜 알림 |
| 코스 | 코스 탐색, 상세, 통합 학습 | OVR 추천, 검색·태그, 등록·재정렬, 현재 단원 자동 펼침, 미션 유형별 라우팅, runtime state, next/submit, 최소 시간·선행 모듈 정책 가드, 완료 후 상세 갱신, 중단·재개 |
| 문제 풀이 | 문제 풀이, Flow 분석, 오답 | 객관식·주관식, 필기 이어풀기, 힌트, 채점 후 Flow 분석, 단계별 정오답·AI 의견, 다음 문제·다시 풀기, 약점·습관, 변형 문제, OX |
| 시험지 | 시험지 풀이, 채점 보고서 | A4 연속 종이 캔버스, 페이지 내부 2열×2행 문항, 썸네일 이동, zoom/pan, 스트로크 좌표, 펜·지우개, undo, 자동 저장, 종료·채점, 히트맵 |
| 교재 | 내 교재, 교재 리더 | DOCX·콘텐츠 블록·LaTeX, 접이식 장·절 목차, 페이지·스크롤 전환, 교재 검색, 북마크, 펜·형광펜·색상·지우개와 필기 자동 저장, 글자 크기, 개념 태그, 마지막 페이지, 최소 체류 시간, heartbeat, 완료 |
| 성취 | 레벨 테스트, 홈 일일 퀘스트, 코스 챌린지, 아레나 | 배치 테스트 start/answer/submit, 홈 모달의 일일 퀘스트 event/complete, 코스 런타임 문제 묶음, 1v1·2v2 시험/OX, 티어, 제한 시간, 재시도, 팀 채팅 파쇄 |
| 커뮤니티 | 친구/소셜 허브, 그룹, 그룹 공간, 학원, 채팅 | 친구 OVR 랭킹과 내 태그 변화, 친구 검색·요청·수락·거절·취소·삭제, 쪽지함·대화 삭제, 초대 메타 확인 후 코드 참가, 공개·비밀번호 그룹 검색, 그룹 생성, 문제풀기·시험지·채팅 3탭, 최근 60일 풀이 최대 5개 공유, Flow 태그·공유자·기간 필터와 내 공유 취소, 학생 답안을 제외한 시험지 공유, 최근 채팅 30개 우선·최대 500개, 멤버·공지, WebSocket |
| 도구 | 학습 도구, 그래프, Flow, 마켓 | 타이머·노트·포커스·서버 채팅, 사용자 저장소, JSXGraph 플랫폼 렌더러, Flow 접근 제한·변형 연결 |

## 핵심 알고리즘

1. **OVR 표시**: `max(rating, 1200) - 1200` 값을 표시 범위로 제한하고 128로 나눈 OVR을 사용한다.
2. **평점 신뢰도**: 누적 풀이 50문항 전에는 추정 상태를 보여주며, 상승률 표시 상한은 OVR 변화 0.5 기준으로 0~100%를 계산한다.
3. **코스 런타임**: 현재 미완료 단원을 우선 펼치고 `runtime state → next module → module type UI → submit result → course detail reload → next` 순서를 유지한다. `textbook_view`, `problem_solve`, `exam_solve`, `level_test`, `wrong_answer_review`, `challenge_group`, `curriculum_group` 라우팅과 최소 시간·선행 모듈 정책을 우회하지 않는다.
4. **교재 런타임**: `start → heartbeat → complete`를 유지하며 최소 체류 시간과 마지막 읽기 위치를 보존한다.
5. **시험지 상호작용**: A4 `794×1123` 연속 페이지와 32px 간격, 페이지 내부 2열×2행 문항 배치, 0.5~2.0 확대·이동 변환, 보기 영역 좌표 선택, 페이지별 스트로크, undo, 답안 상태와 채점 결과를 분리하지 않는다.
6. **Flow 분석**: 답안·시간·행동 데이터를 제출한 직후 별도 분석 대시보드를 만들지 않고 정오답·풀이 시간·약점 단계·AI 의견을 Flow 상단에 요약한다. 원본 `FlowGraphBuilder`의 순차·분기·병합 연결, 220px 노드와 곡선 연결선, 정답·오답·이후 단계 상태, 60~250% 확대·이동, 선택 노드의 힌트·정답 풀이를 분리하지 않는다.
7. **아레나**: 서버가 발급한 `matchId`, 경기 제한 시간, 동일 문항, 남은 재시도, 팀 점수를 기준으로 상태를 갱신하며 팀 채팅은 경기 종료 시 파쇄된다.
8. **일일 퀘스트**: 개별 이벤트와 묶음 이벤트를 기록한 뒤 완료 조건 충족 시에만 보상을 확정한다.

## 연결 계약 범주

- 인증: `/auth/login`, `/auth/kakao`, `/auth/register`, `/auth/username/check`, `/auth/validate`, `/auth/me`
- 코스: `/courses`, `/courses/enrolled`, `/courses/enrollments/reorder`, `/courses/v2/runtime/*`
- 풀이·분석: `/quests`, `/analysis/solve`, `/habit/problem`, `/weakness/tags`, `/rating/*`, `/history/solve`
- 시험: `/exams/{examId}`, 사용자 저장소 기반 스트로크·이어풀기
- 교재: `/textbooks/*`, `/courses/v2/{courseId}/documents`, `/courses/v2/runtime/textbook-view/*`
- 성취: `/level-tests/placement/*`, `/challenges/daily-quests/*`, `/arena/*`
- 소셜: `/social/friends/*`, `/social/friend-requests/*`, `/social/messages`, `/social/study-groups/*`, `/ws/social`
- 학원·일정: `/academy/assignments/my`, `/academy/students/me/schedule`, `/academy/submissions/*`, `/academy/timetable/*`
- 도구: `/serverchat/*`, `/user/storage/{key}`, JSXGraph CDN 렌더러

세부 화면별 기능·메서드·엔드포인트는 `student-app.js`의 `screens` 원장이 단일 기준이다.

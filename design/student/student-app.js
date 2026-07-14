'use strict';

const screenHost = document.getElementById('screenHost');
const primaryNav = document.getElementById('primaryNav');
const mobileNav = document.getElementById('mobileNav');
const mainStage = document.getElementById('mainStage');
const actionPanel = document.getElementById('actionPanel');
const actionTitle = document.getElementById('actionTitle');
const actionKicker = document.getElementById('actionKicker');
const actionBody = document.getElementById('actionBody');
const actionFooter = document.getElementById('actionFooter');
const scrim = document.getElementById('scrim');

// 필요 변수: 화면 ID별 라벨, 그룹, 아이콘, 기능, 서비스 메서드, 엔드포인트.
// 작동 원리: 학생 앱의 실제 기능 계약을 단일 원장으로 유지하고 화면과 검증 정보가 같은 데이터를 사용한다.
const screens = {
  dashboard: { label: '학생 홈', group: '오늘', icon: '⌂', kind: 'dashboard', features: ['프로필·학년 표시', 'OVR 환산', '평점 변화율', '50문항 이전 추정 안내', '오늘 할 일 모달', '날짜별 과제·완료 상태', '과제 상세·제출 이동', '개인 일정 동기화', '일일 테스트·퀘스트 묶음', '퀘스트 이벤트·묶음 완료', '커리큘럼', '학습 모드', '소셜 알림', '활동 배지', '연속 학습', '최근 공지'], methods: ['fetchAccountSummary', 'fetchUserRating', 'fetchDailyQuestBundle', 'submitDailyQuestEventBundle', 'completeDailyQuestBundle', 'listMyAssignments', 'syncMyStudentSchedule', 'listMySystemGroupNotices', 'recordAttendance'], endpoints: ['/account/summary', '/rating/user', '/challenges/daily-quests', '/challenges/daily-quests/event', '/challenges/daily-quests/complete', '/academy/assignments/my', '/academy/students/me/schedule', '/social/study-groups/notices/my/system'] },
  courses: { label: '코스 탐색', group: '학습', icon: '▦', kind: 'courses', features: ['이어 학습 우선 노출', '수강 코스 순서 변경', '코스명·설명·태그 검색', '해시태그 필터', '내 OVR 추천', '추천 코스 비교', '공개·배정·수강 코스 병합', '완료 코스 표시 전환', '수강 전 상세·신청', '수강 중 현재 진도 직행', '완료 코스 미리보기', '등록'], methods: ['listCourses', 'listEnrolledCourses', 'enrollCourse', 'reorderEnrollments', 'fetchCourseRuntimeState'], endpoints: ['/courses', '/courses/hash-tags', '/courses/enrolled', '/courses/enrollments/reorder', '/courses/{id}/runtime/state'] },
  'course-detail': { label: '코스 상세', group: '학습', icon: '◫', kind: 'courseDetail', features: ['코스 메타데이터', 'OVR·난이도', '교사 정보', '태그', '모듈 구성', '등록', '등록 후 시작', '교재 미리보기'], methods: ['getCourse', 'enrollCourse', 'fetchCourseRuntimeState', 'getCourseTextbook'], endpoints: ['/courses/{id}', '/courses/{id}/enroll', '/courses/{id}/runtime/state', '/courses/v2/{courseId}/textbooks/{textbookId}'] },
  'course-learning': { label: '코스 학습', group: '학습', icon: '▶', kind: 'learning', features: ['현재 단원 자동 펼침', '단원 접기·펼치기', '모듈 상태 머신', '정책 가드', '다음 모듈', '최소 학습 시간', '교재 학습', '문제 풀이', '시험 풀이', '레벨 테스트', '챌린지', '커리큘럼 그룹', '오답 복습', '유형별 미션 라우팅', '완료 결과 제출', '완료 후 코스 상세 갱신', '중단 후 재개', '데모 모드 안내'], methods: ['fetchCourseRuntimeState', 'loadCourseRuntimeNext', 'submitCourseRuntimeModule', 'loadCourseProblemSolve', 'startCourseTextbookRuntime', 'heartbeatCourseTextbookRuntime', 'completeCourseTextbookRuntime'], endpoints: ['/courses/v2/runtime/state/{courseId}', '/courses/v2/runtime/next', '/courses/v2/runtime/submit', '/courses/v2/runtime/problem-solve/load', '/courses/v2/runtime/textbook-view/start', '/courses/v2/runtime/textbook-view/heartbeat', '/courses/v2/runtime/textbook-view/complete'] },
  solve: { label: '문제 풀이', group: '학습', icon: '✎', kind: 'solve', badge: '12', features: ['객관식·주관식', '제출 후 Flow 분석', '힌트', '필기', '문항 이동', '임시 저장', '이어풀기', '제출', '채점', '약점 복습 모드', '변형 문항', 'OX 퀴즈'], methods: ['fetchQuestPage', 'saveContinueStrokes', 'loadContinueStrokes', 'submitSolveAnalysis', 'generateVariantFromFlowDraft', 'gradeVariantSolve', 'generateOxQuiz'], endpoints: ['/quests', '/user/storage/{key}', '/analysis/solve', '/quests/variants/from-flow-draft', '/analysis/solve/variant-grade', '/ox_quiz/generate'] },
  'exam-paper': { label: '시험지 풀이', group: '학습', icon: '▤', kind: 'exam', features: ['공용 앱 크롬 제외 전체화면', 'A4 794×1123 종이 캔버스', '연속 페이지·32px 간격', '페이지 내부 2열×2행 문항 배치', 'PC 썸네일 사이드바', '모바일 썸네일 시트', '일관된 SVG 도구 아이콘', '현재 페이지 중심 정렬', '이전·현재·다음 우선 렌더링', '0.5–2.0 확대·이동', '펜 굵기·색상·압력', '지우개', '실행 취소', '문항 보기 좌표 선택', '페이지별 필기 저장', '자동 저장', '시험 종료 확인', '채점', '히트맵', '문항별 보고서', 'PDF 미리보기'], methods: ['getExamStatus', 'layoutItems', 'saveContinueStrokes', 'loadContinueStrokes', 'selectOptionAt', 'submitSolveAnalysis', 'submitRating'], endpoints: ['/exams/{examId}', '/user/storage/{key}', '/analysis/solve', '/rating/submit'] },
  'wrong-answers': { label: '복습', group: '성취', icon: '↺', kind: 'list', features: ['시험·코스 출처 필터', '약점 태그', '복습할 문제', '다시 풀기', '해설 보기', '완료 상태', '변형 문제 생성', '복습 코스'], methods: ['fetchSolveHistory', 'fetchWeaknessTags', 'replayProblemHabit', 'generateVariantFromPromptNote'], endpoints: ['/history/solve', '/weakness/tags', '/habit/problem/replay', '/quests/variants/from-prompt-note'] },
  'level-test': { label: '레벨 테스트', group: '성취', icon: '◈', kind: 'level', features: ['최초 OVR 산정', '50문항 배치 세션', '문항별 정오답·풀이 시간', '개념 태그 분석', '진행 자동 저장', 'OVR 신뢰도', '강점·보완 태그', '추천 코스 연결'], methods: ['startLevelTestPlacement', 'submitLevelTestPlacementAnswer', 'submitLevelTestPlacement', 'submitLevelTestAnalysis'], endpoints: ['/level-tests/placement/start', '/level-tests/placement/{sessionId}/answer', '/level-tests/placement/{sessionId}/submit', '/academy/analysis/level-test'] },
  arena: { label: '아레나', group: '성취', icon: 'A', kind: 'arena', features: ['1v1 시험', '1v1 OX', '2v2 시험', '2v2 OX', '티어 A~E', '레이팅', '예상 대기', '매칭 취소', '경기 타이머', '동일 문항', '재시도 횟수', '팀 점수', '경기 중 팀 채팅', '종료 시 채팅 파쇄'], methods: ['summary', 'joinQueue', 'cancelQueue', 'matchState', 'submit', 'chat'], endpoints: ['/arena/summary', '/arena/queue/join', '/arena/queue/cancel', '/arena/matches/{matchId}', '/arena/matches/{matchId}/answers', '/arena/matches/{matchId}/chat'] },
  textbooks: { label: '책가방', group: '학습', icon: '▧', kind: 'textbooks', features: ['교재 목록', '시험지 목록', '책 북마크', '문제 북마크', '최근 방문 최대 4개', '교재·시험지·북마크 고정', '교재 제목·태그 검색', '교재 목차·요약 통합 검색', '시험지 통합 검색', 'DOCX 문서함', '학습 모드', '개념 태그', '콘텐츠 블록'], methods: ['listTextbooks', 'listExams', 'getTextbook', 'BookmarkStore.load', 'ProblemBookmarkStore.load', 'LocalDb.getString', 'LocalDb.setString'], endpoints: ['/textbooks', '/textbooks/{textbookId}', '/exams', '/user/storage/{key}'] },
  'textbook-reader': { label: '교재 리더', group: '학습', icon: '▥', kind: 'reader', features: ['독립 전체화면 리더', '접이식 장·절 목차', '현재 목차 자동 선택', '콘텐츠 블록·LaTeX 렌더링', '페이지·스크롤 모드', '이전·다음 페이지', '글자 크기', '교재 내부 검색', '북마크', '펜 필기', '형광펜', '펜 색상·굵기', '지우개', '필기 자동 저장', '개념 태그', '최소 체류시간', '60초 하트비트', '마지막 페이지 보존', '완료 처리', '선생님 교재 모드', '모바일 목차 시트'], methods: ['getCourseTextbook', 'BookmarkStore.add', 'parseTextWithLatex', 'startCourseTextbookRuntime', 'heartbeatCourseTextbookRuntime', 'completeCourseTextbookRuntime', 'LocalDb.getString', 'LocalDb.setString'], endpoints: ['/courses/v2/{courseId}/textbooks/{textbookId}', '/courses/v2/runtime/textbook-view/start', '/courses/v2/runtime/textbook-view/heartbeat', '/courses/v2/runtime/textbook-view/complete', '/user/storage/{key}'] },
  schedule: { label: '학습 일정', group: '오늘', icon: '□', kind: 'schedule', features: ['주간(일별) 일정', '월간 달력', '날짜 선택', '과제 표시', '개인 일정', '완료 체크', '커리큘럼 이력', '서버 동기화'], methods: ['listMyAssignments', 'syncMyStudentSchedule'], endpoints: ['/academy/assignments/my', '/academy/students/me/schedule'] },
  groups: { label: '그룹 스터디', group: '커뮤니티', icon: '◎', kind: 'groups', features: ['내 그룹', '그룹 검색', '그룹 생성', '초대 코드 참가', '초대 메타 확인', '비밀번호 그룹', '멤버 수', '그룹 상세'], methods: ['listMyStudyGroups', 'searchStudyGroups', 'createStudyGroup', 'fetchStudyGroupInviteMeta', 'joinStudyGroupByInviteCode'], endpoints: ['/social/study-groups/mine', '/social/study-groups/search', '/social/study-groups', '/social/study-groups/invite/{code}', '/social/study-groups/join-by-code'] },
  'group-detail': { label: '그룹 공간', group: '커뮤니티', icon: '◉', kind: 'group', features: ['그룹 문제풀기 탭', '내 풀이 최대 5개 공유', 'Flow 태그·공유자·기간 필터', '내 공유 Flow 취소', '그룹 시험지 탭', '내 시험지 선택 공유', '학생 답안 공유 제외', '그룹 채팅 탭', '최근 30개 우선 표시', '이전 메시지 더보기', '최대 500개 메시지', '공유 시험지 채팅 카드', '멤버', '공지', '그룹 나가기'], methods: ['listGroupMembers', 'listGroupNotices', 'fetchSolveHistory', 'listSharedFlows', 'shareFlowToGroup', 'deleteSharedFlow', 'listGroupSharedExams', 'shareGroupExam', 'fetchStudyGroupMessages', 'sendStudyGroupMessage'], endpoints: ['/social/study-groups/{groupId}/members', '/social/study-groups/{groupId}/notices', '/history/solve', '/social/study-groups/{groupId}/shared-flows', '/social/study-groups/shared-flows/{shareId}', '/social/study-groups/{groupId}/shared-exams', '/social/study-groups/{groupId}/messages'] },
  academy: { label: '학원', group: '커뮤니티', icon: '⌂', kind: 'academy', features: ['학원 정보', '그룹', '출석', '과제', '제출', '보고서', '학생 시간표', '학습 스냅샷'], methods: ['listAcademies', 'listAcademyGroups', 'listAttendance', 'listMyAssignments', 'listSubmissions', 'getSubmissionReport', 'listTimetablePlans', 'listSnapshots'], endpoints: ['/academy', '/academy/groups', '/academy/attendance', '/academy/assignments/my', '/academy/submissions', '/academy/submissions/{id}/report', '/academy/timetable/plans/{groupId}', '/academy/snapshots'] },
  friends: { label: '친구/소셜', group: '커뮤니티', icon: '♧', kind: 'friends', badge: '2', features: ['친구 OVR 랭킹', '내 평점·태그 변화', '친구 목록·접속 상태', '친구 검색·요청', '받은 요청 수락·거절', '보낸 요청 취소', '친구 삭제', '쪽지함·1:1 메시지', '대화 삭제', '실시간 소셜 알림', '내 스터디 그룹', '그룹 검색·생성', '초대 코드 참가', '비밀번호 그룹', '그룹 문제·시험지·Flow 공유', '그룹 채팅'], methods: ['fetchFriendRankings', 'fetchUserRating', 'listFriends', 'searchFriends', 'listFriendRequests', 'sendFriendRequest', 'acceptFriendRequest', 'declineFriendRequest', 'cancelFriendRequest', 'removeFriend', 'fetchConversationThreads', 'fetchDirectMessages', 'sendDirectMessage', 'deleteConversation', 'connectSocialWebSocket', 'listMyStudyGroups', 'searchStudyGroups', 'createStudyGroup', 'fetchStudyGroupInviteMeta', 'joinStudyGroupByInviteCode', 'listGroupSharedProblems', 'listGroupSharedExams', 'listSharedFlows'], endpoints: ['/rating/user', '/social/friends', '/social/friends/search', '/social/friend-requests', '/social/friends/rankings', '/social/conversations', '/social/messages', '/ws/social', '/social/study-groups/mine', '/social/study-groups/search', '/social/study-groups', '/social/study-groups/invite/{code}', '/social/study-groups/join-by-code', '/social/study-groups/{groupId}/shared-problems', '/social/study-groups/{groupId}/shared-exams', '/social/study-groups/{groupId}/shared-flows'] },
  chat: { label: '채팅', group: '커뮤니티', icon: '◌', kind: 'chat', badge: '3', features: ['대화 목록', '메시지 조회', '메시지 전송', '대화 삭제', '읽지 않음', 'Flow 공유', '실시간 소셜 WebSocket'], methods: ['fetchConversationThreads', 'fetchDirectMessages', 'sendDirectMessage', 'deleteConversation', 'shareFlow', 'connectSocialWebSocket'], endpoints: ['/social/conversations', '/social/messages', '/social/study-groups/{groupId}/shared-flows', '/ws/social'] },
  marketplace: { label: '마켓', group: '커뮤니티', icon: '△', kind: 'market', features: ['문제·교재 탐색', '카테고리', '검색', '상세 보기', '내 교재 연결', '학습 센터 이동'], methods: ['searchQuests', 'listTextbooks', 'fetchQuestPage'], endpoints: ['/quests', '/textbooks'] },
  tools: { label: '학습 도구', group: '도구', icon: '＋', kind: 'tools', features: ['모달 진입', '노트패드 필압 필기', '무한 확장 캔버스', '펜·형광펜·3색·4굵기', '지우개·라인·실행 취소', '500ms 로컬 저장', '스톱워치·타이머 전환', '랩 기록', '시·분·초 직접 입력', '시간 프리셋', '집중 모드 30분~12시간', '애니메이션 잠금 화면', '3초 잠금 해제', '서버 AI 채팅', '채팅 프로필'], methods: ['LocalDb.getString', 'LocalDb.setString', 'Timer.periodic', 'recordLap', 'startFocus', 'startUnlock', 'getServerChatProfile', 'sendServerChatMessage'], endpoints: ['LOCAL notepad_strokes_v2', 'LOCAL timer/focus state', '/serverchat/config', '/serverchat/message'] },
  graph: { label: '그래프 도구', group: '도구', icon: '⌁', kind: 'graph', features: ['함수·직선·산점도', '예제 검색', '축·격자', '각도 모드', '뷰포트 잠금', '확대·초기화', 'JSXGraph Web iframe', 'Native InAppWebView'], methods: ['buildGraphDocument', 'buildJsxGraphHtml'], endpoints: ['JSXGraph CDN (렌더러 의존)'] },
  flow: { label: 'Flow 분석', group: '학습', icon: '⌘', kind: 'flow', features: ['문제 제출 결과 요약', '정오답·풀이 시간', '단계별 정오답', '약점 단계', 'AI 분석 의견', '다음 문제·다시 풀기', '문제 정보·정답 공개 조건', '문제 북마크', '분기형 풀이 노드', '노드 연결선', '정답·오답·이후 단계 상태', '노드 선택 상세', '힌트·정답 풀이', '캔버스 확대·축소·이동', 'AI 질문', '그룹 Flow 공유', '공유 공식 정보', '공유 풀이 오답 분석', '공유 Flow 삭제', '변형 문제 연결'], methods: ['submitSolveAnalysis', 'ProblemBookmarkStore.add', 'FlowGraphBuilder.build', 'getSharedFlow', 'shareFlowToGroup', 'deleteSharedFlow', 'generateVariantFromFlowDraft', 'replayProblemHabit'], endpoints: ['/analysis/solve', '/user/storage/{key}', '/social/study-groups/{groupId}/shared-flows', '/social/study-groups/shared-flows/{shareId}', '/quests/variants/from-flow-draft', '/habit/problem/replay', '/serverchat/message'] },
  profile: { label: '프로필', group: '계정', icon: '○', kind: 'profile', features: ['내 정보 조회', '아이디·이름·학교·학년', '과정·과목', '프로필 수정', '비밀번호 변경', '교재 페이지 모드', '계정 삭제', '로그아웃'], methods: ['getMyProfile', 'updateMyProfile', 'deleteMyProfile', 'AuthStorage.saveUsername', 'TextbookReaderPreferences.savePageMode', 'clearToken'], endpoints: ['GET /auth/me', 'PUT /auth/me', 'DELETE /auth/me', 'LOCAL auth.jwt/auth.username', 'LOCAL textbook_reader.page_mode'] },
  settings: { label: '설정', group: '계정', icon: '⚙', kind: 'settings', features: ['전체 알림 켜기·끄기', '교재 연속 스크롤', '교재 PDF형 페이지', '오픈소스 라이선스'], methods: ['SharedPreferences.getBool/setBool', 'TextbookReaderPreferences.loadPageMode/savePageMode', 'showLicensePage'], endpoints: ['LOCAL settings.notifications_enabled', 'LOCAL textbook_reader.page_mode', 'LOCAL Flutter license registry'] },
  auth: { label: '로그인', group: '계정', icon: '↪', kind: 'auth', features: ['아이디·이메일 로그인', '카카오톡·카카오계정 로그인', 'JWT 로컬 저장', '시작 시 세션 복원', '5초 프로필 검증', '401·403 토큰 제거', '가입 이동'], methods: ['AuthService.login', 'KakaoLoginService.signIn', 'ApiClient.setToken', 'AuthStorage.readToken', 'getMyProfile', 'clearToken'], endpoints: ['POST /auth/login', 'POST /auth/kakao', 'GET /auth/me', 'LOCAL auth.jwt/auth.username'] },
  signup: { label: '회원가입', group: '계정', icon: '＋', kind: 'signup', features: ['이름 확인', '과정·학년·과목', '학교 자동완성', '아이디 형식·중복 확인', '비밀번호 형식 검증', '선택 이메일 검증', '단계별 임시 데이터', '가입 후 JWT 저장'], methods: ['checkUsername', 'validateField', 'register', 'ApiClient.setToken'], endpoints: ['POST /auth/username/check', 'POST /auth/validate', 'POST /auth/register', 'LOCAL auth.jwt/auth.username'] },
};

// 필요 변수: 액션 ID별 제목, 설명, 입력 필드, 연결 계약.
// 작동 원리: 버튼 클릭 시 실제 네트워크 호출 없이 기능 요구사항과 연결 대상만 패널에 표시한다.
const actions = {
  'academy-info': { title: '학원 정보', kicker: 'ACADEMY', description: '소속 학원과 담당 교사, 연결된 그룹을 확인합니다.', contract: 'listAcademies + listAcademyGroups' },
  'attendance-detail': { title: '출석 기록', kicker: 'ACADEMY', description: '오늘 입실 시각과 최근 출석 기록을 확인합니다.', contract: 'listAttendance → /academy/attendance' },
  'academy-timetable': { title: '학생 시간표', kicker: 'ACADEMY', description: '학원 그룹별 수업 계획과 학생 시간표를 확인합니다.', contract: 'listTimetablePlans → /academy/timetable/plans/{groupId}' },
  'academy-submissions': { title: '제출 기록', kicker: 'ACADEMY', description: '과제 제출 상태와 제출물을 확인합니다.', contract: 'listSubmissions → /academy/submissions' },
  'academy-report': { title: '학습 보고서', kicker: 'ACADEMY', description: '제출 결과와 교사 피드백을 확인합니다.', contract: 'getSubmissionReport → /academy/submissions/{id}/report' },
  'academy-snapshot': { title: '학습 스냅샷', kicker: 'ACADEMY', description: '학원에서 공유한 최근 학습 상태를 확인합니다.', contract: 'listSnapshots → /academy/snapshots' },
  'academy-groups': { title: '학원 그룹', kicker: 'ACADEMY', description: '소속 학원의 수업 그룹을 확인합니다.', contract: 'listAcademyGroups → /academy/groups' },
  'market-filter': { title: '마켓 필터', kicker: 'MARKET', description: '카테고리와 과정, 가격 조건으로 문제와 교재를 좁힙니다.', contract: 'searchQuests + listTextbooks' },
  'study-mode': { title: '학습하기', kicker: 'STUDY MODE', description: '시작할 학습 유형을 선택하세요.', contract: '이어하기 / 코스보기 / 복습 / 문제풀기 / 시험 / 교재보기' },
  'tool-note': { title: '노트패드', kicker: 'LEARNING TOOL · MODAL', description: '원본 삼성노트형 필기 캔버스와 우측 56px 도구막대를 모달 안에 유지합니다.', body: '<div class="notepad-shell"><main class="notepad-canvas has-lines"><span class="notepad-canvas-label">필기 캔버스 · 아래로 스크롤하면 자동 확장</span><svg viewBox="0 0 760 520" aria-label="저장된 필기 예시"><path d="M100 110 C165 86 220 91 286 117 S390 153 468 113"/><path d="M112 182 C206 157 300 161 382 187"/><path d="M425 226 L480 174 L532 238 L595 142"/><path class="note-highlight" d="M92 302 C205 289 318 293 441 306"/></svg></main><aside class="notepad-rail" aria-label="노트패드 도구"><button class="is-danger" type="button" title="나가기">×</button><i></i><button class="is-selected" type="button" title="펜">✎</button><button type="button" title="형광펜">▰</button><button type="button" title="색상"><span class="notepad-color"></span>◉</button><button type="button" title="굵기">≡</button><i></i><button type="button" title="지우개">◇</button><button class="is-selected" type="button" title="라인">▦</button><button type="button" title="실행 취소">↶</button><button type="button" title="모두 지우기">⌫</button></aside><span class="notepad-save-note">로컬 자동 저장 · 500ms</span></div>', contract: 'LocalDb[notepad_strokes_v2] · 필압 스트로크 · 500ms 지연 저장 · 1,400px→50,000px 캔버스 자동 확장 · 실행 취소' },
  'tool-timer': { title: '타이머', kicker: 'LEARNING TOOL · MODAL', description: '원본처럼 스톱워치가 기본이며 타이머로 전환하면 직접 입력과 시간 프리셋이 열립니다.', body: '<div class="timer-original"><div class="timer-mode-toggle" role="tablist"><button class="is-selected" type="button" data-timer-mode="stopwatch">◷ 스톱워치</button><button type="button" data-timer-mode="timer">◒ 타이머</button></div><section class="timer-display"><header><span><i></i> 대기 중</span><em id="timerModeLabel">경과 시간</em></header><strong id="timerDisplayValue">00:00</strong><p id="timerModeCopy">필요할 때 랩을 찍어 구간 시간을 확인합니다.</p><div class="timer-progress" hidden><span></span></div></section><section class="timer-setup" data-timer-setup hidden><div><h3>시간 설정</h3><p>직접 입력하거나 자주 쓰는 시간으로 바로 맞춥니다.</p></div><div class="timer-time-fields"><label><input class="field" value="00">시</label><label><input class="field" value="25">분</label><label><input class="field" value="00">초</label></div><div class="timer-preset-row"><button type="button">+10분</button><button type="button">+30분</button><button type="button">+1시간</button><button type="button">+2시간</button></div></section><div class="timer-controls"><button class="button soft" type="button">↻ 리셋</button><button class="button primary" type="button">▶ 시작</button><button class="button soft" type="button" id="timerThirdAction" disabled>⚑ 랩 추가</button></div></div>', contract: 'Timer.periodic(1초) · 스톱워치/타이머 전환 · 랩 기록 · +5분 · 시/분/초 직접 입력 · 완료 알림' },
  'tool-focus': { title: '집중 모드', kicker: 'LEARNING TOOL · MODAL', description: '원본의 시간 선택과 시작 후 잠금 화면 흐름을 유지합니다.', body: '<div class="focus-original" data-focus-setup><p>설정한 시간 동안 방해를 차단합니다</p><strong id="focusSelectedTime">1시간</strong><input type="range" min="30" max="720" step="30" value="60" data-focus-range aria-label="집중 시간"><div class="focus-time-labels"><span>30분</span><span>12시간</span></div><div class="focus-presets"><button type="button" data-focus-minutes="30">30분</button><button class="is-selected" type="button" data-focus-minutes="60">1시간</button><button type="button" data-focus-minutes="120">2시간</button><button type="button" data-focus-minutes="240">4시간</button></div><button class="button primary focus-start" type="button" data-focus-start>▶ 집중 시작</button></div><div class="focus-running" data-focus-running hidden><div class="focus-running-ring"><strong>01:00:00</strong><span>남은 시간</span></div><h3>집중 중...</h3><p>잠금해제 버튼을 눌러 해제하세요</p><button type="button" data-focus-unlock>⌾ 잠금해제</button><small>해제하려면 3초 카운트다운을 완료해야 합니다.</small></div>', contract: '30~720분/30분 단위 · Timer.periodic(1초) · HapticFeedback · 애니메이션 그라데이션 · 3초 잠금 해제' },
  'graph-examples': { title: '그래프 예제', kicker: 'GRAPH CATALOG', description: '과목·단원·공식 또는 검색어로 원본 예제 구성을 선택합니다.', body: '<div class="action-fields"><label>예제 검색<input class="field" value="이차함수"></label><label>과목<select class="field"><option>중학교 수학</option><option>고등학교 수학</option></select></label><label>단원<select class="field"><option>함수와 그래프</option><option>원의 방정식</option><option>삼각함수</option></select></label></div><div class="list" style="margin-top:16px"><button class="list-row is-active"><span class="feature-icon">⌁</span><span><b>이차함수와 직선</b><small>매개변수 a · 교점 비교</small></span><span>선택됨</span></button><button class="list-row"><span class="feature-icon">○</span><span><b>원의 방정식</b><small>중심과 반지름 이동</small></span><span>›</span></button></div>', contract: 'AiFlowGraphExampleCatalog → _loadExample → ActivityStore.recordGraphPractice' },
  'daily-test': { title: '일일 테스트', kicker: 'DAILY QUEST', description: '현재 코스에서 오늘 풀 수 있는 테스트입니다.', body: '<div class="list"><button class="list-row is-active" data-nav="solve"><span class="feature-icon">01</span><span><b>일차함수 기본</b><small>4/10 진행 · 80 XP</small></span><span>›</span></button><button class="list-row" data-nav="solve"><span class="feature-icon">02</span><span><b>그래프 해석</b><small>미시작 · 60 XP</small></span><span>›</span></button><button class="list-row" data-nav="solve"><span class="feature-icon">03</span><span><b>오늘의 OX</b><small>완료 시 40 XP · 문제 풀이로 이동</small></span><span>›</span></button></div>', contract: 'fetchDailyQuestBundle → submitDailyQuestEventBundle → completeDailyQuestBundle' },
  'today-tasks': { title: '오늘 할 일', kicker: 'TODAY TASKS', description: '별도 페이지를 열지 않고 홈에서 교사 과제와 개인 일정을 확인합니다.', body: '<div class="list"><button class="list-row is-active" data-nav="solve"><span class="feature-icon">✓</span><span><b>일차함수 문제 12개</b><small>교사 과제 · 오늘 22:00 · 진행 4/12 · 수정 불가</small></span><span>›</span></button><button class="list-row" data-nav="textbook-reader"><span class="feature-icon">▧</span><span><b>교재 3장 읽기</b><small>교사 과제 · 최소 8분 · 미시작</small></span><span>›</span></button><button class="list-row"><span class="feature-icon">＋</span><span><b>개인 복습 20분</b><small>학생 일정 · 완료 체크와 편집 가능</small></span><span>›</span></button></div><div class="actions" style="margin-top:14px"><button class="button soft" type="button" data-nav="schedule">일정 달력에서 보기</button></div>', contract: 'listMyAssignments + syncMyStudentSchedule + 과제 상세·제출 이동' },
  'social-home': { title: '알림', kicker: 'SOCIAL', description: '놓친 메시지와 친구·그룹 소식을 확인하세요.', body: '<div class="list"><button class="list-row" data-nav="chat"><span class="feature-icon">◌</span><span><b>새 메시지 3개</b><small>이수학 외 1명</small></span><span>›</span></button><button class="list-row" data-nav="friends"><span class="feature-icon">♧</span><span><b>친구 요청 1개</b><small>박함수님이 요청했습니다.</small></span><span>›</span></button><button class="list-row" data-nav="groups"><span class="feature-icon">◎</span><span><b>그룹 공지 1개</b><small>중2 심화 스터디</small></span><span>›</span></button></div>', contract: 'SocialNotificationStore + /ws/social' },
  'group-chat': { title: '중2 심화 스터디', kicker: 'GROUP CHAT · 12명', description: '그룹 공간을 벗어나지 않고 최근 대화와 공유 자료를 확인합니다.', body: '<section class="group-chat-panel is-modal"><div class="group-chat-head"><span><i></i> 4명 온라인 · 최근 30개부터 표시</span><button type="button">이전 메시지 더보기</button></div><div class="group-chat-messages"><div class="group-chat-date">오늘</div><div class="group-message"><span class="social-avatar is-online">이</span><div><b>이수학 <small>19:42</small></b><p>오늘 챌린지 시험지를 공유했어요. 8시에 같이 시작해요!</p></div></div><div class="group-shared-exam"><span class="group-exam-icon">▤</span><span><b>중2 함수 형성평가</b><small>이수학 · 답안 제외 · 20문항</small></span><button type="button" data-nav="exam-paper">열기</button></div><div class="group-message is-me"><div><b>김학생 · 나 <small>19:45</small></b><p>좋아요. 제 풀이 Flow도 공유할게요.</p></div></div><div class="group-message"><span class="social-avatar">박</span><div><b>박함수 <small>19:46</small></b><p>기울기 7번 문제 같이 확인해요.</p></div></div></div><div class="group-chat-composer"><input value="" placeholder="그룹에 메시지를 입력하세요" aria-label="그룹 메시지"><button type="button" data-action="send-message">전송</button></div></section>', contract: 'fetchStudyGroupMessages → sendStudyGroupMessage + /ws/social' },
  'profile-delete': { title: '계정 삭제', kicker: 'DANGER ZONE', description: '계정 삭제는 되돌릴 수 없으며 현재 비밀번호 확인이 필요합니다.', fields: [['현재 비밀번호', '']], contract: 'DELETE /auth/me { password } → clearToken → 랜딩 이동' },
  'rating-detail': { title: '레이팅 상세', kicker: 'OVR DETAIL', description: '현재 실력과 과목별 변화를 확인하세요.', body: `<section class="rating-detail-summary"><span class="is-primary"><small>현재 OVR</small><strong>18.6</strong><em>이번 주 +0.3</em></span><span><small>누적 풀이</small><strong>128</strong><em>신뢰 구간 확보</em></span><span><small>현재 티어</small><strong>B</strong><em>A까지 220점</em></span></section><section class="rating-detail-main"><article class="rating-tag-card"><div class="card-head"><h3>태그 변화</h3><span class="pill">최근 30일</span></div><div class="rating-tag-grid"><section><small>상승</small><b>#그래프</b><em>+0.8</em><span style="width:82%"></span></section><section><small>하락</small><b>#확률</b><em>−0.2</em><span style="width:28%"></span></section><section><small>강점</small><b>#일차함수</b><em>19.2</em><span style="width:90%"></span></section><section><small>보완</small><b>#기하</b><em>16.4</em><span style="width:61%"></span></section></div><div class="rating-detail-actions"><button class="button soft" type="button">세부 해시태그 검색</button><button class="button soft" type="button" data-nav="solve-analysis">보고서 보기</button></div></article><article class="rating-radar-card"><div class="card-head"><div><span class="eyebrow">SUBJECT BALANCE</span><h3>과목별 OVR 레이더 차트</h3></div><span class="pill">MAX 25.0</span></div><svg class="rating-radar" viewBox="0 0 420 340" role="img" aria-label="공통수학1 19.2, 공통수학2 18.1, 대수 17.4, 미적분1 16.9 레이더 차트"><g class="radar-grid"><polygon points="210,142.5 237.5,170 210,197.5 182.5,170"/><polygon points="210,115 265,170 210,225 155,170"/><polygon points="210,87.5 292.5,170 210,252.5 127.5,170"/><polygon points="210,60 320,170 210,280 100,170"/><line x1="210" y1="170" x2="210" y2="60"/><line x1="210" y1="170" x2="320" y2="170"/><line x1="210" y1="170" x2="210" y2="280"/><line x1="210" y1="170" x2="100" y2="170"/></g><polygon class="radar-value" points="210,65 309,170 210,266 117,170"/><g class="radar-points"><circle cx="210" cy="65" r="5"/><circle cx="309" cy="170" r="5"/><circle cx="210" cy="266" r="5"/><circle cx="117" cy="170" r="5"/></g><g class="radar-labels"><text x="210" y="24" text-anchor="middle"><tspan>공통수학1</tspan><tspan x="210" dy="15">19.2</tspan></text><text x="350" y="164" text-anchor="middle"><tspan>공통수학2</tspan><tspan x="350" dy="15">18.1</tspan></text><text x="210" y="310" text-anchor="middle"><tspan>대수</tspan><tspan x="210" dy="15">17.4</tspan></text><text x="68" y="164" text-anchor="middle"><tspan>미적분Ⅰ</tspan><tspan x="68" dy="15">16.9</tspan></text></g></svg></article></section>`, contract: 'fetchUserRating + fetchTagRatings → conceptTagData 상위 4개 영역 평균 OVR' },
  'activity-history': { title: '학습 활동', kicker: 'ACTIVITY', description: '날짜별 학습 점수와 활동 내역을 확인하세요.', body: '<div class="grid three"><article class="card metric"><span class="muted small">이번 주 점수</span><strong>86%</strong><em>목표 7개 중 6개</em></article><article class="card metric"><span class="muted small">학습 일수</span><strong>12일</strong><em>최고 21일</em></article><article class="card metric"><span class="muted small">총 활동</span><strong>34</strong><em>문제 24 · 기타 10</em></article></div><div class="heatmap" style="margin-top:20px">' + Array.from({ length: 70 }, () => '<i></i>').join('') + '</div><div class="feature-ledger"><span class="pill">문제 24</span><span class="pill">시험지 2</span><span class="pill">교재 6</span><span class="pill">강의 2</span></div>', contract: 'ActivityStore.activityPercentFromScore + 날짜별 활동 원장' },
  'system-notices': { title: '공지사항', kicker: 'NOTICE', description: '전체 공지와 내가 참여한 그룹의 공지를 확인하세요.', body: '<div class="list"><button class="list-row is-active"><span class="feature-icon">!</span><span><b>7월 서비스 업데이트 안내</b><small>전체 공지 · 07.13 · 학습 기록 기능이 개선되었습니다.</small></span><span>›</span></button><button class="list-row"><span class="feature-icon">◎</span><span><b>다음 수업 준비물</b><small>중2 심화 스터디 · 07.12 · 교재와 필기구를 준비하세요.</small></span><span>›</span></button><button class="list-row"><span class="feature-icon">!</span><span><b>아레나 시즌 일정</b><small>전체 공지 · 07.10 · 시즌 마감은 7월 31일입니다.</small></span><span>›</span></button></div>', contract: 'listGlobalSystemNotices + listMySystemGroupNotices' },
  achievements: { title: '도전과제 / 업적', kicker: 'ACHIEVEMENT', description: '학습 활동으로 획득한 뱃지와 다음 도전 진행률을 확인하세요.', body: '<div class="grid three"><article class="card"><div class="badge-gem">7</div><h3 style="margin-top:14px">7일 연속 학습</h3><p class="muted small">획득 완료</p></article><article class="card"><div class="badge-gem"><span>50</span></div><h3 style="margin-top:14px">문제 해결사</h3><p class="muted small">획득 완료</p></article><article class="card"><div class="badge-gem">B</div><h3 style="margin-top:14px">B Tier 진입</h3><p class="muted small">획득 완료</p></article></div><div class="card quiet" style="margin-top:14px"><div class="card-head"><h3>다음: 30일 연속 학습</h3><span class="pill">12 / 30</span></div><div class="progress"><span style="width:40%"></span></div></div>', contract: 'ActivityBadgeCatalog.earnedBadges + nextBadges' },
  'bookbag-search': { title: '전체 검색', kicker: 'BOOKBAG SEARCH', description: '교재 목차·요약과 시험지 내용을 한 번에 검색합니다.', fields: [['검색어', '일차함수 그래프 단원']], contract: '교재 content block + 시험지 제목·태그 로컬 통합 검색' },
  'book-library': { title: '보관된 교재', kicker: 'TEXTBOOK LIBRARY', description: '교재 제목이나 태그로 찾고 자주 쓰는 교재를 고정하세요.', body: '<div class="list"><button class="list-row is-active" data-nav="textbook-reader"><span class="feature-icon">▧</span><span><b>중2 일차함수 개념서</b><small>#중2 #함수 · 고정됨</small></span><span>◆</span></button><button class="list-row" data-nav="textbook-reader"><span class="feature-icon">▧</span><span><b>도형의 닮음 워크북</b><small>#기하 #닮음 · 18쪽</small></span><span>›</span></button><button class="list-row" data-nav="textbook-reader"><span class="feature-icon">▧</span><span><b>확률 실전 100제</b><small>#확률 #실전</small></span><span>›</span></button></div>', contract: 'listTextbooks + pinned textbook local key' },
  'exam-library': { title: '보관된 시험지', kicker: 'EXAM LIBRARY', description: '보관된 시험지를 검색하고 마지막 풀이 상태에서 다시 시작하세요.', body: '<div class="list"><button class="list-row is-active" data-nav="exam-paper"><span class="feature-icon">▤</span><span><b>중2 함수 형성평가</b><small>20문항 · 최근 방문 · 고정됨</small></span><span>◆</span></button><button class="list-row" data-nav="exam-paper"><span class="feature-icon">▤</span><span><b>도형 단원 테스트</b><small>15문항 · 미응시</small></span><span>›</span></button></div>', contract: 'listExams + exam continue state' },
  'book-bookmarks': { title: '책 북마크', kicker: 'BOOKMARK', description: '교재에서 저장한 장·절 위치를 검색하고 고정할 수 있습니다.', body: '<div class="list"><button class="list-row is-active" data-nav="textbook-reader"><span class="feature-icon">◆</span><span><b>기울기는 변화의 비율</b><small>일차함수 개념서 · 42쪽 · 고정됨</small></span><span>◆</span></button><button class="list-row" data-nav="textbook-reader"><span class="feature-icon">◆</span><span><b>닮음비의 활용</b><small>도형 워크북 · 18쪽</small></span><span>›</span></button></div>', contract: 'BookmarkStore.load + pinned bookmark local key' },
  'problem-bookmarks': { title: '문제 북마크', kicker: 'PROBLEM BOOKMARK', description: '문제 풀이 중 저장한 문항을 출처와 함께 확인합니다.', body: '<div class="list"><button class="list-row is-active" data-nav="solve"><span class="feature-icon">✎</span><span><b>문제 1 · 일차함수 기울기</b><small>오늘의 문제 · 고정됨</small></span><span>◆</span></button><button class="list-row" data-nav="solve"><span class="feature-icon">✎</span><span><b>문제 2 · 그래프 해석</b><small>함수 형성평가</small></span><span>›</span></button></div>', contract: 'ProblemBookmarkStore.load + server/local overflow merge' },
  'friend-add': { title: '친구 추가', kicker: 'FIND FRIEND', description: '이름이나 아이디로 학생을 찾고 친구 요청을 보냅니다.', body: '<div class="social-search"><input class="field" value="" placeholder="이름 또는 아이디" aria-label="친구 검색"><button class="button primary" type="button">검색</button></div><div class="list"><button class="list-row"><span class="social-avatar">한</span><span><b>한지수</b><small>@jisu_math · OVR 17.9</small></span><span class="pill">요청</span></button><button class="list-row"><span class="social-avatar">윤</span><span><b>윤도형</b><small>@shape_yoon · OVR 16.8</small></span><span class="pill">요청</span></button></div>', contract: 'searchFriends → sendFriendRequest' },
  'friend-requests': { title: '친구 요청', kicker: 'REQUESTS', description: '받은 요청은 수락·거절하고, 보낸 요청은 전송을 취소할 수 있습니다.', body: '<div class="request-switch"><button class="pill is-selected" type="button">받은 요청 1</button><button class="pill" type="button">보낸 요청 1</button></div><div class="social-request"><span class="social-avatar">박</span><span><b>박함수</b><small>A Tier · 2분 전</small></span><div class="actions"><button class="button primary" type="button">수락</button><button class="button soft" type="button">거절</button></div></div><div class="social-request"><span class="social-avatar">최</span><span><b>최도형</b><small>내가 보냄 · 대기 중</small></span><button class="button soft" type="button">요청 취소</button></div>', contract: 'listFriendRequests → acceptFriendRequest / declineFriendRequest / cancelFriendRequest' },
  'message-inbox': { title: '쪽지함', kicker: 'DIRECT MESSAGES', description: '서버의 최근 메시지를 확인하고 대화를 열거나 삭제합니다.', body: '<div class="list"><button class="list-row is-active" data-nav="chat"><span class="social-avatar">이</span><span><b>이수학</b><small>오늘 챌린지 같이 풀래? · 방금</small></span><span class="nav-badge">2</span></button><button class="list-row" data-nav="chat"><span class="social-avatar">박</span><span><b>박함수</b><small>Flow를 공유했습니다 · 18분 전</small></span><span>›</span></button></div><p class="muted small" style="margin-top:14px">서버 최근 메시지 최대 2,000개만 표시하며 로컬에는 저장하지 않습니다. 대화별 이전 메시지 불러오기와 대화 삭제를 지원합니다.</p>', contract: 'fetchConversationThreads → fetchDirectMessages / sendDirectMessage / deleteConversation' },
  'group-find': { title: '그룹 찾기', kicker: 'FIND STUDY GROUP', description: '그룹 이름으로 검색하거나 받은 초대 코드로 참가합니다.', body: '<div class="action-fields"><label>그룹 이름 검색<input class="field" value="함수 스터디"></label><label>초대 코드<input class="field" value="AF-24K8"></label><label>비밀번호가 있는 경우<input class="field" value=""></label></div><div class="actions" style="margin-top:16px"><button class="button soft" type="button">검색</button><button class="button primary" type="button">코드 확인 후 참가</button></div>', contract: 'searchStudyGroups + fetchStudyGroupInviteMeta → joinStudyGroupByInviteCode' },
  'group-create': { title: '그룹 만들기', kicker: 'NEW STUDY GROUP', description: '그룹 정보와 최대 인원, 선택 비밀번호를 설정합니다.', body: '<div class="action-fields"><label>그룹 이름<input class="field" value="중2 함수 마스터"></label><label>설명<textarea class="field">매주 화·목 함께 문제를 풀어요.</textarea></label><label>최대 인원<input class="field" value="12"></label><label>숫자 비밀번호 4~10자리 · 선택<input class="field" value=""></label><label>대표 이미지 · 선택<input class="field" value="선택된 파일 없음" readonly></label></div>', contract: 'createStudyGroup(name, description, maxMembers, image, password)' },
  'group-flow-filter': { title: '공유 Flow 필터', kicker: 'GROUP FLOW FILTER', description: '태그, 공유자, 날짜 범위를 함께 적용해 그룹 풀이를 찾습니다.', body: '<div class="action-fields"><label>태그<input class="field" value="#일차함수 #기울기"></label><label>공유자<input class="field" value="이수학"></label><label>기간<select class="field"><option>최근 7일</option><option>최근 30일</option><option>직접 선택</option></select></label></div>', contract: 'listSharedFlows(groupId, tags, userId, from, to, limit: 30)' },
  'group-share-flow': { title: '내 풀이 공유', kicker: 'SHARE SOLVE HISTORY', description: '최근 60일 풀이 내역에서 최대 5개를 선택해 Flow로 공유합니다.', body: '<div class="list"><button class="list-row is-active"><span class="feature-icon">✓</span><span><b>두 점을 지나는 일차함수</b><small>#일차함수 #기울기 · 오늘</small></span><span>선택</span></button><button class="list-row"><span class="feature-icon">02</span><span><b>그래프의 평행이동</b><small>#그래프 · 어제</small></span><span>○</span></button><button class="list-row"><span class="feature-icon">03</span><span><b>두 직선의 교점</b><small>#연립방정식 · 3일 전</small></span><span>○</span></button></div>', contract: 'fetchSolveHistory(days: 60, limit: 30) → shareFlowToGroup × max 5' },
  'group-share-exam': { title: '시험지 공유', kicker: 'SHARE EXAM', description: '문서함의 내 시험지를 선택해 그룹에 공유합니다. 학생 답안은 포함되지 않습니다.', body: '<div class="action-fields"><label>내 시험지<select class="field"><option>중2 함수 형성평가 · 20문항</option><option>일차함수 단원평가 · 15문항</option></select></label></div><div class="card quiet" style="margin-top:14px"><b>공유 범위</b><p class="muted small">시험지 제목과 문항만 공유되며 필기·선택 답안·채점 결과는 제외됩니다.</p></div>', contract: 'ExamPaperStore.load → shareGroupExam(groupId, examId) → owner validation' },
  'group-members': { title: '그룹 멤버', kicker: '12 / 20 MEMBERS', description: '현재 그룹의 멤버와 역할을 확인합니다.', body: '<div class="list"><div class="list-row is-active"><span class="social-avatar">김</span><span><b>김학생 · 나</b><small>멤버 · 온라인</small></span><span>B</span></div><div class="list-row"><span class="social-avatar">이</span><span><b>이수학</b><small>그룹장 · 온라인</small></span><span>A</span></div><div class="list-row"><span class="social-avatar">박</span><span><b>박함수</b><small>멤버 · 18분 전</small></span><span>B</span></div></div>', contract: 'listGroupMembers(groupId)' },
  'share-flow-group': { title: '그룹에 Flow 공유', kicker: 'SHARE FLOW', description: '내 스터디 그룹을 복수 선택해 현재 풀이 흐름과 단계 상태를 공유합니다.', body: '<div class="list"><button class="list-row is-active"><span class="feature-icon">✓</span><span><b>중2 심화 스터디</b><small>선택됨 · 멤버 12명</small></span><span>✓</span></button><button class="list-row"><span class="feature-icon">◎</span><span><b>수학 아레나 팀</b><small>멤버 4명</small></span><span>○</span></button></div><p class="muted small" style="margin-top:14px">codebaseId, seed, questId, 문제 제목, 단계 상태, 공식, 정답 풀이, 태그와 난이도를 함께 보존합니다.</p>', contract: 'listMyStudyGroups → shareFlowToGroup' },
  'bookmark-flow-problem': { title: '문제 북마크', kicker: 'FLOW BOOKMARK', description: '현재 문제와 Flow 단계 수를 문제 북마크에 저장합니다.', body: '<div class="card quiet"><b>두 점을 지나는 일차함수</b><p class="muted small">Flow 5단계 · 문제 ID와 codebase/seed 포함</p></div><p class="muted small" style="margin-top:14px">서버 한도에 도달하면 기존 정책대로 로컬 문제 북마크에 저장합니다.</p>', contract: 'ProblemBookmarkStore.add → server/local overflow policy' },
  'flow-ai-chat': { title: '풀이 질문하기', kicker: 'EPHEMERAL AI CHAT', description: '문제 지문과 현재 공개 가능한 정답 정보만 임시 AI 채팅에 전달합니다.', body: '<div class="card quiet"><b>전달되는 문맥</b><p class="muted small">문제 지문 · 공개 가능한 정답 풀이 · 학생 공식</p></div><div class="composer" style="margin-top:12px"><input class="field" placeholder="막힌 단계를 질문하세요"><button class="button primary" type="button">전송</button></div><p class="muted small">현재는 정답 제출 전이므로 정답 정보는 전달하지 않습니다.</p>', contract: 'ServerChatPage(initialMode: chat, ephemeral: true)' },
  'exam-pages': { title: '시험지 페이지', kicker: 'PAGE THUMBNAILS', description: '모바일에서는 기존처럼 썸네일 목록을 바텀시트로 열어 페이지를 이동합니다.', body: '<div class="exam-page-picker"><button class="is-selected" type="button"><span class="mini-paper"><i></i><i></i><i></i><i></i></span><b>2 / 5</b></button><button type="button"><span class="mini-paper"><i></i><i></i><i></i><i></i></span><b>3 / 5</b></button><button type="button"><span class="mini-paper"><i></i><i></i><i></i><i></i></span><b>4 / 5</b></button></div>', contract: 'openThumbnailsSheet → setCurrentPage(index) → centerCurrentPage' },
  'finish-exam': { title: '시험 종료', kicker: 'FINISH EXAM', description: '시험을 종료하면 답안을 더 이상 수정할 수 없습니다.', body: '<div class="card quiet"><h3>답안 현황</h3><p class="muted small">20문항 중 12문항 답변 · 미응답 8문항</p><div class="progress"><span style="width:60%"></span></div></div><p style="margin-top:14px">필기와 선택 답안을 저장한 뒤 채점과 풀이 분석을 시작합니다.</p>', contract: 'confirmFinishExam → page capture / objective grade → submitSolveAnalysis → submitRating' },
  'exit-exam': { title: '시험지 나가기', kicker: 'LEAVE EXAM', description: '현재 필기와 답안의 이어풀기 상태를 저장하고 시험지 목록으로 돌아갑니다.', body: '<div class="card quiet"><b>자동 저장됨</b><p class="muted small">2페이지 · 선택 답안 12개 · 페이지별 필기 스트로크</p></div>', contract: 'saveContinueStrokes + selectedOptions → Navigator.maybePop' },
  'course-reorder': { title: '수강 순서 편집', kicker: 'MY COURSE ORDER', description: '홈과 코스 화면에 표시할 수강 중 코스 순서를 변경합니다.', body: '<div class="course-order-list"><button type="button"><span>⠿</span><b>일차함수 완성</b><small>진행률 42%</small></button><button type="button"><span>⠿</span><b>도형의 닮음</b><small>진행률 18%</small></button><button type="button"><span>⠿</span><b>확률 실전</b><small>미시작</small></button></div>', contract: 'reorderEnrollments(courseIds)' },
  'course-compare': { title: '추천 코스 비교', kicker: 'COMPARE COURSES', description: '추천 점수가 높은 두 코스의 목표 OVR, 모듈, 기간과 현재 진행 상태를 비교합니다.', body: '<div class="grid two"><article class="card"><span class="eyebrow">MATCH 91%</span><h3>일차함수 완성</h3><div class="feature-ledger"><span class="pill">목표 OVR 22</span><span class="pill">12강</span><span class="pill">3주</span></div></article><article class="card"><span class="eyebrow">MATCH 84%</span><h3>도형의 닮음</h3><div class="feature-ledger"><span class="pill">목표 OVR 21</span><span class="pill">9강</span><span class="pill">2주</span></div></article></div>', contract: 'OVR recommend score + course metadata comparison' },
  'course-policy': { title: '학습 완료 조건', kicker: 'RUNTIME POLICY', description: '현재 미션을 완료하고 다음 학습이 열리는 조건입니다.', body: '<div class="list"><div class="list-row is-active"><span class="feature-icon">01</span><span><b>최소 학습 시간</b><small>교재 화면에서 실제로 학습한 시간이 8분 이상이어야 합니다.</small></span><span>08:00</span></div><div class="list-row"><span class="feature-icon">02</span><span><b>진행 시간 보존</b><small>학습 중 60초 간격으로 현재 위치와 체류 시간을 보존합니다.</small></span><span>60s</span></div><div class="list-row"><span class="feature-icon">03</span><span><b>완료 후 다음 모듈</b><small>결과 제출 성공 후 코스 상세를 다시 불러오고 다음 미션을 엽니다.</small></span><span>NEXT</span></div></div>', contract: 'startCourseTextbookRuntime → heartbeatCourseTextbookRuntime → completeCourseTextbookRuntime → reloadCourseDetail' },
  'reader-toc': { title: '교재 목차', kicker: 'TABLE OF CONTENTS', description: '장과 절을 펼쳐 원하는 콘텐츠 블록 또는 페이지로 이동합니다.', body: '<div class="list"><button class="list-row"><span class="feature-icon">01</span><span><b>함수의 뜻</b><small>1–4쪽 · 완료</small></span><span>✓</span></button><button class="list-row is-active"><span class="feature-icon">02</span><span><b>좌표와 그래프</b><small>5–12쪽 · 읽는 중</small></span><span>⌄</span></button><button class="list-row"><span class="feature-icon">2.1</span><span><b>좌표평면 읽기</b><small>5쪽</small></span><span>›</span></button><button class="list-row is-active"><span class="feature-icon">2.2</span><span><b>기울기의 의미</b><small>6쪽 · 현재 위치</small></span><span>●</span></button><button class="list-row"><span class="feature-icon">03</span><span><b>일차함수</b><small>13–18쪽</small></span><span>›</span></button></div>', contract: 'chapterExpanded + activeEntryIndex → jumpToPage / scrollToEntry' },
  'reader-search': { title: '교재에서 찾기', kicker: 'TEXTBOOK SEARCH', description: '현재 교재의 장·절 제목과 콘텐츠 블록에서 검색합니다.', fields: [['검색어', '기울기 변화량']], contract: 'local contentEntries search → active entry jump' },
  'reader-complete': { title: '교재 학습 완료', kicker: 'COMPLETE READING', description: '최소 학습 시간과 마지막 페이지를 확인한 뒤 현재 모듈을 완료합니다.', body: '<div class="card quiet"><div class="card-head"><h3>현재 학습 상태</h3><span class="pill">05:12 / 08:00</span></div><div class="progress"><span style="width:65%"></span></div><p class="muted small" style="margin-top:12px">최소 학습 시간이 남아 있어 지금 닫으면 현재 페이지와 시간만 보존됩니다.</p></div>', contract: 'heartbeatCourseTextbookRuntime → completeCourseTextbookRuntime(currentPage, pageFrom, pageTo)' },
  search: { title: '전체 검색', kicker: 'QUICK FIND', description: '코스, 교재, 문제, 친구를 현재 기능별 검색으로 연결합니다.', fields: [['검색어', '함수, 코스, 친구 검색']], contract: '화면별 search/list 메서드로 위임' },
  notifications: { title: '알림 센터', kicker: 'LIVE STATUS', description: '과제 마감, 친구 요청, 그룹 공지, 코스 학습 상태를 한곳에서 확인합니다.', contract: 'SocialWebSocket + 과제/공지 조회' },
  'start-learning': { title: '이어서 학습', kicker: 'COURSE RUNTIME', description: '런타임 상태를 확인하고 정책 가드를 통과한 다음 모듈을 엽니다.', fields: [['코스', '중2 함수 마스터'], ['다음 모듈', '일차함수 실전 04']], contract: 'fetchCourseRuntimeState → POST /courses/v2/runtime/next' },
  'solve-info': { title: '문제풀이 안내', kicker: 'CANVAS GUIDE', description: '문제를 읽고 캔버스에 풀이를 작성합니다. 긴 풀이를 켜면 화면 폭은 유지한 채 아래쪽 공간만 확장됩니다.', contract: '필기 자동 저장 + 문항별 이어풀기 상태' },
  hint: { title: '힌트', kicker: 'HINT 01 / 02', description: '두 점의 y 변화량을 x 변화량으로 나누어 기울기를 먼저 구해 보세요.', contract: '힌트 사용 횟수와 풀이 분석 기록' },
  'submit-answer': { title: '답안 제출', kicker: 'PROBLEM SOLVE', description: '답안과 풀이 시간을 제출한 뒤 단계별 결과를 Flow 분석에서 확인합니다.', fields: [['선택 답안', '① y = 2x + 1'], ['풀이 시간', '01:42']], body: '<div class="actions" style="margin-top:14px"><button class="button primary" type="button" data-nav="flow">제출 결과 · Flow 분석 보기</button></div>', contract: 'POST /analysis/solve → SolveAnalysisResponse → FlowGraphBuilder → Flow 분석' },
  'start-placement': { title: '첫 OVR 측정 시작', kicker: 'PLACEMENT TEST', description: '50문항의 정오답, 풀이 시간과 개념 태그를 기록해 첫 OVR과 신뢰도를 산정합니다.', fields: [['문항 수', '50문항'], ['예상 시간', '60–90분'], ['난이도', '중상–상']], contract: 'startLevelTestPlacement → answer × 50 → submitLevelTestPlacement' },
  'join-arena': { title: '아레나 매칭', kicker: 'RANKED MATCH', description: '선택 대기열에 참가하고 matchId가 올 때까지 상태를 확인합니다.', fields: [['경기', '1v1 시험 대결'], ['티어', 'B · 1580점']], contract: 'POST /arena/queue/join' },
  'save-note': { title: '노트 저장', kicker: 'LEARNING TOOLS', description: 'UTF-8 텍스트를 사용자 저장소에 보관합니다.', fields: [['제목', '오늘의 오답 정리'], ['내용', '기울기 부호를 다시 확인하기']], contract: 'PUT /user/storage/{key}' },
  'send-message': { title: '메시지 보내기', kicker: 'SOCIAL', description: '친구 또는 그룹 대화에 메시지를 전송합니다.', fields: [['받는 사람', '이수학'], ['메시지', '오늘 챌린지 같이 풀래?']], contract: 'POST /social/messages 또는 /study-groups/{id}/messages' },
  'join-group': { title: '초대 코드로 참가', kicker: 'STUDY GROUP', description: '코드 메타를 먼저 확인한 뒤 가입 요청을 전송합니다.', fields: [['참여 코드', 'AF-24K8'], ['비밀번호', '필요한 경우 입력']], contract: 'GET /invite/{code} → POST /join-by-code' },
  'save-profile': { title: '프로필 저장', kicker: 'ACCOUNT', description: '학생 기본 정보만 갱신하며 학습 기록은 유지합니다.', fields: [['이름', '김학생'], ['학교', 'AIFlow 중학교'], ['학년', '중학교 2학년']], contract: 'PUT /auth/me' },
  login: { title: '학생 로그인', kicker: 'AUTH', description: '로그인 토큰을 발급받아 UTF-8 로컬 인증 저장소에 보관합니다.', fields: [['아이디', 'student@example.com'], ['비밀번호', '••••••••']], contract: 'POST /auth/login → setToken' },
  register: { title: '학생 가입', kicker: 'AUTH', description: '중복 확인 후 단계별 가입 데이터를 서버로 전송합니다.', fields: [['아이디', 'new_student'], ['이메일', 'student@example.com']], contract: 'POST /auth/username/check → POST /auth/register' },
};

let activeScreen = 'dashboard';

// 필요 변수: 화면 상단 영문 라벨, 제목, 설명, 우측 액션 HTML.
// 작동 원리: 모든 화면에서 동일한 제목 높이와 반응형 액션 배치를 만든다.
function pageHead(kicker, title, description, actionHtml = '') {
  return `<header class="page-head"><div><span class="eyebrow">${kicker}</span><h1>${title}</h1><p>${description}</p></div><div class="actions">${actionHtml}</div></header>`;
}

// 필요 변수: 버튼 문구, 액션 ID, 스타일, 이동할 화면 ID.
// 작동 원리: 액션 패널과 시안 화면 전환을 하나의 공용 버튼 규칙으로 출력한다.
function button(label, action = '', style = '', nav = '') {
  return `<button class="button ${style}" type="button" ${action ? `data-action="${action}"` : ''} ${nav ? `data-nav="${nav}"` : ''}>${label}</button>`;
}

// 필요 변수: 지표명, 값, 보조 문구, 추가 클래스.
// 작동 원리: 학생 홈과 보고서 수치를 같은 카드 비율로 표시한다.
function metric(label, value, note, extra = '') {
  return `<article class="card metric ${extra}"><span class="muted small">${label}</span><strong>${value}</strong><em class="${note.startsWith('+') ? 'up' : ''}">${note}</em></article>`;
}

// 필요 변수: 아이콘, 제목, 설명, 이동 대상.
// 작동 원리: 기능 카드 전체를 클릭 가능한 화면 이동 영역으로 만든다.
function featureCard(icon, title, copy, nav) {
  return `<button class="card feature-card" type="button" data-nav="${nav}"><span class="feature-icon">${icon}</span><span><h3>${title}</h3><p>${copy}</p></span><span>›</span></button>`;
}

// 필요 변수: 현재 화면 ID.
// 작동 원리: 기능·알고리즘·메서드·엔드포인트를 시각 화면 하단에 항상 남겨 누락 여부를 확인한다.
function ledger(id) {
  const item = screens[id];
  return `<div class="feature-ledger">${item.features.map((value) => `<span class="pill">${value}</span>`).join('')}</div><div class="endpoint-ledger" data-screen-contract="${id}"><b>보존 계약</b><br>METHOD · ${item.methods.join(' · ')}<br>ENDPOINT · ${item.endpoints.join(' · ')}</div>`;
}

// 필요 변수: 제목, 부제, 선택 상태, 선택 시 이동할 화면.
// 작동 원리: 코스·과제·오답 등 반복 목록을 동일한 밀도의 행으로 출력한다.
function listRow(title, copy, active = false, nav = '') {
  return `<button class="list-row ${active ? 'is-active' : ''}" type="button" ${nav ? `data-nav="${nav}"` : ''}><span class="feature-icon">${active ? '▶' : '·'}</span><span><b>${title}</b><small>${copy}</small></span><span>›</span></button>`;
}

// 필요 변수: 2026년 7월의 시작 요일, 말일, 일정이 있는 날짜와 오늘 날짜.
// 작동 원리: 일요일 시작 7열 달력에 앞뒤 빈 칸을 넣고 실제 날짜만 오늘 할 일 모달과 연결한다.
function homeCalendar() {
  const leadingBlankCount = 3;
  const dayCount = 31;
  const totalCellCount = 35;
  const taskDays = new Set([4, 9, 13, 19, 25]);
  return Array.from({ length: totalCellCount }, (_, index) => {
    const day = index - leadingBlankCount + 1;
    if (day < 1 || day > dayCount) return '<span aria-hidden="true"></span>';
    const classes = `${day === 13 ? 'is-today ' : ''}${taskDays.has(day) ? 'has-task' : ''}`;
    return `<button type="button" class="${classes}" data-action="today-tasks">${day}</button>`;
  }).join('');
}

// 필요 변수: 학생 홈 원장 데이터.
// 작동 원리: OVR, 오늘 학습, 기능 진입점을 PC와 모바일에서 밀도만 바꿔 같은 정보로 보여준다.
function renderDashboard() {
  return `<section class="page"><article class="hero dark"><div class="hero-content"><span class="eyebrow">MONDAY · JUL 13</span><h1>김학생님,<br>오늘도 시작해 볼까요?</h1><p>어제 멈춘 학습과 오늘 일정은 아래 학습 영역에서 이어집니다.</p><button class="button round" type="button" data-scroll="homeLearning">학습 영역 보기 ↓</button></div></article><section class="home-learning" id="homeLearning" style="margin-top:14px"><button class="learn-banner" type="button" data-action="study-mode"><span><span class="eyebrow">LEARNING START</span><h2>학습하기</h2><p>이어하기 · 코스보기 · 복습 · 문제풀기 · 시험 · 교재보기</p></span><span class="learn-banner__icon">▶</span></button><div class="grid two" style="margin-top:12px"><button class="home-status-button" type="button" data-action="daily-test"><span class="muted small">일일 테스트</span><strong>4 / 10</strong><em>오늘 80 XP · 자세히 보기</em></button><button class="home-status-button" type="button" data-action="today-tasks"><span class="muted small">오늘 할 일</span><strong>3개</strong><em>과제 2 · 개인 일정 1 · 자세히 보기</em></button></div><div class="home-module-grid"><article class="card"><div class="card-head"><h2>학습 도구</h2><span class="pill">빠른 실행</span></div><div class="tool-strip"><button class="tool-button" data-action="tool-note"><span class="tool-shape tool-shape--note">✎</span><span class="tool-label">노트패드</span></button><button class="tool-button" data-action="tool-timer"><span class="tool-shape tool-shape--timer">◷</span><span class="tool-label">타이머</span></button><button class="tool-button" data-action="tool-focus"><span class="tool-shape tool-shape--focus">◉</span><span class="tool-label">집중 모드</span></button><button class="tool-button" data-nav="graph"><span class="tool-shape tool-shape--graph"><span>⌁</span></span><span class="tool-label">그래프 그리기</span></button></div></article><div class="home-module-stack">${featureCard('▶', '현재 코스', '일차함수 완성 · 진행률 42%', 'course-learning')}<button class="card feature-card" type="button" data-action="social-home"><span class="feature-icon">◌</span><span><h3>알림</h3><p>놓친 알림 5개</p></span><span>›</span></button></div></div></section><section class="activity-strip"><article class="card rating-card"><span class="eyebrow">MY RATING</span><div class="card-head"><div><h2>OVR 18.6</h2><p class="muted small">전날 대비 +0.3 · B Tier</p></div><div class="rank-badge">B</div></div><div class="rating-rise"><span class="pill">상승 60%</span><div class="progress"><span style="width:60%"></span></div></div>${button('레이팅 자세히 보기', 'rating-detail', 'primary round')}</article><button class="card arena-card" type="button" data-nav="arena" style="text-align:left"><span class="arena-orb">▶</span><span class="eyebrow">REAL-TIME MATCH</span><h2 style="font-size:30px">수학 대결장</h2><p class="muted small">1v1 · 2v2 실시간 실력 대결</p><span class="button primary round" style="margin-top:16px">대결장 입장 ›</span></button></section><section class="home-footer-grid"><article class="card"><div class="card-head"><div><span class="eyebrow">JULY 2026</span><h2>일정 달력</h2></div>${button('전체 일정', '', 'soft', 'schedule')}</div><div class="home-calendar">${homeCalendar()}</div></article><article class="card achievement-card"><div class="card-head"><div><span class="eyebrow">ACHIEVEMENT</span><h2>도전과제 / 업적</h2></div><span class="pill">8 / 24</span></div><div class="badge-row"><span class="badge-gem">7</span><span class="badge-gem"><span>50</span></span><span class="badge-gem">B</span></div><p class="muted small">다음: 30일 연속 학습 · 12/30</p><div class="progress"><span style="width:40%"></span></div>${button('업적 보관함', 'achievements', 'soft')}</article><aside class="card"><div class="card-head"><h2>공지사항</h2>${button('전체 보기', 'system-notices', 'soft')}</div><div class="list"><button class="list-row is-active" data-action="system-notices"><span class="feature-icon">!</span><span><b>7월 서비스 업데이트 안내</b><small>전체 공지 · 07.13</small></span><span>›</span></button><button class="list-row" data-action="system-notices"><span class="feature-icon">◎</span><span><b>다음 수업 준비물</b><small>중2 심화 스터디 · 07.12</small></span><span>›</span></button><button class="list-row" data-action="system-notices"><span class="feature-icon">!</span><span><b>아레나 시즌 일정</b><small>전체 공지 · 07.10</small></span><span>›</span></button></div></aside></section>${ledger('dashboard')}</section>`;
}

// 필요 변수: 수강 상태, 진행률, 추천 적합도, OVR 범위, 검색·태그·완료 필터와 공개·배정 코스 목록.
// 작동 원리: 이어 학습→개인화 추천→전체 탐색 순으로 우선순위를 재배치하고 수강 중 코스는 학습으로, 나머지는 상세로 연결한다.
function renderCourses() {
  const courseCard = (match, title, copy, meta, status = '수강 전', nav = 'course-detail') => `<button class="course-catalog-card" type="button" data-nav="${nav}"><div class="course-card-top"><span class="course-match">${match}</span><span class="pill">${status}</span></div><h3>${title}</h3><p>${copy}</p><div class="course-card-meta">${meta.map((value) => `<span>${value}</span>`).join('')}</div><span class="course-card-link">${nav === 'course-learning' ? '현재 진도로 이동' : status.includes('완료') ? '미리보기' : '코스 상세'} ›</span></button>`;
  return `<section class="page course-page">${pageHead('LEARNING PATH', '코스', '현재 학습을 이어가거나 내 실력에 맞는 다음 코스를 선택하세요.', '<div class="course-ovr-chip"><span>MY OVR</span><b>18.6</b><small>B Tier</small></div>')}<section class="course-search-dock"><div class="course-search-field"><span>⌕</span><input value="" placeholder="코스명, 설명, 태그로 검색" aria-label="코스 검색"><button type="button">검색</button></div><div class="course-filter-row"><button class="is-selected" type="button" data-course-filter>전체</button><button type="button" data-course-filter>수강 중</button><button type="button" data-course-filter>추천</button><button type="button" data-course-filter>배정됨</button><button type="button" data-course-filter>완료 코스</button><button type="button" data-course-filter>#중2</button><button type="button" data-course-filter>#함수</button></div></section><section class="course-resume"><div class="course-section-head"><div><span class="eyebrow">CONTINUE LEARNING</span><h2>이어서 학습</h2></div>${button('순서 편집', 'course-reorder', 'soft')}</div><div class="resume-course-list"><button class="resume-course is-primary" type="button" data-nav="course-learning"><span class="resume-course-index">01</span><span><b>일차함수 완성</b><small>그래프 이해 · 06번째 모듈</small></span><div class="resume-progress"><span><i style="width:42%"></i></span><small>42%</small></div><strong>이어하기 ›</strong></button><button class="resume-course" type="button" data-nav="course-learning"><span class="resume-course-index">02</span><span><b>도형의 닮음</b><small>닮음비 · 03번째 모듈</small></span><div class="resume-progress"><span><i style="width:18%"></i></span><small>18%</small></div><strong>열기 ›</strong></button></div></section><section class="course-recommend"><article class="course-recommend-main" data-nav="course-detail"><div class="recommend-copy"><span class="eyebrow">BEST MATCH · 91%</span><h2>다음 코스로<br>일차함수 완성은 어때요?</h2><p>최근 약점인 그래프 해석과 기울기를 교재·문제·시험 흐름으로 보완합니다.</p><div class="course-card-meta"><span>목표 OVR 22</span><span>12강</span><span>약 3주</span><span>#함수</span></div><div class="actions">${button('코스 상세', '', 'primary', 'course-detail')}${button('추천 비교', 'course-compare', 'soft')}</div></div><div class="recommend-visual"><span>91</span><i></i><i></i><i></i><small>OVR 18.6 → 22.0</small></div></article><aside class="course-alternatives"><div class="course-section-head"><div><span class="eyebrow">ALTERNATIVES</span><h2>다른 추천</h2></div>${button('두 코스 비교', 'course-compare', 'soft')}</div><button type="button" data-nav="course-detail"><span class="course-match">84</span><span><b>도형의 닮음</b><small>#기하 · 9강 · 2주</small></span><span>›</span></button><button type="button" data-nav="course-detail"><span class="course-match">78</span><span><b>확률 실전</b><small>#확률 · 8강 · 자율</small></span><span>›</span></button><button type="button" data-nav="course-detail"><span class="course-match">72</span><span><b>수학 기초 회복</b><small>#기초 · 16강 · 4주</small></span><span>›</span></button></aside></section><section class="course-library"><div class="course-section-head"><div><span class="eyebrow">ALL COURSES</span><h2>전체 코스</h2><p>공개 코스와 선생님이 배정한 코스를 함께 표시합니다.</p></div><div class="actions"><span class="pill">24개</span><button class="button soft" type="button">추천순⌄</button></div></div><div class="course-catalog-grid">${courseCard('96', '중2 함수 마스터', '개념부터 시험까지 한 번에 이어지는 선생님 배정 코스', ['배정됨', '14강', '4주'], '선생님 배정')}${courseCard('88', '그래프로 이해하는 함수', '좌표와 그래프를 시각적으로 반복 학습합니다.', ['공개', '10강', '2주'])}${courseCard('82', '도형의 닮음 워크숍', '닮음 조건과 닮음비를 문제 중심으로 익힙니다.', ['공개', '9강', '2주'])}${courseCard('—', '확률 기초부터 실전까지', '경우의 수를 정리하고 실전 문제로 연결합니다.', ['공개', '12강', '자율'])}${courseCard('100', '일차방정식 기초', '완료한 코스의 교재와 문제를 다시 확인할 수 있습니다.', ['완료', '8강', '100%'], '완료 · 미리보기')}${courseCard('76', '서술형 풀이 훈련', '풀이 과정을 단계별로 쓰고 Flow로 분석합니다.', ['공개', '7강', '자율'])}</div></section>${ledger('courses')}</section>`;
}

// 필요 변수: 코스 상세 메타와 모듈 목록.
// 작동 원리: 등록 전 설명과 등록 후 실행 경로를 한 화면에서 비교 가능하게 구성한다.
function renderCourseDetail() {
  return `<section class="page">${pageHead('COURSE 01', '일차함수 완성', '개념 교재부터 실전 시험, 오답 복습까지 하나의 상태 머신으로 이어지는 코스입니다.', button('코스 등록', 'start-learning', 'primary') + button('미리보기', '', '', 'textbook-reader'))}<div class="grid four">${metric('추천 적합도', '91%', 'OVR 16–22')}${metric('모듈', '12', '교재 4 · 문제 6 · 시험 2')}${metric('예상 기간', '3주', '주 4회 기준')}${metric('완료 학생', '1,284', '평균 4.8점')}</div><div class="split" style="margin-top:14px"><div class="card"><div class="card-head"><h2>학습 흐름</h2><span class="pill">12 modules</span></div><div class="list">${listRow('01 · 함수의 뜻', '교재 · 최소 8분', true, 'textbook-reader')}${listRow('02 · 좌표와 그래프', '문제 풀이 · 10문항', false, 'solve')}${listRow('03 · 기울기', '레벨 테스트 · 통과 80%', false, 'level-test')}${listRow('04 · 일차함수 실전', '시험 · 20문항', false, 'exam-paper')}</div></div><aside class="card"><h2>코스 정보</h2><p class="muted small">AIFlow 수학 연구팀 · 중학교 2학년 · 수학</p><div class="feature-ledger"><span class="pill">#일차함수</span><span class="pill">#그래프</span><span class="pill">#기울기</span><span class="pill">#서술형</span></div><div class="endpoint-ledger">등록 전 공개 메타와 등록 후 runtime state를 분리 조회합니다.</div></aside></div>${ledger('course-detail')}</section>`;
}

// 필요 변수: 코스 상세, 단원·미션 상태, 현재 런타임, 최소 학습 시간과 미션 유형별 이동 화면.
// 작동 원리: 원본 코스 학습처럼 현재 단원을 먼저 펼치고 완료·진행·잠금 경로를 순서대로 보여주며 유형별 화면으로 이동한다.
function renderLearning() {
  const mission = (number, icon, title, meta, state, nav = '') => `<div class="learning-mission is-${state}"><span class="mission-index">${number}</span><span class="mission-icon" aria-hidden="true">${icon}</span><span class="mission-copy"><b>${title}</b><small>${meta}</small></span><span class="mission-state">${state === 'done' ? '완료' : state === 'current' ? '학습 중' : state === 'ready' ? '다음' : '잠김'}</span>${nav ? `<button class="mission-open" type="button" data-nav="${nav}" aria-label="${title} 열기">›</button>` : '<span class="mission-lock" aria-hidden="true">⌁</span>'}</div>`;
  const unit = (number, title, meta, state, missions = '') => `<article class="learning-unit is-${state} ${missions ? 'is-expanded' : ''}"><button class="learning-unit-head" type="button" data-course-unit aria-expanded="${missions ? 'true' : 'false'}"><span class="unit-number">${state === 'done' ? '✓' : number}</span><span><b>${title}</b><small>${meta}</small></span><span class="unit-status">${state === 'done' ? '완료' : state === 'active' ? '진행 중' : '잠금'}</span><span class="unit-chevron">⌄</span></button>${missions ? `<div class="learning-missions">${missions}</div>` : '<div class="learning-missions" hidden></div>'}</article>`;
  const currentMissions = mission('05', '▧', '좌표와 그래프 읽기', '교재 열람 · 최소 8분 · 완료', 'done', 'textbook-reader') + mission('06', '▥', '기울기의 의미', '교재 열람 · 05:12 / 08:00', 'current', 'textbook-reader') + mission('07', '✎', '기울기 문제 풀이', '10문항 · 즉시 채점 · 통과 90%', 'ready', 'solve') + mission('08', '◈', '그래프 이해 레벨 테스트', '이전 미션 완료 후 열림 · 통과 80%', 'locked');
  return `<section class="page learning-page">${pageHead('ACTIVE COURSE', '일차함수 완성', '현재 학습 위치에서 이어가고, 단원별 미션과 잠금 조건을 원래 흐름대로 확인하세요.', button('코스 목록', '', 'soft', 'courses'))}<section class="learning-hero"><div class="learning-hero-copy"><div class="course-card-meta"><span>중학교 2학년</span><span>수학</span><span>#일차함수</span><span>#그래프</span></div><h2>일차함수의 개념부터<br>그래프 실전까지</h2><p>교재, 문제, 레벨 테스트와 시험을 정해진 학습 순서로 이어갑니다.</p><div class="learning-author"><span class="author-mark">AF</span><span><b>AIFlow 수학 연구팀</b><small>최근 학습 오늘 14:20</small></span></div></div><div class="learning-overall"><span class="eyebrow">COURSE PROGRESS</span><strong>42<small>%</small></strong><div class="progress"><span style="width:42%"></span></div><div class="learning-overall-meta"><span><b>6 / 14</b><small>완료 미션</small></span><span><b>02 / 04</b><small>현재 단원</small></span><span><b>18.6</b><small>MY OVR</small></span></div></div></section><section class="learning-current"><div class="learning-current-main"><span class="current-sequence">현재 학습 · 06</span><div><span class="eyebrow">UNIT 02 · 그래프 이해</span><h2>기울기의 의미</h2><p>두 점의 변화량을 비교해 직선의 기울기를 이해합니다. 중단한 5분 12초부터 이어집니다.</p></div><div class="current-actions">${button('교재 이어보기', '', 'primary round', 'textbook-reader')}${button('완료 조건', 'course-policy', 'soft round')}</div></div><aside class="learning-time"><div class="learning-clock"><span>학습 시간</span><strong>05:12</strong><small>최소 08:00</small></div><div class="progress"><span style="width:65%"></span></div><p>중단해도 마지막 위치와 시간이 보존됩니다.</p></aside></section><section class="course-path"><div class="course-section-head"><div><span class="eyebrow">COURSE ROUTE</span><h2>코스 진행 경로</h2><p>현재 단원은 자동으로 펼쳐집니다. 단원을 눌러 미션을 확인하세요.</p></div><div class="path-legend"><span><i class="is-done"></i>완료</span><span><i class="is-active"></i>진행</span><span><i></i>잠금</span></div></div><div class="learning-unit-list">${unit('01', '함수의 기초', '4개 미션 · 4/4 완료', 'done')}${unit('02', '그래프 이해', '4개 미션 · 2/4 진행', 'active', currentMissions)}${unit('03', '일차함수 실전', '문제 · 챌린지 · 오답 복습', 'locked')}${unit('04', '최종 평가', '레벨 테스트 · 시험지 풀이', 'locked')}</div></section><footer class="learning-runtime-note"><span>DEMO COURSE</span><p>시안에서는 데이터 요청 없이 상태 전이와 이동 계약만 표시합니다. 실제 앱은 미션 완료 후 코스 상세를 다시 불러와 다음 위치를 갱신합니다.</p>${button('런타임 계약 보기', 'course-policy', 'soft')}</footer>${ledger('course-learning')}</section>`;
}

// 필요 변수: 문제 풀이 화면 계약.
// 작동 원리: 실제 앱의 상단 상태바·필기 캔버스·중앙 문제 카드·하단 도구막대 구조를 웹 시안 디자인으로 재구성한다.
function renderSolve() {
  const choices = ['y = 2x + 1', 'y = 2x - 1', 'y = x + 2', 'y = 3x'];
  return `<section class="page solve-page"><header class="solve-header"><button class="icon-button" type="button" data-nav="dashboard" aria-label="문제 풀이 나가기">‹</button><div class="solve-title"><span class="eyebrow">PROBLEM SESSION</span><h1>오늘의 문제</h1></div><div class="solve-status"><span><small>진행 시간</small><b>01:42</b></span><span><small>자동 저장</small><b>SAVED</b></span><button class="icon-button" type="button" data-action="solve-info" aria-label="문제 풀이 안내">ⓘ</button></div></header><div class="solve-progress" aria-label="전체 12문항 중 4번"><span style="width:33%"></span></div><section class="solve-canvas has-lines" data-solve-canvas><div class="solve-canvas-meta"><span class="pill">04 / 12</span><span class="pill">#일차함수</span><span class="pill">난이도 중</span></div><article class="solve-problem-card"><div class="solve-problem-head"><span class="question-number">04</span><div><span class="eyebrow">MULTIPLE CHOICE</span><h2>일차함수</h2></div><button class="button soft" type="button" data-action="hint">힌트 2</button></div><div class="solve-question-copy">두 점 (1, 3), (3, 7)을 지나는 일차함수의 식을 구하세요.</div><div class="solve-choices">${choices.map((choice, index) => `<button class="solve-choice ${index === 0 ? 'is-selected' : ''}" type="button" data-solve-choice="${index}"><span>${['①', '②', '③', '④'][index]}</span><b>${choice}</b></button>`).join('')}</div></article><svg class="solve-ink" viewBox="0 0 720 260" aria-label="필기 예시"><path d="M110 72 C165 45 225 48 279 76 C315 95 350 98 392 78"/><path d="M142 135 C207 111 276 113 343 141"/><path d="M405 137 L458 92 L500 151 L552 72"/><path d="M182 202 C252 177 326 178 389 202"/></svg><span class="solve-canvas-hint">캔버스에 직접 풀이를 작성하세요 · 아래로 스크롤하면 풀이 공간이 이어집니다.</span></section><footer class="solve-toolbar" aria-label="문제 풀이 도구"><div class="solve-tool-group"><button class="solve-tool is-selected" type="button" data-solve-tool="pen"><span>✎</span><small>펜</small></button><button class="solve-tool" type="button" data-solve-tool="eraser"><span>◇</span><small>지우개</small></button><button class="solve-tool" type="button" data-solve-tool="color"><i class="solve-color-dot"></i><small>색상</small></button><button class="solve-tool is-selected" type="button" data-solve-tool="lines"><span>≡</span><small>노트 줄</small></button></div><i class="solve-toolbar-divider"></i><div class="solve-tool-group"><button class="solve-tool" type="button" data-solve-tool="undo"><span>↶</span><small>되돌리기</small></button><button class="solve-tool" type="button" data-solve-tool="clear"><span>⌫</span><small>전체 삭제</small></button><button class="solve-tool" type="button" data-solve-tool="expand"><span>↕</span><small>긴 풀이</small></button></div><i class="solve-toolbar-divider"></i><div class="solve-question-nav"><button class="icon-button" type="button" aria-label="이전 문제">‹</button><b>4 <span>/ 12</span></b><button class="icon-button" type="button" aria-label="다음 문제">›</button><button class="button primary" type="button" data-action="submit-answer">답안 제출</button></div></footer>${ledger('solve')}</section>`;
}

// 필요 변수: 배치 테스트 문항 수·난이도·예상 시간과 첫 OVR 산정 API 계약.
// 작동 원리: 합격 여부가 아닌 최초 실력 기준점 생성 과정을 소개하고, 준비 확인 후 50문항 배치 세션으로 연결한다.
function renderLevelTest() {
  return `<section class="page level-placement-page"><section class="level-hero"><div class="level-hero-copy"><span class="level-step">FIRST STEP · OVR PLACEMENT</span><h1>처음 만나는<br>나의 실력.</h1><p>50개의 문제로 지금의 학습 위치를 찾습니다.<br>첫 OVR은 앞으로의 코스와 난이도를 결정하는 기준점이 됩니다.</p></div><div class="level-orbit" aria-label="아직 측정되지 않은 OVR"><span class="orbit-track orbit-track--one"></span><span class="orbit-track orbit-track--two"></span><i class="orbit-dot orbit-dot--one"></i><i class="orbit-dot orbit-dot--two"></i><div class="level-core"><span>MY OVR</span><strong>--<small>.–</small></strong><em>READY TO MEASURE</em></div><div class="level-scan"></div></div><div class="level-hero-meta"><span><small>QUESTIONS</small><b>50</b></span><span><small>DIFFICULTY</small><b>중상–상</b></span><span><small>RESULT</small><b>OVR + 태그</b></span></div></section><section class="level-intro"><div><span class="eyebrow">HOW IT WORKS</span><h2>점수가 아니라,<br>학습의 출발점을 찾습니다.</h2></div><p>모든 답은 개념 태그와 풀이 시간으로 함께 분석됩니다. 맞힌 개수만 세지 않고 어떤 영역에서 빠르고 정확한지 확인해 첫 OVR의 신뢰도를 만듭니다.</p></section><section class="level-process" aria-label="레벨 테스트 측정 과정"><article class="level-process-card"><span class="process-number">01</span><div class="process-mark">50</div><h3>폭넓게 확인</h3><p>시험지 후보군에서 선별된 50문항으로 주요 개념을 고르게 확인합니다.</p><div class="process-line"><span style="width:82%"></span></div></article><article class="level-process-card"><span class="process-number">02</span><div class="process-mark">⌁</div><h3>풀이 패턴 분석</h3><p>정오답, 풀이 시간과 단계별 사고 흐름을 문항마다 누적합니다.</p><div class="level-signal"><i></i><i></i><i></i><i></i><i></i></div></article><article class="level-process-card"><span class="process-number">03</span><div class="process-mark">OVR</div><h3>첫 기준점 생성</h3><p>첫 OVR과 신뢰도, 강한 태그와 보완 태그를 함께 제공합니다.</p><div class="process-tags"><span>#강점</span><span>#보완</span></div></article></section><section class="level-ready"><div class="level-ready-copy"><span class="eyebrow">BEFORE YOU START</span><h2>준비되었나요?</h2><p>실제 실력을 정확히 반영할 수 있도록 충분한 시간을 확보해 주세요.</p><div class="level-checks"><span><i>✓</i>50문항 · 약 60–90분</span><span><i>✓</i>중간 진행 자동 저장</span><span><i>✓</i>정답은 제출 후 분석</span><span><i>✓</i>최초 OVR은 이후 학습으로 계속 보정</span></div></div><aside class="level-ready-action"><span class="eyebrow">YOUR BASELINE</span><strong>첫 번째<br>기준점을 만들 시간</strong><button class="button primary round" type="button" data-action="start-placement">레벨 테스트 시작 <span>→</span></button><small>추정 OVR은 이후 풀이 데이터에 따라 변동됩니다.</small></aside></section>${ledger('level-test')}</section>`;
}

// 필요 변수: 분석·오답·레벨 화면 ID.
// 작동 원리: 성취 데이터를 정오답, 약점, 평점 변화와 후속 학습 액션으로 묶는다.
function renderReport(id) {
  const meta = screens[id];
  return `<section class="page">${pageHead('PERFORMANCE', meta.label, '결과 숫자만 보여주지 않고 다음 학습 행동까지 연결합니다.', button('다시 풀기', '', 'primary', 'solve'))}<div class="grid four">${metric('정답률', id === 'level-test' ? '82%' : '75%', '+8% 최근 4주')}${metric('평균 시간', '01:38', '-12초')}${metric('OVR 변화', '+0.3', '현재 18.6')}${metric('집중 지수', '91', '+4 points', 'dark')}</div><div class="split" style="margin-top:14px"><article class="card"><div class="card-head"><h2>${id === 'wrong-answers' ? '남은 오답' : '문항별 분석'}</h2><span class="pill">약점 3</span></div><div class="list">${listRow('일차함수의 기울기', '오답 · 02:18 · 부호 확인 필요', true, 'solve')}${listRow('그래프의 평행이동', '정답 · 01:11')}${listRow('두 직선의 교점', '오답 · 03:04 · 식 정리')}${listRow('함숫값 계산', '정답 · 00:48')}</div></article><aside class="card"><div class="card-head"><h2>약점 태그</h2><span class="pill">AI 분석</span></div><div class="feature-ledger"><span class="pill">#기울기부호 42%</span><span class="pill">#식정리 31%</span><span class="pill">#좌표해석 27%</span></div><div class="heatmap" style="margin-top:20px">${Array.from({ length: 70 }, () => '<i></i>').join('')}</div><p class="muted small">최근 10주 풀이 활동</p>${button('유사 변형 생성', '', 'primary', 'solve')}</aside></div>${ledger(id)}</section>`;
}

// 필요 변수: 풀이 이력, 약점 태그, 출처, 반복 오답 횟수, 복습 완료 상태.
// 작동 원리: 단순 성적표 대신 지금 다시 풀 문제를 우선 제시하고 해설·재풀이·변형 문제로 바로 연결한다.
function renderReview() {
  const reviewItem = ({ number, title, source, meta, tags, attempts, status = 'ready' }) => `<article class="review-item is-${status}"><div class="review-item__number"><span>${number}</span><small>${status === 'done' ? '완료' : '복습'}</small></div><div class="review-item__body"><div class="review-item__title"><div><span class="eyebrow">${source}</span><h3>${title}</h3></div><span class="review-attempt">${attempts}</span></div><p>${meta}</p><div class="review-tags">${tags.map((tag) => `<span>#${tag}</span>`).join('')}</div></div><div class="review-item__actions">${status === 'done' ? button('한 번 더 풀기', '', 'soft', 'solve') : button('해설 보기', 'review-solution', 'soft') + button('다시 풀기', '', 'primary', 'solve')}</div></article>`;
  return `<section class="page review-page">${pageHead('REVIEW', '복습', '틀린 문제를 쌓아두지 않고, 지금 다시 풀 문제부터 차례로 끝냅니다.', button('맞춤 복습 시작', '', 'primary', 'solve'))}<section class="review-hero"><div class="review-hero__copy"><span class="eyebrow">TODAY’S REVIEW</span><h2>오늘은 6문제만<br>다시 보면 돼요.</h2><p>최근 오답과 반복해서 놓친 개념을 우선순위로 정리했습니다.</p><div class="actions">${button('6문제 이어서 풀기', '', 'primary', 'solve')}<button class="button soft" type="button" data-review-filter="repeat">반복 오답만 보기</button></div></div><div class="review-ring" aria-label="오늘 복습 8문제 중 2문제 완료"><span><strong>2</strong><small>/ 8 완료</small></span></div><div class="review-hero__stats"><span><small>이번 주 복습</small><b>18문제</b></span><span><small>다시 맞힌 비율</small><b>76%</b></span><span><small>가장 약한 개념</small><b>기울기</b></span></div></section><div class="review-layout"><main class="review-main"><header class="review-toolbar"><div class="review-filters"><button class="is-active" type="button" data-review-filter="all">전체 8</button><button type="button" data-review-filter="recent">최근 오답 5</button><button type="button" data-review-filter="repeat">반복 오답 3</button><button type="button" data-review-filter="done">완료 2</button></div><button class="button soft" type="button" data-action="review-sort">최신순 ↕</button></header><div class="review-list">${reviewItem({ number: '01', title: '두 직선의 교점 구하기', source: '수학Ⅱ 실전 시험 · 오늘', meta: '식의 이항 과정에서 부호를 반대로 바꿨어요.', tags: ['식정리', '교점'], attempts: '2회 틀림' })}${reviewItem({ number: '02', title: '일차함수의 기울기 판단', source: '함수의 시작 코스 · 어제', meta: 'Δy와 Δx의 순서를 바꾸는 실수가 반복됐어요.', tags: ['기울기', '좌표해석'], attempts: '3회 틀림' })}${reviewItem({ number: '03', title: '그래프의 평행이동', source: '일일 테스트 · 7월 12일', meta: '이동 방향은 맞았지만 상수항 계산을 놓쳤어요.', tags: ['평행이동'], attempts: '1회 틀림' })}${reviewItem({ number: '04', title: '함숫값 계산', source: '함수의 시작 코스 · 7월 11일', meta: '복습에서 연속 두 번 정답을 맞혀 완료됐어요.', tags: ['대입'], attempts: '복습 완료', status: 'done' })}</div></main><aside class="review-side"><section class="card review-focus"><span class="eyebrow">WEAK POINTS</span><h2>먼저 볼 개념</h2><div class="review-skill"><div><b>기울기와 변화량</b><small>관련 오답 4문제</small></div><strong>42%</strong><i><span style="width:42%"></span></i></div><div class="review-skill"><div><b>식 정리</b><small>관련 오답 3문제</small></div><strong>31%</strong><i><span style="width:31%"></span></i></div><div class="review-skill"><div><b>좌표 해석</b><small>관련 오답 2문제</small></div><strong>27%</strong><i><span style="width:27%"></span></i></div>${button('약점 변형 문제 만들기', 'review-variant', 'soft')}</section><section class="card review-rule"><span class="eyebrow">REVIEW RULE</span><h3>완료 기준</h3><p>같은 개념을 연속 두 번 맞히면 복습 완료로 표시합니다. 다시 틀리면 우선순위가 올라갑니다.</p></section></aside></div>${ledger('wrong-answers')}</section>`;
}

// 필요 변수: 시험지 도구 의미에 대응하는 아이콘 이름.
// 작동 원리: 문자 기호 대신 동일한 24px 선 굵기의 SVG를 반환해 PC·모바일에서 도구 의미와 정렬을 일치시킨다.
function examIcon(name) {
  const paths = {
    pages: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h8M8 15h8"/>',
    pen: '<path d="m4 20 4.2-1 10.2-10.2a2.1 2.1 0 0 0-3-3L5.2 16Z"/><path d="m13.8 7.2 3 3"/>',
    eraser: '<path d="m4.8 14.8 7.6-7.6a2 2 0 0 1 2.8 0l3.6 3.6a2 2 0 0 1 0 2.8L12.4 20H8.6l-3.8-3.8a2 2 0 0 1 0-1.4Z"/><path d="m10 9.6 6.4 6.4M12.4 20H21"/>',
    pan: '<path d="M8.5 11V6.5a1.5 1.5 0 0 1 3 0V11M11.5 10V5.5a1.5 1.5 0 0 1 3 0V11M14.5 10V7a1.5 1.5 0 0 1 3 0v5M8.5 10V8.5a1.5 1.5 0 0 0-3 0v5.8c0 3.7 2.8 6.7 6.5 6.7h1.2c3.8 0 6.8-3.1 6.8-6.8V10a1.5 1.5 0 0 0-3 0"/>',
    palette: '<path d="M12 3a9 9 0 0 0 0 18h1.4a1.8 1.8 0 0 0 0-3.6h-.7a1.7 1.7 0 0 1 0-3.4H15a6 6 0 0 0 0-12Z"/><circle cx="7.5" cy="10" r=".8"/><circle cx="10" cy="6.8" r=".8"/><circle cx="15" cy="7" r=".8"/>',
    undo: '<path d="m9 7-5 5 5 5"/><path d="M5 12h8a6 6 0 0 1 6 6"/>',
    flag: '<path d="M6 21V4"/><path d="M6 5h10l-2 3 2 3H6"/>',
    exit: '<path d="M10 5H5v14h5"/><path d="M13 8l4 4-4 4M8 12h9"/>',
    previous: '<path d="m15 18-6-6 6-6"/>',
    next: '<path d="m9 18 6-6-6-6"/>',
    minus: '<path d="M5 12h14"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    fit: '<path d="M9 4H4v5M15 4h5v5M9 20H4v-5M15 20h5v-5"/>',
  };
  return `<svg class="exam-icon" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.pages}</svg>`;
}

// 필요 변수: 시험지 풀이 계약.
// 작동 원리: 공용 앱 크롬을 제외한 전체 화면에서 페이지 탐색, 종이 캔버스, 필기 도구와 제출 상태를 기존 위치에 배치한다.
function renderExam() {
  const thumbnail = (page, selected = false) => `<button class="exam-thumbnail ${selected ? 'is-selected' : ''}" type="button" data-exam-page="${page}"><span class="mini-paper"><i></i><i></i><i></i><i></i></span><small>${page} / 5</small></button>`;
  const option = (index, label, selected = false) => `<button class="paper-option ${selected ? 'is-selected' : ''}" type="button" data-exam-option><span>${index}</span>${label}</button>`;
  return `<section class="page exam-page"><div class="exam-shell"><aside class="exam-thumbnails"><header><h2>페이지</h2><span>5 페이지</span></header><div class="exam-thumbnail-list">${thumbnail(1)}${thumbnail(2, true)}${thumbnail(3)}${thumbnail(4)}${thumbnail(5)}</div><footer><button type="button" data-exam-prev aria-label="이전 페이지">${examIcon('previous')}</button><b id="examPageCount">2 / 5</b><button type="button" data-exam-next aria-label="다음 페이지">${examIcon('next')}</button></footer></aside><main class="exam-canvas-viewport"><button class="exam-mobile-pages" type="button" data-action="exam-pages">${examIcon('pages')}<span>2 / 5</span></button><span class="exam-timer">42:18</span><nav class="exam-tool-rail" aria-label="시험지 도구"><button type="button" title="페이지" aria-label="페이지 목록" data-exam-tool="pages">${examIcon('pages')}</button><button type="button" title="펜" aria-label="펜" data-exam-tool="pen">${examIcon('pen')}</button><button type="button" title="지우개" aria-label="지우개" data-exam-tool="eraser">${examIcon('eraser')}</button><button class="is-selected" type="button" title="이동" aria-label="캔버스 이동" data-exam-tool="pan">${examIcon('pan')}</button><button type="button" title="색상" aria-label="펜 색상" data-exam-tool="color">${examIcon('palette')}<i class="exam-color-dot"></i></button><button type="button" title="실행 취소" aria-label="실행 취소" data-exam-tool="undo">${examIcon('undo')}</button><button type="button" title="시험 종료" aria-label="시험 종료" data-action="finish-exam">${examIcon('flag')}</button><button type="button" title="나가기" aria-label="시험지 나가기" data-action="exit-exam">${examIcon('exit')}</button></nav><div class="exam-zoom-control"><button type="button" data-exam-zoom="out" aria-label="축소">${examIcon('minus')}</button><span id="examZoomValue">100%</span><button type="button" data-exam-zoom="in" aria-label="확대">${examIcon('plus')}</button><button type="button" data-exam-zoom="reset" aria-label="현재 페이지 맞춤">${examIcon('fit')}</button></div><div class="exam-paper-track"><article class="exam-paper-sheet"><header class="paper-header"><div><span>제 2 교시</span><b>2026학년도 AIFlow 학력평가 문제지</b><span>가형</span></div><h2>수 학 영 역</h2></header><div class="paper-question-grid"><section><div class="paper-question-title"><b>5.</b><span>두 점 (1, 3), (3, 7)을 지나는 일차함수의 기울기는?</span><em>3점</em></div><div class="paper-formula">m = (y₂-y₁) / (x₂-x₁)</div><div class="paper-options">${option('①', '1')}${option('②', '2', true)}${option('③', '3')}${option('④', '4')}${option('⑤', '5')}</div></section><section><div class="paper-question-title"><b>6.</b><span>함수 y = 2x + 1의 그래프로 알맞은 것을 고르시오.</span><em>3점</em></div><div class="paper-graph"><i class="axis-x"></i><i class="axis-y"></i><i class="graph-line"></i></div><div class="paper-options compact">${option('①', 'ㄱ')}${option('②', 'ㄴ')}${option('③', 'ㄷ')}</div></section><section><div class="paper-question-title"><b>7.</b><span>다음 표를 보고 x = 4일 때 함숫값을 구하시오.</span><em>4점</em></div><table class="paper-table"><tr><th>x</th><td>1</td><td>2</td><td>3</td><td>4</td></tr><tr><th>y</th><td>3</td><td>5</td><td>7</td><td>?</td></tr></table><div class="paper-writing-line">답: ____________________</div></section><section><div class="paper-question-title"><b>8.</b><span>두 직선의 교점 좌표를 구하는 과정을 서술하시오.</span><em>5점</em></div><div class="paper-writing-area"><i></i><i></i><i></i><i></i></div></section></div><footer class="paper-footer"><span>수학 영역</span><b>2 / 5</b><span>AIFlow</span></footer><svg class="exam-ink-layer" viewBox="0 0 794 1123" aria-hidden="true"><path d="M120 505 C160 470 220 480 250 520 S330 570 355 525"/><path d="M468 772 C515 745 566 758 604 794"/><path d="M510 805 L610 805"/></svg></article><article class="exam-paper-sheet exam-next-paper" aria-hidden="true"><header class="paper-header secondary"><div></div></header><div class="paper-question-grid faded"><section><b>9.</b> 다음 문제를 풀이하시오.</section><section><b>10.</b> 그래프를 해석하시오.</section></div><footer class="paper-footer"><span>수학 영역</span><b>3 / 5</b><span>AIFlow</span></footer></article></div><div class="exam-canvas-hint">한 손가락: 선택·필기 · 두 손가락: 이동·확대 · 더블 탭: 현재 페이지 맞춤</div></main></div>${ledger('exam-paper')}</section>`;
}

// 필요 변수: 교재·시험지·책·문제 북마크 수와 최근 방문 최대 4개.
// 작동 원리: 상단 요약과 최근 방문, 자료 유형만 남기고 각 목록·검색은 모달, 실제 학습은 전체 화면으로 연결한다.
function renderBookbag() {
  const recentItems = [
    ['▧', '중2 일차함수 개념서', '교재 · 42쪽', 'textbook-reader'],
    ['▤', '함수 형성평가', '시험지 · 4/20', 'exam-paper'],
    ['◆', '기울기는 변화의 비율', '책 북마크', 'textbook-reader'],
    ['✎', '그래프 해석 문제', '문제 북마크', 'solve'],
  ];
  // 필요 변수: 아이콘, 제목, 보조 설명과 이동 화면.
  // 작동 원리: 최근 자료를 같은 크기의 간결한 버튼으로 표시하고 원래 학습 화면으로 이동한다.
  const bagItem = ([icon, title, copy, nav]) => `<button class="bag-item" type="button" data-nav="${nav}"><span class="bag-item__type">${icon}</span><span><strong>${title}</strong><small>${copy}</small></span><span class="bag-item__arrow">›</span></button>`;
  const libraryRow = (icon, title, count, copy, action) => `<button class="bookbag-library-row" type="button" data-action="${action}"><span class="bag-item__type">${icon}</span><span><b>${title}</b><small>${copy}</small></span><strong>${count}</strong><i>›</i></button>`;
  return `<section class="page bookbag-page"><header class="bookbag-summary"><div><span class="eyebrow">MY LEARNING MATERIALS</span><h1>책가방</h1><p>최근 자료를 이어보거나 보관된 학습 자료를 찾으세요.</p></div><div class="bookbag-summary-counts"><span><b>14</b><small>교재</small></span><span><b>6</b><small>시험지</small></span><span><b>45</b><small>북마크</small></span></div><button class="button primary round" type="button" data-action="bookbag-search">전체 검색</button></header><section class="bookbag-simple-grid"><article class="card bookbag-recent"><div class="card-head"><div><span class="eyebrow">RECENT</span><h2>최근 방문</h2></div><span class="pill">4개</span></div><div class="bag-item-grid">${recentItems.map((item) => bagItem(item)).join('')}</div></article><aside class="card bookbag-library"><div class="card-head"><div><span class="eyebrow">MY LIBRARY</span><h2>내 자료</h2></div></div><div class="bookbag-library-list">${libraryRow('▧', '교재', '14', '최근 읽은 교재 2개', 'book-library')}${libraryRow('▤', '시험지', '6', '미응시 시험지 2개', 'exam-library')}${libraryRow('◆', '책 북마크', '18', '고정된 위치 1개', 'book-bookmarks')}${libraryRow('✎', '문제 북마크', '27', '저장된 문제 모음', 'problem-bookmarks')}</div></aside></section>${ledger('textbooks')}</section>`;
}

// 필요 변수: 화면 ID와 목록형 기능 계약.
// 작동 원리: 일정, 교재, 그룹, 친구, 마켓의 각 목록 행을 실제 후속 화면과 연결한다.
function renderCollection(id) {
  const meta = screens[id];
  const rows = {
    textbooks: [['중2 일차함수 개념서', '42쪽 · 최근 읽음 12분 전', 'textbook-reader'], ['도형의 닮음 워크북', '18쪽 · 북마크 4개', 'textbook-reader'], ['확률 실전 100제', '마켓에서 추가됨', 'textbook-reader']],
    groups: [['중2 심화 스터디', '멤버 12 · 새 공지 2', 'group-detail'], ['수학 아레나 팀', '멤버 4 · 새 메시지 3', 'group-detail'], ['AIFlow 학교 그룹', '멤버 86 · 과제 1', 'academy']],
    friends: [['이수학', 'B Tier · 학습 중', 'chat'], ['박함수', 'A Tier · 온라인', 'chat'], ['최도형', 'C Tier · 18분 전', 'chat']],
    marketplace: [['중2 함수 실전 100제', '문제 · 평점 4.9', 'textbooks'], ['개념이 보이는 그래프', '교재 · 무료', 'textbook-reader'], ['확률 OX 문제 묶음', '문제 묶음 · 800 P', 'solve']],
  }[id] || [['최근 항목', '상세 정보를 확인하세요', 'dashboard']];
  const primaryAction = id === 'groups' ? button('초대 코드 참가', 'join-group', 'primary') : button('검색·필터', 'search', 'primary');
  return `<section class="page">${pageHead(meta.group.toUpperCase(), meta.label, `${meta.features.slice(0, 4).join(', ')} 기능을 실제 흐름에 맞춰 정리했습니다.`, primaryAction)}<div class="split"><article class="card"><div class="card-head"><h2>${meta.label} 목록</h2><span class="pill">${rows.length} ACTIVE</span></div><div class="list">${rows.map((r, i) => listRow(r[0], r[1], i === 0, r[2])).join('')}</div></article><aside class="card panel sticky"><div class="card-head"><h2>빠른 필터</h2><span class="pill">SYNC</span></div><input class="field" value="" placeholder="검색" aria-label="목록 검색"><div class="feature-ledger">${meta.features.slice(0, 8).map((x) => `<span class="pill">${x}</span>`).join('')}</div></aside></div>${ledger(id)}</section>`;
}

// 필요 변수: 내 그룹, 새 소식, 공개·잠금 상태, 검색어와 초대 코드.
// 작동 원리: 자주 여는 내 그룹을 먼저 보여주고 검색·코드 참가·생성은 한 단계 아래의 명확한 보조 작업으로 배치한다.
function renderGroups() {
  const myGroup = (mark, title, copy, meta, updates = '') => `<button class="study-group-row" type="button" data-nav="group-detail"><span class="study-group-logo ${updates ? 'has-update' : ''}">${mark}</span><span><b>${title}</b><small>${copy}</small></span><div class="study-group-meta">${meta.map((item) => `<span>${item}</span>`).join('')}</div>${updates ? `<strong>${updates}</strong>` : '<i>›</i>'}</button>`;
  const discover = (mark, title, copy, members, locked = false) => `<article class="group-discover-card"><span class="study-group-logo">${mark}</span><span class="pill">${locked ? '비밀번호' : '공개'}</span><h3>${title}</h3><p>${copy}</p><div><span>${members}</span><button type="button" data-action="group-find">${locked ? '비밀번호로 참가' : '참가'}</button></div></article>`;
  return `<section class="page group-study-page">${pageHead('GROUP STUDY', '그룹 스터디', '내 그룹의 새 학습과 대화를 먼저 확인하고, 필요할 때만 검색하거나 초대 코드로 참가하세요.', button('그룹 찾기·코드 참가', 'group-find', 'soft') + button('그룹 만들기', 'group-create', 'primary'))}<section class="group-study-hero"><div><span class="eyebrow">MY GROUPS</span><h2>함께 공부하는<br>공간이 3개 있어요.</h2><p>새 공지 2개와 읽지 않은 메시지 3개가 있습니다.</p></div><div class="group-study-summary"><span><b>3</b><small>내 그룹</small></span><span><b>5</b><small>새 소식</small></span><span><b>2</b><small>공유 Flow</small></span><span><b>1</b><small>오늘 일정</small></span></div></section><section class="group-study-main"><div class="group-study-section-head"><div><span class="eyebrow">CONTINUE TOGETHER</span><h2>내 그룹</h2></div><span class="pill">최근 활동순</span></div><div class="study-group-list">${myGroup('함', '중2 심화 스터디', '함수와 도형을 함께 공부하는 2학년 스터디', ['12 / 20명', '공개', '방금 활동'], '5')}${myGroup('A', '수학 아레나 팀', '매주 화·목 팀 대결을 준비합니다.', ['4 / 4명', '비공개', '오늘 20:00'])}${myGroup('학', 'AIFlow 학교 그룹', '선생님 과제와 공지를 확인하는 학교 그룹', ['86명', '학원 연결', '어제'])}</div></section><aside class="group-join-dock"><div><span class="eyebrow">INVITE CODE</span><h3>초대받은 그룹이 있나요?</h3><p>코드를 확인하면 그룹명·설명·인원을 먼저 보여줍니다.</p></div><div class="group-code-input"><input value="AF-24K8" aria-label="그룹 초대 코드"><button type="button" data-action="join-group">코드 확인</button></div></aside><section class="group-discover"><div class="group-study-section-head"><div><span class="eyebrow">DISCOVER</span><h2>공개 그룹 찾기</h2><p>이름으로 검색하고 공개 또는 비밀번호 그룹에 참가할 수 있습니다.</p></div><div class="group-inline-search"><input value="" placeholder="그룹 이름 검색" aria-label="그룹 검색"><button type="button" data-action="group-find">검색</button></div></div><div class="group-discover-grid">${discover('기', '기하 집중반', '도형의 닮음과 피타고라스 문제를 매일 공유해요.', '8 / 12명')}${discover('확', '확률 실전 스터디', '주 3회 시험지를 풀고 Flow로 풀이를 비교합니다.', '11 / 16명')}${discover('서', '서술형 첨삭 모임', '풀이 과정 중심으로 서로의 Flow를 확인합니다.', '6 / 8명', true)}</div></section>${ledger('groups')}</section>`;
}

// 필요 변수: 그룹 메타, 멤버, 공유 Flow·시험지, 읽지 않은 채팅 수와 선택 탭.
// 작동 원리: 문제풀기·시험지는 그룹 공간에 유지하고 실시간 채팅은 상단 버튼으로 여는 별도 모달에 표시한다.
function renderGroupDetail() {
  const flowCard = (title, user, date, tags, mine = false) => `<article class="group-flow-card"><div><span class="group-flow-state">${mine ? '내 공유' : 'FLOW'}</span><h3>${title}</h3><div class="course-card-meta">${tags.map((tag) => `<span>#${tag}</span>`).join('')}</div></div><footer><span>${user} · ${date}</span><div class="actions">${mine ? '<button type="button">공유 취소</button>' : ''}<button type="button" data-nav="flow">열람</button></div></footer></article>`;
  return `<section class="page group-room-page">${pageHead('GROUP SPACE', '중2 심화 스터디', '그룹 문제와 Flow, 시험지, 채팅을 원래 세 탭 안에서 이어서 사용합니다.', button('그룹 목록', '', 'soft', 'groups') + button('멤버 12명', 'group-members', 'primary'))}<section class="group-room-header"><span class="group-room-logo">함</span><div><div class="course-card-meta"><span>공개 그룹</span><span>12 / 20명</span><span>그룹장 이수학</span></div><h2>함수와 도형을 함께 공부하는<br>중학교 2학년 스터디</h2><p>매주 화·목 20:00 · 풀이 Flow를 공유하고 서로 다른 풀이를 비교합니다.</p></div><aside><span class="eyebrow">PINNED NOTICE</span><b>오늘 20시 일차함수 챌린지</b><small>시험지는 19:50에 공유됩니다.</small></aside></section><nav class="group-room-tabs" aria-label="그룹 공간 탭"><button class="is-active" type="button" data-group-tab="flows"><span>⌘</span><b>그룹 문제풀기</b><small>공유 Flow 8</small></button><button type="button" data-group-tab="exams"><span>▤</span><b>그룹 시험지</b><small>공유 3</small></button><button type="button" data-group-tab="chat"><span>◌</span><b>그룹 채팅</b><small>새 메시지 3</small></button></nav><section class="group-room-panel is-active" data-group-panel="flows"><div class="group-panel-toolbar"><div><span class="eyebrow">SHARED SOLVES</span><h2>그룹 문제풀기</h2><p>최근 60일 내 풀이를 최대 5개 공유하고, 태그·공유자·기간으로 찾습니다.</p></div><div class="actions">${button('필터', 'group-flow-filter', 'soft')}${button('내 풀이 공유', 'group-share-flow', 'primary')}</div></div><div class="group-active-filters"><span>#일차함수 ×</span><span>최근 7일 ×</span><button type="button">전체 해제</button></div><div class="group-flow-grid">${flowCard('두 점을 지나는 일차함수', '김학생', '오늘 14:32', ['일차함수', '기울기'], true)}${flowCard('그래프의 평행이동', '이수학', '오늘 13:18', ['그래프', '평행이동'])}${flowCard('x절편과 y절편 구하기', '박함수', '어제', ['절편', '좌표'])}${flowCard('두 직선의 교점', '최도형', '3일 전', ['연립방정식', '교점'])}</div></section><section class="group-room-panel" data-group-panel="exams" hidden><div class="group-panel-toolbar"><div><span class="eyebrow">SHARED EXAMS</span><h2>그룹 시험지</h2><p>문서함의 내 시험지만 공유할 수 있으며 학생 필기와 답안은 포함되지 않습니다.</p></div>${button('시험지 공유', 'group-share-exam', 'primary')}</div><div class="group-exam-list"><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>중2 함수 형성평가</b><small>이수학 · 오늘 · 20문항</small></span><span>풀기 ›</span></button><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>일차함수 단원평가</b><small>김학생 · 어제 · 15문항</small></span><span>열기 ›</span></button><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>그래프 해석 미니 테스트</b><small>박함수 · 3일 전 · 10문항</small></span><span>열기 ›</span></button></div></section><section class="group-room-panel group-chat-panel" data-group-panel="chat" hidden><div class="group-chat-head"><span>최근 30개부터 표시 · 최대 500개</span><button type="button">이전 메시지 더보기</button></div><div class="group-chat-messages"><div class="group-chat-date">오늘</div><div class="group-message"><span class="social-avatar">이</span><div><b>이수학 <small>19:42</small></b><p>오늘 챌린지 시험지를 공유했어요. 8시에 같이 시작해요!</p></div></div><div class="group-shared-exam"><span class="group-exam-icon">▤</span><span><b>중2 함수 형성평가</b><small>이수학 · 답안 제외 · 20문항</small></span><button type="button" data-nav="exam-paper">열기</button></div><div class="group-message is-me"><div><b>김학생 · 나 <small>19:45</small></b><p>좋아요. 제 풀이 Flow도 공유할게요.</p></div></div><div class="group-message"><span class="social-avatar">박</span><div><b>박함수 <small>19:46</small></b><p>기울기 7번 문제 같이 확인해요.</p></div></div></div><div class="group-chat-composer"><input value="" placeholder="메시지를 입력하세요" aria-label="그룹 메시지"><button type="button" data-action="send-message">전송</button></div></section>${ledger('group-detail')}</section>`;
}

// 필요 변수: 그룹 메타, 공지, 공유 Flow·시험지, 멤버 수와 읽지 않은 채팅 수.
// 작동 원리: 학습 자료는 그룹 공간의 두 탭에 유지하고 채팅은 상단 버튼으로 모달을 열어 화면 맥락을 보존한다.
function renderGroupSpace() {
  const flowCard = (title, user, date, tags, mine = false) => `<article class="group-flow-card"><div><span class="group-flow-state">${mine ? '내 공유' : 'FLOW'}</span><h3>${title}</h3><div class="course-card-meta">${tags.map((tag) => `<span>#${tag}</span>`).join('')}</div></div><footer><span>${user} · ${date}</span><div class="actions">${mine ? '<button type="button">공유 취소</button>' : ''}<button type="button" data-nav="flow">열람</button></div></footer></article>`;
  return `<section class="page group-room-page">${pageHead('GROUP SPACE', '중2 심화 스터디', '공지와 함께 만든 학습 자료를 확인하고, 채팅은 필요할 때 모달로 엽니다.', button('그룹 목록', '', 'soft', 'groups') + button('멤버 12명', 'group-members', 'soft') + button('채팅 열기 · 3', 'group-chat', 'primary'))}<section class="group-room-header"><span class="group-room-logo">함</span><div><div class="course-card-meta"><span>공개 그룹</span><span>12 / 20명</span><span>그룹장 이수학</span></div><h2>함수와 도형을 함께 공부하는<br>중학교 2학년 스터디</h2><p>매주 화·목 20:00 · 풀이 Flow를 공유하고 서로 다른 풀이를 비교합니다.</p></div><aside><span class="eyebrow">PINNED NOTICE</span><b>오늘 20시 일차함수 챌린지</b><small>시험지는 19:50에 공유됩니다.</small><button class="group-notice-chat" type="button" data-action="group-chat">채팅에서 참여 ›</button></aside></section><nav class="group-room-tabs is-two" aria-label="그룹 공간 탭"><button class="is-active" type="button" data-group-tab="flows"><span>⌘</span><b>그룹 문제풀기</b><small>공유 Flow 8</small></button><button type="button" data-group-tab="exams"><span>▤</span><b>그룹 시험지</b><small>공유 3</small></button></nav><section class="group-room-panel is-active" data-group-panel="flows"><div class="group-panel-toolbar"><div><span class="eyebrow">SHARED SOLVES</span><h2>그룹 문제풀기</h2><p>최근 60일 내 풀이를 최대 5개 공유하고, 태그·공유자·기간으로 찾습니다.</p></div><div class="actions">${button('필터', 'group-flow-filter', 'soft')}${button('내 풀이 공유', 'group-share-flow', 'primary')}</div></div><div class="group-active-filters"><span>#일차함수 ×</span><span>최근 7일 ×</span><button type="button">전체 해제</button></div><div class="group-flow-grid">${flowCard('두 점을 지나는 일차함수', '김학생', '오늘 14:32', ['일차함수', '기울기'], true)}${flowCard('그래프의 평행이동', '이수학', '오늘 13:18', ['그래프', '평행이동'])}${flowCard('x절편과 y절편 구하기', '박함수', '어제', ['절편', '좌표'])}${flowCard('두 직선의 교점', '최도형', '3일 전', ['연립방정식', '교점'])}</div></section><section class="group-room-panel" data-group-panel="exams" hidden><div class="group-panel-toolbar"><div><span class="eyebrow">SHARED EXAMS</span><h2>그룹 시험지</h2><p>문서함의 내 시험지만 공유할 수 있으며 학생 필기와 답안은 포함되지 않습니다.</p></div>${button('시험지 공유', 'group-share-exam', 'primary')}</div><div class="group-exam-list"><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>중2 함수 형성평가</b><small>이수학 · 오늘 · 20문항</small></span><span>풀기 ›</span></button><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>일차함수 단원평가</b><small>김학생 · 어제 · 15문항</small></span><span>열기 ›</span></button><button type="button" data-nav="exam-paper"><span class="group-exam-icon">▤</span><span><b>그래프 해석 미니 테스트</b><small>박함수 · 3일 전 · 10문항</small></span><span>열기 ›</span></button></div></section>${ledger('group-detail')}</section>`;
}

// 필요 변수: 미확인 요청·메시지·그룹 소식, 친구 상태, 그룹, 랭킹과 내 평점 태그의 예시 상태.
// 작동 원리: 필수 컴포넌트는 유지하되 즉시 처리할 소식→대화→그룹→평점 순으로 중요도를 재배치하고 세부 작업은 모달·전용 화면으로 연결한다.
function renderSocialHub() {
  const ranking = [
    ['1', '박함수', 'A Tier · 21.4', '+0.6'],
    ['2', '이수학', 'B Tier · 19.1', '+0.2'],
    ['3', '김학생', 'B Tier · 18.6', '+0.3'],
  ];
  const friends = [
    ['이', '이수학', '학습 중 · B Tier', 'chat'],
    ['박', '박함수', '온라인 · A Tier', 'chat'],
    ['최', '최도형', '18분 전 · C Tier', 'chat'],
  ];
  return `<section class="page social-page">${pageHead('FRIENDS & SOCIAL', '친구/소셜', '새 소식을 먼저 처리하고 친구·그룹 학습으로 자연스럽게 이어집니다.', button('친구 추가', 'friend-add', 'primary'))}<section class="social-priority"><button type="button" data-action="friend-requests"><span class="priority-icon">♧</span><span><b>친구 요청</b><small>받은 요청 1 · 보낸 요청 1</small></span><strong>2</strong></button><button type="button" data-action="message-inbox"><span class="priority-icon">◌</span><span><b>안 읽은 쪽지</b><small>이수학 외 1명</small></span><strong>3</strong></button><button type="button" data-nav="group-detail"><span class="priority-icon">◎</span><span><b>그룹 새 소식</b><small>공지 2 · 메시지 3</small></span><strong>5</strong></button><button type="button" data-action="friend-add"><span class="priority-icon is-soft">＋</span><span><b>친구 찾기</b><small>이름·아이디 검색</small></span><span>›</span></button></section><section class="social-main-grid is-priority"><article class="social-panel"><div class="section-title"><div><span class="eyebrow">MESSAGE INBOX</span><h2>최근 대화</h2></div><span class="nav-badge">3</span></div><div class="social-list"><button class="social-row" type="button" data-nav="chat"><span class="social-avatar">이</span><span><b>이수학</b><small>오늘 챌린지 같이 풀래? · 방금</small></span><span class="nav-badge">2</span></button><button class="social-row" type="button" data-nav="chat"><span class="social-avatar">박</span><span><b>박함수</b><small>Flow를 공유했습니다 · 18분 전</small></span><span>›</span></button><button class="social-row" type="button" data-nav="chat"><span class="social-avatar">최</span><span><b>최도형</b><small>고마워! · 어제</small></span><span>›</span></button></div><div class="inline-actions">${button('쪽지함 전체', 'message-inbox', 'soft')}${button('새 메시지', 'send-message', 'primary')}</div></article><article class="social-panel"><div class="section-title"><div><span class="eyebrow">FRIENDS</span><h2>친구 상태</h2></div><span class="pill">온라인 2</span></div><div class="social-list">${friends.map(([initial, name, status, nav]) => `<button class="social-row" type="button" data-nav="${nav}"><span class="social-avatar">${initial}</span><span><b>${name}</b><small>${status}</small></span><span>쪽지 ›</span></button>`).join('')}</div><div class="inline-actions">${button('친구 찾기', 'friend-add', 'soft')}${button('요청 관리', 'friend-requests', 'soft')}</div></article></section><section class="social-groups"><div class="section-title"><div><span class="eyebrow">GROUP STUDY</span><h2>지금 활동 중인 그룹</h2><p class="muted small">그룹 문제풀기 · 그룹 시험지 · 그룹 채팅과 Flow 공유</p></div><div class="actions">${button('그룹 찾기·코드 참가', 'group-find', 'soft')}${button('그룹 만들기', 'group-create', 'primary')}</div></div><div class="group-strip"><button class="group-row" type="button" data-nav="group-detail"><span class="group-mark has-update">01</span><span><b>중2 심화 스터디</b><small>12명 · 새 공지 2 · 새 메시지 3</small></span><span>›</span></button><button class="group-row" type="button" data-nav="group-detail"><span class="group-mark">02</span><span><b>수학 아레나 팀</b><small>4명 · 오늘 20:00 경기</small></span><span>›</span></button><button class="group-row" type="button" data-nav="groups"><span class="group-mark">＋</span><span><b>그룹 더 보기</b><small>검색 · 초대 코드 · 비밀번호 참가</small></span><span>›</span></button></div><div class="shared-content-line"><span><b>함께 학습하기</b><small>문제 · 학생 답안을 제외한 시험지 · 필터 가능한 Flow · 그룹 최근 메시지 30개</small></span><div class="actions">${button('공유 Flow', '', 'soft', 'flow')}${button('그룹 공간 열기', '', 'primary', 'group-detail')}</div></div></section><section class="social-overview is-secondary"><article class="social-panel social-ranking"><div class="section-title"><div><span class="eyebrow">FRIEND OVR</span><h2>친구 랭킹</h2></div><span class="pill">이번 주</span></div><div class="ranking-list">${ranking.map(([rank, name, rating, change], index) => `<div class="ranking-row ${index === 2 ? 'is-me' : ''}"><strong>${rank}</strong><span class="social-avatar">${name[0]}</span><span><b>${name}${index === 2 ? ' · 나' : ''}</b><small>${rating}</small></span><em>${change}</em></div>`).join('')}</div></article><article class="social-rating is-compact"><span class="eyebrow">MY RATING</span><div class="social-rating__main"><div><strong>18.6</strong><p>B Tier · 전날 대비 +0.3</p></div><div class="rank-badge">B</div></div><div class="tag-movement"><span><small>강점</small><b>#일차함수 19.2</b></span><span><small>상승</small><b>#그래프 +0.8</b></span><span><small>약점</small><b>#기하 16.4</b></span><span><small>하락</small><b>#확률 -0.2</b></span></div>${button('내 평점 상세', 'rating-detail', 'round')}</article></section>${ledger('friends')}</section>`;
}

// 필요 변수: 주간 날짜, 선택 날짜의 과제·개인 일정, 월간 과제 표시일, 학습 일정 API 계약.
// 작동 원리: 한 페이지에서 주간(일별)과 월간 보기를 전환하며, 두 보기 모두 선택한 날짜의 상세 일정으로 연결한다.
function renderSchedule() {
  const weekDays = [['월', '13'], ['화', '14'], ['수', '15'], ['목', '16'], ['금', '17'], ['토', '18'], ['일', '19']];
  const weekSelector = weekDays.map(([day, date]) => `<button class="schedule-day ${date === '16' ? 'is-selected' : ''}" type="button" data-schedule-date="${date}"><span>${day}</span><b>${date}</b>${['13', '16', '18'].includes(date) ? '<i aria-label="일정 있음"></i>' : ''}</button>`).join('');
  const monthCalendar = Array.from({ length: 35 }, (_, index) => {
    const date = index + 1;
    const hasTask = [4, 9, 16, 19, 25].includes(date);
    return `<button class="${date === 16 ? 'today' : ''} ${hasTask ? 'has-task' : ''}" type="button" data-schedule-date="${date}"><b>${date}</b>${hasTask ? '<small>2</small>' : ''}</button>`;
  }).join('');
  const dailyTasks = `${listRow('일차함수 12문제', '교사 과제 · 22:00 마감 · 4/12', true, 'solve')}${listRow('교재 3장 읽기', '교사 과제 · 최소 8분', false, 'textbook-reader')}${listRow('개인 복습', '개인 일정 · 20분')}`;

  const viewSwitch = '<div class="schedule-toolbar" role="tablist" aria-label="일정 보기 방식"><button class="is-active" type="button" role="tab" aria-selected="true" data-schedule-view="week">주간(일별)</button><button type="button" role="tab" aria-selected="false" data-schedule-view="month">월간</button></div>';

  return `<section class="page schedule-page">${pageHead('JULY 2026', '학습 일정', '주간의 하루 흐름과 월간 계획을 한 페이지에서 전환해 확인합니다.', viewSwitch)}<section class="schedule-view is-active" data-schedule-panel="week"><article class="card schedule-main"><div class="card-head"><div><span class="eyebrow">THIS WEEK</span><h2>7월 13일 – 19일</h2></div><div class="actions"><button class="icon-button" type="button" aria-label="이전 주">‹</button><button class="icon-button" type="button" aria-label="다음 주">›</button></div></div><div class="schedule-week">${weekSelector}</div><div class="schedule-timeline schedule-timeline--spaced"><div class="time-mark"><b>16:00</b><span></span></div><button class="timeline-task" type="button" data-nav="textbook-reader"><span class="task-kind">교재</span><span><b>교재 3장 읽기</b><small>최소 학습 8분</small></span><em>미시작</em></button><div class="time-mark"><b>19:30</b><span></span></div><button class="timeline-task is-personal" type="button"><span class="task-kind">개인</span><span><b>개인 복습</b><small>기울기와 그래프 · 20분</small></span><em>예정</em></button><div class="time-mark"><b>22:00</b><span></span></div><button class="timeline-task is-active" type="button" data-nav="solve"><span class="task-kind">과제</span><span><b>일차함수 12문제</b><small>진행 4/12 · 오늘 마감</small></span><em>진행 중</em></button></div></article><aside class="card schedule-side"><div class="card-head"><h2>오늘 요약</h2><span class="pill">목요일</span></div><div class="schedule-progress"><strong>33%</strong><div><b>1개 완료</b><div class="progress"><span style="width:33%"></span></div></div></div><div class="list">${dailyTasks}</div><button class="button primary" type="button" style="width:100%;margin-top:14px">＋ 개인 일정 추가</button></aside></section><section class="schedule-view" data-schedule-panel="month" hidden><article class="card schedule-main"><div class="card-head"><div><span class="eyebrow">MONTHLY</span><h2>2026년 7월</h2></div><div class="actions"><button class="icon-button" type="button" aria-label="이전 달">‹</button><button class="icon-button" type="button" aria-label="다음 달">›</button></div></div><div class="calendar-weekdays" aria-hidden="true"><span>일</span><span>월</span><span>화</span><span>수</span><span>목</span><span>금</span><span>토</span></div><div class="calendar calendar--compact">${monthCalendar}</div></article><aside class="card schedule-side"><div class="card-head"><div><span class="eyebrow">SELECTED DAY</span><h2>7월 16일</h2></div><span class="pill">3개</span></div><div class="list">${dailyTasks}</div><button class="button primary" type="button" style="width:100%;margin-top:14px">＋ 개인 일정 추가</button></aside></section>${ledger('schedule')}</section>`;
}

// 필요 변수: 아레나 경기 데이터.
// 작동 원리: 독립 티어를 가진 1v1·2v2 시험/OX 대기열을 전환하고 예상 대기시간과 경기 규칙을 매칭 전에 비교한다.
function renderArena() {
  const queueCard = (type, icon, title, copy, wait, record, accent = '') => `<article class="arena-queue-card ${accent}"><div class="arena-queue-top"><span class="arena-mode-icon">${icon}</span><span class="queue-live"><i></i> LIVE QUEUE</span></div><h3>${title}</h3><p>${copy}</p><div class="arena-queue-stats"><span><small>예상 대기</small><b>${wait}</b></span><span><small>내 전적</small><b>${record}</b></span></div><button class="button ${accent ? 'primary' : 'soft'} round" type="button" data-action="join-arena" data-arena-queue="${type}">매칭 시작 <span>→</span></button></article>`;
  return `<section class="page arena-page"><section class="arena-overview"><div class="arena-overview-copy"><span class="eyebrow">RANKED MATCH</span><h2>실력으로 증명하는<br>20분.</h2><p>시험 대결은 객관식 5문항과 단답형 5문항,<br>OX 대결은 10문항으로 진행됩니다.</p><div class="arena-season-progress"><div><span>A TIER까지</span><b>220점</b></div><div class="progress"><span style="width:58%"></span></div><small>현재 1,580 · 다음 티어 1,800</small></div></div><aside class="arena-player-card"><span class="arena-card-label">MY ARENA PROFILE</span><div class="arena-tier-row"><div class="arena-tier-emblem"><span>B</span></div><div><strong>1,580</strong><small>B TIER · 상위 18%</small></div></div><div class="arena-record"><span><b>18</b><small>승</small></span><span><b>9</b><small>패</small></span><span><b>2</b><small>무</small></span><span><b>66.7%</b><small>승률</small></span></div><div class="arena-streak"><span>최근 전적</span><i class="is-win">W</i><i class="is-win">W</i><i class="is-loss">L</i><i class="is-win">W</i><i class="is-draw">D</i></div></aside></section><section class="arena-match-section"><div class="arena-match-head"><div><span class="eyebrow">CHOOSE YOUR MATCH</span><h2>대결 방식 선택</h2><p>각 방식의 레이팅과 전적은 독립적으로 기록됩니다.</p></div><div class="arena-mode-switch" role="tablist" aria-label="대결 인원 선택"><button class="is-active" type="button" role="tab" aria-selected="true" data-arena-mode="duel">1 VS 1</button><button type="button" role="tab" aria-selected="false" data-arena-mode="team">2 VS 2</button></div></div><div class="arena-queue-panel is-active" data-arena-panel="duel">${queueCard('duel_exam', '▤', '1v1 시험 대결', '객관식 5 + 단답형 5 · 제한 시간 20분', '32초', '18승 9패', 'is-featured')}${queueCard('duel_ox', 'OX', '1v1 OX 스프린트', '빠르게 판단하는 OX 10문항 · 제한 시간 8분', '18초', '24승 11패')}</div><div class="arena-queue-panel" data-arena-panel="team" hidden>${queueCard('team_exam', '2×', '2v2 팀 시험 대결', '팀 합산 점수 · 객관식 5 + 단답형 5', '54초', '8승 4패', 'is-featured')}${queueCard('team_ox', 'OX', '2v2 OX 릴레이', '팀 합산 점수 · OX 10문항 · 경기 중 팀 채팅', '41초', '12승 6패')}</div></section><section class="arena-rules"><div class="arena-rules-head"><span class="eyebrow">FAIR PLAY PROTOCOL</span><h2>모두에게 같은 조건</h2></div><div class="arena-rule-grid"><span><i>01</i><b>동일 문항</b><small>모든 참가자가 같은 문제를 풉니다.</small></span><span><i>02</i><b>20분 제한</b><small>서버 시간을 기준으로 동시에 종료됩니다.</small></span><span><i>03</i><b>재시도 제한</b><small>남은 횟수가 모든 참가자에게 표시됩니다.</small></span><span><i>04</i><b>채팅 파쇄</b><small>2v2 팀 채팅은 경기 종료 즉시 삭제됩니다.</small></span></div></section>${ledger('arena')}</section>`;
}

// 필요 변수: 친구·그룹 채팅 계약.
// 작동 원리: 대화 목록, 본문, 공유 자료를 PC 3열과 모바일 단일 대화 화면으로 전환한다.
function renderChat(id = 'chat') {
  return `<section class="page">${pageHead('SOCIAL', screens[id].label, '친구·그룹 대화와 자료 공유를 실시간 상태로 연결합니다.', button('새 메시지', 'send-message', 'primary'))}<div class="card chat-layout"><aside class="chat-column"><h3>대화</h3><div class="list" style="margin-top:16px">${listRow('이수학', '오늘 챌린지 같이 풀래?', true)}${listRow('중2 심화 스터디', '새 공지가 등록됐어요')}${listRow('박함수', 'Flow를 공유했습니다')}</div></aside><article class="chat-main"><div class="card-head" style="padding:16px 18px;margin:0;border-bottom:1px solid var(--line)"><div><h3>${id === 'group-detail' ? '중2 심화 스터디' : '이수학'}</h3><span class="muted small">온라인 · B Tier</span></div><span class="pill">LIVE</span></div><div class="messages"><div class="message">오늘 일차함수 챌린지 같이 풀래?</div><div class="message me">좋아! 8시에 시작하자.</div><div class="message">내 풀이 Flow도 공유할게.</div><div class="message me">확인했어. 기울기 설명 좋다!</div></div><div class="composer"><input class="field" value="" placeholder="메시지 입력" aria-label="메시지 입력">${button('전송', 'send-message', 'primary')}</div></article><aside class="chat-column"><h3>공유 자료</h3><div class="list" style="margin-top:16px">${listRow('일차함수 풀이 Flow', '공유됨', false, 'flow')}${listRow('함수 형성평가', '20문항', false, 'exam-paper')}</div></aside></div>${ledger(id)}</section>`;
}

// 필요 변수: 교재 도구 이름과 선택 상태.
// 작동 원리: 원본 리더 도구와 같은 의미의 20px 선형 SVG를 반환해 문자 아이콘의 크기 차이를 없앤다.
function readerIcon(name) {
  const paths = {
    back: '<path d="m15 18-6-6 6-6"/>', toc: '<path d="M4 5h3M4 12h3M4 19h3M10 5h10M10 12h10M10 19h10"/>', bookmark: '<path d="M6 3h12v18l-6-4-6 4Z"/>', pen: '<path d="m4 20 4-1 10-10a2.1 2.1 0 0 0-3-3L5 16Z"/><path d="m14 7 3 3"/>', highlight: '<path d="m6 15 7-7 4 4-7 7H6Z"/><path d="M4 21h16M13 8l2-2 4 4-2 2"/>', palette: '<path d="M12 3a9 9 0 0 0 0 18h1.5a2 2 0 0 0 0-4h-.8a1.7 1.7 0 0 1 0-3.4H15A5.7 5.7 0 0 0 15 3Z"/><circle cx="7.5" cy="10" r=".7"/><circle cx="10" cy="6.8" r=".7"/><circle cx="15" cy="7.2" r=".7"/>', eraser: '<path d="m5 15 8-8a2 2 0 0 1 3 0l3 3a2 2 0 0 1 0 3l-7 7H9l-4-3a2 2 0 0 1 0-2Z"/><path d="m10 10 6 6M12 20h9"/>', search: '<circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/>', previous: '<path d="m15 18-6-6 6-6"/>', next: '<path d="m9 18 6-6-6-6"/>', page: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h8M8 15h5"/>', scroll: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8 7h8M8 11h8M8 15h8M8 18h6"/>', collapse: '<path d="m14 18-6-6 6-6"/>'
  };
  return `<svg class="reader-icon" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.page}</svg>`;
}

// 필요 변수: 교재 콘텐츠 블록, 장·절 목차, 페이지·스크롤 모드, 필기 도구와 코스 런타임 상태.
// 작동 원리: 원본 학생 리더의 자체 앱바·접이식 목차·종이 페이지·하단 도구 배치를 유지하고 모바일에서는 목차를 시트로 전환한다.
function renderReader() {
  const tocRow = (number, title, meta, state = '', child = false) => `<button class="reader-toc-row ${state ? `is-${state}` : ''} ${child ? 'is-child' : ''}" type="button" data-reader-toc-row><span>${number}</span><span><b>${title}</b><small>${meta}</small></span><i>${state === 'active' ? '●' : state === 'done' ? '✓' : child ? '' : '›'}</i></button>`;
  return `<section class="reader-page"><header class="reader-topbar"><div class="reader-title-group"><button class="reader-icon-button" type="button" data-nav="course-learning" aria-label="교재 닫기">${readerIcon('back')}</button><span class="reader-brand">A</span><div><h1>중2 일차함수 개념서</h1><p>p.6 / 1–18 · 학습 시간 05:12</p></div></div><div class="reader-runtime"><span>이수율 <b>42%</b></span><div class="progress"><span style="width:42%"></span></div></div><div class="reader-top-actions"><button class="reader-icon-button" type="button" data-reader-tool="bookmark" aria-label="북마크">${readerIcon('bookmark')}</button><button class="reader-icon-button reader-toc-trigger" type="button" data-action="reader-toc" aria-label="목차">${readerIcon('toc')}</button><div class="reader-view-switch" role="group" aria-label="읽기 방식"><button class="is-selected" type="button" data-reader-view="page" aria-label="페이지 보기">${readerIcon('page')}</button><button type="button" data-reader-view="scroll" aria-label="스크롤 보기">${readerIcon('scroll')}</button></div><button class="reader-complete-button" type="button" data-action="reader-complete">학습 완료</button></div></header><div class="reader-shell"><aside class="reader-sidebar"><div class="reader-sidebar-head"><span>${readerIcon('toc')}<b>목차</b></span><button type="button" data-reader-collapse aria-label="목차 접기">${readerIcon('collapse')}</button></div><div class="reader-toc-list">${tocRow('01', '함수의 뜻', '1–4쪽 · 완료', 'done')}${tocRow('02', '좌표와 그래프', '5–12쪽 · 읽는 중')}${tocRow('2.1', '좌표평면 읽기', '5쪽', '', true)}${tocRow('2.2', '기울기의 의미', '6쪽 · 현재 위치', 'active', true)}${tocRow('2.3', '그래프의 변화', '7–12쪽', '', true)}${tocRow('03', '일차함수', '13–16쪽')}${tocRow('04', '일차함수의 활용', '17–18쪽')}</div><div class="reader-sidebar-tools"><div class="reader-tool-row"><button class="is-selected" type="button" data-reader-tool="bookmark" aria-label="북마크">${readerIcon('bookmark')}</button><button type="button" data-reader-tool="pen" aria-label="펜">${readerIcon('pen')}</button><button type="button" data-reader-tool="highlight" aria-label="형광펜">${readerIcon('highlight')}</button><button type="button" data-reader-tool="palette" aria-label="색상">${readerIcon('palette')}<i></i></button><button type="button" data-reader-tool="eraser" aria-label="지우개">${readerIcon('eraser')}</button></div><div class="reader-nav-row"><button type="button" data-action="reader-search" aria-label="검색">${readerIcon('search')}</button><button type="button" data-reader-prev aria-label="이전 페이지">${readerIcon('previous')}</button><span id="readerPageCount">6 / 18</span><button type="button" data-reader-next aria-label="다음 페이지">${readerIcon('next')}</button></div></div></aside><button class="reader-collapse-handle" type="button" data-reader-collapse aria-label="목차 접기">${readerIcon('collapse')}</button><main class="reader-workspace"><div class="reader-document-bar"><span>${readerIcon('page')}<b>일차함수 개념서</b></span><span><button type="button" aria-label="글자 작게">A−</button><b>100%</b><button type="button" aria-label="글자 크게">A＋</button></span></div><div class="reader-page-viewport"><button class="reader-page-arrow is-previous" type="button" data-reader-prev aria-label="이전 페이지">${readerIcon('previous')}</button><article class="reader-paper"><header><span>CHAPTER 02 · 좌표와 그래프</span><small>일차함수 개념서</small></header><h2>기울기는 변화의 비율이다.</h2><p>직선이 얼마나 가파른지를 나타내는 값을 <b>기울기</b>라고 합니다. 두 점을 지날 때 x의 변화량에 대한 y의 변화량의 비로 구할 수 있습니다.</p><section class="reader-concept-block"><span>핵심 개념</span><strong>기울기 = <span>y의 변화량</span> ÷ <span>x의 변화량</span></strong><small>m = (y₂ − y₁) / (x₂ − x₁)</small></section><div class="reader-content-grid"><div><h3>두 점으로 기울기 구하기</h3><p>두 점 A(1, 2), B(4, 8)을 지나는 직선에서 x는 3만큼, y는 6만큼 변합니다.</p><ol><li>변화량을 각각 구합니다.</li><li>y의 변화량을 x의 변화량으로 나눕니다.</li></ol><div class="reader-example"><b>m = (8 − 2) / (4 − 1) = 2</b><span>따라서 직선의 기울기는 2입니다.</span></div></div><figure class="reader-graph"><div class="reader-graph-grid"><i class="axis-x"></i><i class="axis-y"></i><i class="line"></i><i class="point a"></i><i class="point b"></i></div><figcaption>A(1, 2)에서 B(4, 8)까지의 변화</figcaption></figure></div><aside class="reader-note"><b>기억하기</b><p>오른쪽으로 갈수록 올라가면 양의 기울기, 내려가면 음의 기울기입니다.</p></aside><svg class="reader-annotation" viewBox="0 0 600 840" aria-hidden="true"><path d="M92 522c55 12 126 9 188 2"/><path d="M430 655c35-28 79-22 89 10"/></svg><footer><span>#일차함수 · #그래프 · #기울기</span><b>6</b></footer></article><button class="reader-page-arrow is-next" type="button" data-reader-next aria-label="다음 페이지">${readerIcon('next')}</button></div><div class="reader-bottom-nav"><button type="button" data-reader-prev>${readerIcon('previous')} 이전</button><span><b id="readerBottomPage">6</b> / 18</span><button type="button" data-reader-next>다음 ${readerIcon('next')}</button></div></main></div><footer class="reader-mobile-rail"><div><span>학습 시간 05:12 · 최소 08:00</span><div class="progress"><span style="width:65%"></span></div></div><button type="button" data-action="reader-toc">${readerIcon('toc')} 목차</button></footer>${ledger('textbook-reader')}</section>`;
}

// 필요 변수: 도구 화면 ID와 화면 원장의 기능·연결 계약.
// 작동 원리: 일반 학습 도구는 모달 진입 원칙을 안내하고, 그래프만 기존 전용 작업 화면 구조로 렌더링한다.
function renderTools(id) {
  if (id === 'flow') return renderFlow();
  if (id === 'graph') return renderGraph();
  return `<section class="page tool-modal-index">${pageHead('LEARNING TOOLS', '학습 도구', '그래프 그리기를 제외한 도구는 학습 맥락을 유지하는 모달로 실행됩니다.', button('홈으로 돌아가기', '', 'primary', 'dashboard'))}<div class="grid three"><button class="card feature-card" type="button" data-action="tool-note"><span class="feature-icon">✎</span><span><h3>빠른 노트</h3><p>자동 저장 · UTF-8</p></span><span>모달 ›</span></button><button class="card feature-card" type="button" data-action="tool-timer"><span class="feature-icon">◷</span><span><h3>집중 타이머</h3><p>25분 · 학습 시간 기록</p></span><span>모달 ›</span></button><button class="card feature-card" type="button" data-action="tool-focus"><span class="feature-icon">◉</span><span><h3>집중 모드</h3><p>알림 보류 · 주변 UI 절제</p></span><span>모달 ›</span></button></div>${ledger('tools')}</section>`;
}

// 필요 변수: 그래프 식, 매개변수, 표시 옵션과 원본 JSXGraph 렌더링 계약.
// 작동 원리: 기존 JsxGraphPage의 좌측 그래프·우측 편집기 구조를 유지하고 모바일에서는 그래프 다음에 편집기를 쌓는다.
function renderGraph() {
  const keypad = ['x', 'x²', '√', '| |', 'sin', 'cos', 'tan', 'log', 'ln', 'π', 'e', '(', ')', '+', '−', '×', '÷', '^'];
  return `<section class="graph-page"><header class="graph-topbar"><div class="graph-title"><button class="icon-button" type="button" data-nav="dashboard" aria-label="그래프 닫기">‹</button><span class="brand-mark">A</span><div><span class="eyebrow">GRAPH TOOL</span><h1>그래프 그리기</h1></div></div><button class="button soft round" type="button" data-action="graph-examples">ⓘ 예제</button></header><div class="graph-workspace"><main class="graph-board"><div class="graph-board-toolbar"><span><b>좌표평면</b><small>두 손가락으로 이동·확대</small></span><div><button type="button" aria-label="확대">＋</button><button type="button" aria-label="축소">−</button><button type="button" aria-label="초기화">⌂</button></div></div><div class="graph-grid" aria-label="JSXGraph 그래프 캔버스"><i class="graph-axis-x"></i><i class="graph-axis-y"></i><svg viewBox="0 0 760 520" preserveAspectRatio="none" aria-hidden="true"><path class="graph-curve-primary" d="M30 470 C155 465 232 396 300 275 C354 180 405 62 510 52 C615 42 686 102 735 185"/><path class="graph-curve-secondary" d="M35 390 C175 325 304 259 430 197 C550 137 650 87 735 48"/></svg><span class="graph-point point-a">A</span><span class="graph-point point-b">B</span><div class="graph-legend"><span><i class="is-primary"></i>f(x)=a(x-h)²+k</span><span><i class="is-secondary"></i>y=2x+1</span></div></div></main><aside class="graph-editor"><div class="graph-editor-intro"><span class="eyebrow">중학교 2학년 · 함수</span><h2>이차함수와 직선</h2><p>식과 매개변수를 바꾸며 그래프의 이동과 교점을 확인합니다.</p><div><b>현재 그래프 구성</b><span>이차함수 · 직선 · 교점 2개</span></div></div><button class="graph-add-expression" type="button">＋ 식 추가</button><section class="graph-practice"><div><b>실습</b><span>a = 1.0</span></div><input type="range" min="-3" max="3" value="1" aria-label="매개변수 a"><div class="graph-range-label"><span>-3</span><span>a</span><span>3</span></div></section><section class="graph-expression is-active"><header><i></i><span><b>이차함수</b><small>직접 입력 1</small></span><button type="button" aria-label="식 표시 전환">●</button><button type="button" aria-label="식 삭제">×</button></header><input class="field" value="a*(x-1)^2-2" aria-label="이차함수 식"><div class="graph-keypad">${keypad.map((key) => `<button type="button">${key}</button>`).join('')}</div></section><section class="graph-expression"><header><i></i><span><b>직선</b><small>직접 입력 2</small></span><button type="button" aria-label="식 표시 전환">●</button><button type="button" aria-label="식 삭제">×</button></header><input class="field" value="2*x+1" aria-label="직선 식"></section><div class="graph-options"><button class="is-selected" type="button">축</button><button class="is-selected" type="button">격자</button><button type="button">뷰 고정</button><button type="button">라디안</button></div><button class="button primary graph-refresh" type="button">⌁ 그래프 갱신</button></aside></div>${ledger('graph')}</section>`;
}

// 필요 변수: 제출 결과, 풀이 시간, 단계 정오답, 약점 단계와 후속 문제 이동.
// 작동 원리: 별도 풀이 분석 페이지 대신 Flow 캔버스 위에 최소 결과만 요약하고 상세 원인은 노드 선택으로 확인하게 한다.
function flowAnalysisSummary() {
  return `<section class="flow-analysis-summary"><div class="flow-result-mark"><span>제출 결과</span><strong>오답</strong><small>정답까지 1단계</small></div><div class="flow-result-stats"><span><small>풀이 시간</small><b>01:42</b></span><span><small>단계 정답</small><b>3 / 4</b></span><span><small>약점 단계</small><b>변화량 순서</b></span></div><div class="flow-ai-summary"><span class="eyebrow">AI OPINION</span><p>기울기 공식은 이해했지만 Δy와 Δx의 순서를 한 번 바꾸었습니다. 빨간 노드를 선택해 해당 단계만 다시 확인하세요.</p></div><div class="flow-result-actions">${button('다시 풀기', '', 'soft', 'solve')}${button('다음 문제', '', 'primary', 'solve')}</div></section>`;
}

// 필요 변수: 문제 지문·정답 공개 상태, 분기 노드 좌표, 노드별 정오답·힌트·풀이 상태.
// 작동 원리: 기존 FlowViewPage의 3열 구조와 InteractiveViewer형 분기 캔버스를 보존하고 선택 노드의 상세 정보를 우측에 갱신한다.
function renderFlow() {
  const node = (id, step, state, copy, formula, x, y, selected = false) => `<button class="flow-node is-${state} ${selected ? 'is-selected' : ''}" type="button" style="left:${x}px;top:${y}px" data-flow-node="${id}" data-flow-step="${step}" data-flow-summary="${copy}" data-flow-hint="두 점의 좌표와 부호를 순서대로 확인하세요." data-flow-solution="${formula}"><span>${step}</span><b>${copy}</b><small>${formula}</small></button>`;
  return `<section class="page flow-page">${pageHead('SOLUTION FLOW', '풀이 흐름', '기존 분기형 노드와 연결선, 문제·노드 상세의 3열 사용 방식을 유지합니다.', button('그룹에 공유', 'share-flow-group', 'soft') + button('문제 북마크', 'bookmark-flow-problem', 'primary'))}<div class="flow-workspace"><aside class="flow-side flow-problem"><div class="flow-panel-head"><span class="feature-icon">▤</span><h2>문제 정보</h2></div><h3>문제 지문</h3><p>두 점 (1, 3), (3, 7)을 지나는 일차함수의 식을 구하세요.</p><div class="flow-answer"><span>문제 정답</span><b>정답 제출 후 확인 가능합니다.</b></div><button class="button flow-chat" type="button" data-action="flow-ai-chat">질문하기 · 정답 비공개</button><div class="flow-shared-tools"><span class="pill">공유 모드</span><small>공유 Flow에서는 공식 정보와 ‘왜 틀렸는지 분석’, 소유자의 공유 삭제 기능이 표시됩니다.</small></div></aside><article class="flow-canvas-panel"><header><div class="flow-legend"><span><i class="is-correct"></i>정답</span><span><i class="is-wrong"></i>오답</span><span><i class="is-dim"></i>이후 단계</span></div><div class="flow-zoom"><button type="button">−</button><span>100%</span><button type="button">＋</button><button type="button">초기화</button></div></header><div class="flow-viewport" aria-label="확대와 이동이 가능한 풀이 흐름 캔버스"><div class="flow-canvas"><svg viewBox="0 0 760 620" aria-hidden="true"><path d="M380 110 C380 145 160 145 160 190"/><path d="M380 110 C380 145 600 145 600 190"/><path d="M160 270 C160 325 380 310 380 350"/><path d="M600 270 C600 325 380 310 380 350"/><path d="M380 430 L380 500"/></svg>${node('step-1', 'STEP 01', 'correct', '조건 해석', '(1, 3), (3, 7)', 270, 30)}${node('step-2a', 'STEP 02-A', 'wrong', '변화량 순서 확인', 'Δy / Δx = 2 / 4', 50, 190)}${node('step-2b', 'STEP 02-B', 'correct', '기울기 계산', '(7-3) / (3-1) = 2', 490, 190)}${node('step-3', 'STEP 03', 'correct', '절편 구하기', '3 = 2 × 1 + b', 270, 350, true)}${node('step-4', 'STEP 04', 'dim', '다른 점으로 검산', '7 = 2 × 3 + 1', 270, 500)}</div></div><footer><span>드래그하여 이동 · 60%–250% 확대</span><span>노드 5 · 분기 2</span></footer></article><aside class="flow-side flow-detail"><div class="flow-panel-head"><span class="feature-icon">03</span><h2>노드 상세 정보</h2></div><div id="flowNodeDetail"><span class="eyebrow">STEP 03 · 정답</span><h3>절편 구하기</h3><div class="flow-detail-row"><small>노드 요약</small><p>3 = 2 × 1 + b에서 b = 1</p></div><div class="flow-detail-row"><small>개념 태그</small><div class="feature-ledger"><span class="pill">#일차함수</span><span class="pill">#절편</span></div></div><div class="flow-detail-row"><small>힌트</small><p>구한 기울기와 한 점을 y = ax + b에 대입하세요.</p></div><div class="flow-detail-row"><small>정답 풀이</small><p>y = 2x + 1</p></div></div>${button('이 단계로 변형 문제', '', 'soft', 'solve')}</aside></div>${ledger('flow')}</section>`;
}

// 필요 변수: 프로필·설정·인증 화면 ID.
// 작동 원리: 계정 데이터 변경과 인증 계약을 학습 화면과 분리된 집중형 폼으로 보여준다.
function renderAccount(id) {
  const meta = screens[id];
  const isAuth = id === 'auth' || id === 'signup';
  return `<section class="page">${pageHead('AIFlow ACCOUNT', meta.label, `${meta.features.slice(0, 5).join(', ')} 흐름을 포함합니다.`)}<div class="split"><article class="card ${isAuth ? 'dark' : ''}"><div class="card-head"><div><span class="eyebrow">${isAuth ? 'WELCOME' : 'STUDENT PROFILE'}</span><h2>${isAuth ? (id === 'auth' ? '다시 만나서 반가워.' : '나만의 학습 흐름 시작하기') : '김학생'}</h2></div>${!isAuth ? '<div class="rank-badge">B</div>' : ''}</div><div class="action-fields"><label>아이디<input class="field" value="student@example.com"></label><label>${isAuth ? '비밀번호' : '학교·학년'}<input class="field" value="${isAuth ? '••••••••' : 'AIFlow 중학교 · 2학년'}"></label>${!isAuth ? '<label>이름<input class="field" value="김학생"></label>' : ''}</div><div class="actions" style="margin-top:20px">${button(id === 'signup' ? '가입 완료' : id === 'auth' ? '로그인' : '저장', id === 'signup' ? 'register' : id === 'auth' ? 'login' : 'save-profile', 'primary')}${isAuth ? button(id === 'auth' ? '회원가입' : '로그인', '', 'soft', id === 'auth' ? 'signup' : 'auth') : ''}</div></article><aside class="card"><h2>${id === 'settings' ? '환경 설정' : '계정 상태'}</h2><div class="list" style="margin-top:16px">${meta.features.map((x, i) => listRow(x, i < 3 ? '사용 가능' : '설정 확인', i === 0)).join('')}</div></aside></div>${ledger(id)}</section>`;
}

// 필요 변수: 아이디 또는 이메일, 비밀번호, 카카오 OAuth 결과, 저장된 JWT와 사용자명.
// 작동 원리: 일반·카카오 로그인 성공 시 JWT를 저장하고, 재실행 시 /auth/me를 5초 안에 검증해 세션을 복원한다.
function renderLogin() {
  return `<section class="page account-page auth-page"><div class="auth-layout"><aside class="auth-story"><button class="auth-brand" type="button" data-nav="dashboard"><span class="brand-mark">A</span><b>AIFlow</b></button><div><span class="eyebrow">WELCOME BACK</span><h1>멈춘 곳에서<br>다시 시작해요.</h1><p>로그인하면 코스 진도, 필기, 복습 기록과 그룹 활동을 그대로 이어갑니다.</p></div><div class="auth-session-note"><span>SESSION RESTORE</span><b>저장된 로그인은 안전하게 확인합니다.</b><small>JWT 불러오기 → /auth/me 5초 검증 → 401·403이면 자동 삭제</small></div></aside><main class="auth-form-card"><div class="auth-form-head"><span class="eyebrow">STUDENT LOGIN</span><h2>로그인</h2><p>아이디 또는 이메일로 로그인하세요.</p></div><div class="account-fields"><label><span>아이디 또는 이메일</span><input class="field" value="student01" autocomplete="username"></label><label><span>비밀번호</span><div class="account-password"><input class="field" type="password" value="password123" autocomplete="current-password"><button type="button" aria-label="비밀번호 보기">보기</button></div></label></div><button class="account-primary" type="button" data-action="login">로그인</button><div class="auth-divider"><span>또는</span></div><button class="kakao-button" type="button" data-action="kakao-login"><span>●</span> 카카오로 계속하기</button><p class="auth-switch-copy">처음 오셨나요? <button type="button" data-nav="signup">회원가입</button></p><div class="auth-contract"><span>로그인 성공</span><code>POST /auth/login → setToken → 학생 홈</code></div></main></div>${ledger('auth')}</section>`;
}

// 필요 변수: 이름, 과정, 학년, 과목, 학교, 아이디, 비밀번호, 선택 이메일과 현재 가입 단계.
// 작동 원리: 기본 정보→계정 검증→최종 확인 순서로 진행하며 아이디 중복과 필드 형식을 확인한 뒤 한 번만 가입 요청을 전송한다.
function renderSignup() {
  return `<section class="page account-page signup-page"><header class="signup-head"><button class="auth-brand" type="button" data-nav="auth"><span class="brand-mark">A</span><b>AIFlow</b></button><div><span class="eyebrow">CREATE ACCOUNT</span><h1>나에게 맞는 학습을<br>설정해 볼까요?</h1></div><button class="button soft" type="button" data-nav="auth">로그인으로 돌아가기</button></header><div class="signup-progress"><button class="is-active" type="button" data-signup-stage="profile"><span>01</span><b>기본 정보</b><small>이름과 학습 과정</small></button><i></i><button type="button" data-signup-stage="account"><span>02</span><b>계정 만들기</b><small>아이디와 비밀번호</small></button><i></i><button type="button" data-signup-stage="confirm"><span>03</span><b>최종 확인</b><small>입력 정보 검토</small></button></div><section class="signup-stage is-active" data-signup-panel="profile"><div class="signup-stage-copy"><span class="eyebrow">STEP 01 · PROFILE</span><h2>먼저 학생 정보를<br>알려주세요.</h2><p>과정과 학년은 커리큘럼 추천의 기준이 되며 프로필에서 언제든 수정할 수 있습니다.</p><div class="signup-summary"><span><b>필수</b> 이름 · 과정 · 학년 · 학교</span><span><b>선택</b> 고등 과정의 과목</span></div></div><div class="signup-form"><div class="account-fields two"><label><span>이름</span><input class="field" value="김학생"></label><label><span>과정</span><select class="field"><option>중학교</option><option>고등학교</option></select></label><label><span>학년</span><select class="field"><option>2학년</option><option>1학년</option><option>3학년</option></select></label><label><span>과목</span><select class="field"><option>수학</option><option>수학Ⅰ</option><option>미적분</option></select></label><label class="is-wide"><span>학교</span><div class="field-with-action"><input class="field" value="AIFlow 중학교"><button type="button">학교 찾기</button></div><small>학교명을 입력하면 자동완성 결과를 확인합니다.</small></label></div><button class="account-primary" type="button" data-signup-next="account">계정 정보 입력하기 →</button></div></section><section class="signup-stage" data-signup-panel="account" hidden><div class="signup-stage-copy"><span class="eyebrow">STEP 02 · ACCOUNT</span><h2>사용할 계정을<br>만들어 주세요.</h2><p>각 단계가 확인되어야 다음 입력이 열립니다.</p><div class="signup-rules"><span>아이디 <b>영문·숫자 4–16자</b></span><span>비밀번호 <b>영문+숫자 8–20자</b></span><span>이메일 <b>선택 입력</b></span></div></div><div class="signup-form"><div class="account-fields"><label><span>아이디</span><div class="field-with-action"><input class="field" value="student01"><button type="button" data-action="username-check">중복 확인</button></div><small class="is-success">사용 가능한 형식입니다.</small></label><label><span>비밀번호</span><input class="field" type="password" value="password123"><small>영문과 숫자를 모두 포함해 주세요.</small></label><label><span>이메일 <em>선택</em></span><input class="field" value="student@example.com"></label></div><button class="account-primary" type="button" data-signup-next="confirm">입력 정보 확인하기 →</button></div></section><section class="signup-stage" data-signup-panel="confirm" hidden><div class="signup-stage-copy"><span class="eyebrow">STEP 03 · CONFIRM</span><h2>이 정보로<br>시작할게요.</h2><p>가입 완료 후 JWT가 저장되고 학생 홈으로 이동합니다.</p></div><div class="signup-form"><div class="signup-confirm-list"><span><small>학생</small><b>김학생</b></span><span><small>학습 과정</small><b>중학교 2학년 · 수학</b></span><span><small>학교</small><b>AIFlow 중학교</b></span><span><small>아이디</small><b>student01</b></span><span><small>이메일</small><b>student@example.com</b></span></div><label class="signup-agree"><input type="checkbox" checked> 입력 정보와 서비스 이용 안내를 확인했습니다.</label><button class="account-primary" type="button" data-action="register">가입하고 학습 시작하기</button><button class="button soft" type="button" data-signup-next="account">이전 단계 수정</button></div></section>${ledger('signup')}</section>`;
}

// 필요 변수: /auth/me 프로필, OVR 표시, 수정 필드, 새 비밀번호 확인, 교재 보기 모드와 삭제 비밀번호.
// 작동 원리: 조회된 계정 정보를 학습 정체성과 수정 폼으로 분리하고 저장·로그아웃·계정 삭제의 위험도를 명확히 구분한다.
function renderProfile() {
  return `<section class="page account-page profile-page">${pageHead('MY ACCOUNT', '프로필', '학습 정보와 계정 정보를 확인하고 필요한 항목만 수정합니다.', button('설정', '', 'soft', 'settings'))}<section class="profile-identity"><div class="profile-avatar-large">김</div><div><span class="eyebrow">STUDENT PROFILE</span><h2>김학생</h2><p>@student01 · AIFlow 중학교 2학년</p><div class="profile-tags"><span>중학교 과정</span><span>수학</span><span>가입 상태 정상</span></div></div><aside><span><small>현재 OVR</small><b>18.6</b></span><span><small>티어</small><b>B</b></span><span><small>누적 풀이</small><b>128</b></span></aside></section><div class="profile-layout"><main><section class="card account-section"><div class="account-section-head"><div><span class="eyebrow">LEARNING PROFILE</span><h2>학생 정보</h2><p>코스 추천과 학습 분석에 사용하는 정보입니다.</p></div><span class="pill">GET /auth/me</span></div><div class="account-fields two"><label><span>이름</span><input class="field" value="김학생"></label><label><span>아이디</span><input class="field" value="student01"></label><label><span>과정</span><input class="field" value="중학교"></label><label><span>학년</span><input class="field" value="2학년"></label><label><span>과목</span><input class="field" value="수학"></label><label><span>학교</span><input class="field" value="AIFlow 중학교"></label><label class="is-wide"><span>이메일</span><input class="field" value="student@example.com"></label></div></section><section class="card account-section"><div class="account-section-head"><div><span class="eyebrow">SECURITY</span><h2>비밀번호 변경</h2><p>변경하지 않으려면 두 입력란을 비워두세요.</p></div></div><div class="account-fields two"><label><span>새 비밀번호</span><input class="field" type="password" placeholder="8–20자 영문+숫자"></label><label><span>새 비밀번호 확인</span><input class="field" type="password" placeholder="한 번 더 입력"></label></div></section><button class="account-primary profile-save" type="button" data-action="save-profile">변경사항 저장</button></main><aside class="profile-side"><section class="card account-section"><span class="eyebrow">READER</span><h2>교재 보기</h2><p>교재를 PDF형 페이지 단위로 표시합니다.</p><button class="setting-switch is-on" type="button" role="switch" aria-checked="true" data-setting-toggle><span></span><b>페이지 보기 켜짐</b></button></section><section class="card profile-session"><span class="eyebrow">SESSION</span><h2>로그인 상태</h2><p>이 기기의 JWT와 사용자명을 삭제하고 로그아웃합니다.</p><button class="button soft" type="button" data-nav="auth">로그아웃</button></section><section class="card danger-zone"><span class="eyebrow">DANGER ZONE</span><h2>계정 삭제</h2><p>현재 비밀번호 확인 후 계정과 로그인 정보를 삭제합니다. 되돌릴 수 없습니다.</p><button type="button" data-action="profile-delete">계정 삭제</button></section></aside></div>${ledger('profile')}</section>`;
}

// 필요 변수: 전체 알림 여부, 교재 페이지 모드와 앱 라이선스 정보.
// 작동 원리: 실제 로컬 저장 항목 두 개만 즉시 토글하고 라이선스는 Flutter 라이선스 화면으로 연결한다.
function renderSettings() {
  return `<section class="page account-page settings-page">${pageHead('PREFERENCES', '설정', '실제로 저장되는 학습 환경만 간결하게 조정합니다.', button('프로필로 돌아가기', '', 'soft', 'profile'))}<section class="settings-intro"><span class="feature-icon">⚙</span><div><span class="eyebrow">LOCAL PREFERENCES</span><h2>이 기기의 학습 환경</h2><p>변경 내용은 즉시 UTF-8 기반 로컬 설정에 저장됩니다.</p></div><span class="pill">자동 저장</span></section><div class="settings-layout"><main><section class="settings-group"><header><span>01</span><div><h2>교재 보기</h2><p>본문을 연속 스크롤 또는 PDF형 페이지로 봅니다.</p></div></header><button class="setting-row" type="button" data-setting-toggle role="switch" aria-checked="false"><span class="setting-row-icon">▧</span><span><b>PDF형 페이지 보기</b><small data-setting-state>현재 연속 스크롤로 열립니다.</small></span><i><em></em></i></button></section><section class="settings-group"><header><span>02</span><div><h2>알림</h2><p>앱의 모든 알림을 한 번에 켜거나 끕니다.</p></div></header><button class="setting-row is-on" type="button" data-setting-toggle role="switch" aria-checked="true"><span class="setting-row-icon">◌</span><span><b>모든 알림</b><small data-setting-state>현재 모든 알림이 켜져 있습니다.</small></span><i><em></em></i></button><p class="settings-footnote">세부 알림 항목은 현재 구현되어 있지 않습니다.</p></section><section class="settings-group"><header><span>03</span><div><h2>앱 정보</h2><p>AIFlow에 포함된 오픈소스 라이선스를 확인합니다.</p></div></header><button class="setting-link" type="button" data-action="licenses"><span class="setting-row-icon">≡</span><span><b>오픈소스 라이선스</b><small>AIFlow 1.0.0 · Flutter 패키지 정보</small></span><strong>›</strong></button></section></main><aside class="settings-storage-card"><span class="eyebrow">STORAGE CONTRACT</span><h2>서버 요청 없이<br>바로 저장돼요.</h2><code>settings.notifications_enabled</code><code>textbook_reader.page_mode</code><p>설정 화면에서는 /user/storage API를 호출하지 않습니다.</p></aside></div>${ledger('settings')}</section>`;
}

// 필요 변수: 학원 소속, 오늘 출석, 과제, 시간표, 제출·보고서·스냅샷 상태.
// 작동 원리: 기능 목록을 반복 카드로 나열하지 않고 학생이 오늘 처리할 학원 일정과 과제를 먼저 보여주며 나머지 기능은 간결한 상태 행으로 연결한다.
function renderAcademy() {
  return `<section class="page academy-page">${pageHead('ACADEMY', '학원', '오늘 수업과 과제를 한곳에서 확인합니다.', button('학원 정보', 'academy-info', 'soft'))}<section class="academy-context"><span class="academy-mark">A</span><div><span class="eyebrow">AIFLOW MATH ACADEMY</span><h2>AIFlow 수학학원</h2><p>중2 심화반 · 담당 김선생</p></div><div class="academy-context__status"><span><small>오늘 출석</small><b>출석 완료</b></span><span><small>다음 수업</small><b>목 19:30</b></span><span><small>남은 과제</small><b>2개</b></span></div></section><div class="academy-layout"><main class="academy-tasks"><div class="section-title"><div><span class="eyebrow">TODAY</span><h2>오늘 할 일</h2></div><span class="pill">2개 남음</span></div><div class="academy-task-list"><button type="button" data-nav="solve"><span class="academy-task-time">22:00</span><span><b>일차함수 12문제</b><small>과제 · 진행 4/12 · 오늘 마감</small></span><em>이어하기 ›</em></button><button type="button" data-nav="textbook-reader"><span class="academy-task-time">수업 전</span><span><b>교재 3장 읽기</b><small>최소 학습 8분 · 미시작</small></span><em>시작 ›</em></button><button class="is-done" type="button" data-action="attendance-detail"><span class="academy-task-time">18:54</span><span><b>출석 확인</b><small>학원 입실이 기록되었습니다.</small></span><em>완료</em></button></div></main><aside class="academy-timetable"><div class="section-title"><div><span class="eyebrow">TIMETABLE</span><h2>이번 주 수업</h2></div>${button('전체 시간표', 'academy-timetable', 'soft')}</div><div class="academy-class-list"><span><i>화</i><b>함수 심화</b><small>19:30–21:00 · 301호</small></span><span class="is-next"><i>목</i><b>문제 풀이</b><small>19:30–21:00 · 301호</small></span></div></aside></div><section class="academy-records"><button type="button" data-action="academy-submissions"><span>▤</span><b>제출 기록</b><small>최근 제출 4개</small><i>›</i></button><button type="button" data-action="academy-report"><span>⌁</span><b>학습 보고서</b><small>이번 달 1개</small><i>›</i></button><button type="button" data-action="academy-snapshot"><span>◉</span><b>학습 스냅샷</b><small>최근 업데이트 오늘</small><i>›</i></button><button type="button" data-action="academy-groups"><span>◎</span><b>학원 그룹</b><small>가입 그룹 2개</small><i>›</i></button></section>${ledger('academy')}</section>`;
}

// 필요 변수: 문제·교재 검색 결과, 카테고리와 내 교재 연결 상태.
// 작동 원리: 중복된 검색 버튼과 빠른 필터 카드를 하나의 검색 도구로 합치고 결과 목록을 즉시 노출한다.
function renderMarketplace() {
  const marketItem = (kind, title, meta, action, featured = false) => `<button class="market-item ${featured ? 'is-featured' : ''}" type="button" data-nav="${action}"><span class="market-item__icon">${kind === '문제' ? '✎' : '▧'}</span><span><small>${kind}</small><b>${title}</b><em>${meta}</em></span><strong>보기 ›</strong></button>`;
  return `<section class="page market-page">${pageHead('COMMUNITY', '마켓', '필요한 문제와 교재를 찾아 내 학습으로 연결합니다.')}<section class="market-search"><div class="course-search-field"><span>⌕</span><input value="" placeholder="문제·교재·태그 검색" aria-label="마켓 검색"><button type="button">검색</button></div><div class="market-filters"><button class="is-selected" type="button">전체</button><button type="button">문제</button><button type="button">교재</button><button type="button">무료</button><button type="button">내 과정</button><button type="button" data-action="market-filter">필터＋</button></div></section><section class="market-results"><div class="section-title"><div><span class="eyebrow">RECOMMENDED</span><h2>중학교 2학년 추천</h2></div><span class="pill">3개</span></div><div class="market-list">${marketItem('문제', '중2 함수 실전 100제', '평점 4.9 · 1,200 P', 'textbooks', true)}${marketItem('교재', '개념이 보이는 그래프', '무료 · 42쪽', 'textbook-reader')}${marketItem('문제', '확률 OX 문제 묶음', '800 P · 30문항', 'solve')}</div></section>${ledger('marketplace')}</section>`;
}

// 필요 변수: 아직 전용 템플릿이 없는 화면 ID.
// 작동 원리: 기능 원장 전체를 카드와 상태 흐름으로 출력해 어떤 화면도 빈 시안으로 남지 않게 한다.
function renderGeneric(id) {
  const meta = screens[id];
  return `<section class="page">${pageHead(meta.group.toUpperCase(), meta.label, `${meta.features.join(', ')} 기능을 보존한 전체 화면 시안입니다.`, button('주요 기능 실행', 'search', 'primary'))}<div class="grid three">${meta.features.map((x, i) => `<article class="card ${i === 0 ? 'dark' : ''}"><span class="eyebrow">${String(i + 1).padStart(2, '0')}</span><h3>${x}</h3><p class="muted small">기존 상태와 연결 계약을 유지합니다.</p></article>`).join('')}</div>${ledger(id)}</section>`;
}

// 필요 변수: 화면 ID.
// 작동 원리: 화면 성격에 맞는 전용 렌더러를 선택하고 나머지는 기능 원장 기반 템플릿으로 완성한다.
function renderScreen(id) {
  const kind = screens[id]?.kind;
  if (!kind) return renderDashboard();
  if (kind === 'dashboard') return renderDashboard();
  if (kind === 'courses') return renderCourses();
  if (kind === 'courseDetail') return renderCourseDetail();
  if (kind === 'learning') return renderLearning();
  if (kind === 'solve') return renderSolve();
  if (kind === 'exam') return renderExam();
  if (kind === 'level') return renderLevelTest();
  if (kind === 'report') return renderReport(id);
  if (kind === 'list' && id === 'wrong-answers') return renderReview();
  if (kind === 'textbooks') return renderBookbag();
  if (kind === 'friends') return renderSocialHub();
  if (kind === 'groups') return renderGroups();
  if (kind === 'market') return renderMarketplace();
  if (kind === 'schedule') return renderSchedule();
  if (kind === 'arena') return renderArena();
  if (kind === 'group') return renderGroupSpace();
  if (kind === 'chat') return renderChat(id);
  if (kind === 'reader') return renderReader();
  if (['tools', 'graph', 'flow'].includes(kind)) return renderTools(id);
  if (kind === 'profile') return renderProfile();
  if (kind === 'settings') return renderSettings();
  if (kind === 'academy') return renderAcademy();
  if (kind === 'auth') return renderLogin();
  if (kind === 'signup') return renderSignup();
  return renderGeneric(id);
}

// 필요 변수: 학생이 직접 진입할 핵심 화면과 상세 화면의 상위 메뉴 대응 관계.
// 작동 원리: 검수용 전체 화면 원장 대신 실제 사용자 메뉴만 표시하고 하위 화면에서는 상위 메뉴를 활성화한다.
function renderNavigation() {
  const navigationGroups = [
    ['오늘', ['dashboard', 'schedule']],
    ['학습', ['courses', 'textbooks', 'solve', 'wrong-answers', 'level-test']],
    ['경쟁', ['arena']],
    ['커뮤니티', ['friends', 'groups', 'academy', 'marketplace']],
    ['도구·설정', ['tools', 'graph', 'settings']],
  ];
  const activeParents = {
    courses: ['course-detail', 'course-learning'],
    textbooks: ['textbook-reader', 'exam-paper'],
    solve: ['flow'],
    friends: ['chat'],
    groups: ['group-detail'],
    tools: [],
  };
  const isNavActive = (id) => id === activeScreen || (activeParents[id] || []).includes(activeScreen);
  const resume = '<button class="sidebar-resume" type="button" data-nav="course-learning"><span>▶</span><span><small>이어 학습</small><b>일차함수 완성</b><em>진행률 42%</em></span><i>›</i></button>';
  primaryNav.innerHTML = resume + navigationGroups.map(([group, ids]) => `<section class="nav-group"><span class="nav-group__label">${group}</span>${ids.filter((id) => screens[id]).map((id) => { const item = screens[id]; return `<button class="nav-item ${isNavActive(id) ? 'is-active' : ''}" type="button" data-nav="${id}"><span class="nav-icon">${item.icon}</span><span class="nav-label">${item.label}</span>${item.badge ? `<span class="nav-badge">${item.badge}</span>` : ''}</button>`; }).join('')}</section>`).join('');
  const mobileItems = [['dashboard', '홈'], ['courses', '코스'], ['textbooks', '책가방'], ['arena', '대결'], ['friends', '소셜']];
  mobileNav.innerHTML = mobileItems.map(([id, label]) => `<button class="${isNavActive(id) ? 'is-active' : ''}" type="button" data-nav="${id}"><span>${screens[id].icon}</span><span>${label}</span></button>`).join('');
  document.querySelectorAll('.top-tabs [data-nav]').forEach((item) => {
    const target = item.dataset.nav;
    const active = target === activeScreen || (target === 'courses' && ['course-detail', 'course-learning'].includes(activeScreen)) || (target === 'textbooks' && activeScreen === 'textbook-reader') || (target === 'friends' && ['chat', 'groups', 'group-detail'].includes(activeScreen));
    item.classList.toggle('is-active', active);
  });
}

// 필요 변수: 이동할 화면 ID.
// 작동 원리: 네트워크나 Flutter 라우트를 호출하지 않고 DOM만 교체해 전체 시안을 탐색한다.
function navigate(id) {
  if (!screens[id]) return;
  activeScreen = id;
  document.body.dataset.screen = id;
  document.body.classList.toggle('is-exam-mode', id === 'exam-paper');
  document.body.classList.toggle('is-solve-mode', id === 'solve');
  document.body.classList.toggle('is-reader-mode', id === 'textbook-reader');
  screenHost.innerHTML = renderScreen(id);
  if (id === 'flow') {
    const heading = screenHost.querySelector('.page-head h1');
    const description = screenHost.querySelector('.page-head p');
    const workspace = screenHost.querySelector('.flow-workspace');
    if (heading) heading.textContent = 'Flow 분석';
    if (description) description.textContent = '제출 결과를 짧게 확인한 뒤 기존 분기형 Flow에서 틀린 단계와 정답 풀이를 분석합니다.';
    workspace?.insertAdjacentHTML('afterend', flowAnalysisSummary());
  }
  renderNavigation();
  closePanel();
  closeMenu();
  window.scrollTo(0, 0);
  mainStage.focus({ preventScroll: true });
  const flowViewport = document.querySelector('.flow-viewport');
  if (flowViewport) requestAnimationFrame(() => { flowViewport.scrollLeft = Math.max(0, (flowViewport.scrollWidth - flowViewport.clientWidth) / 2); });
}

// 필요 변수: 액션 ID.
// 작동 원리: 실제 요청을 보내지 않고 입력 예시와 보존해야 할 API 계약만 우측/전체 패널에 표시한다.
function openPanel(id) {
  const action = actions[id] || { title: '기능 미리보기', kicker: 'PROTOTYPE', description: '이 버튼은 HTML 시안에서만 동작합니다.', contract: '실제 API 호출 없음' };
  actionTitle.textContent = action.title;
  actionKicker.textContent = action.kicker;
  const studyModes = [
    ['↺', '이어하기', '마지막 학습 위치', 'course-learning'],
    ['▦', '코스보기', '코스 탐색과 상세', 'courses'],
    ['✓', '복습', '오답과 약점 태그', 'wrong-answers'],
    ['✎', '문제풀기', '문제 유형 선택 후 풀이', 'solve'],
    ['▤', '시험', '시험지 선택 후 시작', 'exam-paper'],
    ['▧', '교재보기', '책가방에서 교재 선택', 'textbooks'],
  ];
  const modeBody = `<section class="action-section"><p>${action.description}</p></section><div class="study-mode-grid">${studyModes.map(([icon, title, copy, nav]) => `<button class="study-mode-card" type="button" data-nav="${nav}"><span class="feature-icon">${icon}</span><span><b>${title}</b><small>${copy}</small></span><span>›</span></button>`).join('')}</div>`;
  const homeModalBody = `<section class="action-section"><p>${action.description}</p></section><section class="action-section">${action.body}</section><section class="action-section"><h3>보존 연결 계약</h3><div class="endpoint-ledger">${action.contract}</div><p>HTML 시안에서는 저장·API·활동 기록을 실행하지 않습니다.</p></section>`;
  const isHomeModal = id === 'study-mode' || Boolean(action.body);
  actionBody.innerHTML = id === 'study-mode' ? modeBody : action.body ? homeModalBody : `<section class="action-section"><h3>작동 원리</h3><p>${action.description}</p></section>${action.fields ? `<section class="action-section"><h3>필요 변수</h3><div class="action-fields">${action.fields.map(([label, value]) => `<label>${label}<input class="field" value="${value}"></label>`).join('')}</div></section>` : ''}<section class="action-section"><h3>보존 연결 계약</h3><div class="endpoint-ledger">${action.contract}</div></section><section class="action-section"><p>이 시안에서는 내부 API, 인증, 저장, WebSocket, 다운로드를 실행하지 않습니다.</p></section>`;
  actionFooter.innerHTML = isHomeModal ? `<button class="button soft" type="button" data-close-panel>닫기</button>` : `${button('취소', '', 'soft')}<button class="button primary" type="button" data-prototype-confirm>시안에서 확인</button>`;
  actionPanel.classList.add('is-open');
  actionPanel.setAttribute('aria-hidden', 'false');
  scrim.hidden = false;
}

// 필요 변수: 없음.
// 작동 원리: 열린 작업 패널과 배경 가림막을 함께 닫아 포커스 방해를 제거한다.
function closePanel() {
  actionPanel.classList.remove('is-open');
  actionPanel.setAttribute('aria-hidden', 'true');
  if (!document.querySelector('.sidebar.is-open')) scrim.hidden = true;
}

// 필요 변수: 없음.
// 작동 원리: 기존 Flutter AppDrawer처럼 전체 메뉴를 화면 왼쪽에서 열고 배경 상호작용을 잠근다.
function openMenu() {
  document.querySelector('.sidebar')?.classList.add('is-open');
  scrim.hidden = false;
}

// 필요 변수: 없음.
// 작동 원리: 드로어를 닫고 다른 모달이 없을 때만 공용 배경 가림막을 제거한다.
function closeMenu() {
  document.querySelector('.sidebar')?.classList.remove('is-open');
  if (!actionPanel.classList.contains('is-open')) scrim.hidden = true;
}

// 필요 변수: 이동할 시험지 페이지 번호와 전체 페이지 수.
// 작동 원리: 썸네일 선택과 이전·다음 버튼의 표시 상태만 갱신해 실제 캔버스의 setCurrentPage 흐름을 시각적으로 재현한다.
function selectExamPage(page) {
  const safePage = Math.min(5, Math.max(1, Number(page) || 1));
  document.querySelectorAll('[data-exam-page]').forEach((item) => item.classList.toggle('is-selected', Number(item.dataset.examPage) === safePage));
  const count = document.getElementById('examPageCount');
  if (count) count.textContent = `${safePage} / 5`;
  const mobileCount = document.querySelector('.exam-mobile-pages span');
  if (mobileCount) mobileCount.textContent = `${safePage} / 5`;
}

// 필요 변수: 확대·축소·맞춤 액션과 현재 퍼센트 표시.
// 작동 원리: 원본 0.5~2.0 범위 안에서 10% 단위로 표시값을 바꾸며 캔버스 자체 좌표나 종이 비율은 왜곡하지 않는다.
function adjustExamZoom(action) {
  const value = document.getElementById('examZoomValue');
  if (!value) return;
  const current = Number(value.textContent.replace('%', '')) || 100;
  const next = action === 'reset' ? 100 : Math.min(200, Math.max(50, current + (action === 'in' ? 10 : -10)));
  value.textContent = `${next}%`;
}

// 필요 변수: 페이지 이동 방향과 현재 교재 페이지 표시 요소.
// 작동 원리: API 호출 없이 1~18쪽 범위에서 원본 이전·다음 페이지 조작과 목차의 현재 위치 표시를 함께 갱신한다.
function adjustReaderPage(direction) {
  const counter = document.getElementById('readerPageCount');
  const bottom = document.getElementById('readerBottomPage');
  if (!counter) return;
  const current = Number(counter.textContent.split('/')[0]) || 6;
  const next = Math.min(18, Math.max(1, current + direction));
  counter.textContent = `${next} / 18`;
  if (bottom) bottom.textContent = String(next);
}

// 필요 변수: 선택된 풀이 노드의 단계·요약·힌트·정답 풀이 data 속성.
// 작동 원리: 네트워크 요청 없이 선택 테두리와 우측 노드 상세만 갱신해 기존 FlowViewPage의 노드 선택 방식을 재현한다.
function selectFlowNode(node) {
  document.querySelectorAll('[data-flow-node]').forEach((item) => item.classList.toggle('is-selected', item === node));
  const detail = document.getElementById('flowNodeDetail');
  if (!detail) return;
  const state = node.classList.contains('is-correct') ? '정답' : node.classList.contains('is-wrong') ? '오답' : '이후 단계';
  detail.innerHTML = `<span class="eyebrow">${node.dataset.flowStep} · ${state}</span><h3>${node.dataset.flowSummary}</h3><div class="flow-detail-row"><small>노드 요약</small><p>${node.querySelector('small')?.textContent || '-'}</p></div><div class="flow-detail-row"><small>개념 태그</small><div class="feature-ledger"><span class="pill">#일차함수</span><span class="pill">#풀이단계</span></div></div><div class="flow-detail-row"><small>힌트</small><p>${node.dataset.flowHint}</p></div><div class="flow-detail-row"><small>정답 풀이</small><p>${node.dataset.flowSolution}</p></div>`;
}

// 필요 변수: 문서 클릭 이벤트, 일정·대결 방식·문제풀이 도구·화면 이동·기능 실행을 구분하는 data 속성.
// 작동 원리: 일정 탭, 대결 인원과 캔버스 도구 상태를 먼저 갱신한 뒤 화면 이동과 기능 패널을 위임 처리한다.
document.addEventListener('click', (event) => {
  const signupStep = event.target.closest('[data-signup-stage], [data-signup-next]');
  if (signupStep) {
    const stage = signupStep.dataset.signupStage || signupStep.dataset.signupNext;
    const order = ['profile', 'account', 'confirm'];
    const activeIndex = order.indexOf(stage);
    document.querySelectorAll('[data-signup-stage]').forEach((item) => {
      const itemIndex = order.indexOf(item.dataset.signupStage);
      item.classList.toggle('is-active', itemIndex === activeIndex);
      item.classList.toggle('is-done', itemIndex < activeIndex);
    });
    document.querySelectorAll('[data-signup-panel]').forEach((panel) => {
      const isSelected = panel.dataset.signupPanel === stage;
      panel.classList.toggle('is-active', isSelected);
      panel.hidden = !isSelected;
    });
  }
  const settingToggle = event.target.closest('[data-setting-toggle]');
  if (settingToggle) {
    const nextState = settingToggle.getAttribute('aria-checked') !== 'true';
    settingToggle.setAttribute('aria-checked', String(nextState));
    settingToggle.classList.toggle('is-on', nextState);
    const state = settingToggle.querySelector('[data-setting-state]');
    if (state) {
      const isNotification = settingToggle.textContent.includes('알림');
      state.textContent = isNotification
        ? `현재 모든 알림이 ${nextState ? '켜져' : '꺼져'} 있습니다.`
        : `현재 ${nextState ? 'PDF형 페이지' : '연속 스크롤'}로 열립니다.`;
    }
    const label = settingToggle.querySelector('b');
    if (label && settingToggle.classList.contains('setting-switch')) label.textContent = `페이지 보기 ${nextState ? '켜짐' : '꺼짐'}`;
  }
  const notepadTool = event.target.closest('.notepad-rail button:not(.is-danger)');
  if (notepadTool) {
    const exclusiveTools = [...document.querySelectorAll('.notepad-rail button')].slice(1, 5);
    if (exclusiveTools.includes(notepadTool)) exclusiveTools.forEach((item) => item.classList.toggle('is-selected', item === notepadTool));
    else notepadTool.classList.toggle('is-selected');
  }
  const timerMode = event.target.closest('[data-timer-mode]');
  if (timerMode) {
    const isTimer = timerMode.dataset.timerMode === 'timer';
    document.querySelectorAll('[data-timer-mode]').forEach((item) => item.classList.toggle('is-selected', item === timerMode));
    document.querySelector('[data-timer-setup]')?.toggleAttribute('hidden', !isTimer);
    const modeLabel = document.getElementById('timerModeLabel');
    const display = document.getElementById('timerDisplayValue');
    const copy = document.getElementById('timerModeCopy');
    const thirdAction = document.getElementById('timerThirdAction');
    if (modeLabel) modeLabel.textContent = isTimer ? '남은 시간' : '경과 시간';
    if (display) display.textContent = isTimer ? '25:00' : '00:00';
    if (copy) copy.textContent = isTimer ? '입력값이나 프리셋으로 시간을 빠르게 맞출 수 있습니다.' : '필요할 때 랩을 찍어 구간 시간을 확인합니다.';
    if (thirdAction) {
      thirdAction.textContent = isTimer ? '＋ +5분' : '⚑ 랩 추가';
      thirdAction.toggleAttribute('disabled', !isTimer);
    }
  }
  const focusPreset = event.target.closest('[data-focus-minutes]');
  if (focusPreset) {
    const minutes = Number(focusPreset.dataset.focusMinutes) || 60;
    document.querySelectorAll('[data-focus-minutes]').forEach((item) => item.classList.toggle('is-selected', item === focusPreset));
    const range = document.querySelector('[data-focus-range]');
    if (range) range.value = String(minutes);
    const label = document.getElementById('focusSelectedTime');
    if (label) label.textContent = minutes >= 60 ? `${minutes / 60}시간` : `${minutes}분`;
  }
  if (event.target.closest('[data-focus-start]')) {
    document.querySelector('[data-focus-setup]')?.setAttribute('hidden', '');
    document.querySelector('[data-focus-running]')?.removeAttribute('hidden');
  }
  const focusUnlock = event.target.closest('[data-focus-unlock]');
  if (focusUnlock) {
    focusUnlock.textContent = '3 · 잠금 해제 중';
    focusUnlock.classList.add('is-counting');
  }
  const reviewFilter = event.target.closest('[data-review-filter]');
  if (reviewFilter) {
    document.querySelectorAll('.review-filters [data-review-filter]').forEach((item) => item.classList.toggle('is-active', item.dataset.reviewFilter === reviewFilter.dataset.reviewFilter));
  }
  const scheduleView = event.target.closest('[data-schedule-view]');
  if (scheduleView) {
    const selectedView = scheduleView.dataset.scheduleView;
    document.querySelectorAll('[data-schedule-view]').forEach((item) => {
      const isSelected = item.dataset.scheduleView === selectedView;
      item.classList.toggle('is-active', isSelected);
      item.setAttribute('aria-selected', String(isSelected));
    });
    document.querySelectorAll('[data-schedule-panel]').forEach((panel) => {
      const isSelected = panel.dataset.schedulePanel === selectedView;
      panel.classList.toggle('is-active', isSelected);
      panel.hidden = !isSelected;
    });
  }
  const arenaMode = event.target.closest('[data-arena-mode]');
  if (arenaMode) {
    const selectedMode = arenaMode.dataset.arenaMode;
    document.querySelectorAll('[data-arena-mode]').forEach((item) => {
      const isSelected = item.dataset.arenaMode === selectedMode;
      item.classList.toggle('is-active', isSelected);
      item.setAttribute('aria-selected', String(isSelected));
    });
    document.querySelectorAll('[data-arena-panel]').forEach((panel) => {
      const isSelected = panel.dataset.arenaPanel === selectedMode;
      panel.classList.toggle('is-active', isSelected);
      panel.hidden = !isSelected;
    });
  }
  const solveTool = event.target.closest('[data-solve-tool]');
  if (solveTool) {
    const tool = solveTool.dataset.solveTool;
    if (tool === 'pen' || tool === 'eraser') {
      document.querySelectorAll('[data-solve-tool="pen"], [data-solve-tool="eraser"]').forEach((item) => item.classList.toggle('is-selected', item === solveTool));
    }
    if (tool === 'lines') {
      solveTool.classList.toggle('is-selected');
      document.querySelector('[data-solve-canvas]')?.classList.toggle('has-lines');
    }
    if (tool === 'clear') document.querySelector('.solve-ink')?.classList.add('is-cleared');
    if (tool === 'undo') document.querySelector('.solve-ink')?.classList.remove('is-cleared');
    if (tool === 'expand') document.querySelector('[data-solve-canvas]')?.classList.toggle('is-expanded');
  }
  const solveChoice = event.target.closest('[data-solve-choice]');
  if (solveChoice) {
    document.querySelectorAll('[data-solve-choice]').forEach((item) => item.classList.toggle('is-selected', item === solveChoice));
  }
  const action = event.target.closest('[data-action]');
  const nav = event.target.closest('[data-nav]');
  if (nav && !action) navigate(nav.dataset.nav);
  if (action) openPanel(action.dataset.action);
  if (event.target.closest('[data-close-panel]') || event.target.closest('[data-prototype-confirm]') || (event.target.closest('.action-panel footer .soft'))) closePanel();
  if (event.target.closest('[data-toggle-menu]')) openMenu();
  if (event.target.closest('[data-close-menu]')) closeMenu();
  if (event.target.closest('[data-dismiss-note]')) document.getElementById('prototypeNote')?.remove();
  const flowNode = event.target.closest('[data-flow-node]');
  if (flowNode) selectFlowNode(flowNode);
  const examOption = event.target.closest('[data-exam-option]');
  if (examOption) examOption.classList.toggle('is-selected');
  const examTool = event.target.closest('[data-exam-tool]');
  if (examTool && ['pen', 'eraser', 'pan'].includes(examTool.dataset.examTool)) {
    document.querySelectorAll('[data-exam-tool="pen"], [data-exam-tool="eraser"], [data-exam-tool="pan"]').forEach((item) => item.classList.toggle('is-selected', item === examTool));
  }
  const examPage = event.target.closest('[data-exam-page]');
  if (examPage) selectExamPage(examPage.dataset.examPage);
  if (event.target.closest('[data-exam-prev]')) selectExamPage((Number(document.getElementById('examPageCount')?.textContent.split('/')[0]) || 1) - 1);
  if (event.target.closest('[data-exam-next]')) selectExamPage((Number(document.getElementById('examPageCount')?.textContent.split('/')[0]) || 1) + 1);
  const examZoom = event.target.closest('[data-exam-zoom]');
  if (examZoom) adjustExamZoom(examZoom.dataset.examZoom);
  const courseFilter = event.target.closest('[data-course-filter]');
  if (courseFilter) {
    document.querySelectorAll('[data-course-filter]').forEach((item) => item.classList.toggle('is-selected', item === courseFilter));
  }
  const courseUnit = event.target.closest('[data-course-unit]');
  if (courseUnit) {
    const unit = courseUnit.closest('.learning-unit');
    const missions = unit?.querySelector('.learning-missions');
    const isExpanded = !unit?.classList.contains('is-expanded');
    unit?.classList.toggle('is-expanded', isExpanded);
    courseUnit.setAttribute('aria-expanded', String(isExpanded));
    if (missions) missions.hidden = !isExpanded;
  }
  const groupTab = event.target.closest('[data-group-tab]');
  if (groupTab) {
    const selectedTab = groupTab.dataset.groupTab;
    document.querySelectorAll('[data-group-tab]').forEach((item) => item.classList.toggle('is-active', item === groupTab));
    document.querySelectorAll('[data-group-panel]').forEach((panel) => {
      const isSelected = panel.dataset.groupPanel === selectedTab;
      panel.classList.toggle('is-active', isSelected);
      panel.hidden = !isSelected;
    });
  }
  const readerView = event.target.closest('[data-reader-view]');
  if (readerView) {
    document.querySelectorAll('[data-reader-view]').forEach((item) => item.classList.toggle('is-selected', item === readerView));
    document.querySelector('.reader-page')?.classList.toggle('is-scroll-view', readerView.dataset.readerView === 'scroll');
  }
  const readerTool = event.target.closest('[data-reader-tool]');
  if (readerTool) {
    if (readerTool.dataset.readerTool === 'bookmark') {
      document.querySelectorAll('[data-reader-tool="bookmark"]').forEach((item) => item.classList.toggle('is-selected'));
    } else if (['pen', 'highlight', 'eraser'].includes(readerTool.dataset.readerTool)) {
      document.querySelectorAll('[data-reader-tool="pen"], [data-reader-tool="highlight"], [data-reader-tool="eraser"]').forEach((item) => item.classList.toggle('is-selected', item === readerTool));
    }
  }
  if (event.target.closest('[data-reader-collapse]')) document.querySelector('.reader-shell')?.classList.toggle('is-collapsed');
  const tocEntry = event.target.closest('[data-reader-toc-row]');
  if (tocEntry) document.querySelectorAll('[data-reader-toc-row]').forEach((item) => item.classList.toggle('is-active', item === tocEntry));
  if (event.target.closest('[data-reader-prev]')) adjustReaderPage(-1);
  if (event.target.closest('[data-reader-next]')) adjustReaderPage(1);
  const scrollTarget = event.target.closest('[data-scroll]');
  if (scrollTarget) document.getElementById(scrollTarget.dataset.scroll)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
});

// 필요 변수: 키보드 이벤트.
// 작동 원리: Escape 키로 패널을 닫아 키보드 탐색 흐름을 보존한다.
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closePanel();
});

// 필요 변수: 집중 모드의 30~720분 범위 슬라이더 값.
// 작동 원리: 원본 30분 단위 선택 규칙을 유지하며 현재 선택 시간을 시간·분 문구로 즉시 갱신한다.
document.addEventListener('input', (event) => {
  const range = event.target.closest('[data-focus-range]');
  if (!range) return;
  const minutes = Number(range.value) || 60;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  const label = document.getElementById('focusSelectedTime');
  if (label) label.textContent = hours > 0 ? `${hours}시간${rest ? ` ${rest}분` : ''}` : `${minutes}분`;
  document.querySelectorAll('[data-focus-minutes]').forEach((item) => item.classList.toggle('is-selected', Number(item.dataset.focusMinutes) === minutes));
});

scrim.addEventListener('click', () => {
  closePanel();
  closeMenu();
});

// 필요 변수: URL의 screen 검색 매개변수.
// 작동 원리: 브라우저 검수와 화면 공유 시 특정 화면을 바로 열고 잘못된 값은 학생 홈으로 되돌린다.
const requestedScreen = new URLSearchParams(window.location.search).get('screen');
navigate(requestedScreen && screens[requestedScreen] ? requestedScreen : 'dashboard');

// 필요 변수: URL의 action 검색 매개변수.
// 작동 원리: 검수 링크에서 기존 모달형 빠른 기능을 바로 열어 PC·모바일 렌더를 확인한다.
const requestedAction = new URLSearchParams(window.location.search).get('action');
if (requestedAction && actions[requestedAction]) openPanel(requestedAction);

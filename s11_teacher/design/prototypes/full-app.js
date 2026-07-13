'use strict';

const appFrame = document.getElementById('appFrame');
const screenHost = document.getElementById('screenHost');
const primaryNav = document.getElementById('primaryNav');
const mobileNav = document.getElementById('mobileNav');
const breadcrumbs = document.getElementById('breadcrumbs');
const taskPanel = document.getElementById('taskPanel');
const taskTitle = document.getElementById('taskTitle');
const taskKicker = document.getElementById('taskKicker');
const taskBody = document.getElementById('taskBody');
const taskFoot = document.getElementById('taskFoot');
const scrim = document.getElementById('scrim');

const screenMeta = {
  dashboard: { label: '교사용 홈', group: '시작', icon: '⌂', methods: ['clearToken'] },
  'problem-studio': { label: '문항 제작', group: '제작', icon: '◇', methods: ['getQuestGenerationTagGroups', 'getCourseHashTags', 'listQuestTray', 'searchExamEditorProblems', 'listTeacherDocuments', 'generateVariantFromFlowDraft', 'generateVariantFromPromptNote', 'convertQuestToMcq'] },
  'exam-builder': { label: '빠른 시험지', group: '제작', icon: '▤', methods: ['getQuestGenerationTagGroups', 'createExam', 'getExamStatus', 'examPdfUrl'] },
  'exam-editor': { label: '시험지 편집', group: '제작', icon: '▥', methods: ['searchExamEditorProblems', 'saveExamEditorPaper', 'deployExamEditorPaper', 'getExamStatus', 'examPdfUrl', 'arrangeExamEditorAi'] },
  'course-list': { label: '코스 관리', group: '수업 자료', icon: '▦', methods: ['getCourseHashTags', 'listCoursesV2Page', 'getCourseV2', 'updateCourseV2', 'deleteCourseV2'] },
  'course-builder': { label: '코스 만들기', group: '수업 자료', icon: '＋', methods: ['getCourseHashTags', 'getQuestGenerationTagGroups', 'listTeacherDocuments', 'getCourseV2', 'searchExamEditorProblems', 'createCourseV2', 'updateCourseV2'] },
  'textbook-builder': { label: '교재 작성', group: '수업 자료', icon: '▧', methods: ['createTextbook'] },
  documents: { label: '문서함', group: '수업 자료', icon: '□', methods: ['listTeacherDocuments'] },
  groups: { label: '그룹 관리', group: '학생·학원', icon: '◎', methods: ['listMyStudyGroups', 'createStudyGroup', 'buildStudentInviteUrl'] },
  'group-detail': { label: '그룹 상세', group: '학생·학원', icon: '◉', badge: '12', methods: ['listMyStudyGroups', 'listGroupMembers', 'listStudyGroupMemberProfiles', 'listAcademyGroupMembers', 'listAssignments', 'listGroupNotices', 'buildStudentInviteUrl', 'listCoursesV2', 'listTeacherDocuments', 'createAssignment', 'updateAssignment', 'deleteAssignment', 'upsertGroupNotice', 'deleteGroupNoticeByTitle', 'fetchStudyGroupMessages', 'sendStudyGroupMessage', 'fetchDirectMessages', 'sendDirectMessage', 'fetchStudentAnalysis'] },
  academy: { label: '학원 대시보드', group: '학생·학원', icon: '⌁', methods: ['listAcademyGroupMembers', 'listAttendanceLogs', 'listTuitionPayments', 'listConsultNotes', 'listSnapshots'] },
  operations: { label: '재무·스케줄', group: '학생·학원', icon: '⌑', methods: ['listFinanceEntries', 'financeSummary', 'upsertFinanceEntry', 'deleteFinanceEntry', 'listScheduleEntries', 'upsertScheduleEntry', 'deleteScheduleEntry'] },
  social: { label: '친구', group: '소통·계정', icon: '♧', methods: ['listFriends', 'addFriend', 'removeFriend'] },
  chat: { label: '채팅', group: '소통·계정', icon: '◌', badge: '3', methods: ['fetchDirectMessages', 'sendDirectMessage', 'listCoursesV2'] },
  store: { label: '스토어', group: '소통·계정', icon: '△', methods: ['fetchTeacherStoreSummary', 'topUpTeacherStoreTest', 'purchaseTeacherStoreItem'] },
  profile: { label: '프로필·설정', group: '소통·계정', icon: '○', methods: ['getMyProfile', 'updateMyProfile', 'deleteMyProfile', 'clearToken'] },
  auth: { label: '로그인·가입', group: '소통·계정', icon: '↪', methods: ['isAuthenticated', 'loginTeacher', 'requireToken', 'registerTeacher'] },
};

const featureLedger = {
  auth: ['자동 로그인', '교사 로그인', '교사 가입', '로그인/가입 전환'],
  dashboard: ['코스 생성', '문서함', '코스 관리', '시험지 생성', '문항 제작', '그룹 관리', '학습 분석', '재무제표', '로그아웃'],
  'problem-studio': ['간편/고급 모드', '문항 생성', '객관식 변환', '지시문+노트', '풀이 흐름 캔버스', '노드 태그', '세부 지시', '문제 DB 검색', '문서함 필터', '임시저장함'],
  'exam-builder': ['태그 선택', '시험지 생성', '상태 확인', 'PDF 다운로드', '상세 편집 전환'],
  'exam-editor': ['검색 모드', '문제 담기', '최대 100문항', '순서 변경', '레이아웃 전환', '폰트/간격', '통계', 'AI 배치', '문서함 저장', 'PDF 배포'],
  'course-list': ['공개 필터', '정렬', '태그 필터', '페이지 이동', '노출 전환', '단일/다중 삭제', '편집'],
  'course-builder': ['기본 정보', '난이도/OVR', '모듈 추가', '교재 선택', '시험지 선택', '문항 생성/검색', '오답 복습', '최소 시간', '객관식 자동 구성', 'AI 분석', '저장'],
  'textbook-builder': ['제목/부제', '챕터/섹션', '블록 편집', '슬래시 명령', '미리보기', '저장', '완료 반환'],
  documents: ['교재/시험지 필터', '문서 선택', '태그', '재시도', '미리보기'],
  groups: ['그룹 목록', '그룹 생성', '비밀번호 잠금', '참여코드', 'QR', '그룹 상세 이동'],
  'group-detail': ['멤버', '교사 초대', '코스 배정', '숙제 배정', '공지 CRUD', '과제 수정/삭제', '그룹 채팅', '1:1 채팅', '학생 분석', 'QR'],
  academy: ['출석률', '주간 출석', '수납', '상담', '학생 요약', '약점 태그'],
  operations: ['일간/월간 재무', '수입/지출 저장', '재무 삭제', '스케줄 저장/삭제', '날짜 이동', '기기 캘린더', 'ICS 내보내기'],
  social: ['친구 목록', '친구 추가', '친구 삭제', '1:1 채팅 이동'],
  chat: ['메시지 조회', '메시지 전송', '코스 공유'],
  store: ['잔액/요약', '테스트 충전', '문제/교재/시험지 구매'],
  profile: ['프로필 조회/수정', '설정', '계정 삭제', '로그아웃'],
};

const actionCatalog = {
  'global-search': { title: '전체 검색', kicker: '빠른 이동', fields: [['검색어', '문항, 코스, 교재, 학생 검색']], endpoint: '화면별 검색 API로 위임', confirm: '검색' },
  notifications: { title: '알림', kicker: '최근 활동', body: '<div class="list"><div class="list-item"><div><b>시험지 PDF 생성 완료</b><p>2학기 수학 형성평가</p></div><span class="pill">방금</span></div><div class="list-item"><div><b>새 그룹 참여</b><p>중2 심화반 · 박학생</p></div><span class="pill">12분</span></div></div>', confirm: '확인' },
  'profile-menu': { title: '계정 메뉴', kicker: '김선생', body: '<div class="list"><button class="list-item" data-nav="profile"><b>프로필 수정</b><span>›</span></button><button class="list-item" data-action="logout"><b>로그아웃</b><span>›</span></button></div>' },
  logout: { title: '로그아웃', kicker: '계정', body: '<p>현재 교사 계정의 토큰을 지우고 로그인 화면으로 이동합니다.</p>', endpoint: 'ApiClient.clearToken()', confirm: '로그아웃' },
  'problem-generate': { title: '문항 생성', kicker: '문항 제작', fields: [['생성 방식', '지시문 + 노트'], ['세부 지시', '일차함수의 기울기를 묻는 객관식'], ['난이도', '중']], endpoint: 'POST /quests/variants/from-prompt-note', confirm: '문항 생성' },
  'problem-flow': { title: '풀이 흐름으로 변형', kicker: '고급 제작', fields: [['선택 노드', '식 세우기'], ['노드 태그', '#일차함수 #기울기'], ['세부 지시', '오답 유도 보기를 포함']], endpoint: 'POST /quests/variants/from-flow-draft', confirm: '변형 생성' },
  'problem-convert': { title: '객관식 변환', kicker: '문항 변환', fields: [['보기 수', '5개'], ['정답 위치', '자동 분산']], endpoint: 'POST /quests/variants/convert-mcq', confirm: '변환' },
  'problem-search': { title: '문제 DB 검색', kicker: '검색 조건', fields: [['텍스트', '일차함수'], ['해시태그', '#함수 #중2'], ['기간', '최근 3개월']], endpoint: 'GET /exam-editor/problems/search', confirm: '검색 적용' },
  'exam-create': { title: '빠른 시험지 생성', kicker: '시험지 생성', fields: [['시험지 제목', '2학기 수학 형성평가'], ['해시태그', '#일차함수 #그래프'], ['문항 수', '10']], endpoint: 'POST /exams → GET /exams/{examId} 상태 폴링', confirm: '생성 시작' },
  'exam-save': { title: '문서함 저장', kicker: '시험지 편집', fields: [['제목', '2학기 수학 형성평가'], ['레이아웃', '세로형'], ['문항 수', '10']], endpoint: 'POST /exam-editor/papers', confirm: '저장' },
  'exam-ai': { title: 'AI 자동 배치', kicker: '시험지 편집', fields: [['배치 기준', '난이도 상승'], ['페이지당 문항', '4'], ['기하 문항', '그림 영역 확보']], endpoint: 'POST /exam-editor/arrange/ai', confirm: '자동 배치' },
  'exam-pdf': { title: 'PDF 생성 및 배포', kicker: '시험지 편집', body: '<p>편집본을 배포한 뒤 생성 상태를 폴링하고 완료 시 PDF를 엽니다.</p>', endpoint: 'POST /exam-editor/papers/{paperId}/deploy → GET /exams/{examId} → /exams/{examId}/pdf', confirm: 'PDF 준비' },
  'course-save': { title: '코스 저장', kicker: '코스 빌더', fields: [['제목', '중2 일차함수 완성'], ['공개 상태', '비공개'], ['목표 OVR', '1200']], endpoint: 'POST /courses/v2 또는 PUT /courses/v2/{id}', confirm: '저장' },
  'course-delete': { title: '코스 삭제', kicker: '코스 관리', body: '<p>선택한 코스와 연결 상태를 확인한 뒤 삭제합니다.</p>', endpoint: 'DELETE /courses/v2/{id}', confirm: '삭제' },
  'textbook-save': { title: '교재 저장', kicker: '교재 작성', fields: [['제목', '중2 일차함수 개념서'], ['부제', '개념부터 실전까지']], endpoint: 'POST /textbooks', confirm: '저장' },
  'document-filter': { title: '문서함 필터', kicker: '교사 문서함', fields: [['자료 유형', '교재 + 시험지'], ['태그', '#중2 #함수']], endpoint: 'GET /teacher/documents?type=...', confirm: '적용' },
  'group-create': { title: '새 그룹 만들기', kicker: '그룹 관리', fields: [['그룹명', '중2 심화반'], ['설명', '화·목 집중 수업'], ['참여 방식', '비밀번호 잠금']], endpoint: 'POST /social/study-groups', confirm: '그룹 생성' },
  'group-invite': { title: '학생·교사 초대', kicker: '그룹 상세', body: '<div class="ui-card ui-card--tint"><b>참여코드 AF-24K8</b><p class="muted small">QR과 초대 링크를 함께 제공합니다.</p></div>', endpoint: 'buildStudentInviteUrl(inviteCode)', confirm: '링크 복사' },
  assignment: { title: '코스·숙제 배정', kicker: '그룹 상세', fields: [['대상 학생', '전체 학생 12명'], ['자료', '중2 일차함수 완성'], ['마감', '2026-07-18 22:00']], endpoint: 'POST /academy/assignments', confirm: '배정' },
  notice: { title: '공지 작성', kicker: '그룹 상세', fields: [['제목', '다음 수업 준비물'], ['내용', '교재 42쪽까지 풀어오세요.']], endpoint: 'POST/PUT /social/study-groups/{groupId}/notices', confirm: '공지 저장' },
  'finance-save': { title: '재무 항목 저장', kicker: '재무제표', fields: [['구분', '수입'], ['항목', '7월 수강료'], ['금액', '4,800,000']], endpoint: 'TeacherOperationsStore.upsertFinanceEntry()', confirm: '저장' },
  'schedule-save': { title: '스케줄 저장', kicker: '운영 일정', fields: [['일정', '중2 심화반'], ['시작', '17:00'], ['종료', '18:30']], endpoint: 'TeacherOperationsStore.upsertScheduleEntry()', confirm: '저장' },
  'friend-add': { title: '친구 추가', kicker: '교사 소셜', fields: [['닉네임', '수학쌤민지']], endpoint: 'POST /social/friends/add', confirm: '추가' },
  'message-send': { title: '새 메시지', kicker: '1:1 채팅', fields: [['받는 사람', '수학쌤민지'], ['메시지', '공유드린 코스 확인 부탁드립니다.']], endpoint: 'POST /social/messages', confirm: '전송' },
  'course-share': { title: '코스 공유', kicker: '1:1 채팅', fields: [['공유 코스', '중2 일차함수 완성'], ['메시지', '이 코스를 참고해 보세요.']], endpoint: 'GET /courses/v2?mine_only=true → POST /social/messages', confirm: '공유' },
  'store-topup': { title: '테스트 포인트 충전', kicker: '스토어', fields: [['충전 포인트', '10,000']], endpoint: 'POST /teacher/store/top-up-test', confirm: '충전' },
  purchase: { title: '자료 구매', kicker: '스토어', fields: [['상품', '중2 함수 실전 100제'], ['가격', '2,400 P']], endpoint: 'POST /teacher/store/purchase', confirm: '구매' },
  'profile-save': { title: '프로필 저장', kicker: '계정', fields: [['이름', '김선생'], ['학교/학원', 'AIFlow Academy'], ['담당 과목', '수학']], endpoint: 'PUT /auth/me', confirm: '저장' },
  'account-delete': { title: '계정 삭제', kicker: '주의', body: '<p>현재 프로필과 인증 토큰을 삭제합니다. 이 작업은 되돌릴 수 없습니다.</p>', endpoint: 'DELETE /auth/me → clearToken()', confirm: '계정 삭제' },
  login: { title: '교사 로그인', kicker: '인증', fields: [['아이디', 'teacher@example.com'], ['비밀번호', '••••••••']], endpoint: 'POST /auth/teacher/login → requireToken()', confirm: '로그인' },
  register: { title: '교사 가입', kicker: '인증', fields: [['이메일', 'teacher@example.com'], ['이름', '김선생'], ['비밀번호', '••••••••']], endpoint: 'POST /auth/teacher/register', confirm: '가입' },
};

/**
 * 필요 변수: kicker, title, description, actionsHtml.
 * 작동 원리: 모든 화면의 제목과 주요 액션을 같은 높이·간격으로 조합해 카드가 늘어나거나 눌리는 현상을 막는다.
 */
function pageHead(kicker, title, description, actionsHtml = '') {
  return `<header class="page-head"><div><span class="eyebrow">${kicker}</span><h1>${title}</h1><p class="page-head__copy">${description}</p></div><div class="actions">${actionsHtml}</div></header>`;
}

/**
 * 필요 변수: label, actionId, variant, navigationId.
 * 작동 원리: 액션은 작업 패널을, navigationId가 있으면 실제 시안 화면 전환을 수행하는 공용 버튼을 만든다.
 */
function uiButton(label, actionId = '', variant = '', navigationId = '') {
  const actionAttr = actionId ? `data-action="${actionId}"` : '';
  const navAttr = navigationId ? `data-nav="${navigationId}"` : '';
  return `<button class="ui-button ${variant}" ${actionAttr} ${navAttr}>${label}</button>`;
}

/**
 * 필요 변수: label, value, note.
 * 작동 원리: 대시보드 수치를 동일한 최소 높이와 타이포 계층으로 표시한다.
 */
function metric(label, value, note) {
  return `<article class="ui-card metric-card"><span class="muted small">${label}</span><strong>${value}</strong><span class="muted small">${note}</span></article>`;
}

/**
 * 필요 변수: icon, title, copy, target.
 * 작동 원리: 기능 카드의 비율을 고정하고 전체 카드 클릭을 대상 화면 이동으로 연결한다.
 */
function featureCard(icon, title, copy, target) {
  return `<button class="ui-card feature-card" data-nav="${target}"><span class="feature-card__icon">${icon}</span><span><h3>${title}</h3><p>${copy}</p></span><span>›</span></button>`;
}

/**
 * 필요 변수: screenId.
 * 작동 원리: 화면별 실제 서비스 메서드를 숨기지 않고 하단에 기록해 기능 매핑 검증 근거로 사용한다.
 */
function methodLedger(screenId) {
  const methods = screenMeta[screenId].methods;
  return `<div class="endpoint-box" data-method-ledger="${screenId}"><b>연결 유지 대상</b><br>${methods.join(' · ')}</div>`;
}

const screenTemplates = {
  dashboard: `<section class="page">${pageHead('Teacher Workspace', '오늘 필요한 수업 도구', '자료 제작부터 학생 관리까지 실제 교사용 기능을 한 번에 시작합니다.', uiButton('새 코스', '', 'ui-button--primary', 'course-builder'))}<div class="grid grid--4">${metric('오늘 수업', '4', '다음 수업 17:00')}${metric('미제출 과제', '7', '2개 그룹')}${metric('이번 달 수납', '92%', '48명 중 44명')}${metric('보유 포인트', '12,480P', '스토어 사용 가능')}</div><div class="grid grid--3" style="margin-top:14px">${featureCard('◇', '문항 제작', '생성·변형·DB 검색·객관식 변환', 'problem-studio')}${featureCard('▥', '시험지 제작', '문항 구성·AI 배치·PDF 배포', 'exam-editor')}${featureCard('▦', '코스 관리', '교재·시험지·학습 조건 연결', 'course-list')}${featureCard('□', '교사 문서함', '교재와 시험지 자료만 모아보기', 'documents')}${featureCard('◎', '그룹 관리', '과제·공지·학생 분석·채팅', 'groups')}${featureCard('⌑', '재무·스케줄', '일간/월간 회계와 수업 일정', 'operations')}</div>${methodLedger('dashboard')}</section>`,

  'problem-studio': `<section class="page">${pageHead('Problem Studio', '문항 제작 스튜디오', '간편 생성과 고급 풀이 흐름, 문서함·DB 검색을 기존 기능 그대로 배치했습니다.', uiButton('DB 검색', 'problem-search') + uiButton('문항 생성', 'problem-generate', 'ui-button--primary'))}<div class="studio-layout"><aside class="ui-card studio-panel studio-panel--sticky"><div class="card-head"><h2>제작 방식</h2><span class="pill pill--green">고급</span></div><div class="segment" data-segment><button>간편</button><button class="is-active">고급</button></div><div class="field-stack" style="margin-top:14px"><button class="list-item is-selected" data-action="problem-flow"><span><b>풀이 흐름 초안</b><p>노드별 논리 구성</p></span><span>›</span></button><button class="list-item" data-action="problem-generate"><span><b>지시문 + 노트</b><p>자연어 세부 지시</p></span><span>›</span></button><button class="list-item" data-action="problem-convert"><span><b>객관식 변환</b><p>보기 5개 자동 구성</p></span><span>›</span></button><button class="list-item" data-action="problem-search"><span><b>문제 DB 검색</b><p>텍스트·태그·날짜</p></span><span>›</span></button></div><div class="endpoint-box">임시저장함 8개<br>교재 14권 · 시험지 6개</div></aside><article class="question-sheet"><div class="actions"><span class="question-number">01</span><span class="pill">중2 · 함수</span><span class="pill">난이도 중</span><span class="pill pill--green">#일차함수</span></div><div class="question-copy">두 점 (1, 3), (3, 7)을 지나는 일차함수의 식을 구하고 풀이 과정을 설명하세요.</div><ul class="list"><li class="list-item is-selected"><span>① y = 2x + 1</span><span class="pill pill--green">정답</span></li><li class="list-item"><span>② y = 2x - 1</span></li><li class="list-item"><span>③ y = x + 2</span></li><li class="list-item"><span>④ y = 3x</span></li></ul><div class="ui-card ui-card--flat" style="margin-top:14px"><div class="card-head"><h3>풀이 논리 캔버스</h3>${uiButton('노드 추가', 'problem-flow', 'ui-button--soft')}</div><div class="timeline"><div class="timeline-item"><span class="small muted">1단계</span><span class="timeline-dot"></span><div><b>기울기 계산</b><p class="small muted">(7-3) ÷ (3-1) = 2</p></div></div><div class="timeline-item"><span class="small muted">2단계</span><span class="timeline-dot"></span><div><b>y절편 계산</b><p class="small muted">3 = 2 × 1 + b</p></div></div></div></div></article><aside class="ui-card studio-panel studio-panel--sticky"><div class="card-head"><h2>세부 설정</h2><button class="icon-button">↺</button></div><div class="field-stack"><label class="field">난이도<select><option>중</option><option>하</option><option>상</option></select></label><label class="field">해시태그<input value="#일차함수 #기울기"></label><label class="field">세부 지시<textarea>오답 유도 보기를 포함하고 풀이를 2단계로 구성</textarea></label>${uiButton('선택 노드 삭제', '', 'ui-button--danger ui-button--block')}${uiButton('트레이에 임시 저장', '', 'ui-button--block')}</div></aside></div>${methodLedger('problem-studio')}</section>`,

  'exam-builder': `<section class="page">${pageHead('Quick Exam', '빠른 시험지 생성', '태그와 문항 수만 선택해 생성하고 상태 확인 후 PDF를 받는 기존 흐름입니다.', uiButton('상세 편집으로', '', '', 'exam-editor'))}<div class="split-layout"><article class="ui-card"><div class="card-head"><h2>생성 조건</h2><span class="pill">AIFlow CSAT</span></div><div class="field-stack"><label class="field">시험지 제목<input value="2학기 수학 형성평가"></label><label class="field">문항 수<select><option>10문항</option><option>20문항</option></select></label><label class="field">해시태그<input value="#일차함수 #그래프"></label><div class="actions"><span class="pill pill--green">#중2</span><span class="pill">#객관식</span><span class="pill">#서술형</span></div>${uiButton('시험지 생성', 'exam-create', 'ui-button--primary ui-button--block')}</div></article><article class="paper-sheet"><div class="paper-head"><span class="eyebrow">AIFlow CSAT</span><h2>2학기 수학 형성평가</h2><p class="muted small">생성 전 미리보기 · 10문항 · 40분</p></div><div class="empty-state"><div><b>조건을 확인한 뒤 시험지를 생성하세요.</b><p class="small">생성 완료 후 상태 확인과 PDF 다운로드 버튼이 활성화됩니다.</p></div></div></article></div>${methodLedger('exam-builder')}</section>`,

  'exam-editor': `<section class="page">${pageHead('Exam Studio', '시험지 제작 스튜디오', '검색·담기·정렬·레이아웃·통계·AI 배치·문서함 저장·PDF 배포를 모두 유지합니다.', uiButton('AI 배치', 'exam-ai', 'ui-button--soft') + uiButton('문서함 저장', 'exam-save') + uiButton('PDF', 'exam-pdf', 'ui-button--primary'))}<div class="studio-layout"><aside class="ui-card studio-panel"><div class="card-head"><h2>문제 검색</h2><span class="pill">3개 결과</span></div><div class="segment" data-segment><button class="is-active">텍스트</button><button>태그</button><button>문서함</button></div><input class="search-field" style="margin:12px 0" value="일차함수"><ul class="list"><li class="list-item"><span><b>두 점과 일차함수</b><p>#함수 · 중</p></span><button class="ui-button" data-action="exam-add">담기</button></li><li class="list-item"><span><b>기울기 구하기</b><p>#그래프 · 하</p></span><button class="ui-button" data-action="exam-add">담기</button></li></ul><div class="card-head" style="margin-top:18px"><h3>문제 세트</h3><span class="pill pill--green">3 / 100</span></div><ul class="list"><li class="list-item is-selected"><span>1. 두 점과 일차함수</span><span>↕ ×</span></li><li class="list-item"><span>2. 그래프 기울기</span><span>↕ ×</span></li><li class="list-item"><span>3. 함수의 활용</span><span>↕ ×</span></li></ul></aside><article class="paper-sheet"><div class="paper-head"><span class="eyebrow">AIFlow Academy</span><h2>2학기 수학 형성평가</h2><p class="muted small">2학년 · 제한시간 40분 · 10문항</p></div><div class="paper-question"><b>1</b><span>두 점을 지나는 일차함수의 식을 구하시오.</span><span class="pill">4점</span></div><div class="paper-question"><b>2</b><span>그래프의 기울기와 y절편을 각각 구하시오.</span><span class="pill">4점</span></div><div class="paper-question"><b>3</b><span>일차함수 활용 문제를 풀이 과정과 함께 서술하시오.</span><span class="pill">6점</span></div></article><aside class="ui-card studio-panel"><div class="card-head"><h2>편집 설정</h2><button class="icon-button" data-action="exam-stats">▥</button></div><div class="field-stack"><label class="field">레이아웃<select><option>세로형</option><option>슬라이더</option><option>그리드</option></select></label><label class="field">문제 글자<input value="11 pt"></label><label class="field">문제 간격<input value="18 pt"></label><div class="ui-card ui-card--tint"><b>문항 통계</b><p class="small muted">객관식 2 · 서술형 1<br>하 1 · 중 1 · 상 1</p></div>${uiButton('소스 표시 전환', 'exam-source', 'ui-button--block')}${uiButton('객관식으로 변경', 'problem-convert', 'ui-button--block')}</div></aside></div>${methodLedger('exam-editor')}</section>`,

  'course-list': `<section class="page">${pageHead('Courses', '코스 관리', '공개 상태, 정렬, 태그, 페이지네이션과 다중 삭제를 동일하게 제공합니다.', uiButton('새 코스', '', 'ui-button--primary', 'course-builder'))}<div class="ui-card ui-card--flat"><div class="actions"><div class="segment" data-segment><button class="is-active">전체</button><button>공개</button><button>비공개</button></div><input class="search-field" style="width:min(260px,100%)" value="코스 검색"><button class="ui-button" data-action="course-filter">전체 태그</button><button class="ui-button ui-button--danger" data-action="course-delete">선택 삭제</button></div></div><div class="table-wrap" style="margin-top:14px"><table class="data-table course-table"><thead><tr><th>선택</th><th>코스</th><th>모듈</th><th>노출</th><th>교재</th><th>태그</th><th>수정일</th><th></th></tr></thead><tbody><tr><td>□</td><td><b>중2 일차함수 완성</b><br><span class="small muted">목표 OVR 1200</span></td><td>8</td><td><span class="pill pill--green">공개</span></td><td>2권</td><td>#함수</td><td>오늘</td><td>${uiButton('편집', '', '', 'course-builder')}</td></tr><tr><td>□</td><td><b>중1 방정식 복습</b></td><td>5</td><td><span class="pill">비공개</span></td><td>1권</td><td>#방정식</td><td>어제</td><td>${uiButton('편집', '', '', 'course-builder')}</td></tr></tbody></table></div><div class="actions" style="justify-content:flex-end;margin-top:12px">${uiButton('이전')}<span class="pill">1 / 4</span>${uiButton('다음')}</div>${methodLedger('course-list')}</section>`,

  'course-builder': `<section class="page">${pageHead('Course Builder', '코스 만들기', '교재·시험지·문항 모듈과 학습 조건, 오답 복습 및 AI 분석 설정을 보존합니다.', uiButton('저장', 'course-save', 'ui-button--primary'))}<div class="split-layout"><aside class="ui-card"><div class="card-head"><h2>기본 정보</h2><span class="pill">비공개</span></div><div class="field-stack"><label class="field">코스 제목<input value="중2 일차함수 완성"></label><label class="field">설명<textarea>개념 학습부터 형성평가까지 이어지는 4주 코스</textarea></label><label class="field">난이도<select><option>중</option></select></label><label class="field">목표 OVR<input value="1200"></label><label class="field">해시태그<input value="#중2 #일차함수"></label></div></aside><div class="grid"><article class="ui-card"><div class="card-head"><h2>학습 모듈</h2>${uiButton('모듈 추가', 'course-module', 'ui-button--soft')}</div><ul class="list"><li class="list-item is-selected"><span><b>1. 교재 보기</b><p>일차함수 개념서 · 1~24쪽 · 최소 12분</p></span><span>↕</span></li><li class="list-item"><span><b>2. 문제 풀이</b><p>DB 문항 10개 · 객관식 자동 구성</p></span><span>↕</span></li><li class="list-item"><span><b>3. 시험지 풀이</b><p>2학기 형성평가 · AI 분석 사용</p></span><span>↕</span></li><li class="list-item"><span><b>4. 오답 복습</b><p>기준 점수 미만 시 자동 삽입</p></span><span>↕</span></li></ul></article><article class="ui-card"><div class="card-head"><h2>선택 모듈 상세</h2><span class="pill pill--green">교재 보기</span></div><div class="grid grid--2"><label class="field">교재<select><option>일차함수 개념서</option></select></label><label class="field">페이지 범위<input value="1 - 24"></label><label class="field">최소 학습 시간<input value="12분"></label><label class="field">완료 조건<select><option>페이지 + 누적 시간</option></select></label></div><div class="actions" style="margin-top:14px"><button class="ui-button" data-action="course-document">문서함에서 선택</button><button class="ui-button" data-action="course-problem">생성해서 추가</button><button class="ui-button">이 모듈 오답 복습</button></div></article></div></div>${methodLedger('course-builder')}</section>`,

  'textbook-builder': `<section class="page">${pageHead('Textbook Builder', '교재 작성', '챕터·섹션 구조와 블록 편집, 슬래시 명령, 미리보기 및 완료 반환을 유지합니다.', uiButton('미리보기', 'textbook-preview') + uiButton('저장', 'textbook-save', 'ui-button--primary'))}<div class="studio-layout"><aside class="ui-card"><div class="card-head"><h2>목차</h2><button class="icon-button">＋</button></div><ul class="list"><li class="list-item is-selected"><span><b>Chapter 1</b><p>일차함수의 뜻</p></span><span>•••</span></li><li class="list-item"><span><b>Chapter 2</b><p>그래프와 기울기</p></span><span>•••</span></li><li class="list-item"><span><b>Chapter 3</b><p>일차함수의 활용</p></span><span>•••</span></li></ul></aside><article class="editor-sheet"><label class="field">교재 제목<input value="중2 일차함수 개념서"></label><label class="field" style="margin-top:10px">부제<input value="개념부터 실전까지"></label><hr style="border:0;border-top:1px solid var(--line);margin:22px 0"><h2>일차함수의 뜻</h2><p class="muted">x의 값이 하나 정해질 때 y의 값이 하나씩 정해지는 관계를 함수라고 합니다.</p><div class="ui-card ui-card--tint" style="margin-top:18px"><b>예제 1</b><p>y = 2x + 1에서 x = 3일 때 y의 값을 구하세요.</p></div><button class="ui-button ui-button--block" style="margin-top:14px" data-action="slash-command">/ 블록 추가</button></article><aside class="ui-card"><div class="card-head"><h2>블록 도구</h2></div><ul class="list"><li class="list-item"><span>본문</span><span>⌘1</span></li><li class="list-item"><span>제목</span><span>⌘2</span></li><li class="list-item"><span>수식</span><span>fx</span></li><li class="list-item"><span>이미지</span><span>▧</span></li><li class="list-item"><span>예제/문제</span><span>◇</span></li></ul></aside></div>${methodLedger('textbook-builder')}</section>`,

  documents: `<section class="page">${pageHead('Teacher Documents', '교사 문서함', '교사가 보유한 교재와 시험지를 유형·태그로 걸러 코스와 그룹에 연결합니다.', uiButton('필터', 'document-filter'))}<div class="tabs" data-tabs><button class="tab is-active">전체 20</button><button class="tab">교재 14</button><button class="tab">시험지 6</button></div><div class="split-layout"><div class="grid"><button class="ui-card feature-card"><span class="feature-card__icon">▧</span><span><h3>중2 일차함수 개념서</h3><p>#중2 #함수 · 42쪽</p></span><span>›</span></button><button class="ui-card feature-card"><span class="feature-card__icon">▤</span><span><h3>2학기 수학 형성평가</h3><p>#시험지 #10문항</p></span><span>›</span></button><button class="ui-card feature-card"><span class="feature-card__icon">▧</span><span><h3>중1 방정식 복습</h3><p>#중1 #방정식 · 28쪽</p></span><span>›</span></button></div><article class="paper-sheet"><div class="paper-head"><span class="eyebrow">Textbook</span><h2>중2 일차함수 개념서</h2><p class="muted small">최근 수정 오늘 · 태그 #중2 #함수</p></div><div class="question-copy"><b>Chapter 1. 일차함수의 뜻</b><br><br>함수의 기본 개념과 대응 관계를 학습합니다.</div><div class="actions">${uiButton('코스에 연결', 'course-document')}${uiButton('그룹에 배정', 'assignment', 'ui-button--primary')}</div></article></div>${methodLedger('documents')}</section>`,

  groups: `<section class="page">${pageHead('Study Groups', '그룹 관리', '교사 그룹 생성, 참여코드·QR, 멤버와 수업 운영 상태를 관리합니다.', uiButton('새 그룹', 'group-create', 'ui-button--primary'))}<div class="grid grid--3"><button class="ui-card feature-card" data-nav="group-detail"><span class="feature-card__icon">2A</span><span><h3>중2 심화반</h3><p>학생 12명 · 과제 3개 · 공지 1개</p></span><span>›</span></button><button class="ui-card feature-card" data-nav="group-detail"><span class="feature-card__icon">1B</span><span><h3>중1 기본반</h3><p>학생 9명 · 과제 1개</p></span><span>›</span></button><button class="ui-card feature-card" data-nav="group-detail"><span class="feature-card__icon">3C</span><span><h3>중3 내신반</h3><p>학생 15명 · 과제 4개</p></span><span>›</span></button></div><div class="ui-card" style="margin-top:14px"><div class="card-head"><h2>참여 안내</h2>${uiButton('QR 보기', 'group-invite')}</div><p class="muted small">비밀번호 잠금 그룹은 참여코드와 암호를 모두 입력해야 합니다. 초대 링크는 학생 화면으로 연결됩니다.</p></div>${methodLedger('groups')}</section>`,

  'group-detail': `<section class="page">${pageHead('중2 심화반', '그룹 상세', '멤버, 과제, 공지, 채팅, 학생 분석을 한 화면의 탭으로 관리합니다.', uiButton('초대', 'group-invite') + uiButton('코스·숙제 배정', 'assignment', 'ui-button--primary'))}<div class="tabs" data-tabs><button class="tab is-active">개요</button><button class="tab">학생 12</button><button class="tab">과제 3</button><button class="tab">공지 1</button><button class="tab">그룹 채팅</button><button class="tab">학습 분석</button></div><div class="grid grid--4">${metric('학생', '12명', '활성 11명')}${metric('진행 과제', '3', '미제출 7건')}${metric('평균 OVR', '1,184', '지난주 +24')}${metric('최근 메시지', '8', '읽지 않음 2')}</div><div class="split-layout" style="margin-top:14px"><article class="ui-card"><div class="card-head"><h2>학생</h2>${uiButton('전체 보기', '', '', 'academy')}</div><ul class="list"><li class="list-item"><span><b>박학생</b><p>OVR 1,240 · 최근 학습 오늘</p></span>${uiButton('분석', 'student-analysis')}</li><li class="list-item"><span><b>이학생</b><p>OVR 1,105 · 미제출 1</p></span>${uiButton('채팅', 'message-send')}</li><li class="list-item"><span><b>최학생</b><p>OVR 1,198 · 최근 학습 어제</p></span>${uiButton('분석', 'student-analysis')}</li></ul></article><article class="ui-card"><div class="card-head"><h2>수업 운영</h2>${uiButton('공지 작성', 'notice')}</div><div class="timeline"><div class="timeline-item"><span class="small muted">오늘</span><span class="timeline-dot"></span><div><b>일차함수 형성평가 배정</b><p class="small muted">마감 7월 18일 · 전체 학생</p></div></div><div class="timeline-item"><span class="small muted">어제</span><span class="timeline-dot"></span><div><b>다음 수업 준비물 공지</b><p class="small muted">교재 42쪽까지</p></div></div></div></article></div>${methodLedger('group-detail')}</section>`,

  academy: `<section class="page">${pageHead('Academy Dashboard', '학원 대시보드', '출석, 수납, 상담, 학생 요약 스냅샷과 약점 태그를 실제 집계 구조대로 표시합니다.', uiButton('새로고침'))}<div class="grid grid--4">${metric('오늘 출석률', '91.7%', '11 / 12명')}${metric('이번 달 수납', '92%', '미납 4명')}${metric('상담 예정', '3건', '이번 주')}${metric('평균 OVR', '1,184', '+24')}</div><div class="tabs" data-tabs style="margin-top:18px"><button class="tab is-active">출석</button><button class="tab">수납</button><button class="tab">상담</button><button class="tab">학생 요약</button></div><div class="table-wrap"><table class="data-table"><thead><tr><th>학생</th><th>월</th><th>화</th><th>수</th><th>목</th><th>금</th><th>수납</th><th>약점 태그</th></tr></thead><tbody><tr><td><b>박학생</b></td><td>출석</td><td>출석</td><td>-</td><td>출석</td><td>-</td><td><span class="pill pill--green">완료</span></td><td>#함수그래프</td></tr><tr><td><b>이학생</b></td><td>출석</td><td>지각</td><td>-</td><td>결석</td><td>-</td><td><span class="pill">미납</span></td><td>#기울기</td></tr></tbody></table></div>${methodLedger('academy')}</section>`,

  operations: `<section class="page">${pageHead('Operations', '재무·스케줄', '로컬 DB에 저장되는 일간/월간 회계와 수업 일정, 캘린더·ICS 내보내기를 포함합니다.', uiButton('재무 입력', 'finance-save') + uiButton('일정 추가', 'schedule-save', 'ui-button--primary'))}<div class="tabs" data-tabs><button class="tab is-active">재무제표</button><button class="tab">스케줄</button></div><div class="grid grid--3">${metric('7월 수입', '₩4,800,000', '수강료 48건')}${metric('7월 지출', '₩1,320,000', '교재·임대료')}${metric('순이익', '₩3,480,000', '전월 +8.4%')}</div><div class="split-layout" style="margin-top:14px"><article class="ui-card"><div class="card-head"><h2>오늘 일정</h2><div class="actions"><button class="icon-button">‹</button><span class="pill">7월 13일</span><button class="icon-button">›</button></div></div><div class="timeline"><div class="timeline-item"><span class="small muted">15:00</span><span class="timeline-dot"></span><div><b>학부모 상담</b><p class="small muted">박학생 · 상담실</p></div></div><div class="timeline-item"><span class="small muted">17:00</span><span class="timeline-dot"></span><div><b>중2 심화반</b><p class="small muted">일차함수 형성평가</p></div></div></div><div class="actions">${uiButton('기기 캘린더 열기')}${uiButton('ICS 내보내기')}</div></article><article class="ui-card"><div class="card-head"><h2>최근 재무 항목</h2><span class="pill">월간</span></div><ul class="list"><li class="list-item"><span><b>7월 수강료</b><p>수입 · 오늘</p></span><b>+₩4,800,000</b></li><li class="list-item"><span><b>교재 인쇄비</b><p>지출 · 어제</p></span><b>-₩320,000</b></li><li class="list-item"><span><b>임대료</b><p>지출 · 7월 1일</p></span><b>-₩1,000,000</b></li></ul></article></div>${methodLedger('operations')}</section>`,

  social: `<section class="page">${pageHead('Teacher Social', '친구', '교사 친구를 추가·삭제하고 1:1 채팅으로 이동합니다.', uiButton('친구 추가', 'friend-add', 'ui-button--primary'))}<div class="grid grid--3"><article class="ui-card"><div class="card-head"><span class="avatar">민</span><span class="pill pill--green">온라인</span></div><h3>수학쌤민지</h3><p class="muted small">수학 · 중등</p><div class="actions">${uiButton('채팅', '', 'ui-button--primary', 'chat')}${uiButton('삭제', 'friend-remove', 'ui-button--danger')}</div></article><article class="ui-card"><div class="card-head"><span class="avatar">준</span><span class="pill">1시간 전</span></div><h3>과학쌤준호</h3><p class="muted small">과학 · 고등</p><div class="actions">${uiButton('채팅', '', 'ui-button--primary', 'chat')}${uiButton('삭제', 'friend-remove', 'ui-button--danger')}</div></article></div>${methodLedger('social')}</section>`,

  chat: `<section class="page">${pageHead('Direct Message', '수학쌤민지', '메시지 조회·전송과 내 코스 공유를 동일한 대화 흐름에서 제공합니다.', uiButton('코스 공유', 'course-share'))}<div class="split-layout"><aside class="ui-card"><input class="search-field" value="대화 검색"><ul class="list" style="margin-top:12px"><li class="list-item is-selected"><span><b>수학쌤민지</b><p>코스 확인해 볼게요!</p></span><span class="pill pill--green">2</span></li><li class="list-item"><span><b>과학쌤준호</b><p>자료 감사합니다.</p></span></li></ul></aside><article class="ui-card" style="min-height:560px;display:grid;grid-template-rows:1fr auto"><div class="field-stack"><div class="ui-card ui-card--tint" style="max-width:76%"><p>지난번 말씀드린 일차함수 코스 공유드려요.</p><span class="small muted">오후 2:14</span></div><div class="ui-card" style="max-width:76%;margin-left:auto"><p>네, 코스 확인해 볼게요!</p><span class="small muted">오후 2:18</span></div></div><div class="actions" style="margin-top:20px"><input class="search-field" style="flex:1" placeholder="메시지 입력">${uiButton('전송', 'message-send', 'ui-button--primary')}</div></article></div>${methodLedger('chat')}</section>`,

  store: `<section class="page">${pageHead('Teacher Store', '스토어', '포인트 요약, 테스트 충전, 문제·교재·시험지 DB 자료 구매를 포함합니다.', uiButton('포인트 충전', 'store-topup'))}<div class="grid grid--3">${metric('보유 포인트', '12,480P', '사용 가능')}${metric('구매 자료', '18개', '문제 12 · 교재 4 · 시험지 2')}${metric('이번 달 사용', '4,200P', '지난달 대비 -12%')}</div><div class="tabs" data-tabs style="margin-top:18px"><button class="tab is-active">추천</button><button class="tab">문제 DB</button><button class="tab">교재</button><button class="tab">시험지</button></div><div class="grid grid--3"><article class="ui-card"><span class="pill pill--green">문제 DB</span><h3>중2 함수 실전 100제</h3><p class="muted small">난이도별 분류 · 해설 포함</p><div class="card-head"><b>2,400P</b>${uiButton('구매', 'purchase', 'ui-button--primary')}</div></article><article class="ui-card"><span class="pill">교재</span><h3>일차함수 핵심 개념서</h3><p class="muted small">42쪽 · 편집 가능</p><div class="card-head"><b>3,200P</b>${uiButton('구매', 'purchase', 'ui-button--primary')}</div></article><article class="ui-card"><span class="pill">시험지</span><h3>중간고사 대비 3회분</h3><p class="muted small">PDF · 정답지 포함</p><div class="card-head"><b>1,800P</b>${uiButton('구매', 'purchase', 'ui-button--primary')}</div></article></div>${methodLedger('store')}</section>`,

  profile: `<section class="page">${pageHead('Account', '프로필·설정', '회원 정보, 앱 환경, 계정 상태 수정과 로그아웃·계정 삭제를 제공합니다.', uiButton('저장', 'profile-save', 'ui-button--primary'))}<div class="split-layout"><aside class="ui-card"><div style="display:grid;place-items:center;text-align:center"><span class="avatar" style="width:72px;height:72px;font-size:24px">김</span><h2>김선생</h2><p class="muted small">teacher@example.com</p></div><div class="tabs" style="display:grid"><button class="tab is-active">프로필</button><button class="tab">앱 설정</button><button class="tab">계정 상태</button></div></aside><article class="ui-card"><div class="card-head"><h2>회원 정보</h2><span class="pill pill--green">교사 인증</span></div><div class="grid grid--2"><label class="field">이름<input value="김선생"></label><label class="field">닉네임<input value="수학쌤김"></label><label class="field">학교/학원<input value="AIFlow Academy"></label><label class="field">담당 과목<input value="수학"></label></div><div class="ui-card ui-card--flat" style="margin-top:18px"><div class="card-head"><h3>앱 환경</h3></div><ul class="list"><li class="list-item"><span>알림 받기</span><span class="pill pill--green">켜짐</span></li><li class="list-item"><span>모바일 간소화 모드</span><span class="pill">자동</span></li></ul></div><div class="actions" style="margin-top:18px">${uiButton('로그아웃', 'logout')}${uiButton('계정 삭제', 'account-delete', 'ui-button--danger')}</div></article></div>${methodLedger('profile')}</section>`,

  auth: `<section class="page">${pageHead('Authentication', '로그인·가입 시안', 'AuthWrapper 자동 인증 확인과 로그인·가입 전환, 토큰 확인 흐름을 표현합니다.')}<div class="grid grid--2"><article class="ui-card" style="min-height:420px"><span class="eyebrow">Welcome back</span><h2>교사 로그인</h2><div class="field-stack"><label class="field">이메일<input value="teacher@example.com"></label><label class="field">비밀번호<input value="••••••••"></label>${uiButton('로그인', 'login', 'ui-button--primary ui-button--block')}</div><p class="small muted">로그인 성공 후 토큰을 확인하고 교사용 홈으로 이동합니다.</p></article><article class="ui-card ui-card--tint" style="min-height:420px"><span class="eyebrow">New teacher</span><h2>교사 계정 만들기</h2><div class="field-stack"><label class="field">이름<input value="김선생"></label><label class="field">이메일<input value="teacher@example.com"></label><label class="field">비밀번호<input value="••••••••"></label>${uiButton('가입', 'register', 'ui-button--primary ui-button--block')}</div></article></div>${methodLedger('auth')}</section>`,
};

/**
 * 필요 변수: 없음. screenMeta의 그룹·화면 정보.
 * 작동 원리: 데스크톱 전체 메뉴와 모바일 핵심 메뉴를 같은 화면 ID로 생성해 라우팅 불일치를 방지한다.
 */
function buildNavigation() {
  let currentGroup = '';
  primaryNav.innerHTML = Object.entries(screenMeta).map(([id, meta]) => {
    const group = meta.group !== currentGroup ? `<div class="nav-label">${meta.group}</div>` : '';
    currentGroup = meta.group;
    return `${group}<button class="nav-item" data-nav="${id}"><span class="nav-item__icon">${meta.icon}</span><span>${meta.label}</span>${meta.badge ? `<span class="nav-item__badge">${meta.badge}</span>` : '<span></span>'}</button>`;
  }).join('');
  const mobileIds = ['dashboard', 'problem-studio', 'exam-editor', 'groups', 'profile'];
  mobileNav.innerHTML = mobileIds.map((id) => `<button data-nav="${id}"><span>${screenMeta[id].icon}</span><span>${screenMeta[id].label.replace('교사용 ', '').replace(' 제작', '')}</span></button>`).join('');
}

/**
 * 필요 변수: screenId. screenTemplates와 screenMeta의 동일 ID 항목.
 * 작동 원리: 지정 화면을 렌더링하고 PC·모바일 내비게이션 선택 상태와 breadcrumb를 동시에 갱신한다.
 */
function navigateTo(screenId) {
  if (!screenTemplates[screenId]) return;
  closePanel();
  screenHost.innerHTML = screenTemplates[screenId];
  breadcrumbs.textContent = `교사용 홈 / ${screenMeta[screenId].label}`;
  document.querySelectorAll('[data-nav]').forEach((button) => button.classList.toggle('is-active', button.dataset.nav === screenId));
  screenHost.focus({ preventScroll: true });
  const url = new URL(window.location.href);
  url.searchParams.set('screen', screenId);
  history.replaceState(null, '', url);
}

/**
 * 필요 변수: actionId. actionCatalog의 작업 설명 및 입력 필드.
 * 작동 원리: 데스크톱에서는 우측 작업 패널, 모바일에서는 전체 화면 패널로 같은 기능·엔드포인트를 보여준다.
 */
function openAction(actionId) {
  if (actionId === 'close-panel') {
    closePanel();
    return;
  }
  if (actionId === 'coverage') {
    openCoverage();
    return;
  }
  const config = actionCatalog[actionId] || {
    title: '기능 확인',
    kicker: '현재 화면 작업',
    body: '<p>이 컨트롤은 기존 화면의 로컬 상태 변경 또는 후속 선택 작업을 나타냅니다.</p>',
    endpoint: '기존 Dart 콜백 및 상태 전이 유지',
    confirm: '확인',
  };
  taskKicker.textContent = config.kicker || '작업';
  taskTitle.textContent = config.title;
  const fields = (config.fields || []).map(([label, value]) => `<label class="field">${label}<input value="${value}"></label>`).join('');
  taskBody.innerHTML = `${config.body || `<div class="field-stack">${fields}</div>`}${config.endpoint ? `<div class="endpoint-box"><b>연결 계약</b><br>${config.endpoint}</div>` : ''}`;
  taskFoot.innerHTML = `${uiButton('취소', 'close-panel')}${config.confirm ? `<button class="ui-button ui-button--primary" data-confirm-action="${actionId}">${config.confirm}</button>` : ''}`;
  taskPanel.classList.add('is-open');
  taskPanel.setAttribute('aria-hidden', 'false');
  scrim.hidden = false;
}

/**
 * 필요 변수: 없음. screenMeta 전체 화면·메서드 목록.
 * 작동 원리: 시안에 포함된 화면 수와 각 화면의 실제 서비스 메서드를 검토 패널로 노출한다.
 */
function openCoverage() {
  taskKicker.textContent = 'Coverage';
  taskTitle.textContent = `전체 기능 매핑 · ${Object.keys(screenMeta).length}개 화면`;
  taskBody.innerHTML = `<div class="coverage-list">${Object.entries(screenMeta).map(([id, meta]) => `<div class="coverage-item"><strong>${meta.label}<span class="pill pill--green">포함</span></strong><p><b>기능</b> · ${featureLedger[id].join(' · ')}</p><p><b>메서드</b> · ${meta.methods.join(' · ')}</p><button class="ui-button" style="margin-top:9px" data-nav="${id}">화면 보기</button></div>`).join('')}</div>`;
  taskFoot.innerHTML = uiButton('닫기', 'close-panel');
  taskPanel.classList.add('is-open');
  taskPanel.setAttribute('aria-hidden', 'false');
  scrim.hidden = false;
}

/**
 * 필요 변수: 없음. 작업 패널과 배경 scrim 요소.
 * 작동 원리: 패널의 열림 상태와 접근성 속성을 함께 초기화한다.
 */
function closePanel() {
  taskPanel.classList.remove('is-open');
  taskPanel.setAttribute('aria-hidden', 'true');
  scrim.hidden = true;
}

/**
 * 필요 변수: mode(desktop 또는 mobile), appFrame과 화면 전환 버튼.
 * 작동 원리: 콘텐츠를 확대·축소하지 않고 실제 390px 레이아웃 클래스를 적용해 컴포넌트 왜곡을 방지한다.
 */
function setViewport(mode) {
  appFrame.classList.toggle('is-mobile', mode === 'mobile');
  document.querySelectorAll('[data-viewport]').forEach((button) => button.classList.toggle('is-active', button.dataset.viewport === mode));
}

/**
 * 필요 변수: message. app-shell 요소.
 * 작동 원리: 네트워크를 호출하지 않는 시안에서 액션 완료 상태를 짧은 토스트로 확인시킨다.
 */
function showToast(message) {
  document.querySelector('.toast')?.remove();
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.textContent = message;
  document.querySelector('.app-shell').appendChild(toast);
  window.setTimeout(() => toast.remove(), 2200);
}

document.addEventListener('click', (event) => {
  const nav = event.target.closest('[data-nav]');
  if (nav) {
    navigateTo(nav.dataset.nav);
    return;
  }
  const action = event.target.closest('[data-action]');
  if (action) {
    openAction(action.dataset.action);
    return;
  }
  const confirm = event.target.closest('[data-confirm-action]');
  if (confirm) {
    const label = actionCatalog[confirm.dataset.confirmAction]?.confirm || '완료';
    closePanel();
    showToast(`${label} 작업을 시안에서 확인했습니다.`);
    if (confirm.dataset.confirmAction === 'logout') navigateTo('auth');
    return;
  }
  const segmentButton = event.target.closest('[data-segment] button, [data-tabs] button');
  if (segmentButton) {
    segmentButton.parentElement.querySelectorAll('button').forEach((button) => button.classList.toggle('is-active', button === segmentButton));
    showToast(`${segmentButton.textContent.trim()} 보기로 전환했습니다.`);
    return;
  }
  const passiveButton = event.target.closest('button');
  if (passiveButton && screenHost.contains(passiveButton)) {
    showToast(`${passiveButton.textContent.trim() || '선택'} 기능을 시안에서 확인했습니다.`);
  }
});

scrim.addEventListener('click', closePanel);
document.querySelectorAll('[data-viewport]').forEach((button) => button.addEventListener('click', () => setViewport(button.dataset.viewport)));

buildNavigation();
const initialParams = new URLSearchParams(window.location.search);
if (initialParams.get('viewport') === 'mobile' || window.innerWidth <= 520) setViewport('mobile');
navigateTo(initialParams.get('screen') || 'dashboard');
if (initialParams.get('action')) openAction(initialParams.get('action'));

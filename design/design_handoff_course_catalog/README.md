# Handoff: 코스 화면 리디자인 (Course Catalog)

## Overview
학생용 앱의 "코스" 화면을 데스크톱과 모바일(세로) 두 가지로 리디자인했습니다. 최종적으로 확정된 화면은 **모바일 "내 코스" 화면**이며, 데스크톱 시안은 참고용으로 함께 포함합니다.

## About the Design Files
이 폴더의 HTML 파일들은 **디자인 레퍼런스**입니다 (Design Component 프로토타입). 실제 Flutter 앱에 반영할 때는 이 HTML을 그대로 쓰는 게 아니라, `Upstudy-app/lib/sessions/course/ui/course_catalog_page.dart` 등 기존 Dart 위젯 구조와 `StudentDensityTokens`, `StudentDensitySurface` 같은 기존 컴포넌트/토큰을 그대로 활용해서 **동일한 레이아웃·스타일을 Flutter로 재현**해야 합니다.

## Fidelity
**High-fidelity.** 색상, 타이포그래피, spacing, 컴포넌트 구조가 확정된 상태입니다. 아래 스펙대로 픽셀 단위로 재현해 주세요.

## Screens / Views

### 1. 내 코스 (모바일, 최종본) — `Course Catalog Redesign - Mobile.dc.html`

**Purpose**: 학생이 수강 중인 코스와 완료한 코스만 확인하는 화면. 코스 탐색/추천/전체 카탈로그는 이 화면에서 제거됨 (별도 화면으로 분리 예정).

**Layout**
- 컨테이너: 폭 390px 기준 모바일 뷰포트, 배경 `#f2f2f4`
- 상단 바 없음, OVR 카드 없음, 검색창 없음 — 페이지 제목만 바로 노출
- 상단 패딩 24px 16px 0
- 하단 고정 네비게이션 바로 인해 컨테이너 `padding-bottom: 96px`

**Components**

1. **페이지 제목**
   - `<h1>내 코스</h1>` — font-size 32px, line-height 1.05, letter-spacing -0.045em, font-weight 700(기본 h1)
   - 설명문: `현재 학습을 이어가거나 완료한 코스를 확인하세요.` — color `#71717a`, font-size 12px, line-height 1.55, margin-top 8px
   - 하단 margin 18px

2. **필터 칩 (2개)**
   - `수강중`, `완료코스` — 2열 그리드 (`grid-template-columns: repeat(2, 1fr)`), gap 6px
   - `position: sticky; top: 12px; z-index: 4;`
   - 기본 선택값: `수강중`
   - 비선택 상태: 배경 `#f6f6f8`, 텍스트 `#71717a`, border `1px solid rgba(9,9,11,0.1)`
   - 선택 상태: 배경 `#0a0a0b`, 텍스트 `#fff`, border `1px solid #0a0a0b`
   - 버튼 높이: min-height 40px, border-radius 12px, font-size 11px, font-weight 800
   - 하단 margin 16px

3. **코스 카드 리스트** (필터에 따라 표시되는 항목이 달라짐)
   - 카드: 배경 `#fff`, border `1px solid rgba(9,9,11,0.1)`, border-radius 22px, padding 18px, box-shadow `0 10px 28px rgba(0,0,0,0.05)`
   - 카드 간 gap 12px
   - 카드 내부 상단: flex row, gap 14px
     - **진행률 링(SVG)**: 52×52px, 원형, stroke-width 4.5px, 배경 트랙 `#ececef`, 진행 색 `#0a0a0b` (`stroke-linecap: round`, `transform: rotate(-90deg)`로 12시 방향에서 시작)
       - 중앙 텍스트: 진행률 %(예: `42%`) 또는 완료 시 체크마크 `✓`
     - **텍스트 영역**:
       - 제목(`b`): font-size 16px, font-weight 900, letter-spacing -0.02em
       - 메타 텍스트(`small`): color `#71717a`, font-size 11px, margin-top 4px (예: `그래프 이해 · 06번째 모듈`)
       - 상태 뱃지: 배경 `#f6f6f8`, 텍스트 `#71717a`, padding 3px 8px, border-radius 999px, font-size 9px, font-weight 850, margin-top 6px (예: `수강중`, `완료`)
   - CTA 버튼 (전체폭, 카드 하단): min-height 46px, margin-top 14px, background `#0a0a0b`, color `#fff`, border-radius 14px, font-size 13px, font-weight 900 (예: `이어하기 ›`, `다시보기 ›`)
   - 빈 상태: 해당 필터에 항목이 없으면 `해당하는 코스가 없습니다.` 안내 카드 표시 (padding 40px 20px, 중앙 정렬, color `#71717a`)

4. **하단 고정 네비게이션 바** (기존 `student-app.css`의 `.mobile-nav` 스펙 그대로 적용)
   - `position: fixed; bottom: 0;` 폭 390px, 배경 `#0a0a0b`
   - `display: flex; justify-content: space-around;`, padding `10px 8px calc(10px + safe-area-inset-bottom)`
   - 항목 5개: 홈(⌂), 코스(▦, 현재 활성), 책가방(▧), 대결(A), 소셜(♧)
   - 비활성 버튼: 텍스트 `#94949a`, 배경 투명
   - 활성 버튼: 텍스트 `#fff`, 배경 `rgba(255,255,255,0.12)`, border-radius 18px
   - 버튼 내부: 아이콘 18px 위, 라벨 9px/weight 750 아래, gap 2px
   - 터치 영역: min-width 56px, min-height 48px

**Data (mock, 실제 연동 시 API로 대체)**
```
[
  { title: '일차함수 완성', meta: '그래프 이해 · 06번째 모듈', status: 'active', progress: 0.42, cta: '이어하기' },
  { title: '도형의 닮음', meta: '닮음비 · 03번째 모듈', status: 'active', progress: 0.18, cta: '이어하기' },
  { title: '일차방정식 기초', meta: '완료 · 100%', status: 'done', progress: 1, cta: '다시보기' },
]
```
- `수강중` 필터 → `status === 'active'` 항목만
- `완료코스` 필터 → `status === 'done'` 항목만 (완료 항목은 다른 필터에는 절대 노출되지 않음)

### 2. 코스 탐색 (데스크톱, 참고용) — `Course Catalog Redesign.dc.html`
데스크톱 와이드 레이아웃 버전. 이어서 학습(원형 링 진행률) + 추천 코스(다크 히어로 카드) + 전체 코스 카탈로그(그리드)로 구성. 모바일 화면에서는 이 중 "이어서 학습" 개념만 "내 코스"로 단순화되어 남았고, 추천/전체 카탈로그는 제외되었습니다. 상세 스펙은 파일 내 인라인 스타일을 직접 참고하세요.

## Interactions & Behavior
- 필터 칩 클릭 시 즉시 리스트 필터링 (애니메이션 없음, 즉시 전환)
- 카드/CTA 버튼 클릭 시 해당 코스의 학습 화면(`CourseLearningPage`)으로 이동해야 함 — 기존 `course_catalog_page.dart`의 `_openCourse` / `courseEntryTarget` 로직 재사용
- 완료 코스의 CTA(`다시보기`)는 읽기 전용 진입 (`CourseDetailPage`)으로 연결
- 하단 네비게이션은 기존 앱의 라우팅(`courses`, `dashboard`, `textbooks`, `arena`, `friends`)과 동일하게 연결

## State Management
- `filter: 'active' | 'done'` — 현재 선택된 필터 (기본값 `'active'`)
- 코스 리스트는 기존 `CourseService.fetchMyCourses()` 등록 코스 응답에서 `isCompleted` 여부로 `active`/`done` 분기

## Design Tokens
기존 앱 토큰(`Upstudy-app/lib/shared/theme/app_colors.dart`, `design/student/student-app.css`)과 동일하게 유지:
- ink: `#09090b`
- muted: `#71717a`
- faint: `#a1a1aa`
- dark: `#0a0a0b`
- surface: `#ffffff`
- surface-muted: `#f6f6f8`
- canvas: `#f2f2f4`
- line: `rgba(9,9,11,0.1)`
- 카드 radius: 22px (모바일), 28px(데스크톱 `--radius-lg`)
- 카드 shadow: `0 10px 28px rgba(0,0,0,0.05)` (모바일 카드), `--shadow-card: 0 14px 44px rgba(0,0,0,0.06)` (데스크톱)

## Assets
아이콘은 별도 이미지 없이 유니코드 글리프(⌂ ▦ ▧ A ♧ ⌕ ✓ › ⌄) 사용 — 실제 구현 시 Material Icons 등 기존 아이콘 세트로 대체 권장.

## Files
- `Course Catalog Redesign - Mobile.dc.html` — 최종 모바일 화면 (기준 스펙)
- `Course Catalog Redesign.dc.html` — 데스크톱 참고 시안

# student 세션

## 기능 요약
- 학생 대시보드 화면을 제공합니다.
- 학생 프로필, 학년, 완료율, 최근 활동 내역을 시각화하여 보여줍니다.

## 폴더 구조
- `session/`: 세션 진입점 및 외부 노출용 배럴 파일
- `business/`: 학생 대시보드 데이터 모델 및 도메인 로직
- `ui/`: 학생 대시보드 페이지 위젯
- `shared/`: 세션 내부 공통 상수/모델/헬퍼 (현재 없음)

## 주요 진입점
- `session/student.dart` — 외부에서 `BuildboxCopyWidget` 또는 `StudentDashboardData`를 import할 때 사용

## 주요 비즈니스 함수
- `StudentDashboardData.copyWith(...)`: 대시보드 데이터의 불변 복사본을 생성
- `StudentDashboardData.demo`: 미리 채워진 데모 데이터

## 공통화된 의존성
- `pages/mainpage_widget.dart` 사용 (기존 메인 페이지 이동 버튼)

// HTML 감사 원본 경로와 현재 학습 모드 구현을 연결하는 호환 진입점이다.
//
// 동작·상태·내비게이션은 기존 `study_mode_modal.dart`가 소유한다. 이 파일은
// 화면 원장과 코드 검색이 실제 구현을 놓치지 않도록 공개 API만 재노출한다.
export '../modals/study_mode_modal.dart'
    show showStudyModeModal, StudypageCopyWidget;

// 기능 경로와 세션 경로가 서로 다른 교재 UI를 사용하지 않도록 단일 리더를 노출한다.
//
// 기본 교재보기는 이 경로를 통해 열리므로, student 디자인·통합 개념서·JSXGraph가
// 모두 실제 학생 앱 진입점에 적용된다.
export 'package:s11/sessions/textbook/ui/pages/book_page.dart'
    show
        BookWidget,
        BookLibraryPage,
        BookLibraryModal,
        showBookLibraryModal,
        showCommonBookLibraryModal;

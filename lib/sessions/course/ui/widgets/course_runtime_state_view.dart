import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF173B29);
const _accent = Color(0xFF35A85A);
const _background = Color(0xFFF3F6F3);

/// 코스 내부 모듈이 데이터를 준비하거나 오류를 표시할 때 사용하는 공용 화면이다.
/// 필요 변수: 화면 제목, 안내 문구, 로딩 여부, 오류 내용, 재시도 콜백을 사용한다.
/// 작동 원리: 모든 런타임 진입 화면에 같은 뒤로가기와 상태 카드를 제공해 전환 맥락을 유지한다.
class CourseRuntimeStateView extends StatelessWidget {
  const CourseRuntimeStateView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.loading,
    this.error,
    this.detail,
    this.onRetry,
    this.embedded = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool loading;
  final String? error;
  final String? detail;
  final VoidCallback? onRetry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final hasError = !loading && error != null;
    final card = Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE7DF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120C2918),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (hasError ? Colors.redAccent : _accent).withValues(
                alpha: 0.1,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasError ? Icons.error_outline_rounded : icon,
              size: 34,
              color: hasError ? Colors.redAccent : _accent,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            hasError ? '준비하지 못했어요' : message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasError
                ? error!
                : (detail ?? '학습에 필요한 내용을 확인하고 있습니다. 잠시만 기다려 주세요.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              height: 1.5,
              fontSize: 14,
              color: const Color(0xFF68746C),
            ),
          ),
          const SizedBox(height: 24),
          if (loading)
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              child: LinearProgressIndicator(
                minHeight: 7,
                color: _accent,
                backgroundColor: Color(0xFFE5EEE7),
              ),
            )
          else if (hasError)
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: _ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
        ],
      ),
    );
    if (embedded) return Center(child: card);
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        foregroundColor: _ink,
        leading: IconButton(
          tooltip: '코스로 돌아가기',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: card,
          ),
        ),
      ),
    );
  }
}

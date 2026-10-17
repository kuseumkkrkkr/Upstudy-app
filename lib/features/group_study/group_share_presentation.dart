import '../../shared/services/api/api_client.dart';

/// 공유 선택기에 내부 콘텐츠 키 대신 학생이 이해할 수 있는 제목을 반환한다.
String groupShareTitleForDisplay(SolveHistoryItem item) {
  final rawTitle = item.questTitleRaw?.trim() ?? '';
  if (rawTitle.isNotEmpty && !_looksLikeInternalId(rawTitle)) return rawTitle;
  for (final key in const ['question', 'prompt', 'problem_text', 'statement']) {
    final value = item.data?[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && !_looksLikeInternalId(value)) {
      return value.length > 64 ? '${value.substring(0, 61)}…' : value;
    }
  }
  return '문제 풀이 기록';
}

/// 태그와 현지 시각을 표시하고 원본 ISO 문자열은 UI에 노출하지 않는다.
String groupShareMetadataForDisplay(SolveHistoryItem item) {
  final tags = item.hashTags.map((tag) => '#$tag').join(' · ');
  final date = DateTime.tryParse(item.createdAt)?.toLocal();
  final formattedDate = date == null
      ? '날짜 정보 없음'
      : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return tags.isEmpty ? formattedDate : '$tags · $formattedDate';
}

bool _looksLikeInternalId(String value) =>
    RegExp(r'^[A-Za-z0-9]+(?:[-_/][A-Za-z0-9]+)+$').hasMatch(
      value.replaceFirst(
        RegExp(r'^(문제|question)\s+', caseSensitive: false),
        '',
      ),
    );

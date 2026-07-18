part of 'package:s11/sessions/friend/friend.dart';

const _green = StudentDensityTokens.dark;
const _bgGrey = StudentDensityTokens.background;
const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

BoxDecoration _cardDeco({double radius = 16, Color color = Colors.white}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [_shadow],
    );

BoxDecoration _listCardDeco({
  double radius = 12,
  Color color = Colors.white,
  Color borderColor = const Color(0x1A000000),
  double borderWidth = 1.2,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: borderColor, width: borderWidth),
);

String _formatTimeLabel(DateTime value) {
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${value.month}/${value.day}';
}

/// JSON blocks 형식을 파싱해 ContentBlock 리스트 반환.
List<ContentBlock> _parseQuestBlocks(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['blocks'] as List<dynamic>? ?? [];
    return list
        .whereType<Map>()
        .map(
          (b) => ContentBlock(
            type: b['type']?.toString() ?? 'text',
            content: b['content']?.toString() ?? '',
          ),
        )
        .toList();
  } catch (_) {
    return [ContentBlock(type: 'text', content: raw)];
  }
}

/// 필요 변수: 서버 원본 OVR. 작동 원리: 별도 축 변환 없이 반올림한 동일 점수를 표시한다.
String _formatOvrLabel(double value) {
  if (value.isNaN || value <= 0) return '--';
  return value.round().toString();
}

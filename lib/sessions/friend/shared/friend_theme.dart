part of 'package:s11/sessions/friend/friend.dart';

const _green = Color(0xFF1B402B);
const _bgGrey = Color(0xFFF7F7F7);
const _shadow = BoxShadow(
  blurRadius: 4,
  color: Color(0x33000000),
  offset: Offset(0, 2),
);

TextStyle _ts({
  double size = 16,
  FontWeight weight = FontWeight.normal,
  Color color = Colors.black,
  bool scaleUp = true,
}) => TextStyle(
  fontSize: size * (scaleUp ? 1.1 : 1.0),
  fontWeight: weight,
  color: color,
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

double _uiScale(BuildContext context, {double min = 0.6, double max = 1.0}) {
  final width = MediaQuery.of(context).size.width;
  final scale = width / 1100;
  if (scale < min) return min;
  if (scale > max) return max;
  return scale;
}

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

/// JSON blocks 형식에서 텍스트 파트만 추출해 평문 반환.
String _extractPlainText(String? raw) {
  if (raw == null || raw.isEmpty) return '풀이 내역';
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final blocks = decoded['blocks'] as List<dynamic>? ?? [];
    final text = blocks
        .whereType<Map>()
        .map((b) => b['content']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .join(' ')
        .trim();
    return text.isEmpty ? '풀이 내역' : text;
  } catch (_) {
    return raw.length > 60 ? '${raw.substring(0, 60)}...' : raw;
  }
}

/// Formats a visible OVR score from the server.
/// Returns 'NaN' when the server intentionally hides the score.
String _formatOvrLabel(double value) {
  if (value.isNaN) return 'NaN';
  return value.toStringAsFixed(1);
}

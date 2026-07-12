part of 'package:s11/sessions/friend/friend.dart';

const _green = Color(0xFF1B402B);
const _bgGrey = Color(0xFFF7F7F7);
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

const double _visibleOvrFloor = 1200;
const double _visibleOvrMax = 32767;
const double _visibleOvrDivider = 128;

/// Formats a raw rating into the same visible OVR scale used on the dashboard.
String _formatOvrLabel(double value) {
  if (value.isNaN || value <= 0) return '--';
  if (value < _visibleOvrFloor) return value.toStringAsFixed(1);
  final visible = value - _visibleOvrFloor;
  final ovr = visible.clamp(0, _visibleOvrMax) / _visibleOvrDivider;
  return ovr.toStringAsFixed(1);
}

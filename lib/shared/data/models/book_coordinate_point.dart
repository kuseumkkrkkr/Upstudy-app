/// A bounded integer-grid point. Definition parsing is strict; movement clamps.
class BookCoordinatePoint {
  const BookCoordinatePoint._(this.x, this.y);
  static const minimum = -5, maximum = 5;
  final int x, y;
  factory BookCoordinatePoint.fromJson(Map<String, dynamic> json) {
    if (json.length != 2 || !json.containsKey('x') || !json.containsKey('y')) {
      throw const FormatException('Coordinate point requires x and y only');
    }
    for (final value in json.values) {
      if (value is! int || value < minimum || value > maximum) {
        throw const FormatException('Coordinates require integers -5..5');
      }
    }
    return BookCoordinatePoint._(json['x'] as int, json['y'] as int);
  }
  factory BookCoordinatePoint.bounded(int x, int y) => BookCoordinatePoint._(
    x.clamp(minimum, maximum),
    y.clamp(minimum, maximum),
  );

  /// Match the source Math.round tie rule (toward +infinity), then clamp.
  factory BookCoordinatePoint.snapped(double x, double y) {
    if (!x.isFinite || !y.isFinite) {
      throw ArgumentError('Finite coordinates required');
    }
    return BookCoordinatePoint.bounded((x + .5).floor(), (y + .5).floor());
  }
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  BookCoordinatePoint move(int dx, int dy) =>
      BookCoordinatePoint.bounded(x + dx, y + dy);
  String get quadrant {
    if (x == 0 && y == 0) return '원점';
    if (x == 0) return 'y축 위';
    if (y == 0) return 'x축 위';
    return x > 0 ? (y > 0 ? '제1사분면' : '제4사분면') : (y > 0 ? '제2사분면' : '제3사분면');
  }

  String get horizontal =>
      x == 0 ? '가로 이동 없이' : '${x < 0 ? '왼쪽' : '오른쪽'}으로 ${x.abs()}';
  String get vertical =>
      y == 0 ? '세로 이동 없이' : '${y < 0 ? '아래' : '위'}로 ${y.abs()}';
}

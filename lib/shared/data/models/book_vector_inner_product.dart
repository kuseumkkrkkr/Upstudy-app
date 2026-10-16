/// Bounded vector magnitudes and included angle for a plane inner-product demo.
class BookVectorInnerProduct {
  const BookVectorInnerProduct({
    required this.uLength,
    required this.vLength,
    required this.angleDeg,
  });

  final int uLength;
  final int vLength;
  final int angleDeg;

  factory BookVectorInnerProduct.fromJson(Map<String, dynamic> json) {
    final u = json['u_length'];
    final v = json['v_length'];
    final angle = json['angle_deg'];
    if (u is! int ||
        u < 1 ||
        u > 5 ||
        v is! int ||
        v < 1 ||
        v > 5 ||
        angle is! int ||
        angle < 0 ||
        angle > 180 ||
        angle % 15 != 0) {
      throw const FormatException('Invalid bounded vector inner product');
    }
    return BookVectorInnerProduct(uLength: u, vLength: v, angleDeg: angle);
  }

  Map<String, dynamic> toJson() => {
    'u_length': uLength,
    'v_length': vLength,
    'angle_deg': angleDeg,
  };
}

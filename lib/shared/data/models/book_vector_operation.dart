/// A strict, bounded plane-vector operation. It contains definition only.
class BookVectorOperation {
  const BookVectorOperation({
    required this.operation,
    required this.ux,
    required this.uy,
    required this.vx,
    required this.vy,
    required this.alpha,
  });

  final String operation;
  final int ux, uy, vx, vy;
  final double alpha;

  factory BookVectorOperation.fromJson(Map<String, dynamic> json) {
    final operation = json['operation'];
    int component(String name) {
      final value = json[name];
      if (value is! int || value < -4 || value > 4) {
        throw const FormatException('Invalid bounded vector component');
      }
      return value;
    }

    final rawAlpha = json['alpha'];
    if (operation is! String ||
        !{'add', 'subtract', 'scalar'}.contains(operation) ||
        rawAlpha is! num ||
        !rawAlpha.isFinite ||
        rawAlpha < -2 ||
        rawAlpha > 2 ||
        (rawAlpha * 2 - (rawAlpha * 2).round()).abs() > 1e-9) {
      throw const FormatException('Invalid vector operation definition');
    }
    return BookVectorOperation(
      operation: operation,
      ux: component('ux'),
      uy: component('uy'),
      vx: component('vx'),
      vy: component('vy'),
      alpha: rawAlpha.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'ux': ux,
    'uy': uy,
    'vx': vx,
    'vy': vy,
    'alpha': alpha,
  };
}

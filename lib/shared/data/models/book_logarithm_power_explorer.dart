import 'dart:math' as math;

/// Bounded, author-defined controls for exploring a^x and log_a(y).
/// This payload contains numbers only; it never evaluates author-supplied code.
class BookLogarithmPowerExplorer {
  const BookLogarithmPowerExplorer({
    required this.bases,
    required this.initialBase,
    required this.initialExponent,
    required this.minExponent,
    required this.maxExponent,
    required this.step,
  });

  final List<double> bases;
  final double initialBase;
  final double initialExponent;
  final double minExponent;
  final double maxExponent;
  final double step;

  factory BookLogarithmPowerExplorer.fromJson(Map<String, dynamic> json) {
    Never fail() =>
        throw const FormatException('Invalid logarithm power explorer');
    double number(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 100) fail();
      return value.toDouble();
    }

    final rawBases = json['bases'];
    if (rawBases is! List || rawBases.length < 2 || rawBases.length > 8) {
      fail();
    }
    final bases = rawBases.map(number).toList(growable: false);
    if (bases.toSet().length != bases.length ||
        bases.any((base) => base <= 0 || (base - 1).abs() < 1e-9)) {
      fail();
    }
    final initialBase = number(json['initial_base']);
    final minExponent = number(json['min_exponent']);
    final maxExponent = number(json['max_exponent']);
    final initialExponent = number(json['initial_exponent']);
    final step = number(json['step']);
    if (!bases.contains(initialBase) ||
        minExponent < -4 ||
        maxExponent > 4 ||
        minExponent >= maxExponent ||
        initialExponent < minExponent ||
        initialExponent > maxExponent ||
        step <= 0 ||
        step > 1 ||
        ((maxExponent - minExponent) / step -
                    ((maxExponent - minExponent) / step).round())
                .abs() >
            1e-9) {
      fail();
    }
    return BookLogarithmPowerExplorer(
      bases: List.unmodifiable(bases),
      initialBase: initialBase,
      initialExponent: initialExponent,
      minExponent: minExponent,
      maxExponent: maxExponent,
      step: step,
    );
  }

  Map<String, dynamic> toJson() => {
    'bases': bases,
    'initial_base': initialBase,
    'initial_exponent': initialExponent,
    'min_exponent': minExponent,
    'max_exponent': maxExponent,
    'step': step,
  };

  double valueAt(double exponent) => math.pow(initialBase, exponent).toDouble();
}

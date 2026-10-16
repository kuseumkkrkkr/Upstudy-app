/// Bounded numeric controls for y = sqrt(a*x+b)+c. No executable payloads.
class BookRadicalFunctionExplorer {
  const BookRadicalFunctionExplorer({
    required this.aValues,
    required this.initialA,
    required this.minB,
    required this.maxB,
    required this.bStep,
    required this.initialB,
    required this.minC,
    required this.maxC,
    required this.cStep,
    required this.initialC,
  });

  final List<double> aValues;
  final double initialA,
      minB,
      maxB,
      bStep,
      initialB,
      minC,
      maxC,
      cStep,
      initialC;

  factory BookRadicalFunctionExplorer.fromJson(Map<String, dynamic> json) {
    Never fail() =>
        throw const FormatException('Invalid radical function explorer');
    double numValue(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 10) fail();
      return value.toDouble();
    }

    final raw = json['a_values'];
    if (raw is! List || raw.length < 2 || raw.length > 6) fail();
    final aValues = raw.map(numValue).toList(growable: false);
    final a = numValue(json['initial_a']);
    final minB = numValue(json['min_b']), maxB = numValue(json['max_b']);
    final bStep = numValue(json['b_step']),
        initialB = numValue(json['initial_b']);
    final minC = numValue(json['min_c']), maxC = numValue(json['max_c']);
    final cStep = numValue(json['c_step']),
        initialC = numValue(json['initial_c']);
    bool range(double lo, double hi, double step, double initial) =>
        lo < hi &&
        step > 0 &&
        step <= 1 &&
        initial >= lo &&
        initial <= hi &&
        (((hi - lo) / step) - ((hi - lo) / step).round()).abs() < 1e-9;
    if (aValues.toSet().length != aValues.length ||
        aValues.any((v) => v == 0 || v.abs() > 5) ||
        !aValues.contains(a) ||
        !range(minB, maxB, bStep, initialB) ||
        !range(minC, maxC, cStep, initialC))
      fail();
    return BookRadicalFunctionExplorer(
      aValues: List.unmodifiable(aValues),
      initialA: a,
      minB: minB,
      maxB: maxB,
      bStep: bStep,
      initialB: initialB,
      minC: minC,
      maxC: maxC,
      cStep: cStep,
      initialC: initialC,
    );
  }

  Map<String, dynamic> toJson() => {
    'a_values': aValues,
    'initial_a': initialA,
    'min_b': minB,
    'max_b': maxB,
    'b_step': bStep,
    'initial_b': initialB,
    'min_c': minC,
    'max_c': maxC,
    'c_step': cStep,
    'initial_c': initialC,
  };
}

/// Numeric controls for y = a/(x-h)+k. No executable author content is read.
class BookRationalFunctionExplorer {
  const BookRationalFunctionExplorer({
    required this.aValues,
    required this.initialA,
    required this.minH,
    required this.maxH,
    required this.hStep,
    required this.initialH,
    required this.minK,
    required this.maxK,
    required this.kStep,
    required this.initialK,
  });

  final List<double> aValues;
  final double initialA,
      minH,
      maxH,
      hStep,
      initialH,
      minK,
      maxK,
      kStep,
      initialK;

  factory BookRationalFunctionExplorer.fromJson(Map<String, dynamic> json) {
    Never fail() =>
        throw const FormatException('Invalid rational function explorer');
    double number(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 10) fail();
      return value.toDouble();
    }

    final raw = json['a_values'];
    if (raw is! List || raw.length < 2 || raw.length > 6) fail();
    final aValues = raw.map(number).toList(growable: false);
    final initialA = number(json['initial_a']);
    final minH = number(json['min_h']), maxH = number(json['max_h']);
    final hStep = number(json['h_step']), initialH = number(json['initial_h']);
    final minK = number(json['min_k']), maxK = number(json['max_k']);
    final kStep = number(json['k_step']), initialK = number(json['initial_k']);
    bool validRange(double min, double max, double step, double initial) =>
        min < max &&
        step > 0 &&
        step <= 1 &&
        initial >= min &&
        initial <= max &&
        (((max - min) / step) - ((max - min) / step).round()).abs() < 1e-9;
    if (aValues.toSet().length != aValues.length ||
        aValues.any((a) => a == 0 || a.abs() > 5) ||
        !aValues.contains(initialA) ||
        !validRange(minH, maxH, hStep, initialH) ||
        !validRange(minK, maxK, kStep, initialK)) {
      fail();
    }
    return BookRationalFunctionExplorer(
      aValues: List.unmodifiable(aValues),
      initialA: initialA,
      minH: minH,
      maxH: maxH,
      hStep: hStep,
      initialH: initialH,
      minK: minK,
      maxK: maxK,
      kStep: kStep,
      initialK: initialK,
    );
  }

  Map<String, dynamic> toJson() => {
    'a_values': aValues,
    'initial_a': initialA,
    'min_h': minH,
    'max_h': maxH,
    'h_step': hStep,
    'initial_h': initialH,
    'min_k': minK,
    'max_k': maxK,
    'k_step': kStep,
    'initial_k': initialK,
  };
}

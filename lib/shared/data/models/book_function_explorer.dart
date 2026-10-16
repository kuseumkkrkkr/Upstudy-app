import 'dart:math' as math;

enum BookFunctionKind { radical, rational, power }

/// Immutable numeric controls for three fixed formulas; no author expressions.
class BookFunctionExplorer {
  const BookFunctionExplorer._(
    this.kind,
    this.values,
    this.initialCoefficient,
    this.minU,
    this.maxU,
    this.stepU,
    this.initialU,
    this.minV,
    this.maxV,
    this.stepV,
    this.initialV,
  );

  final BookFunctionKind kind;
  final List<double> values;
  final double initialCoefficient, minU, maxU, stepU, initialU;
  final double minV, maxV, stepV, initialV;
  bool get isPower => kind == BookFunctionKind.power;
  String get uName => isPower
      ? 'exponent'
      : kind == BookFunctionKind.radical
      ? 'b'
      : 'h';
  String get vName => kind == BookFunctionKind.radical ? 'c' : 'k';

  factory BookFunctionExplorer.fromJson(
    String activityKind,
    Map<String, dynamic> json,
  ) {
    Never fail() =>
        throw const FormatException('Invalid bounded function explorer');
    final kind = switch (activityKind) {
      'radicalFunctionExplorer' => BookFunctionKind.radical,
      'rationalFunctionExplorer' => BookFunctionKind.rational,
      'logarithmPowerExplorer' => BookFunctionKind.power,
      _ => fail(),
    };
    final power = kind == BookFunctionKind.power;
    final names = power
        ? ['exponent']
        : kind == BookFunctionKind.radical
        ? ['b', 'c']
        : ['h', 'k'];
    final allowed = power
        ? {'bases', 'initial_base'}
        : {'a_values', 'initial_a'};
    for (final name in names) {
      allowed.addAll({
        'min_$name',
        'max_$name',
        'initial_$name',
        power ? 'step' : '${name}_step',
      });
    }
    if (json.length != allowed.length ||
        json.keys.any((key) => !allowed.contains(key))) {
      fail();
    }
    double number(dynamic value, [double bound = 10]) {
      if (value is! num || !value.isFinite || value.abs() > bound) fail();
      return value.toDouble();
    }

    final raw = json[power ? 'bases' : 'a_values'];
    if (raw is! List || raw.length < 2 || raw.length > (power ? 8 : 6)) fail();
    final values = raw.map((value) => number(value, power ? 100 : 5)).toList();
    if (values.toSet().length != values.length ||
        values.any(
          (value) =>
              power ? value <= 0 || (value - 1).abs() < 1e-9 : value.abs() < .1,
        )) {
      fail();
    }
    final coefficient = number(
      json[power ? 'initial_base' : 'initial_a'],
      power ? 100 : 5,
    );
    if (!values.contains(coefficient)) fail();
    final ranges = <List<double>>[];
    for (final name in names) {
      final lo = number(json['min_$name']), hi = number(json['max_$name']);
      final step = number(json[power ? 'step' : '${name}_step']);
      final start = number(json['initial_$name']);
      if (lo >= hi || step <= 0 || step > 1 || start < lo || start > hi) fail();
      final divisions = (hi - lo) / step, offset = (start - lo) / step;
      if (divisions < 1 ||
          divisions > 400 ||
          (divisions - divisions.round()).abs() > 1e-9 ||
          (offset - offset.round()).abs() > 1e-9) {
        fail();
      }
      if (power) {
        if (lo < -4 || hi > 4) fail();
        for (final base in values) {
          for (final exponent in [lo, hi]) {
            final result = math.pow(base, exponent).toDouble();
            if (!result.isFinite || result < 1e-6 || result > 1e6) fail();
          }
        }
      }
      ranges.add([lo, hi, step, start]);
    }
    final u = ranges.first, v = power ? [0.0, 0.0, 1.0, 0.0] : ranges.last;
    return BookFunctionExplorer._(
      kind,
      List.unmodifiable(values),
      coefficient,
      u[0],
      u[1],
      u[2],
      u[3],
      v[0],
      v[1],
      v[2],
      v[3],
    );
  }

  Map<String, dynamic> toJson() => {
    isPower ? 'bases' : 'a_values': values,
    isPower ? 'initial_base' : 'initial_a': initialCoefficient,
    'min_$uName': minU,
    'max_$uName': maxU,
    isPower ? 'step' : '${uName}_step': stepU,
    'initial_$uName': initialU,
    if (!isPower) ...{
      'min_$vName': minV,
      'max_$vName': maxV,
      '${vName}_step': stepV,
      'initial_$vName': initialV,
    },
  };

  double? valueAt(double x, double coefficient, double u, double v) {
    final result = switch (kind) {
      BookFunctionKind.power => math.pow(coefficient, x).toDouble(),
      BookFunctionKind.radical =>
        coefficient * x + u < 0
            ? double.nan
            : math.sqrt(coefficient * x + u) + v,
      BookFunctionKind.rational =>
        x == u ? double.nan : coefficient / (x - u) + v,
    };
    return result.isFinite ? result : null;
  }
}

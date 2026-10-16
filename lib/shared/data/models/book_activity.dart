import 'book_discrete_experiment.dart';
import 'book_statistics_estimator.dart';
import 'book_coordinate_point.dart';

/// Registered V2 practice, not an exam/OVR grading authority. No executable data.
class BookActivity {
  const BookActivity._(
    this.id,
    this.kind,
    this.prompt,
    this.hints,
    this.options,
    this.correctIndex,
    this.answer,
    this.tolerance,
    this.correctFeedback,
    this.incorrectFeedback,
    this.steps,
    this.p,
    this.x,
    this.experiment,
    this.statistics,
    this.legA,
    this.legB,
    this.point,
  );

  final String id, kind, prompt, correctFeedback, incorrectFeedback;
  final List<String> hints, options, steps;
  final int? correctIndex;
  final double? answer;
  final double tolerance, p, x;
  final BookDiscreteExperiment? experiment;
  final BookStatisticsEstimator? statistics;
  final int legA, legB;
  final BookCoordinatePoint? point;

  factory BookActivity.fromJson(Map<String, dynamic> json) {
    Never fail() =>
        throw const FormatException('Unsupported BookData activity');
    String text(dynamic value, [int limit = 2000]) {
      if (value is! String || value.trim().isEmpty || value.length > limit) {
        fail();
      }
      return value;
    }

    List<String> texts(dynamic value, int low, int high) {
      if (value is! List || value.length < low || value.length > high) fail();
      return List.unmodifiable(value.map((item) => text(item)));
    }

    double number(dynamic value) {
      if (value is! num || !value.isFinite || value.abs() > 1e6) fail();
      return value.toDouble();
    }

    final kind = json['kind'];
    final allowed = {'id', 'kind', 'prompt', 'hints'};
    var options = const <String>[];
    var steps = const <String>[];
    int? index;
    double? answer;
    double tolerance = 0, p = 2, x = 4;
    var correct = '', incorrect = '';
    BookDiscreteExperiment? experiment;
    BookStatisticsEstimator? statistics;
    var legA = 6, legB = 8;
    BookCoordinatePoint? point;
    switch (kind) {
      case 'quiz':
        allowed.addAll({
          'options',
          'correct_index',
          'answer',
          'tolerance',
          'correct_feedback',
          'incorrect_feedback',
        });
        correct = text(json['correct_feedback']);
        incorrect = text(json['incorrect_feedback']);
        if (json.containsKey('options')) {
          options = texts(json['options'], 2, 6);
          final candidate = json['correct_index'];
          if (candidate is! int ||
              candidate < 0 ||
              candidate >= options.length ||
              json.containsKey('answer') ||
              json.containsKey('tolerance')) {
            fail();
          }
          index = candidate;
        } else {
          answer = number(json['answer']);
          tolerance = number(
            json.containsKey('tolerance') ? json['tolerance'] : 0,
          );
          if (tolerance < 0 || json.containsKey('correct_index')) fail();
        }
      case 'discreteExperiment':
        allowed.add('experiment');
        final payload = json['experiment'];
        if (payload is! Map) fail();
        experiment = BookDiscreteExperiment.fromJson(
          Map<String, dynamic>.from(payload),
        );
      case 'statisticsEstimator':
        allowed.add('statistics');
        final payload = json['statistics'];
        if (payload is! Map) fail();
        statistics = BookStatisticsEstimator.fromJson(
          Map<String, dynamic>.from(payload),
        );
      case 'coordinatePoint':
        allowed.addAll({'x', 'y'});
        point = BookCoordinatePoint.fromJson({'x': json['x'], 'y': json['y']});
      case 'rightTriangle':
        allowed.addAll({'a', 'b'});
        int leg(dynamic value) {
          if (value is! int || value < 1 || value > 12) fail();
          return value;
        }
        legA = leg(json['a']);
        legB = leg(json['b']);
      case 'steps':
        allowed.add('steps');
        steps = texts(json['steps'], 1, 12);
      case 'parabolaDistance':
        allowed.addAll({'p', 'x'});
        p = number(json['p']);
        x = number(json['x']);
        if (p < .5 || p > 3 || x < -4 || x > 4) fail();
      default:
        fail();
    }
    if (json.keys.any((key) => !allowed.contains(key))) fail();
    return BookActivity._(
      text(json['id'], 80),
      kind as String,
      text(json['prompt']),
      texts(json.containsKey('hints') ? json['hints'] : [], 0, 8),
      options,
      index,
      answer,
      tolerance,
      correct,
      incorrect,
      steps,
      p,
      x,
      experiment,
      statistics,
      legA,
      legB,
      point,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'prompt': prompt,
    'hints': hints,
    if (kind == 'quiz') ...{
      'correct_feedback': correctFeedback,
      'incorrect_feedback': incorrectFeedback,
      if (options.isNotEmpty) ...{
        'options': options,
        'correct_index': correctIndex,
      } else ...{
        'answer': answer,
        'tolerance': tolerance,
      },
    },
    if (kind == 'steps') 'steps': steps,
    if (kind == 'parabolaDistance') ...{'p': p, 'x': x},
    if (experiment != null) 'experiment': experiment!.toJson(),
    if (statistics != null) 'statistics': statistics!.toJson(),
    if (kind == 'rightTriangle') ...{'a': legA, 'b': legB},
    if (point != null) ...point!.toJson(),
  };

  /// Finite decimal or a single fraction only; no evaluation of author/user code.
  static double? numericInput(String source) {
    final parts = source.trim().split('/');
    if (parts.isEmpty || parts.length > 2 || source.length > 80) return null;
    final numerator = double.tryParse(parts.first.trim());
    final denominator = parts.length == 1
        ? 1.0
        : double.tryParse(parts.last.trim());
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    final value = numerator / denominator;
    return value.isFinite ? value : null;
  }
}

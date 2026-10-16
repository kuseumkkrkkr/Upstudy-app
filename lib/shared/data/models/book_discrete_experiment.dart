import 'dart:math' as math;

/// Finite weighted outcomes only. No author scripts, remote RNG, or grading writes.
class BookDiscreteExperiment {
  const BookDiscreteExperiment._(
    this.outcomes,
    this.maxTrials,
    this.batchSizes,
  );
  final List<BookExperimentOutcome> outcomes;
  final int maxTrials;
  final List<int> batchSizes;

  factory BookDiscreteExperiment.fromJson(Map<String, dynamic> json) {
    Never invalid() =>
        throw const FormatException('Invalid discrete experiment');
    if (json.keys.any(
      (key) => !{'outcomes', 'max_trials', 'batch_sizes'}.contains(key),
    )) {
      invalid();
    }
    final raw = json['outcomes'];
    if (raw is! List || raw.length < 2 || raw.length > 32) invalid();
    final outcomes = <BookExperimentOutcome>[];
    final labels = <String>{};
    for (final entry in raw) {
      if (entry is! Map ||
          entry.keys.any(
            (key) => !{'label', 'weight', 'success'}.contains(key),
          )) {
        invalid();
      }
      final label = entry['label'],
          weight = entry.containsKey('weight') ? entry['weight'] : 1,
          success = entry['success'];
      if (label is! String ||
          label.trim().isEmpty ||
          label.length > 120 ||
          !labels.add(label) ||
          weight is! num ||
          !weight.isFinite ||
          weight < 0 ||
          weight > 1e6 ||
          success is! bool) {
        invalid();
      }
      outcomes.add(BookExperimentOutcome(label, weight.toDouble(), success));
    }
    if (outcomes.fold<double>(0, (sum, o) => sum + o.weight) <= 0) invalid();
    final maximum = json.containsKey('max_trials') ? json['max_trials'] : 10000;
    if (maximum is! int || maximum < 1 || maximum > 100000) invalid();
    final batches = json.containsKey('batch_sizes') ? json['batch_sizes'] : [1];
    if (batches is! List ||
        batches.isEmpty ||
        batches.length > 4 ||
        batches.any((n) => n is! int || n < 1 || n > math.min(1000, maximum)) ||
        batches.toSet().length != batches.length) {
      invalid();
    }
    return BookDiscreteExperiment._(
      List.unmodifiable(outcomes),
      maximum,
      List<int>.unmodifiable(batches),
    );
  }

  Map<String, dynamic> toJson() => {
    'outcomes': outcomes.map((o) => o.toJson()).toList(),
    'max_trials': maxTrials,
    'batch_sizes': batchSizes,
  };

  /// Select one bounded outcome. Zero-weight outcomes cannot be sampled.
  int sample(math.Random random) {
    var remaining =
        random.nextDouble() *
        outcomes.fold<double>(0, (sum, o) => sum + o.weight);
    var fallback = 0;
    for (var i = 0; i < outcomes.length; i++) {
      if (outcomes[i].weight <= 0) continue;
      fallback = i;
      if (remaining < outcomes[i].weight) return i;
      remaining -= outcomes[i].weight;
    }
    return fallback;
  }
}

class BookExperimentOutcome {
  const BookExperimentOutcome(this.label, this.weight, this.success);
  final String label;
  final double weight;
  final bool success;
  Map<String, dynamic> toJson() => {
    'label': label,
    'weight': weight,
    'success': success,
  };
}

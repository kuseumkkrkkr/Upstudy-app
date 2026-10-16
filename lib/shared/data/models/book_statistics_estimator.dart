/// Bounded sample definition, not a population fact or a confidence interval.
class BookStatisticsEstimator {
  const BookStatisticsEstimator._(
    this.mode,
    this.samples,
    this.successes,
    this.trials,
  );
  final String mode;
  final List<double> samples;
  final int successes, trials;
  factory BookStatisticsEstimator.fromJson(Map<String, dynamic> json) {
    Never invalid() =>
        throw const FormatException('Invalid statistics estimator');
    final mode = json['mode'];
    if (mode == 'mean') {
      if (json.keys.any((key) => !{'mode', 'sample_values'}.contains(key))) {
        invalid();
      }
      final raw = json['sample_values'];
      if (raw is! List ||
          raw.isEmpty ||
          raw.length > 200 ||
          raw.any((v) => v is! num || !v.isFinite || v.abs() > 1e6)) {
        invalid();
      }
      return BookStatisticsEstimator._(
        mode,
        List<double>.unmodifiable(raw.map((v) => (v as num).toDouble())),
        0,
        0,
      );
    }
    if (mode == 'proportion') {
      if (json.keys.any(
        (key) => !{'mode', 'successes', 'trials'}.contains(key),
      )) {
        invalid();
      }
      final successes = json['successes'], trials = json['trials'];
      if (trials is! int ||
          trials < 1 ||
          trials > 100000 ||
          successes is! int ||
          successes < 0 ||
          successes > trials) {
        invalid();
      }
      return BookStatisticsEstimator._(mode, const [], successes, trials);
    }
    invalid();
  }
  Map<String, dynamic> toJson() => {
    'mode': mode,
    if (mode == 'mean')
      'sample_values': samples
    else ...{
      'successes': successes,
      'trials': trials,
    },
  };
}

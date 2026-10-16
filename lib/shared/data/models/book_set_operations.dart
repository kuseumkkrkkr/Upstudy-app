/// Six-element, two-set exploration. No expressions, scripts or persisted answers.
class BookSetOperations {
  const BookSetOperations._(this.a, this.b, this.operation);
  final List<int> a, b;
  final String operation;
  static const operations = [
    'intersection',
    'union',
    'difference',
    'complement',
  ];
  static const labels = ['A∩B', 'A∪B', 'A\\B', 'Aᶜ'];
  static const universe = [1, 2, 3, 4, 5, 6];

  factory BookSetOperations.fromJson(Map<String, dynamic> json) {
    Never fail() => throw const FormatException('Invalid set operation');
    final u = json['universe'];
    if (u is! List || u.length != 6) fail();
    for (var i = 0; i < 6; i++) {
      if (u[i] is! int || u[i] != i + 1) fail();
    }
    List<int> members(dynamic value) {
      if (value is! List ||
          value.length > 6 ||
          value.any((n) => n is! int || n < 1 || n > 6) ||
          value.toSet().length != value.length) {
        fail();
      }
      return List<int>.unmodifiable(value.cast<int>());
    }

    final operation = json['operation'];
    if (!operations.contains(operation)) fail();
    return BookSetOperations._(
      members(json['set_a']),
      members(json['set_b']),
      operation as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'universe': universe,
    'set_a': a,
    'set_b': b,
    'operation': operation,
  };

  /// Stable universe order; complement always uses the declared fixed universe.
  static List<int> result(Set<int> a, Set<int> b, String operation) => universe
      .where(
        (n) => switch (operation) {
          'intersection' => a.contains(n) && b.contains(n),
          'union' => a.contains(n) || b.contains(n),
          'difference' => a.contains(n) && !b.contains(n),
          'complement' => !a.contains(n),
          _ => throw const FormatException('Invalid set operation'),
        },
      )
      .toList();
}

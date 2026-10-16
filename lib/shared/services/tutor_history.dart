/// Successful exchanges only, kept in memory for one page/session.
/// Limits use Unicode code points, matching the server rather than UTF-16 units.
class TutorHistory {
  static const maxTurns = 8;
  static const maxCharacters = 6000;
  static const maxTurnCharacters = 2000;
  final List<Map<String, String>> _turns = [];

  /// Fresh list and immutable turn maps; caller edits cannot rewrite stored turns.
  List<Map<String, String>> get snapshot => [
    for (final turn in _turns) Map<String, String>.unmodifiable(turn),
  ];

  /// Erases page/session memory, with no server or model-provider deletion claim.
  void clear() => _turns.clear();

  /// Records one acknowledged exchange, trimming text and evicting whole pairs.
  /// Blank inputs are not a successful exchange and are ignored.
  void rememberExchange(String user, String assistant) {
    final a = _bounded(user);
    final b = _bounded(assistant);
    if (a.isEmpty || b.isEmpty) return;
    _turns.addAll([
      {'role': 'user', 'content': a},
      {'role': 'assistant', 'content': b},
    ]);
    while (_turns.length > maxTurns ||
        _turns.fold<int>(0, (n, turn) => n + turn['content']!.runes.length) >
            maxCharacters) {
      _turns.removeRange(0, 2);
    }
  }

  String _bounded(String value) {
    final runes = value.trim().runes.take(maxTurnCharacters + 1).toList();
    if (runes.length <= maxTurnCharacters) return String.fromCharCodes(runes);
    return '${String.fromCharCodes(runes.take(maxTurnCharacters - 1))}…';
  }
}

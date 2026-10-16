import 'package:flutter/material.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';
import 'package:s11/shared/data/models/book_activity.dart';

/// Renders supported practice activities and keeps an explicit fallback for
/// unsupported kinds. The containing model retains the original payload.
class TextbookActivityBlock extends StatefulWidget {
  const TextbookActivityBlock({super.key, required this.activity});

  final Map<String, dynamic> activity;

  @override
  State<TextbookActivityBlock> createState() => _TextbookActivityBlockState();
}

class _TextbookActivityBlockState extends State<TextbookActivityBlock> {
  int? _selectedIndex;
  bool _submitted = false;
  bool _showHints = false;

  @override
  void didUpdateWidget(covariant TextbookActivityBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.activity, widget.activity)) {
      _selectedIndex = null;
      _submitted = false;
      _showHints = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final kind = activity['kind']?.toString() ?? 'unknown';
    final prompt = activity['prompt']?.toString().trim() ?? '';
    final options = _stringList(activity['options']);
    final correctValue = activity['correct_index'];
    final correctIndex = correctValue is num ? correctValue.toInt() : -1;
    final isValidQuiz =
        kind == 'quiz' &&
        prompt.isNotEmpty &&
        options.length >= 2 &&
        correctIndex >= 0 &&
        correctIndex < options.length;
    if (kind != 'quiz' || !activity.containsKey('options')) {
      try {
        return BookActivityView(activity: BookActivity.fromJson(activity));
      } on FormatException {
        // Keep malformed or future payloads visible without executing them.
      }
    }
    final colors = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey('textbook-activity-${activity['id'] ?? kind}'),
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isValidQuiz
            ? _buildQuiz(context, activity, prompt, options, correctIndex)
            : _buildUnsupported(context, activity, kind, prompt),
      ),
    );
  }

  Widget _buildQuiz(
    BuildContext context,
    Map<String, dynamic> activity,
    String prompt,
    List<String> options,
    int correctIndex,
  ) {
    final colors = Theme.of(context).colorScheme;
    final hints = _stringList(activity['hints']);
    final isCorrect = _submitted && _selectedIndex == correctIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.quiz_outlined, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              '확인 퀴즈',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(prompt, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: _submitted,
          child: RadioGroup<int>(
            groupValue: _selectedIndex,
            onChanged: (value) {
              if (!_submitted) setState(() => _selectedIndex = value);
            },
            child: Column(
              children: [
                for (var index = 0; index < options.length; index++)
                  RadioListTile<int>(
                    key: ValueKey('quiz-option-$index'),
                    value: index,
                    title: Text(options[index]),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _selectedIndex == null || _submitted
                  ? null
                  : () => setState(() => _submitted = true),
              child: const Text('정답 확인'),
            ),
            if (_submitted)
              OutlinedButton(
                onPressed: () => setState(() {
                  _selectedIndex = null;
                  _submitted = false;
                }),
                child: const Text('다시 풀기'),
              ),
            if (hints.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _showHints = !_showHints),
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(_showHints ? '힌트 숨기기' : '힌트 보기'),
              ),
          ],
        ),
        if (_submitted) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              (isCorrect
                              ? activity['correct_feedback']
                              : activity['incorrect_feedback'])
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? (isCorrect
                            ? activity['correct_feedback']
                            : activity['incorrect_feedback'])
                        .toString()
                  : (isCorrect ? '정답입니다.' : '다시 생각해 보세요.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isCorrect ? Colors.green.shade800 : colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_showHints) ...[
          const SizedBox(height: 8),
          for (var index = 0; index < hints.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${index + 1}. ${hints[index]}'),
            ),
        ],
      ],
    );
  }

  Widget _buildUnsupported(
    BuildContext context,
    Map<String, dynamic> activity,
    String kind,
    String prompt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지원하지 않는 활동: $kind',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (prompt.isNotEmpty) ...[const SizedBox(height: 8), Text(prompt)],
        const SizedBox(height: 6),
        const Text('활동 데이터는 보존되어 있으며, 이 화면에서는 실행할 수 없습니다.'),
        if (activity['hints'] is List) ...[
          for (final hint in _stringList(activity['hints']))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('힌트: $hint'),
            ),
        ],
      ],
    );
  }

  List<String> _stringList(dynamic value) => value is List
      ? value
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];
}

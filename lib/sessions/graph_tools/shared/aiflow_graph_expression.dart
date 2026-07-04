import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

class AiFlowExpressionValidationResult {
  const AiFlowExpressionValidationResult({
    required this.isValid,
    required this.normalizedExpression,
    this.errorMessage,
  });

  final bool isValid;
  final String normalizedExpression;
  final String? errorMessage;
}

String normalizeAiFlowExpression(String source) {
  var expression = source.trim();
  expression = expression.replaceFirst(RegExp(r'^y\s*=\s*', caseSensitive: false), '');
  expression = expression.replaceAllMapped(
    RegExp(r'\bPI\b', caseSensitive: false),
    (_) => 'pi',
  );
  expression = expression.replaceAllMapped(
    RegExp(r'\bE\b', caseSensitive: false),
    (_) => 'e',
  );
  return expression;
}

AiFlowExpressionValidationResult validateAiFlowExpression(
  String source, {
  bool degreeMode = false,
  Map<String, double> parameters = const <String, double>{},
}) {
  final normalized = normalizeAiFlowExpression(source);
  if (normalized.isEmpty) {
    return const AiFlowExpressionValidationResult(
      isValid: false,
      normalizedExpression: '',
      errorMessage: '식을 입력하세요.',
    );
  }

  final parser = GrammarParser();
  try {
    final expression = parser.parse(_toValidationSyntax(normalized, degreeMode: degreeMode));
    final context = ContextModel()..bindVariableName('e', Number(math.e));
    for (final entry in parameters.entries) {
      context.bindVariableName(entry.key, Number(entry.value));
    }
    final evaluator = RealEvaluator(context);
    final sampleXs = <double>[-4, -2, -1, -0.5, 0, 0.5, 1, 2, 4];

    var finiteValueCount = 0;
    for (final x in sampleXs) {
      context.bindVariableName('x', Number(x));
      final value = evaluator.evaluate(expression);
      if (value.isFinite) {
        finiteValueCount += 1;
      }
    }

    if (finiteValueCount == 0) {
      return AiFlowExpressionValidationResult(
        isValid: false,
        normalizedExpression: normalized,
        errorMessage: '표시 가능한 실수값이 나오지 않습니다.',
      );
    }
  } catch (_) {
    return AiFlowExpressionValidationResult(
      isValid: false,
      normalizedExpression: normalized,
      errorMessage: '지원되는 형식으로 다시 입력하세요. 예: sin(x), x^2-1, log(x)',
    );
  }

  return AiFlowExpressionValidationResult(
    isValid: true,
    normalizedExpression: normalized,
  );
}

String _toValidationSyntax(String source, {required bool degreeMode}) {
  var expression = source;
  if (degreeMode) {
    expression = _replaceUnaryFunction(
      expression,
      functionName: 'sin',
      replacement: '(sin((#) * pi / 180))',
    );
    expression = _replaceUnaryFunction(
      expression,
      functionName: 'cos',
      replacement: '(cos((#) * pi / 180))',
    );
    expression = _replaceUnaryFunction(
      expression,
      functionName: 'tan',
      replacement: '(tan((#) * pi / 180))',
    );
  }

  expression = _replaceUnaryFunction(
    expression,
    functionName: 'log',
    replacement: '(ln(#) / ln(10))',
  );

  return expression;
}

String _replaceUnaryFunction(
  String expression, {
  required String functionName,
  required String replacement,
}) {
  var cursor = 0;
  final buffer = StringBuffer();
  while (cursor < expression.length) {
    final match = RegExp(
      '$functionName\\s*\\(',
      caseSensitive: false,
    ).matchAsPrefix(expression, cursor);
    if (match == null) {
      buffer.write(expression[cursor]);
      cursor += 1;
      continue;
    }

    final start = expression.indexOf('(', match.start);
    final end = _findClosingParenthesis(expression, start);
    if (end == -1) {
      throw const FormatException('Unmatched parenthesis');
    }

    final inner = expression.substring(start + 1, end);
    final replacedInner = _replaceUnaryFunction(
      inner,
      functionName: functionName,
      replacement: replacement,
    );
    buffer.write(replacement.replaceFirst('#', replacedInner));
    cursor = end + 1;
  }
  return buffer.toString();
}

int _findClosingParenthesis(String expression, int openIndex) {
  var depth = 0;
  for (var index = openIndex; index < expression.length; index += 1) {
    final char = expression[index];
    if (char == '(') {
      depth += 1;
    } else if (char == ')') {
      depth -= 1;
      if (depth == 0) {
        return index;
      }
    }
  }
  return -1;
}

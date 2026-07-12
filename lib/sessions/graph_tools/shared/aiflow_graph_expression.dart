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
  expression = expression.replaceFirst(
    RegExp(r'^y\s*=\s*', caseSensitive: false),
    '',
  );
  expression = expression
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll('π', 'pi');
  expression = expression.replaceAllMapped(
    RegExp(r'\bPI\b', caseSensitive: false),
    (_) => 'pi',
  );
  expression = expression.replaceAllMapped(
    RegExp(r'\bE\b', caseSensitive: false),
    (_) => 'e',
  );
  return _insertImplicitMultiplication(expression);
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
    final expression = parser.parse(
      _toValidationSyntax(normalized, degreeMode: degreeMode),
    );
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

String _insertImplicitMultiplication(String source) {
  final tokens = _tokenizeExpression(source);
  if (tokens.length < 2) {
    return source.replaceAll(RegExp(r'\s+'), '');
  }

  final buffer = StringBuffer();
  for (var i = 0; i < tokens.length; i += 1) {
    final token = tokens[i];
    if (i > 0 && _needsMultiplication(tokens[i - 1], token)) {
      buffer.write('*');
    }
    buffer.write(token.text);
  }
  return buffer.toString();
}

List<_ExpressionToken> _tokenizeExpression(String source) {
  final tokens = <_ExpressionToken>[];
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    if (char.trim().isEmpty) {
      index += 1;
      continue;
    }
    if (_isDigit(char) || char == '.') {
      final start = index;
      index += 1;
      while (index < source.length &&
          (_isDigit(source[index]) || source[index] == '.')) {
        index += 1;
      }
      tokens.add(
        _ExpressionToken(source.substring(start, index), _TokenKind.number),
      );
      continue;
    }
    if (_isIdentifierStart(char)) {
      final start = index;
      index += 1;
      while (index < source.length && _isIdentifierPart(source[index])) {
        index += 1;
      }
      tokens.add(
        _ExpressionToken(source.substring(start, index), _TokenKind.identifier),
      );
      continue;
    }
    if (char == '(') {
      tokens.add(const _ExpressionToken('(', _TokenKind.openParen));
    } else if (char == ')') {
      tokens.add(const _ExpressionToken(')', _TokenKind.closeParen));
    } else {
      tokens.add(_ExpressionToken(char, _TokenKind.operator));
    }
    index += 1;
  }
  return tokens;
}

bool _needsMultiplication(_ExpressionToken left, _ExpressionToken right) {
  if (!_canEndFactor(left) || !_canStartFactor(right)) {
    return false;
  }
  if (left.kind == _TokenKind.identifier &&
      right.kind == _TokenKind.openParen &&
      _functionNames.contains(left.text.toLowerCase())) {
    return false;
  }
  return true;
}

bool _canEndFactor(_ExpressionToken token) =>
    token.kind == _TokenKind.number ||
    token.kind == _TokenKind.identifier ||
    token.kind == _TokenKind.closeParen;

bool _canStartFactor(_ExpressionToken token) =>
    token.kind == _TokenKind.number ||
    token.kind == _TokenKind.identifier ||
    token.kind == _TokenKind.openParen;

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

bool _isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);
  return (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      char == '_';
}

bool _isIdentifierPart(String char) =>
    _isIdentifierStart(char) || _isDigit(char);

const _functionNames = <String>{
  'abs',
  'acos',
  'asin',
  'atan',
  'ceil',
  'cos',
  'exp',
  'floor',
  'ln',
  'log',
  'max',
  'min',
  'pow',
  'round',
  'sin',
  'sqrt',
  'tan',
};

enum _TokenKind { number, identifier, openParen, closeParen, operator }

class _ExpressionToken {
  const _ExpressionToken(this.text, this.kind);

  final String text;
  final _TokenKind kind;
}

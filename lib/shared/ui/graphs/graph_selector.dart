import 'package:flutter/material.dart';

import 'interactive_trigonometric_graph.dart';
import 'quadratic_graph.dart';
import 'exponential_graph.dart';
import 'logarithmic_graph.dart';
import 'rational_graph.dart';
import 'irrational_graph.dart';
import 'derivative_graph.dart';

Widget? selectGraphForTags(List<String> tags) {
  final normalized = tags.map((t) => t.replaceFirst('#', '').trim().toLowerCase()).toList();

  final candidates = <String, Widget>{
    '도함수': const RepaintBoundary(child: InteractiveDerivativeGraph()),
    '이차함수': const RepaintBoundary(child: InteractiveQuadraticGraph()),
    '지수함수': const RepaintBoundary(child: InteractiveExponentialGraph()),
    '로그함수': const RepaintBoundary(child: InteractiveLogarithmicGraph()),
    '유리함수': const RepaintBoundary(child: InteractiveRationalGraph()),
    '무리함수': const RepaintBoundary(child: InteractiveIrrationalGraph()),
    '삼각함수': const RepaintBoundary(child: InteractiveTrigonometricGraph()),
  };

  for (final entry in candidates.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }

  if (normalized.any((t) => t.contains('삼각') || t.contains('코사인') || t.contains('사인') || t.contains('탄젠트'))) {
    return const RepaintBoundary(child: InteractiveTrigonometricGraph());
  }

  return null;
}

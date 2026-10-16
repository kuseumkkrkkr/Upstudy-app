import 'aiflow_graph_document.dart';

/// Validates an observed runtime snapshot, never mutating author initial values.
Map<String, double>? validateGraphParameters(
  AiFlowGraphDocument document,
  Object? values,
) {
  final parameters = document.settings.parameters;
  if (values is! Map || parameters.isEmpty || parameters.length > 16 ||
      values.length != parameters.length) {
    return null;
  }
  final result = <String, double>{};
  var observers = 0;
  for (final parameter in parameters) {
    final id = parameter.id;
    final value = values[id];
    if (parameter.role != 'coefficient' && parameter.role != 'observationX') {
      return null;
    }
    if (parameter.role == 'observationX' && ++observers > 1) return null;
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,31}$').hasMatch(id) ||
        const {'abs', 'max', 'min', 'sqrt', 'pow', 'exp', 'ln', 'log', 'sin',
          'cos', 'tan', 'ceil', 'floor', 'round', 'x', 'y', 'pi', 'e',
          'constructor', 'prototype', '__proto__', 'window', 'parent',
          'document', 'globalThis', 'this'}.contains(id) ||
        result.containsKey(id) || value is! num || !value.isFinite ||
        !parameter.min.isFinite || !parameter.max.isFinite ||
        parameter.min > parameter.max || value < parameter.min ||
        value > parameter.max || value.abs() > 1e9 ||
        parameter.min.abs() > 1e9 || parameter.max.abs() > 1e9) {
      return null;
    }
    result[id] = value.toDouble();
  }
  return Map.unmodifiable(result);
}

/// Drops messages from an earlier document revision; callers also bind source.
Map<String, double>? readGraphParameterEvent(
  AiFlowGraphDocument document, Object? data, int revision,
) {
  if (data is! Map || data['type'] != 'aiflow-parameters' ||
      data['revision'] is! int || data['revision'] != revision) {
    return null;
  }
  return validateGraphParameters(document, data['values']);
}

/// Structured student observations, not grade/ownership evidence or instructions.
Map<String, dynamic> graphTutorObservation(
  AiFlowGraphDocument document,
  Map<String, double> values,
  String graphId,
) => {
  'graph_id': graphId,
  'parameters': [
    for (final parameter in document.settings.parameters)
      {'id': parameter.id, 'value': values[parameter.id],
       if (parameter.role != 'coefficient') 'role': parameter.role,
       'min': parameter.min, 'max': parameter.max},
  ],
};

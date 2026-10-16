import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/graph_parameter_observation.dart';

void main() {
  const document = AiFlowGraphDocument(items: [], settings: AiFlowGraphSettings(parameters: [
    AiFlowGraphParameter(id: 'p', label: 'p', value: 2, min: .5, max: 3),
  ]));
  test('observations are bounded, immutable and separate from author JSON', () {
    final before = jsonEncode(document.toJson());
    final values = validateGraphParameters(document, {'p': 2.5})!;
    expect(graphTutorObservation(document, values, 'page-1-graph-0')['parameters'], [
      {'id': 'p', 'value': 2.5, 'min': .5, 'max': 3.0},
    ]);
    expect(() => values['p'] = 1, throwsUnsupportedError);
    expect(jsonEncode(document.toJson()), before);
    expect(document.settings.parameters.single.value, 2);
    for (final invalid in [null, {'p': true}, {'p': '2'}, {'p': double.nan},
      {'p': double.infinity}, {'p': 4}, {'p': 0}, {'q': 2}, {'p': 2, 'script': 1}]) {
      expect(validateGraphParameters(document, invalid), isNull);
    }
  });
  test('only current document revision accepts actual observation events', () {
    final event = {'type': 'aiflow-parameters', 'revision': 1, 'values': {'p': 2.5}};
    expect(readGraphParameterEvent(document, event, 1), {'p': 2.5});
    expect(readGraphParameterEvent(document, event, 2), isNull);
    expect(readGraphParameterEvent(document, {...event, 'revision': true}, 1), isNull);
    expect(readGraphParameterEvent(document, {...event, 'type': 'script'}, 1), isNull);
  });
  test('cursor role survives model copy and structured tutor context', () {
    const cursor = AiFlowGraphParameter(id: 'observed_x', label: '관찰 위치 x',
        value: -1, min: -2, max: 2, role: 'observationX');
    final graph = AiFlowGraphDocument(items: [], settings: AiFlowGraphSettings(parameters: [cursor]));
    expect(cursor.copyWith(value: .5).toJson()['role'], 'observationX');
    final values = validateGraphParameters(graph, {'observed_x': .5})!;
    final observation = graphTutorObservation(graph, values, 'page-1-graph-0');
    expect((observation['parameters'] as List).single['role'], 'observationX');
    final invalid = AiFlowGraphDocument(items: [], settings: AiFlowGraphSettings(parameters: [
      cursor, cursor.copyWith(id: 'another'),
    ]));
    expect(validateGraphParameters(invalid, {'observed_x': .5, 'another': 0}), isNull);
  });
}

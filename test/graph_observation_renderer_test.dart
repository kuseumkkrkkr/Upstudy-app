import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

void main() {
  test('singleton scatter renders in both paths while empty and singleton lines do not', () async {
    final graphJson = {
      'items': [
        {'id': 'a', 'type': 'scatter', 'xValues': [-2], 'yValues': [3]},
        {'id': 'b', 'type': 'scatter', 'xValues': [3], 'yValues': [-2]},
        {'id': 'empty', 'type': 'scatter', 'xValues': [], 'yValues': []},
        {'id': 'line', 'type': 'line', 'xValues': [1], 'yValues': [2]},
      ],
      'settings': <String, dynamic>{},
    };
    final book = BookData.fromJson({'title': 'Synthetic', 'chapters': [
      {'title': 'Points', 'sections': [{'title': 'Reference', 'graph': graphJson}]},
    ]});
    final graph = book.chapters.single.sections.single.graph!;
    final roundtrip = BookData.fromJson(book.toJson()).chapters.single.sections.single.graph!;
    expect(roundtrip.toJson(), graph.toJson());
    final fixture = File('build/temp/graph-singleton-scatter-fixture.html');
    await fixture.writeAsString(buildAiFlowGraphHtml(graph));
    final process = await Process.run('node', ['tests/graph_renderer_cursor_probe.cjs', fixture.path, 'scatter']);
    expect(process.exitCode, 0, reason: process.stderr.toString());
    expect((jsonDecode(process.stdout as String) as List).map((row) => row['singletonScatter']), [2, 2]);
  });
  test('shared web/native renderer updates cursor points and canvas fallback', () async {
    final source = {'title': 'Synthetic', 'chapters': [{'title': 'Observation', 'sections': [
      {'title': 'Graph', 'graph': {'items': [
        {'id': 'cubic', 'type': 'function', 'expression': 'x^3-3*x'},
        {'id': 'quadratic', 'type': 'function', 'expression': 'x^2-4*x+3'},
        {'id': 'derivative', 'type': 'function', 'expression': '2*x-4'},
      ], 'settings': {'parameters': [{'id': 'observed_x', 'role': 'observationX',
          'label': '관찰 위치 x', 'value': -1, 'min': -2, 'max': 2, 'step': .1}]}}}
    ]}]};
    final graph = BookData.fromJson(source).chapters.single.sections.single.graph!;
    expect(graph.settings.parameters.single.role, 'observationX');
    final fixture = File('build/temp/graph-cursor-renderer-fixture.html');
    await fixture.writeAsString(buildAiFlowGraphHtml(graph));
    final process = await Process.run('node', ['tests/graph_renderer_cursor_probe.cjs', fixture.path]);
    expect(process.exitCode, 0, reason: process.stderr.toString());
    final result = jsonDecode(process.stdout as String) as List;
    expect(result.map((row) => row['fallback']), [false, true]);
    expect(graph.toJson()['settings']['parameters'][0]['role'], 'observationX');
  });
}

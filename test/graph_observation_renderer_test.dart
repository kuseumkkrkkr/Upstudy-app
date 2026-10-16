import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

void main() {
  test(
    'singleton scatter renders in both paths while empty and singleton lines do not',
    () async {
      final graph = AiFlowGraphDocument(
        items: const [
          AiFlowGraphItem(
            id: 'a',
            type: AiFlowGraphItemType.scatter,
            label: 'A',
            colorHex: '#2563EB',
            xValues: [-2],
            yValues: [3],
          ),
          AiFlowGraphItem(
            id: 'b',
            type: AiFlowGraphItemType.scatter,
            label: 'B',
            colorHex: '#DC2626',
            xValues: [3],
            yValues: [-2],
          ),
          AiFlowGraphItem(
            id: 'empty',
            type: AiFlowGraphItemType.scatter,
            label: 'Empty',
            colorHex: '#6B7280',
            xValues: [],
            yValues: [],
          ),
          AiFlowGraphItem(
            id: 'line',
            type: AiFlowGraphItemType.line,
            label: 'Incomplete line',
            colorHex: '#16A34A',
            xValues: [1],
            yValues: [2],
          ),
        ],
        settings: AiFlowGraphSettings(),
      );
      final directory = await Directory.systemTemp.createTemp(
        'aiflow-single-scatter-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final fixture = File('${directory.path}${Platform.pathSeparator}graph.html');
      await fixture.writeAsString(buildAiFlowGraphHtml(graph));

      final process = await Process.run('node', [
        'test/fixtures/graph_renderer_cursor_probe.cjs',
        fixture.path,
        'scatter',
      ]);

      expect(process.exitCode, 0, reason: process.stderr.toString());
      final results = jsonDecode(process.stdout as String) as List<dynamic>;
      expect(
        results.map((result) => (result as Map)['singletonScatter']),
        [2, 2],
      );
    },
  );
}

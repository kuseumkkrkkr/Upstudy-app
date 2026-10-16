import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';

void main() {
  test(
    'graph renderer escapes author data and emits valid bounded-parser JS',
    () async {
      const document = AiFlowGraphDocument(
        items: [
          AiFlowGraphItem(
            id: 'curve',
            type: AiFlowGraphItemType.function,
            expression: 'x*x/(4*p)',
            colorHex: '#315DA8',
            label:
                "' \" \\ \n </script><script>parent.bad=1</script> & __AIFLOW_SAFE_MATH__",
          ),
        ],
        settings: AiFlowGraphSettings(
          parameters: [
            AiFlowGraphParameter(
              id: 'p',
              label: 'p',
              value: 2,
              min: .5,
              max: 3,
              step: .5,
            ),
          ],
        ),
      );
      final html = buildAiFlowGraphHtml(document);
      expect(html, isNot(contains('</script><script>parent.bad')));
      expect(html, isNot(contains('new Function')));
      expect(html, isNot(contains('eval(')));
      expect(html, contains(r'\u003c/script\u003e'));
      expect(
        html.indexOf('function compileGraphMath('),
        lessThan(html.indexOf('function safeFunctionFromExpression(')),
      );
      // A placeholder in author data must remain data, not be substituted as code.
      expect(RegExp('__AIFLOW_SAFE_MATH__').allMatches(html), hasLength(1));
      final embedded = RegExp(
        r'initialPayload = (\{[^\n]+\});',
      ).firstMatch(html);
      expect(embedded, isNotNull);
      expect(jsonDecode(embedded!.group(1)!), document.toJson());
      final scripts = RegExp(r'<script>([\s\S]*?)</script>').allMatches(html);
      expect(scripts, hasLength(1));
      final process = await Process.start('node', ['--check', '-']);
      final error = process.stderr.transform(utf8.decoder).join();
      final output = process.stdout.drain<void>();
      process.stdin.write(scripts.single.group(1));
      await process.stdin.close();
      expect(await process.exitCode, 0, reason: await error);
      await output;
    },
  );
}

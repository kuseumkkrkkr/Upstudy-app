import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/graph_tools/shared/safe_graph_math.dart';
import 'package:s11/sessions/graph_tools/shared/parametric_graph_math.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/parametric_reader.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test(
    'BookData round trip retains parametric expressions and trace contract',
    () {
      final book = BookData.fromJson(fixture());
      final graph = book.chapters.single.pages.single.blocks.last.graph!;
      final item = graph.items.single;
      expect(item.type, AiFlowGraphItemType.parametric);
      expect(item.xExpression, 't^2');
      expect(item.yExpression, 't^3+t');
      expect(item.tMin, -2);
      expect(item.tMax, 2);
      expect(item.traceParameterId, 'u');
      expect(item.copyWith(label: 'renamed').toJson()['yExpression'], 't^3+t');
      final reloaded = BookData.fromJson(jsonDecode(jsonEncode(book.toJson())));
      expect(
        reloaded.chapters.single.pages.single.blocks.last.graph!.toJson(),
        graph.toJson(),
      );
      final html = buildAiFlowGraphHtml(graph);
      expect(html, contains("type === 'parametric'"));
      expect(html, contains('function parametricGraph('));
      expect(html, isNot(contains('new Function')));
      expect(html, isNot(contains('eval(')));
    },
  );

  test(
    'actual shared JS moves point, measures slope, bounds and rejects code',
    () async {
      final graph = fixture()['chapters'][0]['pages'][0]['blocks'][1]['graph'];
      final program =
          '''
$safeGraphMathJavascript
const normalizeExpression = value => typeof value === 'string' ? value : '';
let parameterValues = {u: 1};
$parametricGraphMathJavascript
const graph = ${jsonEncode(graph)};
const item = graph.items[0], settings = graph.settings;
const before = parametricGraph(item, settings);
parameterValues.u = 2;
const after = parametricGraph(item, settings);
parameterValues.u = 0;
const vertical = parametricGraph(item, settings);
const invalid = ['window.alert(1)', 't.constructor', 'globalThis', 't;1'].map(
 source => parametricGraph({...item, xExpression: source}, settings));
const pole = parametricGraph({...item,xExpression:'t',yExpression:'1/(t-0.003)'},settings);
console.log(JSON.stringify({before: before.point, after: after.point,
  vertical: vertical.point, samples: before.segments[0].length, invalid,
  poleBridged: pole.segments.some(segment => segment.some((p,i) => i>0 && segment[i-1][0]<0.003 && p[0]>0.003)),
  invalidRange: parametricGraph({...item,tMax:-2},settings)}));
''';
      final process = await Process.start('node', ['-']);
      final output = process.stdout.transform(utf8.decoder).join();
      final errors = process.stderr.transform(utf8.decoder).join();
      process.stdin.write(program);
      await process.stdin.close();
      expect(await process.exitCode, 0, reason: await errors);
      final result = jsonDecode(await output);
      expect(result['before']['x'], 1);
      expect(result['before']['y'], 2);
      expect(result['before']['slope'], closeTo(2, 1e-6));
      expect(result['after']['x'], 4);
      expect(result['after']['y'], 10);
      expect(result['after']['slope'], closeTo(3.25, 1e-3));
      expect(result['vertical']['slope'], isNull);
      expect(result['samples'], 401);
      expect(result['invalid'], everyElement(isNull));
      expect(result['invalidRange'], isNull);
      expect(result['poleBridged'], isFalse);
    },
  );
}

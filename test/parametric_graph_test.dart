import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/textbook.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/sessions/graph_tools/shared/safe_graph_math.dart';
import 'package:s11/sessions/graph_tools/shared/parametric_graph_math.dart';
import 'package:s11/sessions/graph_tools/shared/graph_parameter_observation.dart';

void main() {
  Map<String, dynamic> fixture() =>
      jsonDecode(
            File('test/fixtures/parametric_reader.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  test(
    'supplied candidate parametric graph survives real reader model',
    () {
      final source = jsonDecode(
        File(
          Platform.environment['BOOKDATA_CANDIDATE_PATH']!,
        ).readAsStringSync(),
      );
      final raw =
          source['chapters'][13]['pages'][3]['blocks'][1]['graph'] as Map;
      final book = BookData.fromJson(Map<String, dynamic>.from(source));
      final graph = book.chapters[13].pages[3].blocks[1].graph!;
      final item = graph.items.single;
      expect(item.parameterRange, raw['items'][0]['parameterRange']);
      expect(item.xExpression, 'u^2');
      expect(item.yExpression, 'u^3');
      expect(item.tMin, isNull);
      expect(item.tMax, isNull);
      final restored = BookData.fromJson(jsonDecode(jsonEncode(book.toJson())));
      expect(
        restored.chapters[13].pages[3].blocks[1].graph!.toJson(),
        graph.toJson(),
      );
    },
    skip: Platform.environment['BOOKDATA_CANDIDATE_PATH'] == null,
  );

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
const canonical = {...item, xExpression:'u^2', yExpression:'u^3',
  parameterRange:{id:'u',min:-2,max:2,step:0.05}};
parameterValues.u = 2;
const canonicalPoint = parametricGraph(canonical,settings).point;
const badRanges = [null, {id:'window',min:-2,max:2,step:0.05},
 {id:'u',min:-2,max:2,step:0}, {id:'u',min:-2,max:3,step:0.05}];
console.log(JSON.stringify({before: before.point, after: after.point,
  canonicalPoint,
  invalidCanonical: badRanges.slice(1).map(parameterRange => parametricGraph({...canonical,parameterRange},settings)),
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
      expect(result['canonicalPoint']['x'], 4);
      expect(result['canonicalPoint']['y'], 8);
      expect(result['canonicalPoint']['slope'], closeTo(3, 1e-3));
      expect(result['invalidCanonical'], everyElement(isNull));
    },
  );

  test(
    'canonical domain and unknown graph metadata survive reader round trip',
    () {
      final source = fixture();
      final raw =
          source['chapters'][0]['pages'][0]['blocks'][1]['graph'] as Map;
      final item = raw['items'][0] as Map;
      item.remove('tMin');
      item.remove('tMax');
      item['parameterRange'] = {'id': 'u', 'min': -2, 'max': 2, 'step': .05};
      item['xExpression'] = 'u^2';
      item['yExpression'] = 'u^3';
      item['futureItem'] = {
        'data': [1, 2],
      };
      raw['futureDocument'] = 'preserved';
      raw['settings']['futureSettings'] = true;
      raw['settings']['viewport']['futureViewport'] = 'data';
      raw['settings']['parameters'][0]['futureParameter'] = 'data';
      final graph = BookData.fromJson(
        source,
      ).chapters.single.pages.single.blocks.last.graph!;
      final encoded = graph.toJson();
      expect(encoded['items'][0]['parameterRange'], item['parameterRange']);
      expect(encoded['items'][0].containsKey('tMin'), isFalse);
      expect(encoded['items'][0]['futureItem'], item['futureItem']);
      expect(encoded['futureDocument'], 'preserved');
      expect(encoded['settings']['futureSettings'], true);
      expect(encoded['settings']['viewport']['futureViewport'], 'data');
      expect(encoded['settings']['parameters'][0]['futureParameter'], 'data');
      final observed = graphWithObservedParameters(graph, {'u': 2}).toJson();
      expect(observed['futureDocument'], 'preserved');
      expect(observed['settings']['futureSettings'], true);
      expect(observed['settings']['parameters'][0]['futureParameter'], 'data');
      expect(observed['settings']['parameters'][0]['value'], 2);
      expect(graph.settings.parameters.single.value, 1);
      item['type'] = 'future-non-executable';
      final unknown = BookData.fromJson(
        source,
      ).chapters.single.pages.single.blocks.last.graph!.items.single;
      expect(unknown.isFunction, isFalse);
      expect(
        unknown.copyWith(label: 'renamed').toJson()['type'],
        'future-non-executable',
      );
      expect(unknown.toJson()['futureItem'], item['futureItem']);
    },
  );
}

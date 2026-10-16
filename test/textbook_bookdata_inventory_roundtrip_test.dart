import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11/sessions/graph_tools/shared/aiflow_graph_document.dart';
import 'package:s11/sessions/graph_tools/shared/jsx_graph_html_builder.dart';
import 'package:s11/shared/data/models/textbook.dart';

void main() {
  test(
    'all current BookData files preserve pages and activities through round trip',
    () {
      final directory = Directory(
        'docs/advanced-generation-vault/07 Data/교재 원고',
      );
      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.json') &&
                RegExp(r'BookData.*\.json$').hasMatch(file.path),
          )
          .toList();
      expect(files, hasLength(185));

      var activities = 0;
      for (final file in files) {
        final source = BookData.fromJson(
          Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
        );
        final copy = BookData.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(jsonEncode(source.toJson())) as Map,
          ),
        );
        expect(copy.toJson(), source.toJson(), reason: file.path);
        expect(copy.chapters.length, source.chapters.length, reason: file.path);
        final sourcePages = source.chapters
            .expand((chapter) => chapter.pages)
            .toList();
        final copyPages = copy.chapters
            .expand((chapter) => chapter.pages)
            .toList();
        expect(
          copyPages.map((page) => page.id),
          sourcePages.map((page) => page.id),
          reason: file.path,
        );
        final sourceActivities = sourcePages
            .expand((page) => page.blocks)
            .where((block) => block.activity != null)
            .map((block) => block.activity)
            .toList();
        final copyActivities = copyPages
            .expand((page) => page.blocks)
            .where((block) => block.activity != null)
            .map((block) => block.activity)
            .toList();
        activities += sourceActivities.length;
        expect(copyActivities, sourceActivities, reason: file.path);
      }
      // Keep a visible aggregate in the test result for the checkpoint.
      expect(activities, greaterThan(0));
    },
  );

  test('all function graph expressions declare their nonbuilt-in symbols', () {
    final directory = Directory('docs/advanced-generation-vault/07 Data/교재 원고');
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.json') &&
              RegExp(r'BookData.*\.json$').hasMatch(file.path),
        )
        .toList();
    const builtins = <String>{
      'x',
      'pi',
      'e',
      'abs',
      'max',
      'min',
      'sqrt',
      'pow',
      'exp',
      'ln',
      'log',
      'sin',
      'cos',
      'tan',
      'ceil',
      'floor',
      'round',
    };
    var functionItems = 0;
    void verifyGraph(AiFlowGraphDocument graph, String reason) {
      final parameters = graph.settings.parameters
          .map((parameter) => parameter.id)
          .toSet();
      for (final item in graph.items) {
        final expression = item.expression;
        if (item.type.name != 'function' || expression == null) continue;
        functionItems++;
        if (reason.contains('수학Ⅰ_2015개정_지수로그누락기준_Batch2')) {
          expect(
            buildAiFlowGraphHtml(graph),
            contains('renderCurrentGraph()'),
            reason: reason,
          );
        }
        final symbols = RegExp(
          r'\b[A-Za-z_][A-Za-z0-9_]*\b',
        ).allMatches(expression).map((match) => match.group(0)!).toSet();
        expect(
          symbols.difference(builtins).difference(parameters),
          isEmpty,
          reason: '$reason · ${item.id} · $expression',
        );
      }
    }

    for (final file in files) {
      final book = BookData.fromJson(
        Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map),
      );
      for (final chapter in book.chapters) {
        for (final section in chapter.sections) {
          final graph = section.graph;
          if (graph != null) {
            verifyGraph(graph, '${file.path} · ${section.title}');
          }
        }
        for (final page in chapter.pages) {
          for (final block in page.blocks) {
            final graph = block.graph;
            if (graph == null) continue;
            verifyGraph(graph, '${file.path} · ${page.id}');
          }
        }
      }
    }
    expect(files, hasLength(185));
    expect(functionItems, 108);
  });

  test('2015 quadratic graph coefficient control survives graph generation', () {
    const path =
        'docs/advanced-generation-vault/07 Data/교재 원고/중등수학_2015개정_함수그래프_부분초안/중등수학_2015개정_함수그래프_BookData_V2_시범.json';
    final raw =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final book = BookData.fromJson(raw);
    final graph = book.chapters
        .expand((chapter) => chapter.pages)
        .expand((page) => page.blocks)
        .map((block) => block.graph)
        .whereType<AiFlowGraphDocument>()
        .singleWhere(
          (graph) => graph.items.any((item) => item.expression == 'a*x^2'),
        );
    final coefficient = graph.settings.parameters.singleWhere(
      (parameter) => parameter.id == 'a',
    );
    expect(coefficient.value, 1);
    expect(coefficient.min, -3);
    expect(coefficient.max, 3);
    expect(coefficient.step, 0.5);
    expect(buildAiFlowGraphHtml(graph), contains('function buildFormulaMap()'));
  });
}

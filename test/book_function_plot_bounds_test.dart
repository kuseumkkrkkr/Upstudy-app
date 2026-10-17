import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/data/models/book_activity.dart';
import 'package:s11/sessions/textbook/ui/widgets/book_activity_view.dart';

void main() {
  for (final endpoint in [-2.0, 2.0]) {
    testWidgets('power marker remains whole at endpoint $endpoint', (
      tester,
    ) async {
      final fixture = jsonDecode(
        File('test/fixtures/function_explorers.json').readAsStringSync(),
      );
      final activity = BookActivity.fromJson(
        Map<String, dynamic>.from(
          fixture['chapters'][0]['pages'][2]['blocks'][0]['activity'],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookActivityView(activity: activity),
            ),
          ),
        ),
      );
      tester
          .widget<Slider>(find.byKey(const ValueKey('explorer-u')))
          .onChanged!(endpoint);
      await tester.pumpAndSettle();
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('function-explorer-plot')),
          )
          .painter!;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(320, 230));
      final picture = recorder.endRecording();
      final data = await tester.runAsync(() async {
        final image = await picture.toImage(320, 230);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      });
      // Marker centers are x=40 or308; these samples are 2px outside the plot
      // but inside each 4px marker and the reserved outer chart margin.
      final x = endpoint < 0 ? 38 : 310;
      final y = endpoint < 0 ? 197 : 125;
      final offset = (y * 320 + x) * 4;
      expect(
        data!.sublist(offset, offset + 4),
        [194, 65, 12, 255],
        reason:
            'The observation marker must extend beyond the curve clip boundary',
      );
      picture.dispose();
    });
  }
}

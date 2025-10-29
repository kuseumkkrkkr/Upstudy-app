import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StrokePoint {
  final Offset position;
  final int timestamp; // 밀리초 단위
  final bool isPenUp; // true: 펜을 뗀 상태, false: 펜을 누른 상태

  StrokePoint({
    required this.position,
    required this.timestamp,
    required this.isPenUp,
  });
}

class DataManager {
  final List<Map<String, dynamic>> _data = [];

  Future<void> saveStroke(String label, List<List<StrokePoint>> strokes) async {
    final jsonStrokes = strokes
        .map((stroke) => stroke
            .map((p) => {
                  'x': p.position.dx,
                  'y': p.position.dy,
                  't': p.timestamp,
                  'p': p.isPenUp ? 0.0 : 1.0 // 펜이 떼어진 상태면 0, 아니면 1
                })
            .toList())
        .toList();

    _data.add({
      'label': label.toUpperCase(),
      'strokes': jsonStrokes,
    });
  }

  Future<List<Map<String, dynamic>>> loadAll() async => _data;

  Future<void> exportData(BuildContext context) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(_data);
    const fileName = 'handwriting_data.json';

    if (kIsWeb) {
      // Web 플랫폼은 현재 지원하지 않습니다
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹 버전에서는 내보내기가 지원되지 않습니다.')),
      );
      return;
    }

    // 앱에서: 파일로 저장 후 공유
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 완료: ${file.path}')),
      );
    }

    await Share.shareXFiles([XFile(file.path)], text: 'Handwriting dataset');
  }
}

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'drawing_painter.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  List<List<StrokePoint>> strokes = [];
  List<StrokePoint> currentStroke = [];
  int? startTime; // 획 시작 시간
  final TextEditingController labelController = TextEditingController();
  final DataManager dataManager = DataManager();

  void _startStroke(PointerDownEvent details) {
    startTime = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      currentStroke = [
        StrokePoint(
          position: details.localPosition,
          timestamp: 0, // 상대적 시간으로 저장
          isPenUp: false, // 펜이 눌린 상태
        ),
      ];
    });
  }

  void _updateStroke(PointerMoveEvent details) {
    if (startTime == null) return;

    setState(() {
      currentStroke.add(
        StrokePoint(
          position: details.localPosition,
          timestamp: DateTime.now().millisecondsSinceEpoch - startTime!,
          isPenUp: false, // 펜이 여전히 눌린 상태
        ),
      );
    });
  }

  void _endStroke(PointerUpEvent details) {
    setState(() {
      if (currentStroke.isNotEmpty) {
        // 마지막 점을 추가 (펜이 떼어진 상태)
        currentStroke.add(
          StrokePoint(
            position: details.localPosition,
            timestamp: DateTime.now().millisecondsSinceEpoch - startTime!,
            isPenUp: true, // 펜을 뗀 상태
          ),
        );
        strokes.add(currentStroke);
      }
      currentStroke = [];
      startTime = null;
      if (currentStroke.isNotEmpty) {
        strokes.add(currentStroke);
      }
      currentStroke = [];
      startTime = null;
    });
  }

  Future<void> _saveDrawing() async {
    final label = labelController.text.trim();
    if (label.isEmpty || strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('라벨과 필기를 모두 입력해주세요.')),
      );
      return;
    }

    await dataManager.saveStroke(label, strokes);
    setState(() {
      strokes = [];
      labelController.clear();
    });
  }

  void _exportData() async {
    await dataManager.exportData(context);
  }

  void _showStoredData() async {
    final json = jsonEncode(await dataManager.loadAll());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장된 데이터'),
        content: SingleChildScrollView(child: Text(json)),
        actions: [
          TextButton(
            child: const Text('닫기'),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('필기 데이터 수집기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showStoredData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) => Listener(
                onPointerDown: _startStroke,
                onPointerMove: _updateStroke,
                onPointerUp: _endStroke,
                child: Container(
                  color: Colors.white,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: DrawingPainter(strokes, currentStroke),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: labelController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '문자 라벨 (예: A)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('저장'),
                  onPressed: _saveDrawing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

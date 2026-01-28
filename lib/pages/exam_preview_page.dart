import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';
import '../models/content_block.dart';
import '../widgets/content_blocks_view.dart';

class ExamPreviewPage extends StatefulWidget {
  final String examId;

  const ExamPreviewPage({super.key, required this.examId});

  @override
  State<ExamPreviewPage> createState() => _ExamPreviewPageState();
}

class _ExamPreviewPageState extends State<ExamPreviewPage> {
  ExamStatus? _status;
  Timer? _pollTimer;
  bool _loading = true;
  String? _error;
  static const int _largeFlowThreshold = 5;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_status == null ||
          (_status!.status != 'done' && _status!.status != 'failed')) {
        _fetchStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await ApiClient.instance.getExamStatus(widget.examId);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _loading = false;
        _error = null;
      });
      if (status.status == 'done' || status.status == 'failed') {
        _pollTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load exam status.';
        _loading = false;
      });
    }
  }

  Future<void> _openPdf({required bool inline}) async {
    final url = await ApiClient.instance
        .examPdfUrl(widget.examId, inline: inline);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open PDF.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatus,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _openPdf(inline: true),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _openPdf(inline: false),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : status == null
                  ? const Center(child: Text('No data.'))
                  : _buildPreview(status.items),
    );
  }

  Widget _buildPreview(List<ExamItem> items) {
    final pages = _layoutItems(items);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final page = pages[index];
        final pageNumber = index + 1;

        return AspectRatio(
          aspectRatio: 1 / 1.414,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              color: Colors.white,
            ),
            child: _buildPage(
              page,
              pageNumber: pageNumber,
              totalPages: pages.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(
    _PageLayout page, {
    required int pageNumber,
    required int totalPages,
  }) {
    final isFirstPage = pageNumber == 1;
    const titleText = 'AIFlow 모의고사';
    const footerText = 'Learningmate';
    const doubleLineGap = 4.0;
    const verticalOffset = 8.0;
    const double topLineRatioFirst = 0.16;
    const double topLineRatioRest = 0.12;
    const double titleRatio = 0.065;
    const double bottomReservedRatio = 0.09;

    return LayoutBuilder(
      builder: (context, constraints) {
        final topLineY = constraints.maxHeight *
            (isFirstPage ? topLineRatioFirst : topLineRatioRest);
        final bottomReserved = constraints.maxHeight * bottomReservedRatio;
        final contentTop = topLineY + verticalOffset + doubleLineGap;
        final gridHeight =
            (constraints.maxHeight - contentTop - bottomReserved)
                .clamp(120.0, constraints.maxHeight) as double;
        final columnWidth = constraints.maxWidth / 2;
        final rowHeight = gridHeight / 2;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ExamPageDecorPainter(
                  isFirstPage: isFirstPage,
                  title: titleText,
                  footer: footerText,
                  topLineY: topLineY,
                  titleY: constraints.maxHeight * titleRatio,
                  doubleLineGap: doubleLineGap,
                  bottomReserved: bottomReserved,
                ),
              ),
            ),
            Positioned(
              top: contentTop,
              left: 0,
              right: 0,
              height: gridHeight,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridPainter(
                        splitLeft: !page.columnSpans[0],
                        splitRight: !page.columnSpans[1],
                        color: const Color(0xFF2F2F2F),
                      ),
                    ),
                  ),
                  ...page.entries.map((entry) {
                    final left = entry.column * columnWidth;
                    final top = entry.row * rowHeight;
                    final height = rowHeight * entry.rowSpan;
                    return Positioned(
                      left: left,
                      top: top,
                      width: columnWidth,
                      height: height,
                      child: _buildCell(entry.item),
                    );
                  }),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: bottomReserved * 0.45,
              child: Text(
                '$pageNumber / $totalPages',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCell(ExamItem item) {
    final titleBlocks = parseContentBlocks(item.questTitle);
    final displayTitleBlocks = titleBlocks.isEmpty
        ? [const ContentBlock(type: 'text', content: 'Generating...')]
        : titleBlocks;
    final flowCount = item.flowCount ?? item.solvesCount;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${item.itemIndex} (${flowCount} flows)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRect(
              child: ContentBlocksView(
                blocks: displayTitleBlocks,
                textStyle: const TextStyle(fontSize: 12),
                latexStyle: const TextStyle(fontSize: 12),
                spacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.status,
            style: TextStyle(
              fontSize: 11,
              color: item.status == 'done' || item.status == 'reused'
                  ? Colors.green[700]
                  : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutEntry {
  final ExamItem item;
  final int column;
  final int row;
  final int rowSpan;

  _LayoutEntry(
    this.item, {
    required this.column,
    required this.row,
    required this.rowSpan,
  });
}

class _PageLayout {
  final List<_LayoutEntry> entries;
  final List<bool> columnSpans;

  _PageLayout({
    required this.entries,
    required this.columnSpans,
  });
}

class _ExamPageDecorPainter extends CustomPainter {
  final bool isFirstPage;
  final String title;
  final String footer;
  final double topLineY;
  final double titleY;
  final double doubleLineGap;
  final double bottomReserved;

  const _ExamPageDecorPainter({
    required this.isFirstPage,
    required this.title,
    required this.footer,
    required this.topLineY,
    required this.titleY,
    required this.doubleLineGap,
    required this.bottomReserved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const lineColor = Color(0xFF2F2F2F);
    final inset = size.width * 0.06;
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    if (isFirstPage) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - inset * 2);
      titlePainter.paint(
        canvas,
        Offset((size.width - titlePainter.width) / 2, titleY),
      );
    }

    final firstLineY = topLineY;
    final secondLineY = topLineY + doubleLineGap;
    canvas.drawLine(
      Offset(inset, firstLineY),
      Offset(size.width - inset, firstLineY),
      linePaint,
    );
    canvas.drawLine(
      Offset(inset, secondLineY),
      Offset(size.width - inset, secondLineY),
      linePaint,
    );

    final verticalStart = secondLineY + (doubleLineGap * 0.75);
    final verticalEnd = size.height - bottomReserved + 8;
    canvas.drawLine(
      Offset(size.width / 2, verticalStart),
      Offset(size.width / 2, verticalEnd),
      linePaint,
    );

    final footerPainter = TextPainter(
      text: TextSpan(
        text: footer,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - inset * 2);
    final footerY = size.height - bottomReserved +
        (bottomReserved - footerPainter.height) / 2;
    footerPainter.paint(
      canvas,
      Offset((size.width - footerPainter.width) / 2, footerY),
    );
  }

  @override
  bool shouldRepaint(covariant _ExamPageDecorPainter oldDelegate) {
    return isFirstPage != oldDelegate.isFirstPage ||
        title != oldDelegate.title ||
        footer != oldDelegate.footer ||
        topLineY != oldDelegate.topLineY ||
        titleY != oldDelegate.titleY ||
        doubleLineGap != oldDelegate.doubleLineGap ||
        bottomReserved != oldDelegate.bottomReserved;
  }
}

class _GridPainter extends CustomPainter {
  final bool splitLeft;
  final bool splitRight;
  final Color color;

  _GridPainter({
    required this.splitLeft,
    required this.splitRight,
    this.color = Colors.black12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final midX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
    if (splitLeft) {
      canvas.drawLine(Offset(0, midY), Offset(midX, midY), paint);
    }
    if (splitRight) {
      canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.splitLeft != splitLeft ||
        oldDelegate.splitRight != splitRight ||
        oldDelegate.color != color;
  }
}

List<_PageLayout> _layoutItems(List<ExamItem> items) {
  final pages = <_PageLayout>[];
  var entries = <_LayoutEntry>[];
  var columnSpans = [false, false];
  var occupied = [
    [false, false],
    [false, false],
  ];

  void flush() {
    if (entries.isNotEmpty) {
      pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
    }
    entries = <_LayoutEntry>[];
    columnSpans = [false, false];
    occupied = [
      [false, false],
      [false, false],
    ];
  }

  int? findFreeColumn() {
    for (var col = 0; col < 2; col++) {
      if (!occupied[col][0] && !occupied[col][1]) {
        return col;
      }
    }
    return null;
  }

  List<int>? findFreeSlot() {
    for (var col = 0; col < 2; col++) {
      for (var row = 0; row < 2; row++) {
        if (!occupied[col][row]) {
          return [col, row];
        }
      }
    }
    return null;
  }

  for (final item in items) {
    final flowCount = item.flowCount ?? item.solvesCount;
    final isLarge = flowCount > _ExamPreviewPageState._largeFlowThreshold;

    if (isLarge) {
      var column = findFreeColumn();
      if (column == null) {
        flush();
        column = findFreeColumn() ?? 0;
      }
      entries.add(
        _LayoutEntry(
          item,
          column: column,
          row: 0,
          rowSpan: 2,
        ),
      );
      columnSpans[column] = true;
      occupied[column][0] = true;
      occupied[column][1] = true;
      continue;
    }

    var slot = findFreeSlot();
    if (slot == null) {
      flush();
      slot = findFreeSlot() ?? [0, 0];
    }
    entries.add(
      _LayoutEntry(
        item,
        column: slot[0],
        row: slot[1],
        rowSpan: 1,
      ),
    );
    occupied[slot[0]][slot[1]] = true;
  }

  if (entries.isNotEmpty) {
    pages.add(_PageLayout(entries: entries, columnSpans: columnSpans));
  }

  return pages;
}

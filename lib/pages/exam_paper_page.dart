import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/content_block.dart';
import '../services/api_client.dart';
import '../services/activity_store.dart';
import '../services/rating_store.dart';
import '../utils/heatmap_engine.dart';
import '../widgets/content_blocks_view.dart';
import 'flow_view_page.dart';

part 'exam_paper/logic/exam_paper_state.dart';
part 'exam_paper/logic/exam_paper_state_interaction.dart';
part 'exam_paper/logic/exam_paper_state_ui.dart';
part 'exam_paper/logic/exam_paper_state_grading.dart';
part 'exam_paper/logic/exam_paper_layout.dart';
part 'exam_paper/models/exam_paper_models.dart';
part 'exam_paper/widgets/exam_paper_content.dart';
part 'exam_paper/widgets/exam_grading_report_page.dart';
part 'exam_paper/widgets/exam_paper_toolbar_widgets.dart';
part 'exam_paper/widgets/exam_paper_painter.dart';

class ExamPaperPage extends StatefulWidget {
  const ExamPaperPage({
    super.key,
    this.examId,
    this.expectedQuestionCount,
  });

  final String? examId;
  final int? expectedQuestionCount;

  @override
  State<ExamPaperPage> createState() => _ExamPaperPageState();
}



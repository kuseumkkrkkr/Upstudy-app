import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/business/usecases/heatmap_engine.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';

part 'package:s11/sessions/exam_paper/business/exam_paper_state.dart';
part 'package:s11/sessions/exam_paper/business/exam_paper_state_interaction.dart';
part 'package:s11/sessions/exam_paper/ui/exam_paper_state_ui.dart';
part 'package:s11/sessions/exam_paper/business/exam_paper_state_grading.dart';
part 'package:s11/sessions/exam_paper/business/exam_paper_layout.dart';
part 'package:s11/sessions/exam_paper/shared/exam_paper_models.dart';
part 'package:s11/sessions/exam_paper/ui/exam_paper_content.dart';
part 'package:s11/sessions/exam_paper/ui/exam_grading_report_page.dart';
part 'package:s11/sessions/exam_paper/ui/exam_paper_toolbar_widgets.dart';
part 'package:s11/sessions/exam_paper/ui/exam_paper_painter.dart';
part 'package:s11/sessions/exam_paper/ui/mini_chooser.dart';

class ExamPaperPage extends StatefulWidget {
  const ExamPaperPage({
    super.key,
    this.examId,
    this.courseId,
    this.moduleId,
    this.passRate = 100,
    this.expectedQuestionCount,
    this.timeLimitMinutes,
    this.pageCountHint = 0,
    this.initialPageIndex = 0,
    this.marketplaceListingId,
  });

  final String? examId;
  final String? courseId;
  final String? moduleId;
  final int passRate;
  final int? expectedQuestionCount;
  final int? timeLimitMinutes;
  final int pageCountHint;
  final int initialPageIndex;
  final String? marketplaceListingId;

  @override
  State<ExamPaperPage> createState() => _ExamPaperPageState();
}

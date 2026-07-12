import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/solve_analysis_page.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/solve_debug_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/rating_store.dart';
import 'package:s11/shared/business/usecases/heatmap_engine.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';

part '../business/problem_config.dart';
part '../session/build_page_widget.dart';
part '../ui/widgets/ui_components.dart';
part '../ui/widgets/painting.dart';
part '../business/analysis.dart';
part '../business/solution_analysis.dart';

// Legacy aliases for backward compatibility
typedef SharedFlowConfig = ProblemSolveConfig;

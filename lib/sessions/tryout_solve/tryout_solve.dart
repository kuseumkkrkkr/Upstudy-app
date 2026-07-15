// Barrel file for tryout_solve session - exports all public APIs

// Legacy entry (mother file; sub-files are part of it and must NOT be exported directly)
export 'package:s11/sessions/tryout_solve/legacy_entry/tryout.dart';

// Session pages
export 'package:s11/sessions/tryout_solve/session/quick_generate_page.dart';

// UI - Pages
export 'package:s11/sessions/tryout_solve/ui/pages/flow_view_page.dart';
export 'package:s11/sessions/tryout_solve/ui/pages/solution_view_page.dart';
export 'package:s11/sessions/tryout_solve/ui/pages/shared_flow_view_page.dart';
export 'package:s11/sessions/tryout_solve/ui/pages/ox_quiz_page.dart';
export 'package:s11/sessions/tryout_solve/ui/pages/solve_analysis_page.dart';
export 'package:s11/sessions/tryout_solve/ui/pages/solve_debug_page.dart';

// UI - Modals
export 'package:s11/sessions/tryout_solve/ui/modals/problem_solve_mode.dart';
export 'package:s11/sessions/tryout_solve/ui/modals/weakness_review_mode.dart';

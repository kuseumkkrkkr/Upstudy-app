library friend;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s11/shared/services/api/api_client.dart' hide FriendRank;
import 'package:s11/features/level_test/level_test.dart';
import 'package:s11/shared/business/repositories/activity_store.dart';
import 'package:s11/shared/business/repositories/exam_paper_store.dart';
import 'package:s11/sessions/textbook/ui/pages/docx_box.dart' as docx;
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    as study_center;
import 'package:s11/sessions/student_dashboard/ui/modals/rating_detail_modal.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/business/repositories/social_notification_store.dart';
import 'package:s11/shared/services/api/social_ws_service.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/shared_flow_view_page.dart';
import 'package:s11/shared/data/models/concept_tag.dart';
import 'package:s11/shared/data/models/content_block.dart';
import 'package:s11/shared/ui/components/content_blocks_view.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

part 'shared/friend_theme.dart';
part 'shared/friend_models.dart';
part 'ui/friend_dialogs.dart';
part 'ui/friend_screen.dart';

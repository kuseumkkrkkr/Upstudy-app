import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_contract.dart';
import 'auth_storage.dart';

class ExamRangeRequest {
  final String key;
  final List<String> tags;

  ExamRangeRequest({required this.key, required this.tags});

  Map<String, dynamic> toJson() {
    return {'key': key, 'tags': tags};
  }
}

class ExamItem {
  final int itemIndex;
  final String status;
  final String subjectKey;
  final List<String> hashTags;
  final int difficultyTier;
  final int solvesCount;
  final int strategyLevel;
  final int branchConditions;
  final String? questionType;
  final String? questId;
  final int? flowCount;
  final int? codebaseId;
  final int? seed;
  final dynamic questTitle;
  final List<dynamic>? questOptions;
  final String? error;

  ExamItem({
    required this.itemIndex,
    required this.status,
    required this.subjectKey,
    required this.hashTags,
    required this.difficultyTier,
    required this.solvesCount,
    required this.strategyLevel,
    required this.branchConditions,
    this.questionType,
    this.questId,
    this.flowCount,
    this.codebaseId,
    this.seed,
    this.questTitle,
    this.questOptions,
    this.error,
  });

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      itemIndex: json['item_index'] as int,
      status: json['status'] as String,
      subjectKey: json['subject_key'] as String,
      hashTags: List<String>.from(json['hash_tags'] as List<dynamic>),
      difficultyTier: json['difficulty_tier'] as int,
      solvesCount: json['solves_count'] as int,
      strategyLevel: json['strategy_level'] as int,
      branchConditions: json['branch_conditions'] as int,
      questionType: json['question_type'] as String?,
      questId: json['quest_id'] as String?,
      flowCount: json['flow_count'] as int?,
      codebaseId: json['codebase_id'] as int?,
      seed: json['seed'] as int?,
      questTitle: json['quest_title'],
      questOptions: json['quest_options'] as List<dynamic>?,
      error: json['error'] as String?,
    );
  }
}

class ExamStatus {
  final String examId;
  final String status;
  final List<ExamItem> items;

  ExamStatus({required this.examId, required this.status, required this.items});

  factory ExamStatus.fromJson(Map<String, dynamic> json) {
    return ExamStatus(
      examId: json['exam_id'] as String,
      status: json['status'] as String,
      items: (json['items'] as List<dynamic>)
          .map((item) => ExamItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestSearchResult {
  final List<Map<String, dynamic>> quests;
  final int total;
  final int page;
  final int pageSize;

  QuestSearchResult({
    required this.quests,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory QuestSearchResult.fromJson(Map<String, dynamic> json) {
    final quests = (json['quests'] as List<dynamic>? ?? [])
        .map((quest) => quest as Map<String, dynamic>)
        .toList();
    return QuestSearchResult(
      quests: quests,
      total: json['total'] as int? ?? quests.length,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? quests.length,
    );
  }
}

class DailyQuestTemplate {
  const DailyQuestTemplate({
    required this.templateKey,
    required this.title,
    required this.questType,
    required this.difficulty,
    required this.target,
    required this.rewardPoints,
    this.id,
    this.description = '',
    this.moduleTypes = const [],
    this.enabled = true,
    this.sortOrder = 0,
    this.updatedAt = '',
  });

  final int? id;
  final String templateKey;
  final String title;
  final String description;
  final String questType;
  final String difficulty;
  final int target;
  final int rewardPoints;
  final List<String> moduleTypes;
  final bool enabled;
  final int sortOrder;
  final String updatedAt;

  factory DailyQuestTemplate.fromJson(Map<String, dynamic> json) {
    final moduleTypesRaw = json['module_types'];
    return DailyQuestTemplate(
      id: (json['id'] as num?)?.toInt(),
      templateKey: (json['template_key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      questType: (json['quest_type'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? 'easy').toString(),
      target: (json['target'] as num?)?.toInt() ?? 1,
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      moduleTypes: moduleTypesRaw is List
          ? moduleTypesRaw.map((e) => e.toString()).toList()
          : const <String>[],
      enabled: json['enabled'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template_key': templateKey,
      'title': title,
      'description': description,
      'quest_type': questType,
      'difficulty': difficulty,
      'target': target,
      'reward_points': rewardPoints,
      'module_types': moduleTypes,
      'enabled': enabled,
      'sort_order': sortOrder,
    };
  }
}

class FlowStatus {
  final int flowNumber;
  final String status; // "O" or "X"

  FlowStatus({required this.flowNumber, required this.status});

  bool get isCorrect => status.toUpperCase() == 'O';
}

class ContinueState {
  const ContinueState({
    required this.targetId,
    required this.strokes,
    this.updatedAt,
    this.allowBack = false,
  });

  final String targetId;
  final List<dynamic> strokes;
  final String? updatedAt;
  final bool allowBack;

  factory ContinueState.fromJson(Map<String, dynamic> json) {
    return ContinueState(
      targetId: json['target_id']?.toString() ?? '',
      strokes: (json['strokes'] as List<dynamic>? ?? const <dynamic>[]),
      updatedAt: json['updated_at']?.toString(),
      allowBack: json['allow_back'] == true,
    );
  }
}

class SolveAnalysisResponse {
  final List<FlowStatus> status;
  final List<int> inPanic;
  final String aiOpinion;
  final String? questId;
  final List<String> questModel;
  final List<String> warnings;
  final Map<String, dynamic>? debugInfo;

  SolveAnalysisResponse({
    required this.status,
    required this.inPanic,
    required this.aiOpinion,
    required this.questModel,
    required this.warnings,
    this.questId,
    this.debugInfo,
  });

  static List<FlowStatus> _parseStatus(dynamic value) {
    final results = <FlowStatus>[];
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final entry = value[i];
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final flowRaw = map['flow_number'] ?? map['step_id'] ?? map['index'];
          final flowNumber = int.tryParse(flowRaw?.toString() ?? '') ?? i;
          final statusRaw = map['status'] ?? map['correct'] ?? map['value'];
          final statusText = statusRaw?.toString().trim().toUpperCase() ?? 'X';
          results.add(
            FlowStatus(
              flowNumber: flowNumber,
              status: statusText == 'O' ? 'O' : 'X',
            ),
          );
        } else {
          final statusText = entry.toString().trim().toUpperCase();
          results.add(
            FlowStatus(flowNumber: i, status: statusText == 'O' ? 'O' : 'X'),
          );
        }
      }
      return results;
    }
    return results;
  }

  static List<int> _parseInPanic(dynamic value) {
    if (value is List) {
      return value
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toList();
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed == null ? <int>[] : [parsed];
  }

  List<Map<String, dynamic>> get stepCorrectness {
    final sorted = List<FlowStatus>.from(status)
      ..sort((a, b) => a.flowNumber.compareTo(b.flowNumber));
    return sorted
        .map(
          (entry) => {'step_id': entry.flowNumber, 'correct': entry.isCorrect},
        )
        .toList();
  }

  bool? get isCorrect {
    if (status.isEmpty) return null;
    return status.every((entry) => entry.isCorrect);
  }

  factory SolveAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final debugRaw = json['debug'];
    final debugInfo = debugRaw is Map
        ? Map<String, dynamic>.from(debugRaw)
        : null;
    final status = _parseStatus(
      json['status'] ?? json['flow_status'] ?? json['step_correctness'],
    );
    return SolveAnalysisResponse(
      status: status,
      inPanic: _parseInPanic(json['in_panic']),
      aiOpinion: json['ai_opinion']?.toString().trim() ?? '',
      questId: json['quest_id'] as String?,
      questModel: List<String>.from(
        json['quest_model'] as List<dynamic>? ?? [],
      ),
      warnings: List<String>.from(json['warnings'] as List<dynamic>? ?? []),
      debugInfo: debugInfo,
    );
  }
}

class SolveOcrResponse {
  final String? allOcr;
  final String? hitMapped;
  final String? userAnswer;
  final List<String> warnings;
  final String ocrSource;
  final Map<String, dynamic>? debugInfo;

  SolveOcrResponse({
    required this.allOcr,
    required this.hitMapped,
    required this.userAnswer,
    required this.warnings,
    required this.ocrSource,
    this.debugInfo,
  });

  static String? _normalizeNullableText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final lowered = text.toLowerCase();
    if (lowered == 'null' ||
        lowered == 'none' ||
        lowered == 'nil' ||
        text == '?놁쓬') {
      return null;
    }
    return text;
  }

  factory SolveOcrResponse.fromJson(Map<String, dynamic> json) {
    final debugRaw = json['debug'];
    final debugInfo = debugRaw is Map
        ? Map<String, dynamic>.from(debugRaw)
        : null;
    return SolveOcrResponse(
      allOcr: _normalizeNullableText(json['all_ocr']),
      hitMapped: _normalizeNullableText(json['hit_mapped']),
      userAnswer: _normalizeNullableText(
        json['user_answer'] ?? json['student_answer'] ?? json['answer'],
      ),
      warnings: List<String>.from(json['warnings'] as List<dynamic>? ?? []),
      ocrSource: json['ocr_source'] as String? ?? '',
      debugInfo: debugInfo,
    );
  }
}

class UserRating {
  final double rating;
  final double ovr;
  final double ovrDelta;
  final double recentAccuracy;
  final int loseStreak;

  UserRating({
    required this.rating,
    required this.ovr,
    required this.ovrDelta,
    required this.recentAccuracy,
    required this.loseStreak,
  });

  factory UserRating.fromJson(Map<String, dynamic> json) {
    return UserRating(
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ovr: (json['ovr'] as num?)?.toDouble() ?? 0.0,
      ovrDelta: (json['ovr_delta'] as num?)?.toDouble() ?? 0.0,
      recentAccuracy: (json['recent_accuracy'] as num?)?.toDouble() ?? 0.0,
      loseStreak: (json['lose_streak'] as num?)?.toInt() ?? 0,
    );
  }
}

class TagRating {
  final String tag;
  final double rating;
  final double delta;
  final int attempts;

  TagRating({
    required this.tag,
    required this.rating,
    required this.delta,
    required this.attempts,
  });

  factory TagRating.fromJson(Map<String, dynamic> json) {
    return TagRating(
      tag: json['tag']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      delta: (json['delta'] as num?)?.toDouble() ?? 0.0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class WeaknessTag {
  final String tag;
  final int count;
  final String? updatedAt;

  WeaknessTag({required this.tag, required this.count, this.updatedAt});

  factory WeaknessTag.fromJson(Map<String, dynamic> json) {
    return WeaknessTag(
      tag: json['tag']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class OxQuizQuestion {
  final int? id;
  final String tag;
  final String question;
  final bool answer;

  OxQuizQuestion({
    required this.tag,
    required this.question,
    required this.answer,
    this.id,
  });

  factory OxQuizQuestion.fromJson(Map<String, dynamic> json) {
    return OxQuizQuestion(
      id: json['id'] as int?,
      tag: json['tag']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      answer: json['answer'] as bool? ?? false,
    );
  }
}

class SharedFlowItem {
  final String shareId;
  final String groupId;
  final String userId;
  final int codebaseId;
  final int seed;
  final String questId;
  final String questTitle;
  final String statusJson;
  final String allFormulas;
  final String answerRiddle;
  final List<String> tags;
  final int? difficulty;
  final String createdAt;

  SharedFlowItem({
    required this.shareId,
    required this.groupId,
    required this.userId,
    required this.codebaseId,
    required this.seed,
    required this.questId,
    required this.questTitle,
    required this.statusJson,
    required this.allFormulas,
    required this.answerRiddle,
    required this.tags,
    required this.difficulty,
    required this.createdAt,
  });

  factory SharedFlowItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    } else if (rawTags is String && rawTags.isNotEmpty) {
      parsedTags = rawTags
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return SharedFlowItem(
      shareId: json['share_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      codebaseId: json['codebase_id'] as int? ?? 0,
      seed: json['seed'] as int? ?? 0,
      questId: json['quest_id']?.toString() ?? '',
      questTitle: json['quest_title']?.toString() ?? '',
      statusJson: json['status_json']?.toString() ?? '',
      allFormulas: json['all_formulas']?.toString() ?? '',
      answerRiddle: json['answer_riddle']?.toString() ?? '',
      tags: parsedTags,
      difficulty: json['difficulty'] as int?,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ProblemHabitItem {
  final int codebaseId;
  final String seed;
  final List<String> tags;
  final String? questTitle;
  final int retryCount;
  final String updatedAt;

  ProblemHabitItem({
    required this.codebaseId,
    required this.seed,
    required this.tags,
    required this.retryCount,
    required this.updatedAt,
    this.questTitle,
  });

  factory ProblemHabitItem.fromJson(Map<String, dynamic> json) {
    return ProblemHabitItem(
      codebaseId: json['codebase_id'] as int? ?? 0,
      seed: json['seed']?.toString() ?? '',
      tags: List<String>.from(json['tags'] as List<dynamic>? ?? []),
      questTitle: json['quest_title']?.toString(),
      retryCount: json['retry_count'] as int? ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class FriendProfile {
  final String userId;
  final String username;
  final String? name;
  final String? profileImage;
  final double ovr;
  final String status;

  FriendProfile({
    required this.userId,
    required this.username,
    this.name,
    this.profileImage,
    this.ovr = double.nan,
    this.status = '',
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    double parseOvr(dynamic raw) {
      if (raw == null) return double.nan;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? double.nan;
    }

    final ovrRaw = json['visible_ovr'] ?? json['ovr'];
    return FriendProfile(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      profileImage: json['profile_image'] as String?,
      ovr: parseOvr(ovrRaw),
      status: json['status'] as String? ?? '',
    );
  }
}

class FriendRequest {
  final String id;
  final String username;
  final String direction;
  final String status;
  final String? message;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.username,
    required this.direction,
    required this.status,
    required this.createdAt,
    this.message,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at']?.toString() ?? '';
    final created = DateTime.tryParse(createdRaw) ?? DateTime.now();
    return FriendRequest(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'incoming',
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString(),
      createdAt: created,
    );
  }
}

class StudyGroup {
  final String groupId;
  final String name;
  final String description;
  final int maxMembers;
  final bool isPublic;
  final int? logoIndex;
  final bool lockEnabled;
  final String ownerRole;
  final String? inviteCode;
  final String createdAt;
  final String creatorId;
  final List<String> memberIds;

  StudyGroup({
    required this.groupId,
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.isPublic,
    this.logoIndex,
    required this.lockEnabled,
    this.ownerRole = 'student',
    this.inviteCode,
    required this.createdAt,
    required this.creatorId,
    required this.memberIds,
  });

  bool get isTeacherGroup => ownerRole == 'teacher';

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      groupId: json['group_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      maxMembers: json['max_members'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      logoIndex: json['logo_index'] as int?,
      lockEnabled: json['lock_enabled'] as bool? ?? false,
      ownerRole: (json['owner_role'] as String? ?? 'student'),
      inviteCode: json['invite_code'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      creatorId: json['creator_id'] as String? ?? '',
      memberIds: List<String>.from(json['member_ids'] as List<dynamic>? ?? []),
    );
  }
}

class StudyGroupSearchItem {
  final String groupId;
  final String name;
  final String description;
  final int maxMembers;
  final int members;
  final bool isPublic;
  final int? logoIndex;
  final bool lockEnabled;
  final String ownerRole;

  StudyGroupSearchItem({
    required this.groupId,
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.members,
    required this.isPublic,
    this.logoIndex,
    required this.lockEnabled,
    this.ownerRole = 'student',
  });

  factory StudyGroupSearchItem.fromJson(Map<String, dynamic> json) {
    return StudyGroupSearchItem(
      groupId: json['group_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      maxMembers: json['max_members'] as int? ?? 0,
      members: json['members'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      logoIndex: json['logo_index'] as int?,
      lockEnabled: json['lock_enabled'] as bool? ?? false,
      ownerRole: (json['owner_role'] as String? ?? 'student'),
    );
  }
}

class StudyGroupInviteMeta {
  final String groupId;
  final String name;
  final String description;
  final int maxMembers;
  final int members;
  final bool lockEnabled;
  final String inviteCode;

  StudyGroupInviteMeta({
    required this.groupId,
    required this.name,
    required this.description,
    required this.maxMembers,
    required this.members,
    required this.lockEnabled,
    required this.inviteCode,
  });

  factory StudyGroupInviteMeta.fromJson(Map<String, dynamic> json) {
    return StudyGroupInviteMeta(
      groupId: json['group_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      members: (json['members'] as num?)?.toInt() ?? 0,
      lockEnabled: json['lock_enabled'] as bool? ?? false,
      inviteCode: json['invite_code']?.toString() ?? '',
    );
  }
}

class StudyGroupMessage {
  final String messageId;
  final String groupId;
  final String userId;
  final String text;
  final String createdAt;

  StudyGroupMessage({
    required this.messageId,
    required this.groupId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });

  factory StudyGroupMessage.fromJson(Map<String, dynamic> json) {
    return StudyGroupMessage(
      messageId: json['message_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class StudyGroupNotice {
  final String noticeId;
  final String groupId;
  final String? groupName;
  final String title;
  final String contentHtml;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;

  StudyGroupNotice({
    required this.noticeId,
    required this.groupId,
    required this.title,
    required this.contentHtml,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.groupName,
  });

  factory StudyGroupNotice.fromJson(Map<String, dynamic> json) {
    return StudyGroupNotice(
      noticeId: json['notice_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      groupName: json['group_name']?.toString(),
      title: json['title']?.toString() ?? '',
      contentHtml: json['content_html']?.toString() ?? '',
      createdByUserId: json['created_by_user_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class GroupSharedProblem {
  final String shareId;
  final String groupId;
  final String userId;
  final int codebaseId;
  final int seed;
  final String createdAt;

  GroupSharedProblem({
    required this.shareId,
    required this.groupId,
    required this.userId,
    required this.codebaseId,
    required this.seed,
    required this.createdAt,
  });

  factory GroupSharedProblem.fromJson(Map<String, dynamic> json) {
    return GroupSharedProblem(
      shareId: json['share_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      codebaseId: json['codebase_id'] as int? ?? 0,
      seed: json['seed'] as int? ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class GroupSharedExam {
  final String shareId;
  final String groupId;
  final String userId;
  final String examId;
  final int seed;
  final String createdAt;

  GroupSharedExam({
    required this.shareId,
    required this.groupId,
    required this.userId,
    required this.examId,
    required this.seed,
    required this.createdAt,
  });

  factory GroupSharedExam.fromJson(Map<String, dynamic> json) {
    return GroupSharedExam(
      shareId: json['share_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      seed: json['seed'] as int? ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class FriendRank {
  final String userId;
  final String username;
  final double visibleOvr;
  final int rank;
  final bool isMe;

  FriendRank({
    required this.userId,
    required this.username,
    required this.visibleOvr,
    required this.rank,
    this.isMe = false,
  });

  factory FriendRank.fromJson(Map<String, dynamic> json) {
    double parseVisible(dynamic raw) {
      if (raw == null) return double.nan;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString()) ?? double.nan;
    }

    return FriendRank(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      visibleOvr: parseVisible(json['visible_ovr']),
      rank: json['rank'] as int? ?? 0,
      isMe: json['is_me'] as bool? ?? false,
    );
  }
}

class StudyGroupTopic {
  final String groupId;
  final String topic;
  final String updatedAt;

  StudyGroupTopic({
    required this.groupId,
    required this.topic,
    required this.updatedAt,
  });

  factory StudyGroupTopic.fromJson(Map<String, dynamic> json) {
    return StudyGroupTopic(
      groupId: json['group_id']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class StudyGroupExam {
  final String groupId;
  final String examId;
  final String title;
  final String createdAt;

  StudyGroupExam({
    required this.groupId,
    required this.examId,
    required this.title,
    required this.createdAt,
  });

  factory StudyGroupExam.fromJson(Map<String, dynamic> json) {
    return StudyGroupExam(
      groupId: json['group_id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class DirectMessage {
  final String id;
  final String from;
  final String to;
  final String text;
  final DateTime createdAt;
  final bool isMine;

  DirectMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    return DirectMessage(
      id: json['id']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: created ?? DateTime.now(),
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}

class ServerChatStats {
  final double attendanceScore;
  final int solvedToday;
  final double accuracyToday;
  final double visibleOvr;

  const ServerChatStats({
    required this.attendanceScore,
    required this.solvedToday,
    required this.accuracyToday,
    required this.visibleOvr,
  });

  factory ServerChatStats.fromJson(Map<String, dynamic> json) {
    return ServerChatStats(
      attendanceScore: (json['attendance_score'] as num?)?.toDouble() ?? 0.0,
      solvedToday: (json['solved_today'] as num?)?.toInt() ?? 0,
      accuracyToday: (json['accuracy_today'] as num?)?.toDouble() ?? 0.0,
      visibleOvr: (json['visible_ovr'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ServerChatResponse {
  final String assistantMessage;
  final double affectionScore;
  final Map<String, double> affectionBreakdown;
  final String character;
  final String characterName;
  final ServerChatStats stats;
  final int historySize;
  final int userTurns;

  const ServerChatResponse({
    required this.assistantMessage,
    required this.affectionScore,
    required this.affectionBreakdown,
    required this.character,
    required this.characterName,
    required this.stats,
    required this.historySize,
    required this.userTurns,
  });

  factory ServerChatResponse.fromJson(Map<String, dynamic> json) {
    final breakdownRaw =
        json['affection_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = breakdownRaw.map(
      (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0.0),
    );
    return ServerChatResponse(
      assistantMessage: json['assistant_message'] as String? ?? '',
      affectionScore: (json['affection_score'] as num?)?.toDouble() ?? 0.0,
      affectionBreakdown: breakdown,
      character: json['character'] as String? ?? 'female',
      characterName: json['character_name'] as String? ?? '',
      stats: ServerChatStats.fromJson(
        Map<String, dynamic>.from(json['stats'] as Map? ?? {}),
      ),
      historySize: (json['history_size'] as num?)?.toInt() ?? 0,
      userTurns: (json['user_turns'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExamPaperSummary {
  final String examId;
  final String title;
  final int itemCount;

  const ExamPaperSummary({
    required this.examId,
    required this.title,
    required this.itemCount,
  });

  factory ExamPaperSummary.fromJson(Map<String, dynamic> json) {
    final examId = (json['exam_id'] ?? json['id'] ?? '').toString();
    final title = (json['title'] ?? '').toString();
    final itemCount =
        (json['item_count'] as num?)?.toInt() ??
        (json['items_count'] as num?)?.toInt() ??
        (json['question_count'] as num?)?.toInt() ??
        0;
    return ExamPaperSummary(examId: examId, title: title, itemCount: itemCount);
  }
}

class AcademyGroup {
  final String groupId;
  final String academyId;
  final String name;
  final String? grade;
  final String? subject;
  final String? scheduleJson;
  final String groupType;
  final bool searchable;
  final bool friendVerificationRequired;
  final int maxMembers;
  final String? styleBorderColor;
  final String? styleBadgeText;

  AcademyGroup({
    required this.groupId,
    required this.academyId,
    required this.name,
    this.grade,
    this.subject,
    this.scheduleJson,
    this.groupType = 'academy_tutoring_group',
    this.searchable = false,
    this.friendVerificationRequired = true,
    this.maxMembers = 20,
    this.styleBorderColor,
    this.styleBadgeText,
  });

  factory AcademyGroup.fromJson(Map<String, dynamic> json) {
    return AcademyGroup(
      groupId: json['group_id']?.toString() ?? '',
      academyId: json['academy_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      grade: json['grade']?.toString(),
      subject: json['subject']?.toString(),
      scheduleJson: json['schedule_json']?.toString(),
      groupType: json['group_type']?.toString() ?? 'academy_tutoring_group',
      searchable: json['searchable'] == true || json['searchable'] == 1,
      friendVerificationRequired:
          json['friend_verification_required'] == true ||
          json['friend_verification_required'] == 1,
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 20,
      styleBorderColor: json['style_border_color']?.toString(),
      styleBadgeText: json['style_badge_text']?.toString(),
    );
  }
}

class AcademyGroupMember {
  final String memberId;
  final String groupId;
  final String userId;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final DateTime? removedAt;

  AcademyGroupMember({
    required this.memberId,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.removedAt,
  });

  factory AcademyGroupMember.fromJson(Map<String, dynamic> json) {
    return AcademyGroupMember(
      memberId: json['member_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      status: json['status']?.toString() ?? 'active',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
      removedAt: json['removed_at'] != null
          ? DateTime.tryParse(json['removed_at'].toString())
          : null,
    );
  }
}

class AttendanceLog {
  final String logId;
  final String groupId;
  final String userId;
  final String date;
  final String status;
  final DateTime? checkedAt;

  AttendanceLog({
    required this.logId,
    required this.groupId,
    required this.userId,
    required this.date,
    required this.status,
    this.checkedAt,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      logId: json['log_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'present',
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'].toString())
          : null,
    );
  }
}

class TuitionPayment {
  final String paymentId;
  final String academyId;
  final String userId;
  final int amount;
  final String monthLabel;
  final DateTime? paidAt;

  TuitionPayment({
    required this.paymentId,
    required this.academyId,
    required this.userId,
    required this.amount,
    required this.monthLabel,
    this.paidAt,
  });

  factory TuitionPayment.fromJson(Map<String, dynamic> json) {
    return TuitionPayment(
      paymentId: json['payment_id']?.toString() ?? '',
      academyId: json['academy_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      monthLabel: json['month_label']?.toString() ?? '',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
    );
  }
}

class ParentConsultNote {
  final String noteId;
  final String academyId;
  final String studentUserId;
  final String? parentName;
  final String? topic;
  final String? content;
  final DateTime? consultedAt;
  final String? followUpDate;

  ParentConsultNote({
    required this.noteId,
    required this.academyId,
    required this.studentUserId,
    this.parentName,
    this.topic,
    this.content,
    this.consultedAt,
    this.followUpDate,
  });

  factory ParentConsultNote.fromJson(Map<String, dynamic> json) {
    return ParentConsultNote(
      noteId: json['note_id']?.toString() ?? '',
      academyId: json['academy_id']?.toString() ?? '',
      studentUserId: json['student_user_id']?.toString() ?? '',
      parentName: json['parent_name']?.toString(),
      topic: json['topic']?.toString(),
      content: json['content']?.toString(),
      consultedAt: json['consulted_at'] != null
          ? DateTime.tryParse(json['consulted_at'].toString())
          : null,
      followUpDate: json['follow_up_date']?.toString(),
    );
  }
}

class StudentOverviewSnapshot {
  final String snapshotId;
  final String userId;
  final String academyId;
  final String? groupId;
  final double? overallScore;
  final double? attendanceRate;
  final String? tuitionStatus;
  final String? summaryJson;
  final DateTime? createdAt;

  StudentOverviewSnapshot({
    required this.snapshotId,
    required this.userId,
    required this.academyId,
    this.groupId,
    this.overallScore,
    this.attendanceRate,
    this.tuitionStatus,
    this.summaryJson,
    this.createdAt,
  });

  factory StudentOverviewSnapshot.fromJson(Map<String, dynamic> json) {
    return StudentOverviewSnapshot(
      snapshotId: json['snapshot_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      academyId: json['academy_id']?.toString() ?? '',
      groupId: json['group_id']?.toString(),
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble(),
      tuitionStatus: json['tuition_status']?.toString(),
      summaryJson: json['summary_json']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String? get snapshotJson => summaryJson;
}

class GroupAssignment {
  final String assignmentId;
  final String groupId;
  final String senderUserId;
  final String kind;
  final String refId;
  final String? title;
  final String? message;
  final String? dueDate;
  final DateTime? createdAt;
  final List<String> targetUserIds;
  final int submissionCount;

  GroupAssignment({
    required this.assignmentId,
    required this.groupId,
    this.senderUserId = '',
    required this.kind,
    required this.refId,
    this.title,
    this.message,
    this.dueDate,
    this.createdAt,
    this.targetUserIds = const [],
    this.submissionCount = 0,
  });

  factory GroupAssignment.fromJson(Map<String, dynamic> json) {
    return GroupAssignment(
      assignmentId: json['assignment_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      senderUserId: json['sender_user_id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      refId: json['ref_id']?.toString() ?? '',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      dueDate: json['due_date']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      targetUserIds: (json['target_user_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudyGroupMemberProfile {
  final String userId;
  final String username;

  StudyGroupMemberProfile({required this.userId, required this.username});

  factory StudyGroupMemberProfile.fromJson(Map<String, dynamic> json) {
    return StudyGroupMemberProfile(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
    );
  }
}

class TimetablePreference {
  final String preferenceId;
  final String groupId;
  final String userId;
  final String dayOfWeek;
  final String timeSlot;
  final int priority;

  TimetablePreference({
    required this.preferenceId,
    required this.groupId,
    required this.userId,
    required this.dayOfWeek,
    required this.timeSlot,
    required this.priority,
  });

  factory TimetablePreference.fromJson(Map<String, dynamic> json) {
    return TimetablePreference(
      preferenceId: json['preference_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      dayOfWeek: json['day_of_week']?.toString() ?? '',
      timeSlot: json['time_slot']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
    );
  }
}

class TimetablePlan {
  final String planId;
  final String groupId;
  final String planJson;
  final String version;
  final bool applied;

  TimetablePlan({
    required this.planId,
    required this.groupId,
    required this.planJson,
    required this.version,
    required this.applied,
  });

  factory TimetablePlan.fromJson(Map<String, dynamic> json) {
    return TimetablePlan(
      planId: json['plan_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      planJson: json['plan_json']?.toString() ?? '',
      version: json['version']?.toString() ?? 'v1',
      applied: json['applied'] == true || json['applied'] == 1,
    );
  }
}

class UserProfile {
  final String userId;
  final String username;
  final String name;
  final String? role;
  final String? grade;
  final String? track;
  final String? subject;
  final String? school;
  final String? email;

  UserProfile({
    required this.userId,
    required this.username,
    required this.name,
    this.role,
    this.grade,
    this.track,
    this.subject,
    this.school,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString(),
      grade: json['grade']?.toString(),
      track: json['track']?.toString(),
      subject: json['subject']?.toString(),
      school: json['school']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toUpdatePayload({
    String? newUsername,
    String? password,
    String? grade,
    String? track,
    String? subject,
    String? school,
    String? email,
    String? name,
  }) {
    final body = <String, dynamic>{};
    if (newUsername != null && newUsername.trim().isNotEmpty) {
      body['username'] = newUsername.trim();
    }
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
    }
    if (name != null && name.isNotEmpty) {
      body['name'] = name.trim();
    }
    if (grade != null) {
      body['grade'] = grade.trim().isEmpty ? null : grade.trim();
    }
    if (track != null) {
      body['track'] = track.trim().isEmpty ? null : track.trim();
    }
    if (subject != null) {
      body['subject'] = subject.trim().isEmpty ? null : subject.trim();
    }
    if (school != null) {
      body['school'] = school.trim().isEmpty ? null : school.trim();
    }
    if (email != null) {
      body['email'] = email.trim().isEmpty ? null : email.trim();
    }
    return body;
  }
}

class CourseV2ListResult {
  CourseV2ListResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory CourseV2ListResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return CourseV2ListResult(
        items: items,
        total: (data['total'] as num?)?.toInt() ?? items.length,
        limit: (data['limit'] as num?)?.toInt() ?? items.length,
        offset: (data['offset'] as num?)?.toInt() ?? 0,
      );
    }
    final items = (data as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return CourseV2ListResult(
      items: items,
      total: items.length,
      limit: items.length,
      offset: 0,
    );
  }

  final List<Map<String, dynamic>> items;
  final int total;
  final int limit;
  final int offset;
}

class ApiClient {
  ApiClient._() {
    _assertBaseUrlConfigured();
  }

  static final ApiClient instance = ApiClient._();

  static const String baseUrl = ApiContract.baseUrl;

  static String resourceUrl(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return ApiContract.url(trimmed);
  }

  final http.Client _client = http.Client();
  String? _token;
  bool _loadedPersistedToken = false;

  void _assertBaseUrlConfigured() {
    final isLocal =
        baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    if (isLocal && kReleaseMode) {
      throw StateError(
        'API_BASE_URL is not configured. Pass --dart-define=API_BASE_URL=<prod> when building.',
      );
    }
  }

  Future<void> setToken(String token, {String? username, String? role}) async {
    _token = token;
    await AuthStorage.instance.saveToken(token, username: username, role: role);
  }

  Future<void> clearToken() async {
    _token = null;
    await AuthStorage.instance.clear();
  }

  Future<String> requireToken() => _ensureToken();

  Future<String> _ensureToken() async {
    _assertBaseUrlConfigured();
    if (_token != null) {
      return _token!;
    }
    if (!_loadedPersistedToken) {
      _loadedPersistedToken = true;
      final stored = await AuthStorage.instance.readToken();
      if (stored != null && stored.isNotEmpty) {
        _token = stored;
        return stored;
      }
    }
    final uri = ApiContract.uri(ApiPaths.authAnonymous);
    final response = await _client.post(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to obtain token: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Token missing in response');
    }
    _token = token;
    return token;
  }

  Future<String> _ensureTeacherToken() async {
    _assertBaseUrlConfigured();
    final stored = await AuthStorage.instance.readToken();
    if (stored != null && stored.isNotEmpty) {
      _loadedPersistedToken = true;
      _token = stored;
      return stored;
    }
    _token = null;
    _loadedPersistedToken = true;
    throw Exception('Teacher login required');
  }

  Future<void> _clearTokenIfUnauthorized(int statusCode) async {
    if (statusCode == 401) {
      await clearToken();
    }
  }

  Future<String?> getUserStorage(String key) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.userStorage(key));
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch storage: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['value']?.toString();
  }

  Future<void> setUserStorage(String key, String value) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.userStorage(key));
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'value': value}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to set storage: ${response.statusCode}');
    }
  }

  Future<UserProfile> getMyProfile() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.authMe);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(payload);
  }

  Future<UserProfile> updateMyProfile(Map<String, dynamic> body) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.authMe);
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update profile: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserProfile.fromJson(payload);
  }

  Future<void> deleteMyProfile({required String password}) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.authMe);
    final response = await _client.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete account: ${response.statusCode}');
    }
  }

  Future<void> deleteUserStorage(String key) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(ApiPaths.userStorage(key));
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      if (response.statusCode == 404) {
        return;
      }
      throw Exception('Failed to delete storage: ${response.statusCode}');
    }
  }

  Future<void> saveContinueStrokes({
    required String kind,
    required String targetId,
    required List<dynamic> strokes,
    bool forcedExit = true,
    bool allowBack = true,
    bool completed = false,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/continue/strokes');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'kind': kind,
        'target_id': targetId,
        'strokes': strokes,
        'forced_exit': forcedExit,
        'allow_back': allowBack,
        'completed': completed,
      }),
    );
    if (response.statusCode == 409 || response.statusCode == 404) {
      return;
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save continue strokes: ${response.statusCode}',
      );
    }
  }

  Future<ContinueState?> loadContinueStrokes({
    required String kind,
    required String targetId,
  }) async {
    final token = await _ensureToken();
    final encodedTarget = Uri.encodeComponent(targetId);
    final uri = ApiContract.uri(
      '/continue/strokes?kind=$kind&target_id=$encodedTarget',
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404 || response.statusCode == 409) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load continue strokes: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ContinueState.fromJson(payload);
  }

  Future<String> createExam({
    required List<ExamRangeRequest> ranges,
    required int difficultyTier,
    required int questionCount,
    String paperType = 'aiflow',
    String? title,
    bool saveToDocumentBox = false,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exams');
    final body = jsonEncode({
      'ranges': ranges.map((range) => range.toJson()).toList(),
      'difficulty_tier': difficultyTier,
      'question_count': questionCount,
      'paper_type': paperType,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'save_to_document_box': saveToDocumentBox,
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      var detail = response.body;
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map && payload['detail'] != null) {
          detail = payload['detail'].toString();
        }
      } catch (_) {}
      throw Exception('Failed to create exam: ${response.statusCode} $detail');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['exam_id'] as String;
  }

  Future<ExamStatus> getExamStatus(String examId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exams/$examId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exam: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ExamStatus.fromJson(payload);
  }

  Future<List<ExamPaperSummary>> listExams({int limit = 100}) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/exams',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to list exams: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => ExamPaperSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (payload is Map<String, dynamic>) {
      final items =
          payload['items'] as List<dynamic>? ??
          payload['exams'] as List<dynamic>? ??
          const <dynamic>[];
      return items
          .whereType<Map>()
          .map((e) => ExamPaperSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return const [];
  }

  Future<String> examPdfUrl(String examId, {bool inline = false}) async {
    final token = await _ensureToken();
    return ApiContract.url(
      ApiPaths.examPdf(examId),
      query: {'inline': inline ? '1' : '0', 'token': token},
    );
  }

  Future<List<Map<String, dynamic>>> searchQuests({
    String? hashTag,
    String? questId,
    String? textQuery,
    bool? isVariant,
    bool? isMcqBranch,
    int pageSize = 200,
  }) async {
    final hasQuery = [
      hashTag,
      questId,
      textQuery,
    ].any((value) => value != null && value.trim().isNotEmpty);
    if (!hasQuery) {
      throw Exception('Search requires hash_tag, quest_id, or text');
    }
    if (isVariant == true || isMcqBranch == true) {
      return <Map<String, dynamic>>[];
    }
    final payload = await searchExamEditorProblems(
      hashTag: hashTag,
      questId: questId,
      text: textQuery,
      pageSize: pageSize,
    );
    return _ownedQuestSearchResultFromJson(
      payload,
      page: 1,
      pageSize: pageSize,
    ).quests;
  }

  Future<Map<String, dynamic>> generateVariantFromFlowDraft({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/from-flow-draft');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate variant (flow draft): ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateVariantFromPromptNote({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/from-prompt-note');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate variant (prompt/note): ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertQuestToMcq({
    required String questId,
    String offsetPattern = 'pm2',
    bool randomChoices = true,
    String visibilityScope = 'private_mcq',
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/convert-mcq');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'base_quest_ref': {'quest_id': questId},
        'mcq_policy': {
          'offset_pattern': offsetPattern,
          'random_choices': randomChoices,
        },
        'visibility_scope': visibilityScope,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to convert quest to MCQ: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gradeVariantSolve({
    required String questId,
    int? selectedIndex,
    String? userAnswer,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/analysis/solve/variant-grade');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'quest_id': questId,
        if (selectedIndex != null) 'selected_index': selectedIndex,
        if (userAnswer != null) 'user_answer': userAnswer,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to grade variant solve: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listQuestTray({int limit = 100}) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/quests/tray',
    ).replace(queryParameters: {'limit': '$limit'});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch quest tray: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createQuestTrayItem({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/tray');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create quest tray item: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveExamEditorPaper({
    String? paperId,
    required String title,
    required bool twoPerPage,
    String gradingAreaDirection = 'bottom',
    String? expectedUpdatedAt,
    required List<Map<String, dynamic>> items,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exam-editor/papers');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (paperId != null) 'paper_id': paperId,
        'title': title,
        'two_per_page': twoPerPage,
        'grading_area_direction': gradingAreaDirection,
        if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt,
        'items': items,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save exam editor paper: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deployExamEditorPaper(String paperId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exam-editor/papers/$paperId/deploy');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to deploy exam editor paper: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchExamEditorProblems({
    String? hashTag,
    String? questId,
    String? text,
    String? dateFrom,
    String? dateTo,
    bool ownedOnly = true,
    int page = 1,
    int pageSize = 50,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'owned_only': 'true',
      if (hashTag != null && hashTag.trim().isNotEmpty)
        'hash_tag': hashTag.trim(),
      if (questId != null && questId.trim().isNotEmpty)
        'quest_id': questId.trim(),
      if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      if (dateFrom != null && dateFrom.trim().isNotEmpty)
        'date_from': dateFrom.trim(),
      if (dateTo != null && dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    };
    final uri = ApiContract.uri(
      '/exam-editor/problems/search',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search exam editor problems: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importExamEditorTray({
    required String sourceExamId,
    required List<int> itemIndexes,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exam-editor/tray/import');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'source_exam_id': sourceExamId,
        'item_indexes': itemIndexes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to import tray items: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> arrangeExamEditorAi({
    String? paperId,
    required List<Map<String, dynamic>> items,
    String? instruction,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exam-editor/arrange/ai');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (paperId != null) 'paper_id': paperId,
        'items': items,
        if (instruction != null && instruction.trim().isNotEmpty)
          'instruction': instruction.trim(),
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to run exam editor AI arrange: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> toggleExamEditorSource(bool enabled) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/exam-editor/source/toggle');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'enabled': enabled}),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to toggle exam editor source: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['enabled'] == true;
  }

  Future<Map<String, dynamic>> generateQuest({
    required List<String> hashTags,
    required int solvesCount,
    required int strategyLevel,
    required int branchConditions,
    String? referenceQuestId,
    bool strictTags = false,
    int? seed,
    String? requestId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/generate');
    final body = jsonEncode({
      'hash_tags': hashTags,
      'solves_count': solvesCount,
      'strategy_level': strategyLevel,
      'branch_conditions': branchConditions,
      if (referenceQuestId != null && referenceQuestId.trim().isNotEmpty)
        'reference_quest_id': referenceQuestId.trim(),
      'strict_tags': strictTags,
      if (seed != null) 'seed': seed,
      if (requestId != null) 'request_id': requestId,
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate quest: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final quest = payload['quest'] as Map<String, dynamic>?;
    if (quest != null) {
      return quest;
    }
    final queuedRequestId = (payload['request_id'] ?? requestId)?.toString();
    if (queuedRequestId == null || queuedRequestId.isEmpty) {
      throw Exception('Missing quest data in response');
    }
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final status = await fetchQuestGenerateStatus(requestId: queuedRequestId);
      final state = status['status']?.toString();
      final statusQuest = status['quest'];
      if (statusQuest is Map) {
        return Map<String, dynamic>.from(statusQuest);
      }
      final result = status['result'];
      if (result is Map && result['quest'] is Map) {
        return Map<String, dynamic>.from(result['quest'] as Map);
      }
      if (state == 'failed' || state == 'error' || state == 'cancelled') {
        throw Exception(
          status['error']?.toString() ?? 'Quest generation failed',
        );
      }
    }
    throw Exception('Quest generation timed out');
  }

  Future<Map<String, dynamic>> fetchQuestGenerateStatus({
    required String requestId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/quests/generate/status',
    ).replace(queryParameters: {'request_id': requestId});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelQuestGeneration({
    required String requestId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      ApiPaths.questsGenerateCancel,
    ).replace(queryParameters: {'request_id': requestId});
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cancel quest generation: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchTeacherStoreSummary() async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/teacher/store/summary');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load teacher store: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> topUpTeacherStoreTest(int amount) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/teacher/store/top-up-test');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to charge points: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> purchaseTeacherStoreItem(String itemId) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/teacher/store/purchase');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'item_id': itemId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to purchase store item: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> generateProblemSet({
    required List<String> hashTags,
    required int minDifficultyTier,
    required int maxDifficultyTier,
    required int questionCount,
  }) async {
    final quests = <Map<String, dynamic>>[];
    await for (final quest in generateProblemSetStream(
      hashTags: hashTags,
      minDifficultyTier: minDifficultyTier,
      maxDifficultyTier: maxDifficultyTier,
      questionCount: questionCount,
    )) {
      quests.add(quest);
    }
    if (quests.isEmpty) {
      throw Exception('Missing quests in response');
    }
    return quests;
  }

  Stream<Map<String, dynamic>> generateProblemSetStream({
    required List<String> hashTags,
    required int minDifficultyTier,
    required int maxDifficultyTier,
    required int questionCount,
  }) async* {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/generate/stream');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'hash_tags': hashTags,
      'min_difficulty_tier': minDifficultyTier,
      'max_difficulty_tier': maxDifficultyTier,
      'question_count': questionCount,
    });

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e) {
      throw Exception('Connection failed: $e');
    }

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      String message = 'Failed: ${streamed.statusCode}';
      try {
        final parsed = jsonDecode(body) as Map<String, dynamic>;
        final detail = parsed['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          message = detail.trim();
        }
      } catch (_) {}
      throw Exception(message);
    }

    final buffer = StringBuffer();
    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      final text = buffer.toString();
      final lines = text.split('\n');
      buffer.clear();
      buffer.write(lines.last);
      for (var i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;
        try {
          final obj = jsonDecode(data) as Map<String, dynamic>;
          if (obj.containsKey('error')) throw Exception(obj['error'] as String);
          yield obj;
        } catch (e) {
          if (e is Exception) rethrow;
        }
      }
    }
  }

  Future<Map<String, dynamic>> fetchUnitProblems({
    required String courseId,
    required int unitIndex,
  }) async {
    // Legacy endpoint removed on backend. Keep compatibility by returning
    // an empty payload for callers that still reference this API.
    return <String, dynamic>{'quests': const <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> generateCubicProblem({int? seed}) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/csat/cubic');
    final body = jsonEncode({if (seed != null) 'seed': seed});
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate cubic problem: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<QuestSearchResult> fetchQuestPage({
    int page = 1,
    int pageSize = 20,
  }) async {
    final payload = await searchExamEditorProblems(
      page: page,
      pageSize: pageSize,
    );
    return _ownedQuestSearchResultFromJson(
      payload,
      page: page,
      pageSize: pageSize,
    );
  }

  QuestSearchResult _ownedQuestSearchResultFromJson(
    Map<String, dynamic> payload, {
    required int page,
    required int pageSize,
  }) {
    final rawItems = payload['items'] as List<dynamic>? ?? const [];
    final quests = rawItems.whereType<Map>().map((item) {
      final quest = Map<String, dynamic>.from(item);
      final title =
          quest['quest_title'] ?? quest['quest_title_text'] ?? quest['content'];
      return <String, dynamic>{
        ...quest,
        'id': quest['quest_id'] ?? quest['id'],
        'quest_title': title,
        'quest_title_text': quest['quest_title_text'] ?? title,
        'hash_tags': quest['hash_tags'] ?? const <String>[],
      };
    }).toList();
    return QuestSearchResult(
      quests: quests,
      total: (payload['total'] as num?)?.toInt() ?? quests.length,
      page: (payload['page'] as num?)?.toInt() ?? page,
      pageSize: (payload['page_size'] as num?)?.toInt() ?? pageSize,
    );
  }

  Future<SolveAnalysisResponse> submitSolveAnalysis({
    required Map<String, dynamic> payload,
    Uint8List? studentWorkImage,
    Uint8List? problemImage,
    Uint8List? heatmapImage,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/analysis/solve');
    final payloadWithImages = Map<String, dynamic>.from(payload);
    if (studentWorkImage != null && studentWorkImage.isNotEmpty) {
      payloadWithImages['student_work_image'] = base64Encode(studentWorkImage);
    }
    if (problemImage != null && problemImage.isNotEmpty) {
      payloadWithImages['problem_image'] = base64Encode(problemImage);
    }
    if (heatmapImage != null && heatmapImage.isNotEmpty) {
      payloadWithImages['heatmap_image'] = base64Encode(heatmapImage);
    }
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payloadWithImages),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to analyze solve: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return SolveAnalysisResponse.fromJson(decoded);
  }

  Future<SolveOcrResponse> submitSolveOcr({
    required Map<String, dynamic> payload,
    Uint8List? studentWorkImage,
    Uint8List? heatmapImage,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/analysis/ocr');
    final payloadWithImages = Map<String, dynamic>.from(payload);
    if (studentWorkImage != null && studentWorkImage.isNotEmpty) {
      payloadWithImages['student_work_image'] = base64Encode(studentWorkImage);
    }
    if (heatmapImage != null && heatmapImage.isNotEmpty) {
      payloadWithImages['heatmap_image'] = base64Encode(heatmapImage);
    }
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payloadWithImages),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to OCR solve: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return SolveOcrResponse.fromJson(decoded);
  }

  Future<UserRating> submitRating({
    required String questId,
    required bool isCorrect,
    required List<String> tags,
    List<Map<String, dynamic>>? stepCorrectness,
    double? answerTime,
    String? submissionId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/rating/submit');
    final body = jsonEncode({
      'quest_id': questId,
      'is_correct': isCorrect,
      'tags': tags,
      if (answerTime != null) 'answer_time': answerTime,
      if (stepCorrectness != null) 'step_correctness': stepCorrectness,
      if (submissionId != null) 'submission_id': submissionId,
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit rating: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserRating.fromJson(payload);
  }

  Future<UserRating> fetchUserRating() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/rating/user');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch rating: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserRating.fromJson(payload);
  }

  Future<UserRating> fetchUserRatingFor(String userId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/rating/user/${Uri.encodeComponent(userId)}');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch student rating: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UserRating.fromJson(payload);
  }

  Future<Map<String, dynamic>> fetchStudentAnalysis(String userId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/academy/analysis/students/${Uri.encodeComponent(userId)}',
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch student analysis: ${response.statusCode}',
      );
    }
    final data = _academyPayload(response);
    if (data is Map<String, dynamic>) return data;
    throw Exception('Invalid student analysis payload');
  }

  Future<List<TagRating>> fetchTagRatings() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/rating/tags');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch tag ratings: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['tags'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => TagRating.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<WeaknessTag>> fetchWeaknessTags() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/weakness/tags');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch weakness tags: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['tags'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => WeaknessTag.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ProblemHabitItem>> fetchProblemHabits({
    int days = 60,
    String? tag,
    int limit = 200,
  }) async {
    final token = await _ensureToken();
    final params = {
      'days': days.toString(),
      'limit': limit.toString(),
      if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
    };
    final uri = ApiContract.uri(
      '/habit/problem',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch problem habits: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map(
          (item) => ProblemHabitItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> recordProblemHabit({
    required int codebaseId,
    required String seed,
    List<String> tags = const [],
    String? questTitle,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/habit/problem');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codebase_id': codebaseId,
        'seed': seed,
        'tags': tags,
        if (questTitle != null) 'quest_title': questTitle,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to record problem habit: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> replayProblemHabit({
    required int codebaseId,
    required String seed,
    String? questId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/habit/problem/replay');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'codebase_id': codebaseId,
        'seed': seed,
        if (questId != null) 'quest_id': questId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Replay failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<OxQuizQuestion>> generateOxQuiz({
    required List<String> tags,
    int perTag = 3,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/ox_quiz/generate');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'tags': tags, 'per_tag': perTag}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate OX quiz: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['questions'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => OxQuizQuestion.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<OxQuizQuestion>> listOxQuiz({
    required List<String> tags,
    int perTag = 3,
  }) async {
    final token = await _ensureToken();
    final params = {'tags': tags.join(','), 'per_tag': perTag.toString()};
    final uri = ApiContract.uri('/ox_quiz').replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch OX quiz: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['questions'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => OxQuizQuestion.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<FriendProfile>> searchFriends({
    required String query,
    int limit = 20,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friends/search');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'query': query.trim(), 'limit': limit}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search friends: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final users = payload['users'] as List<dynamic>? ?? [];
    return users
        .map((item) => FriendProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendProfile>> searchAcademyFriendsByNickname({
    required String query,
    int limit = 20,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/academy/friends/search-nickname',
    ).replace(queryParameters: {'q': query.trim(), 'limit': '$limit'});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to search academy friends: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => FriendProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<FriendProfile>> listFriends() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friends');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch friends: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final friends = payload['friends'] as List<dynamic>? ?? [];
    return friends
        .map((item) => FriendProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRank>> fetchFriendRankings() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friends/rankings');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load friend rankings: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final ranks = payload['ranks'] as List<dynamic>? ?? [];
    return ranks
        .map((item) => FriendRank.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FriendProfile> addFriend(String username) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friends/add');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'username': username.trim()}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add friend: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendProfile.fromJson(payload);
  }

  Future<FriendProfile> removeFriend(String username) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friends/remove');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'username': username.trim()}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to remove friend: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendProfile.fromJson(payload);
  }

  Future<List<FriendRequest>> listFriendRequests() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friend-requests');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch friend requests: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['requests'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => FriendRequest.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<FriendRequest> sendFriendRequest({
    required String username,
    String? message,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friend-requests');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'username': username.trim(),
        if (message != null) 'message': message,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send friend request: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendRequest.fromJson(payload);
  }

  Future<FriendProfile> acceptFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friend-requests/$requestId/accept');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to accept friend request: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendProfile.fromJson(payload);
  }

  Future<FriendRequest> cancelFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friend-requests/$requestId/cancel');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cancel friend request: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendRequest.fromJson(payload);
  }

  Future<FriendRequest> declineFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/friend-requests/$requestId/decline');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to decline friend request: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendRequest.fromJson(payload);
  }

  Future<StudyGroup> createStudyGroup({
    required String name,
    required String description,
    required int maxMembers,
    required bool isPublic,
    int? logoIndex,
    bool lockEnabled = false,
    String? password,
    String? inviteCode,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups');
    final body = jsonEncode({
      'name': name.trim(),
      'description': description.trim(),
      'max_members': maxMembers,
      'is_public': isPublic,
      'logo_index': logoIndex,
      'lock_enabled': lockEnabled,
      if (lockEnabled && password != null) 'password': password.trim(),
      if (inviteCode != null && inviteCode.trim().isNotEmpty)
        'invite_code': inviteCode.trim(),
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create study group: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroup.fromJson(payload);
  }

  Future<List<StudyGroup>> listMyStudyGroups() async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/social/study-groups/mine');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to load study groups: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final groups = payload['groups'] as List<dynamic>? ?? [];
    return groups
        .map((g) => StudyGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<List<StudyGroupSearchItem>> searchStudyGroups(
    String keyword, {
    int limit = 20,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/search',
    ).replace(queryParameters: {'q': keyword, 'limit': limit.toString()});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search study groups: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final groups = payload['groups'] as List<dynamic>? ?? [];
    return groups
        .map((g) => StudyGroupSearchItem.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroupSharedProblem>> listGroupSharedProblems(
    String groupId, {
    int limit = 30,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/shared-problems',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load shared problems: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .map(
          (item) => GroupSharedProblem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<GroupSharedProblem> shareGroupProblem({
    required String groupId,
    required int codebaseId,
    required int seed,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/shared-problems',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'codebase_id': codebaseId, 'seed': seed}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to share problem: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupSharedProblem.fromJson(payload);
  }

  Future<List<GroupSharedExam>> listGroupSharedExams(
    String groupId, {
    int limit = 5,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/shared-exams',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load shared exams: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .map((item) => GroupSharedExam.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GroupSharedExam> shareGroupExam({
    required String groupId,
    required String examId,
    required int seed,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/shared-exams');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'exam_id': examId.trim(), 'seed': seed}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to share exam: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupSharedExam.fromJson(payload);
  }

  Future<StudyGroup> joinStudyGroup({
    required String groupId,
    String? password,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/join');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to join study group: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroup.fromJson(payload);
  }

  Future<StudyGroup> joinStudyGroupByInviteCode({
    required String inviteCode,
    String? password,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/join-by-code');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'invite_code': inviteCode.trim(),
        if (password != null) 'password': password,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to join study group by code: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroup.fromJson(payload);
  }

  Future<StudyGroupInviteMeta> fetchStudyGroupInviteMeta(
    String inviteCode,
  ) async {
    final uri = ApiContract.uri(
      '/social/study-groups/invite/${inviteCode.trim()}',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load invite metadata: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupInviteMeta.fromJson(payload);
  }

  String buildStudentInviteUrl(String inviteCode) {
    final code = inviteCode.trim();
    return 's11://groups/join?code=$code';
  }

  Future<List<StudyGroupNotice>> listMySystemGroupNotices({
    int limit = 20,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/notices/my/system',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load system group notices: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final notices = payload['notices'] as List<dynamic>? ?? [];
    return notices
        .map((n) => StudyGroupNotice.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<List<StudyGroupNotice>> listGroupNotices(
    String groupId, {
    int limit = 20,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/notices',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load group notices: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final notices = payload['notices'] as List<dynamic>? ?? [];
    return notices
        .map((n) => StudyGroupNotice.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<StudyGroupNotice> upsertGroupNotice({
    required String groupId,
    required String title,
    required String contentHtml,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/notices');
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'title': title.trim(), 'content_html': contentHtml}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save group notice: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupNotice.fromJson(payload);
  }

  Future<void> deleteGroupNoticeByTitle({
    required String groupId,
    required String title,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/notices',
    ).replace(queryParameters: {'title': title.trim()});
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete group notice: ${response.statusCode}');
    }
  }

  Future<List<StudyGroupMessage>> fetchStudyGroupMessages({
    required String groupId,
    int limit = 50,
    String? before,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{'limit': limit.toString()};
    if (before != null) params['before'] = before;
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/messages',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load group messages: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = payload['messages'] as List<dynamic>? ?? [];
    return messages
        .map((m) => StudyGroupMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<StudyGroupMessage> sendStudyGroupMessage({
    required String groupId,
    required String text,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/messages');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to send group message: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupMessage.fromJson(payload);
  }

  Future<StudyGroupTopic> getStudyGroupTopic(String groupId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/topic');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load group topic: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupTopic.fromJson(payload);
  }

  Future<StudyGroupTopic> setStudyGroupTopic({
    required String groupId,
    required String topic,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/topic');
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'topic': topic}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update group topic: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupTopic.fromJson(payload);
  }

  Future<List<StudyGroupExam>> listStudyGroupExams(String groupId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/exams');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load group exams: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final exams = payload['exams'] as List<dynamic>? ?? [];
    return exams
        .map((e) => StudyGroupExam.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudyGroupExam> addStudyGroupExam({
    required String groupId,
    required String examId,
    String? title,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/exams');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'exam_id': examId, 'title': title}),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add group exam: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return StudyGroupExam.fromJson(payload);
  }

  Future<List<DirectMessage>> fetchDirectMessages({
    required String peerUsername,
    int limit = 30,
    String? beforeMessageId,
    int maxTotal = 2000,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{
      'peer': peerUsername.trim(),
      'limit': limit.toString(),
      'max_total': maxTotal.toString(),
    };
    if (beforeMessageId != null && beforeMessageId.trim().isNotEmpty) {
      params['before'] = beforeMessageId.trim();
    }
    final uri = ApiContract.uri(
      '/social/messages',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load messages: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['messages'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => DirectMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<DirectMessage> sendDirectMessage({
    required String peerUsername,
    required String text,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/messages');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'peer': peerUsername.trim(), 'text': text.trim()}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send message: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return DirectMessage.fromJson(payload);
  }

  Future<List<DirectMessage>> fetchConversationThreads({
    int limit = 15,
    String? before,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{'limit': limit.toString()};
    if (before != null && before.trim().isNotEmpty) {
      params['before'] = before.trim();
    }
    final uri = ApiContract.uri(
      '/social/conversations',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load conversations: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['messages'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => DirectMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> deleteConversation(String peerUsername) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/social/messages/${Uri.encodeComponent(peerUsername)}/delete',
    );
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation: ${response.statusCode}');
    }
  }

  Future<Map<String, String>> getServerChatProfile() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/serverchat/config');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch character: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'character': payload['character']?.toString() ?? 'female',
      'character_name': payload['character_name']?.toString() ?? '',
    };
  }

  Future<String> setServerChatCharacter(String character) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/serverchat/config');
    final response = await _client.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'character': character}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save character: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['character']?.toString() ?? character;
  }

  Future<ServerChatResponse> sendServerChatMessage({
    required String message,
    String? character,
    String? questTitle,
    String? flow,
    String? ocr,
    String mode = 'chat',
    bool? ephemeral,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/serverchat/message');
    final body = <String, dynamic>{
      'user_message': message,
      'mode': mode,
      if (character != null) 'character': character,
      if (questTitle != null) 'quest_title': questTitle,
      if (flow != null) 'flow': flow,
      if (ocr != null) 'ocr': ocr,
      if (ephemeral != null) 'ephemeral': ephemeral,
    };
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to send chat: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ServerChatResponse.fromJson(payload);
  }

  Future<List<Map<String, dynamic>>> listTextbooks({
    String? category,
    String? tag,
    String? type,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{};
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      params['type'] = type.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      params['tag'] = tag.trim();
    }
    final uri = ApiContract.uri('/textbooks').replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch textbooks: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['textbooks'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listTeacherDocuments({
    String? category,
    String? tag,
    String? type,
  }) async {
    final token = await _ensureTeacherToken();
    final params = <String, String>{};
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (type != null && type.trim().isNotEmpty) {
      params['type'] = type.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      params['tag'] = tag.trim();
    }
    final uri = ApiContract.uri(
      '/teacher/documents',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch teacher documents: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['textbooks'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getTextbook(String textbookId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/textbooks/$textbookId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch textbook: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTextbook(
    Map<String, dynamic> payload,
  ) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/textbooks');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create textbook: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<SharedFlowItem>> listSharedFlows(
    String groupId, {
    int limit = 30,
    List<String>? tags,
    String? from,
    String? to,
    String? userId,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{'limit': '$limit'};
    if (tags != null && tags.isNotEmpty) {
      params['tags'] = tags.join(',');
    }
    if (from != null) params['date_from'] = from;
    if (to != null) params['date_to'] = to;
    if (userId != null) params['user_id_filter'] = userId;
    final uri = ApiContract.uri(
      '/social/study-groups/$groupId/shared-flows',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load shared flows: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload.map((e) => SharedFlowItem.fromJson(e)).toList();
  }

  Future<SharedFlowItem> shareFlowToGroup({
    required String groupId,
    required int codebaseId,
    required int seed,
    String? questId,
    String? questTitle,
    required String statusJson,
    required String allFormulas,
    required String answerRiddle,
    List<String>? tags,
    int? difficulty,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/shared-flows');
    final body = jsonEncode({
      'codebase_id': codebaseId,
      'seed': seed,
      if (questId != null) 'quest_id': questId,
      if (questTitle != null) 'quest_title': questTitle,
      'status_json': statusJson,
      'all_formulas': allFormulas,
      'answer_riddle': answerRiddle,
      if (tags != null) 'tags': tags,
      if (difficulty != null) 'difficulty': difficulty,
    });
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to share flow: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SharedFlowItem.fromJson(payload);
  }

  // --- Solve history (server-side stored grading payloads) ---
  Future<List<SolveHistoryItem>> fetchSolveHistory({
    int days = 30,
    int limit = 200,
    String? kind,
  }) async {
    final token = await _ensureToken();
    final params = {
      'days': days.toString(),
      'limit': limit.toString(),
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
    };
    final uri = ApiContract.uri(
      '/history/solve',
    ).replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch solve history: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final items = payload['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((e) => SolveHistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteSharedFlow(String shareId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/shared-flows/$shareId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete shared flow: ${response.statusCode}');
    }
  }

  Future<List<String>> listGroupMembers(String groupId) async {
    final profiles = await listStudyGroupMemberProfiles(groupId);
    return profiles
        .map((profile) => profile.username)
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<StudyGroupMemberProfile>> listStudyGroupMemberProfiles(
    String groupId,
  ) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/$groupId/members');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load group members: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .whereType<Map>()
        .map(
          (e) => StudyGroupMemberProfile.fromJson(Map<String, dynamic>.from(e)),
        )
        .where((e) => e.userId.isNotEmpty)
        .toList();
  }

  Future<SharedFlowItem> getSharedFlow(String shareId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/social/study-groups/shared-flows/$shareId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch shared flow: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SharedFlowItem.fromJson(payload);
  }

  Future<http.Response> authedGet(Uri uri, {String? token}) async {
    final tk = token ?? await _ensureToken();
    return _client.get(uri, headers: {'Authorization': 'Bearer $tk'});
  }

  Future<http.Response> authedPost(
    Uri uri, {
    String? token,
    Object? body,
  }) async {
    final tk = token ?? await _ensureToken();
    return _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $tk',
        if (body != null) 'Content-Type': 'application/json',
      },
      body: body,
    );
  }

  Map<String, dynamic> _decodeMapBody(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Invalid response payload');
  }

  dynamic _academyPayload(http.Response response) {
    final payload = _decodeMapBody(response);
    if (payload.containsKey('data')) {
      return payload['data'];
    }
    return payload;
  }

  Future<List<AcademyGroup>> listAcademyGroups({String? academyId}) async {
    final token = await _ensureToken();
    final query = <String, String>{
      if (academyId != null && academyId.isNotEmpty) 'academy_id': academyId,
      'group_type': 'academy_tutoring_group',
    };
    final uri = ApiContract.uri(
      '/academy/groups',
    ).replace(queryParameters: query);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load academy groups: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => AcademyGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AcademyGroup> getAcademyGroup(String groupId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/groups/$groupId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load academy group: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid academy group payload');
    }
    return AcademyGroup.fromJson(data);
  }

  Future<AcademyGroup> createAcademyGroup({
    required String academyId,
    required String name,
    String groupType = 'academy_tutoring_group',
    bool searchable = false,
    bool friendVerificationRequired = true,
    int maxMembers = 20,
    String? grade,
    String? subject,
    String? scheduleJson,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/groups');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'academy_id': academyId,
        'name': name,
        'group_type': groupType,
        'searchable': searchable,
        'friend_verification_required': friendVerificationRequired,
        'max_members': maxMembers,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (scheduleJson != null && scheduleJson.isNotEmpty)
          'schedule_json': scheduleJson,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create academy group: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid academy group payload');
    }
    return AcademyGroup.fromJson(data);
  }

  Future<List<AcademyGroupMember>> listAcademyGroupMembers({
    required String groupId,
    String? status,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/groups/$groupId/members');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load academy members: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final rawItems = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    final members = rawItems
        .whereType<Map>()
        .map((e) => AcademyGroupMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (status == null || status.isEmpty) return members;
    return members.where((m) => m.status == status).toList();
  }

  Future<AcademyGroupMember> inviteGroupMember({
    required String groupId,
    required String invitedUserId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/members/invite');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'group_id': groupId, 'invited_user_id': invitedUserId}),
    );
    if (response.statusCode != 200) {
      final body = _decodeMapBody(response);
      throw Exception(body['detail']?.toString() ?? 'Failed to invite member');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid invite payload');
    }
    return AcademyGroupMember.fromJson(data);
  }

  Future<List<AttendanceLog>> listAttendanceLogs({
    required String groupId,
    String? userId,
    String? date,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/attendance').replace(
      queryParameters: {
        'group_id': groupId,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (date != null && date.isNotEmpty) 'date': date,
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load attendance logs: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => AttendanceLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TuitionPayment>> listTuitionPayments({
    required String academyId,
    String? userId,
    String? monthLabel,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/tuition').replace(
      queryParameters: {
        'academy_id': academyId,
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (monthLabel != null && monthLabel.isNotEmpty)
          'month_label': monthLabel,
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load tuition payments: ${response.statusCode}',
      );
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => TuitionPayment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ParentConsultNote>> listConsultNotes({
    required String academyId,
    String? studentUserId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/consult').replace(
      queryParameters: {
        'academy_id': academyId,
        if (studentUserId != null && studentUserId.isNotEmpty)
          'student_user_id': studentUserId,
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load consult notes: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => ParentConsultNote.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<StudentOverviewSnapshot>> listSnapshots({
    required String academyId,
    String? groupId,
    int limit = 50,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/snapshots').replace(
      queryParameters: {
        'academy_id': academyId,
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        'limit': '$limit',
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load snapshots: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map(
          (e) => StudentOverviewSnapshot.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<GroupAssignment> createAssignment({
    required String groupId,
    required String kind,
    required String refId,
    String? title,
    String? message,
    String? dueDate,
    List<String>? targetUserIds,
    String chatMode = 'auto',
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/assignments');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'group_id': groupId,
        'kind': kind,
        'ref_id': refId,
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (dueDate != null) 'due_date': dueDate,
        if (targetUserIds != null) 'target_user_ids': targetUserIds,
        'chat_mode': chatMode,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create assignment: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid assignment payload');
    }
    return GroupAssignment.fromJson(data);
  }

  Future<List<GroupAssignment>> listAssignments({
    required String groupId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/academy/assignments',
    ).replace(queryParameters: {'group_id': groupId});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404) {
      return const <GroupAssignment>[];
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load assignments: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => GroupAssignment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<GroupAssignment> updateAssignment({
    required String assignmentId,
    String? title,
    String? message,
    String? dueDate,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/assignments/$assignmentId');
    final response = await _client.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (dueDate != null) 'due_date': dueDate,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update assignment: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid assignment payload');
    }
    return GroupAssignment.fromJson(data);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/assignments/$assignmentId');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete assignment: ${response.statusCode}');
    }
  }

  Future<TimetablePreference> createTimetablePreference({
    required String groupId,
    required String dayOfWeek,
    required String timeSlot,
    int priority = 1,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/timetable/preferences');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'group_id': groupId,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
        'priority': priority,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to create timetable preference: ${response.statusCode}',
      );
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid timetable preference payload');
    }
    return TimetablePreference.fromJson(data);
  }

  Future<List<TimetablePreference>> listTimetablePreferences({
    required String groupId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      '/academy/timetable/preferences',
    ).replace(queryParameters: {'group_id': groupId});
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load timetable preferences: ${response.statusCode}',
      );
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => TimetablePreference.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> generateTimetable(String groupId) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/timetable/generate/$groupId');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate timetable: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid timetable payload');
    }
    return data;
  }

  Future<List<TimetablePlan>> listTimetablePlans({
    required String groupId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/timetable/plans/$groupId');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load timetable plans: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    final items = data is Map<String, dynamic>
        ? (data['items'] as List<dynamic>? ?? const [])
        : const [];
    return items
        .whereType<Map>()
        .map((e) => TimetablePlan.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TimetablePlan> applyTimetablePlan({required String planId}) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/academy/timetable/plans/$planId/apply');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to apply timetable plan: ${response.statusCode}');
    }
    final data = _academyPayload(response);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid timetable plan payload');
    }
    return TimetablePlan.fromJson(data);
  }

  // -- Teacher Auth APIs ---------------------------------------------------

  Future<bool> isAuthenticated() async {
    try {
      final token = await AuthStorage.instance.readToken();
      final role = await AuthStorage.instance.readRole();
      if (token == null || token.trim().isEmpty) return false;
      return role == 'teacher' || role == 'admin';
    } catch (_) {
      return false;
    }
  }

  Future<void> loginTeacher(String email, String password) async {
    final uri = ApiContract.uri('/auth/teacher/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('Login failed: ');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('No token in response');
    }
    final role = payload['role']?.toString() ?? 'teacher';
    await setToken(token, username: email, role: role);
  }

  Future<void> registerTeacher({
    required String email,
    required String password,
    required String name,
  }) async {
    final uri = ApiContract.uri('/auth/teacher/register');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Registration failed: ');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = payload['token']?.toString();
    if (token != null && token.isNotEmpty) {
      final role = payload['role']?.toString() ?? 'teacher';
      await setToken(token, username: email, role: role);
    }
  }

  // -- Course V2 APIs ------------------------------------------------------

  Future<Map<String, dynamic>> getCourseV2(String id) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/courses/v2/$id');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to load course: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    return payload;
  }

  Future<CourseV2ListResult> listCoursesV2Page({
    bool mineOnly = false,
    String? query,
    String? tag,
    String visibility = 'all',
    int limit = 50,
    int offset = 0,
    String sort = 'updated_at',
    String order = 'desc',
    bool includeTotal = true,
  }) async {
    final token = await _ensureTeacherToken();
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      'sort': sort,
      'order': order,
      'include_total': includeTotal ? 'true' : 'false',
    };
    if (mineOnly) {
      params['mine_only'] = 'true';
    }
    if (query != null && query.trim().isNotEmpty) {
      params['query'] = query.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      params['tag'] = tag.trim();
    }
    if (visibility != 'all') {
      params['visibility'] = visibility;
    }

    final uri = ApiContract.uri('/courses/v2').replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to list courses: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return CourseV2ListResult.fromJson(payload);
  }

  Future<List<Map<String, dynamic>>> listCoursesV2({
    bool mineOnly = false,
    String? query,
    String? tag,
    String visibility = 'all',
    int limit = 50,
    int offset = 0,
    String sort = 'updated_at',
    String order = 'desc',
  }) async {
    final result = await listCoursesV2Page(
      mineOnly: mineOnly,
      query: query,
      tag: tag,
      visibility: visibility,
      limit: limit,
      offset: offset,
      sort: sort,
      order: order,
      includeTotal: false,
    );
    return result.items;
  }

  Future<Map<String, dynamic>> createCourseV2(
    Map<String, dynamic> payload,
  ) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/courses/v2');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to create course: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }

  Future<Map<String, dynamic>> updateCourseV2(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/courses/v2/$id');
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to update course: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }

  Future<void> deleteCourseV2(String id) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/courses/v2/$id');
    final response = await _client.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      await _clearTokenIfUnauthorized(response.statusCode);
      throw Exception('Failed to delete course: ${response.statusCode}');
    }
  }

  Future<List<String>> getCourseHashTags() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/courses/hash-tags');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load hash tags: ');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['tags'] as List<dynamic>?;
    if (data == null) return [];
    return data.map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getQuestGenerationTagGroups() async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/generation-tags');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load generation tags: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final groups = payload['groups'] as List<dynamic>? ?? const [];
    return groups
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> bindCourseToAcademyGroup({
    required String courseId,
    required String academyId,
    required String groupId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/courses/v2/$courseId/bind-academy-group');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'academy_id': academyId, 'group_id': groupId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to bind academy group: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }

  Future<List<Map<String, dynamic>>> generateAiCurriculum({
    required Map<String, dynamic> textbook,
    required Map<String, dynamic> metadata,
  }) async {
    final token = await _ensureToken();
    final commonHeaders = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final toolsUri = ApiContract.uri('/courses/v2/ai/agent/tools');
    final toolsRes = await _client.get(
      toolsUri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (toolsRes.statusCode != 200) {
      throw Exception('Failed to load AI agent tools: ${toolsRes.statusCode}');
    }

    final toolResults = <String, dynamic>{};
    final toolCallUri = ApiContract.uri('/courses/v2/ai/agent/call');
    final friendsRes = await _client.post(
      toolCallUri,
      headers: commonHeaders,
      body: jsonEncode({
        'tool_name': 'list_friend_students',
        'arguments': {'limit': 30},
      }),
    );
    if (friendsRes.statusCode == 200) {
      final payload = jsonDecode(friendsRes.body) as Map<String, dynamic>;
      toolResults['list_friend_students'] = payload['data'];
    }

    final nicknameQuery = (metadata['nickname_query'] ?? '').toString().trim();
    if (nicknameQuery.isNotEmpty) {
      final searchRes = await _client.post(
        toolCallUri,
        headers: commonHeaders,
        body: jsonEncode({
          'tool_name': 'search_students_nickname',
          'arguments': {'query': nicknameQuery, 'limit': 20},
        }),
      );
      if (searchRes.statusCode == 200) {
        final payload = jsonDecode(searchRes.body) as Map<String, dynamic>;
        toolResults['search_students_nickname'] = payload['data'];
      }
    }

    final proposeUri = ApiContract.uri('/courses/v2/ai/agent/propose');
    final response = await _client.post(
      proposeUri,
      headers: commonHeaders,
      body: jsonEncode({
        'student_ovr': metadata['student_ovr'] ?? const <String, dynamic>{},
        'weakness_tags':
            metadata['weakness_tags'] ?? (textbook['tags'] ?? const <String>[]),
        'prompt_extra': metadata['prompt_extra'] ?? '',
        'course_title_hint': metadata['course_title_hint'] ?? '',
        'tool_results': toolResults,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to generate curriculum (tool mode): ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : const <String, dynamic>{};
    final proposed = data['proposed_course'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(data['proposed_course'] as Map)
        : const <String, dynamic>{};
    final modules = proposed['modules'] as List<dynamic>? ?? const [];
    return modules
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<DailyQuestTemplate>> listDailyQuestTemplates({
    bool? enabled,
    String? difficulty,
  }) async {
    final token = await _ensureTeacherToken();
    final query = <String, String>{
      if (enabled != null) 'enabled': enabled ? 'true' : 'false',
      if (difficulty != null && difficulty.trim().isNotEmpty)
        'difficulty': difficulty.trim(),
    };
    final uri = ApiContract.uri(
      '/challenges/daily-quest-templates',
      query: query,
    );
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load daily challenge templates: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : const <String, dynamic>{};
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map>()
        .map((e) => DailyQuestTemplate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DailyQuestTemplate> saveDailyQuestTemplate(
    DailyQuestTemplate template,
  ) async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri('/challenges/daily-quest-templates');
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(template.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save daily challenge template: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : const <String, dynamic>{};
    final item = data['item'] is Map
        ? Map<String, dynamic>.from(data['item'] as Map)
        : const <String, dynamic>{};
    return DailyQuestTemplate.fromJson(item);
  }

  Future<int> resetDailyQuestTemplates() async {
    final token = await _ensureTeacherToken();
    final uri = ApiContract.uri(
      '/challenges/daily-quest-templates/reset-defaults',
    );
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reset daily challenge templates: ${response.statusCode}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : const <String, dynamic>{};
    return (data['reset_count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> updateTextbook(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/textbooks/$id');
    final response = await _client.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update textbook: ');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}

class SolveHistoryItem {
  SolveHistoryItem({
    required this.createdAt,
    required this.kind,
    this.questId,
    this.examId,
    this.codebaseId,
    this.seed,
    this.data,
    this.questTitleRaw,
    this.hashTags = const [],
  });

  final String createdAt;
  final String kind; // 'problem' | 'exam'
  final String? questId;
  final String? examId;
  final int? codebaseId;
  final int? seed;
  final Map<String, dynamic>? data;
  final String? questTitleRaw; // JSON blocks ?뺤떇
  final List<String> hashTags;

  factory SolveHistoryItem.fromJson(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final data = dataRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(dataRaw)
        : null;
    final rawTags = data?['hash_tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];
    return SolveHistoryItem(
      createdAt: json['created_at']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      questId: json['quest_id']?.toString(),
      examId: json['exam_id']?.toString(),
      codebaseId: (json['codebase_id'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      data: data,
      questTitleRaw: data?['quest_title']?.toString(),
      hashTags: tags,
    );
  }
}

import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s11/shared/services/api/api_contract.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;

  ApiResponse({required this.success, this.data, this.message});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? parser,
  ) {
    return ApiResponse(
      success: json['success'] ?? true,
      data: parser != null && json['data'] != null
          ? parser(json['data'])
          : json['data'] as T?,
      message: json['message'] as String?,
    );
  }
}

/// 필요한 변수는 API 목록 원본, 행 변환 함수와 조회 출처다.
/// 작동 원리는 각 행의 형변환·모델 생성을 독립 처리해 손상된 사용자 관련 행 하나가 전체 목록을 폐기하지 않게 하는 것이다.
List<T> _parseListItemsSafely<T>(
  Iterable<dynamic> items,
  T Function(Map<String, dynamic>) parser, {
  required String source,
}) {
  final parsed = <T>[];
  for (final item in items) {
    try {
      parsed.add(parser(Map<String, dynamic>.from(item as Map)));
    } catch (error) {
      log(
        'API 목록 행을 건너뜁니다: source=$source error=${error.runtimeType}',
        name: 'ApiClient',
      );
    }
  }
  return parsed;
}

class _CachedApiResponse {
  _CachedApiResponse({
    required this.savedAt,
    required this.ttlMs,
    required this.body,
    required this.statusCode,
    this.etag,
    this.lastModified = '',
    this.headersJson,
  });

  factory _CachedApiResponse.fromJson(Map<String, dynamic> json) {
    return _CachedApiResponse(
      savedAt: (json['savedAt'] is num)
          ? (json['savedAt'] as num).toInt()
          : int.tryParse(json['savedAt']?.toString() ?? '') ?? 0,
      ttlMs: (json['ttlMs'] is num)
          ? (json['ttlMs'] as num).toInt()
          : int.tryParse(json['ttlMs']?.toString() ?? '') ?? 0,
      body: (json['body'] ?? '').toString(),
      statusCode: (json['statusCode'] is num)
          ? (json['statusCode'] as num).toInt()
          : int.tryParse(json['statusCode']?.toString() ?? '') ?? 200,
      etag: json['etag']?.toString(),
      lastModified: json['lastModified']?.toString() ?? '',
      headersJson: json['headersJson']?.toString(),
    );
  }

  final int savedAt;
  final int ttlMs;
  final String body;
  final int statusCode;
  final String? etag;
  final String lastModified;
  final String? headersJson;

  bool isFresh(int nowMs) => ttlMs > 0 && nowMs - savedAt <= ttlMs;

  Map<String, dynamic> toJsonMap() {
    return <String, dynamic>{
      'savedAt': savedAt,
      'ttlMs': ttlMs,
      'body': body,
      'statusCode': statusCode,
      if (etag != null) 'etag': etag!,
      if (lastModified.isNotEmpty) 'lastModified': lastModified,
      if (headersJson != null) 'headersJson': headersJson!,
    };
  }
}

class StudyGroup {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final int maxMembers;
  final bool isPublic;
  final int? logoIndex;
  final bool lockEnabled;
  final String ownerRole;
  final String? inviteCode;
  final List<String> memberIds;
  final String? password;
  final DateTime? createdAt;
  final String creatorId;

  StudyGroup({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    this.maxMembers = 0,
    this.isPublic = true,
    this.logoIndex,
    this.lockEnabled = false,
    this.ownerRole = 'student',
    this.inviteCode,
    this.memberIds = const [],
    this.password,
    this.createdAt,
    this.creatorId = '',
  });

  String get groupId => id;
  int get members => memberCount;
  bool get isTeacherGroup => ownerRole == 'teacher';

  /// 필요한 변수는 서버 그룹 JSON과 숫자·목록 필드다.
  /// 작동 원리: 웹에서 null·문자열·숫자가 섞여 와도 안전하게 문자열과 정수로 정규화해 런타임 형변환 오류를 막는다.
  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    final rawMemberIds = json['member_ids'];
    return StudyGroup(
      id: (json['group_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      memberCount:
          int.tryParse(
            (json['member_count'] ?? json['members'] ?? 0).toString(),
          ) ??
          0,
      maxMembers: int.tryParse((json['max_members'] ?? 0).toString()) ?? 0,
      isPublic: json['is_public'] != false,
      logoIndex: int.tryParse(json['logo_index']?.toString() ?? ''),
      lockEnabled: json['lock_enabled'] == true,
      ownerRole: (json['owner_role'] ?? 'student').toString(),
      inviteCode: json['invite_code']?.toString(),
      memberIds: rawMemberIds is List
          ? rawMemberIds
                .map((value) => value.toString())
                .toList(growable: false)
          : const [],
      password: json['password']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      creatorId: (json['creator_id'] ?? '').toString(),
    );
  }
}

/// 필요한 변수는 그룹 API가 반환한 null·목록·래핑 객체다.
/// 작동 원리: `groups` 누락과 잘못된 항목을 빈 목록 또는 유효 그룹만으로 정규화해 한 항목 때문에 화면 전체가 깨지지 않게 한다.
List<StudyGroup> parseStudyGroupListPayload(Object? data) {
  final Object? rawItems = data is List
      ? data
      : data is Map
      ? data['groups']
      : null;
  if (rawItems is! List) return const <StudyGroup>[];
  return rawItems
      .whereType<Map>()
      .map((item) => StudyGroup.fromJson(Map<String, dynamic>.from(item)))
      .where((group) => group.id.isNotEmpty || group.name.isNotEmpty)
      .toList(growable: false);
}

class StudyGroupMember {
  final String userId;
  final String username;

  const StudyGroupMember({required this.userId, required this.username});

  /// 필요한 변수는 서버가 반환한 사용자 ID와 닉네임이다.
  /// 작동 원리는 닉네임이 비어 있거나 이전 서버 응답일 때 사용자 ID를 대체값으로 사용해 멤버 행이 비어 보이지 않게 하는 것이다.
  factory StudyGroupMember.fromJson(Map<String, dynamic> json) {
    final userId = (json['user_id'] ?? json['id'] ?? '').toString();
    final username = (json['username'] ?? json['name'] ?? userId).toString();
    return StudyGroupMember(userId: userId, username: username);
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
      groupId: (json['group_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      maxMembers: (json['max_members'] as num?)?.toInt() ?? 0,
      members: (json['members'] as num?)?.toInt() ?? 0,
      lockEnabled: json['lock_enabled'] == true,
      inviteCode: (json['invite_code'] ?? '').toString(),
    );
  }
}

class StudyGroupSchedule {
  final String scheduleId;
  final String groupId;
  final String title;
  final String scheduledDate;
  final String? scheduledTime;
  final String createdAt;

  const StudyGroupSchedule({
    required this.scheduleId,
    required this.groupId,
    required this.title,
    required this.scheduledDate,
    this.scheduledTime,
    required this.createdAt,
  });

  /// 필요한 변수는 서버 일정 JSON이다.
  /// 작동 원리는 서버가 만료된 항목을 제거한 뒤 반환한 필드만 모델로 변환한다.
  factory StudyGroupSchedule.fromJson(Map<String, dynamic> json) {
    return StudyGroupSchedule(
      scheduleId: (json['schedule_id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      scheduledDate: (json['scheduled_date'] ?? '').toString(),
      scheduledTime: json['scheduled_time']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
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
    this.ovr = 0,
    this.status = '',
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      userId: json['user_id'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      name: (json['name'] ?? json['display_name'])?.toString(),
      profileImage: json['profile_image']?.toString(),
      ovr:
          (json['ovr'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          0,
      status: (json['status'] ?? '').toString(),
    );
  }
}

class FriendRequest {
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final String status;
  final String username;
  final String direction;
  final String? message;
  final DateTime? createdAt;

  FriendRequest({
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.username = '',
    this.direction = 'incoming',
    this.message,
    this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      requestId: json['request_id'] ?? json['id'] ?? '',
      fromUserId: json['from_user_id'] ?? '',
      toUserId: json['to_user_id'] ?? '',
      status: json['status'] ?? 'pending',
      username: (json['username'] ?? '').toString(),
      direction: (json['direction'] ?? 'incoming').toString(),
      message: json['message']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  String get id => requestId;
}

class SharedFlowItem {
  final String id;
  final String groupId;
  final String senderId;
  final String kind;
  final String refId;
  final String? title;
  final DateTime? createdAt;
  final int codebaseId;
  final int seed;
  final String statusJson;
  final String allFormulas;
  final String answerRiddle;
  final List<String> tags;
  final int? difficulty;

  SharedFlowItem({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.kind,
    required this.refId,
    this.title,
    this.createdAt,
    this.codebaseId = 0,
    this.seed = 0,
    this.statusJson = '{}',
    this.allFormulas = '',
    this.answerRiddle = '',
    this.tags = const [],
    this.difficulty,
  });

  factory SharedFlowItem.fromJson(Map<String, dynamic> json) {
    return SharedFlowItem(
      id: json['share_id'] ?? json['id'] ?? json['flow_id'] ?? '',
      groupId: json['group_id'] ?? '',
      senderId:
          json['user_id'] ?? json['sender_id'] ?? json['sender_user_id'] ?? '',
      kind: json['kind'] ?? 'flow',
      refId: json['quest_id'] ?? json['ref_id'] ?? '',
      title: json['quest_title'] ?? json['title'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      codebaseId: (json['codebase_id'] as num?)?.toInt() ?? 0,
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      statusJson: json['status_json']?.toString() ?? '{}',
      allFormulas: json['all_formulas']?.toString() ?? '',
      answerRiddle: json['answer_riddle']?.toString() ?? '',
      tags: (json['tags'] as List? ?? const [])
          .map((tag) => tag.toString())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      difficulty: (json['difficulty'] as num?)?.toInt(),
    );
  }
}

class ExamItem {
  final String examId;
  final String? title;
  final int? itemCount;
  final DateTime? createdAt;
  final int? itemIndex;
  final String? status;
  final String? subjectKey;
  final List<String>? hashTags;
  final int? difficultyTier;
  final int? solvesCount;
  final int? strategyLevel;
  final int? branchConditions;
  final String? questionType;
  final String? questId;
  final int? flowCount;
  final int? codebaseId;
  final int? seed;
  final dynamic questTitle;
  final List<dynamic>? questOptions;
  final String? error;

  ExamItem({
    required this.examId,
    this.title,
    this.itemCount,
    this.createdAt,
    this.itemIndex,
    this.status,
    this.subjectKey,
    this.hashTags,
    this.difficultyTier,
    this.solvesCount,
    this.strategyLevel,
    this.branchConditions,
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
    final hashTagsRaw = json['hash_tags'];
    return ExamItem(
      examId: json['exam_id'] ?? json['id'] ?? '',
      title: json['title'],
      itemCount: json['item_count'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      itemIndex: (json['item_index'] as num?)?.toInt(),
      status: json['status']?.toString(),
      subjectKey: json['subject_key']?.toString(),
      hashTags: hashTagsRaw is List
          ? hashTagsRaw.map((e) => e.toString()).toList()
          : null,
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt(),
      solvesCount: (json['solves_count'] as num?)?.toInt(),
      strategyLevel: (json['strategy_level'] as num?)?.toInt(),
      branchConditions: (json['branch_conditions'] as num?)?.toInt(),
      questionType: json['question_type']?.toString(),
      questId: json['quest_id']?.toString(),
      flowCount: (json['flow_count'] as num?)?.toInt(),
      codebaseId: (json['codebase_id'] as num?)?.toInt(),
      seed: (json['seed'] as num?)?.toInt(),
      questTitle: json['quest_title'],
      questOptions: json['quest_options'] is List
          ? List<dynamic>.from(json['quest_options'] as List)
          : null,
      error: json['error']?.toString(),
    );
  }
}

class DailyQuestItem {
  final String id;
  final String questType;
  final String title;
  final int target;
  final int progress;
  final String status;
  final int rewardPoints;
  final bool rewardClaimed;
  final int claimedPoints;
  final String claimStatus;
  final bool claimable;
  final String difficulty;
  final String difficultyLabel;
  final String description;

  const DailyQuestItem({
    required this.id,
    required this.questType,
    required this.title,
    required this.target,
    required this.progress,
    required this.status,
    this.rewardPoints = 0,
    this.rewardClaimed = false,
    this.claimedPoints = 0,
    this.claimStatus = '',
    this.claimable = false,
    this.difficulty = 'easy',
    this.difficultyLabel = '하',
    this.description = '',
  });

  factory DailyQuestItem.fromJson(Map<String, dynamic> json) {
    return DailyQuestItem(
      id: (json['id'] ?? '').toString(),
      questType: (json['quest_type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      target: (json['target'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      rewardPoints: (json['reward_points'] as num?)?.toInt() ?? 0,
      rewardClaimed: json['reward_claimed'] == true,
      claimedPoints: (json['claimed_points'] as num?)?.toInt() ?? 0,
      claimStatus: (json['claim_status'] ?? '').toString(),
      claimable: json['claimable'] == true,
      difficulty: (json['difficulty'] ?? 'easy').toString(),
      difficultyLabel: (json['difficulty_label'] ?? '하').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class AccountSummary {
  final int totalPoints;
  final int activityScore;
  final int level;
  final int currentLevelScore;
  final int nextLevelScore;
  final double levelProgress;
  final int dailyPoints;
  final int dailyPointLimit;
  final int dailyPointsRemaining;
  final int activityDisplayDailyCap;
  final int grantedPoints;
  final bool duplicateReward;
  final bool dailyCapReached;

  const AccountSummary({
    this.totalPoints = 0,
    this.activityScore = 0,
    this.level = 1,
    this.currentLevelScore = 0,
    this.nextLevelScore = 100,
    this.levelProgress = 0,
    this.dailyPoints = 0,
    this.dailyPointLimit = 100,
    this.dailyPointsRemaining = 100,
    this.activityDisplayDailyCap = 2000,
    this.grantedPoints = 0,
    this.duplicateReward = false,
    this.dailyCapReached = false,
  });

  factory AccountSummary.fromJson(Map<String, dynamic> json) {
    final rewardRaw = json['reward'];
    final reward = rewardRaw is Map
        ? Map<String, dynamic>.from(rewardRaw)
        : const <String, dynamic>{};
    return AccountSummary(
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      activityScore: (json['activity_score'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentLevelScore: (json['current_level_score'] as num?)?.toInt() ?? 0,
      nextLevelScore: (json['next_level_score'] as num?)?.toInt() ?? 100,
      levelProgress:
          ((json['level_progress'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.0)
              .toDouble(),
      dailyPoints: (json['daily_points'] as num?)?.toInt() ?? 0,
      dailyPointLimit: (json['daily_point_limit'] as num?)?.toInt() ?? 100,
      dailyPointsRemaining:
          (json['daily_points_remaining'] as num?)?.toInt() ?? 100,
      activityDisplayDailyCap:
          (json['activity_display_daily_cap'] as num?)?.toInt() ?? 2000,
      grantedPoints: (reward['granted_points'] as num?)?.toInt() ?? 0,
      duplicateReward: reward['duplicate'] == true,
      dailyCapReached: reward['daily_cap_reached'] == true,
    );
  }
}

class DailyQuestBundle {
  final List<DailyQuestItem> items;
  final AccountSummary account;
  final int revision;

  const DailyQuestBundle({
    required this.items,
    required this.account,
    this.revision = 1,
  });

  factory DailyQuestBundle.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => DailyQuestItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final accountRaw = json['account'];
    final account = accountRaw is Map
        ? AccountSummary.fromJson(Map<String, dynamic>.from(accountRaw))
        : const AccountSummary();
    return DailyQuestBundle(
      items: items,
      account: account,
      revision: (json['revision'] as num?)?.toInt() ?? 1,
    );
  }
}

class SolveAnalysisResponse {
  final double? correctRate;
  final int? totalSolved;
  final int? totalCorrect;
  final List<String>? weakTags;
  final Map<String, dynamic>? details;
  final List<Map<String, dynamic>> status;
  final List<Map<String, dynamic>> stepCorrectness;
  final bool? isCorrect;
  final List<int> inPanic;
  final String aiOpinion;
  final String? questId;
  final List<String> questModel;
  final List<String> warnings;
  final Map<String, dynamic>? debugInfo;

  SolveAnalysisResponse({
    this.correctRate,
    this.totalSolved,
    this.totalCorrect,
    this.weakTags,
    this.details,
    this.status = const [],
    this.stepCorrectness = const [],
    this.isCorrect,
    this.inPanic = const [],
    this.aiOpinion = '',
    this.questId,
    this.questModel = const [],
    this.warnings = const [],
    this.debugInfo,
  });

  factory SolveAnalysisResponse.fromJson(Map<String, dynamic> json) {
    final status = _mapList(json['status']);
    final stepCorrectness = _mapList(json['step_correctness']);
    final parsedIsCorrect = _parseBool(json['is_correct']);
    return SolveAnalysisResponse(
      correctRate: json['correct_rate'] != null
          ? (json['correct_rate'] as num).toDouble()
          : null,
      totalSolved: (json['total_solved'] as num?)?.toInt(),
      totalCorrect: (json['total_correct'] as num?)?.toInt(),
      weakTags: json['weak_tags'] != null
          ? (json['weak_tags'] as List<dynamic>)
                .map((item) => item.toString())
                .toList()
          : null,
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : null,
      status: status,
      stepCorrectness: stepCorrectness.isNotEmpty
          ? stepCorrectness
          : _stepCorrectnessFromStatus(status),
      isCorrect: parsedIsCorrect ?? _isCorrectFromStatus(status),
      inPanic: (json['in_panic'] as List<dynamic>? ?? const [])
          .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
          .whereType<int>()
          .toList(),
      aiOpinion: (json['ai_opinion'] ?? '').toString(),
      questId: json['quest_id']?.toString(),
      questModel: (json['quest_model'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      debugInfo: json['debug'] is Map
          ? Map<String, dynamic>.from(json['debug'] as Map)
          : null,
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value == null) return null;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  static bool? _isCorrectFromStatus(List<Map<String, dynamic>> status) {
    if (status.isEmpty) return null;
    return status.every(
      (item) => item['status']?.toString().toUpperCase() == 'O',
    );
  }

  static List<Map<String, dynamic>> _stepCorrectnessFromStatus(
    List<Map<String, dynamic>> status,
  ) {
    return status.asMap().entries.map((entry) {
      final item = entry.value;
      final rawFlowNumber = item['flow_number'] ?? entry.key;
      final flowNumber = rawFlowNumber is num
          ? rawFlowNumber.toInt()
          : int.tryParse('$rawFlowNumber') ?? entry.key;
      final correct = item['status']?.toString().toUpperCase() == 'O';
      return {
        'step_id': flowNumber + 1,
        'flow_number': flowNumber,
        'correct': correct,
        'similarity': correct ? 1.0 : 0.0,
      };
    }).toList();
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
      userId: (json['user_id'] ?? json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      role: json['role']?.toString(),
      grade: json['grade']?.toString(),
      track: json['track']?.toString(),
      subject: json['subject']?.toString(),
      school: json['school']?.toString(),
      email: json['email']?.toString(),
    );
  }

  UserProfile copyWith({
    String? userId,
    String? username,
    String? name,
    String? role,
    String? grade,
    String? track,
    String? subject,
    String? school,
    String? email,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      name: name ?? this.name,
      role: role ?? this.role,
      grade: grade ?? this.grade,
      track: track ?? this.track,
      subject: subject ?? this.subject,
      school: school ?? this.school,
      email: email ?? this.email,
    );
  }
}

class MarketplaceListingPage {
  const MarketplaceListingPage({
    required this.items,
    required this.total,
    this.nextOffset,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int? nextOffset;
}

// ---------------------------------------------------------------------------
// Academy Domain Models
// ---------------------------------------------------------------------------

class Academy {
  final String academyId;
  final String name;
  final String? address;
  final String? phone;
  final String? adminUserId;
  final DateTime? createdAt;

  Academy({
    required this.academyId,
    required this.name,
    this.address,
    this.phone,
    this.adminUserId,
    this.createdAt,
  });

  factory Academy.fromJson(Map<String, dynamic> json) {
    return Academy(
      academyId: json['academy_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      adminUserId: json['admin_user_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class AcademyGroup {
  final String groupId;
  final String academyId;
  final String name;
  final String? grade;
  final String? subject;
  final String? teacherUserId;
  final String groupType;
  final bool searchable;
  final bool friendVerificationRequired;
  final int maxMembers;
  final String? styleBorderColor;
  final String? styleBadgeText;
  final String? scheduleJson;
  final DateTime? createdAt;

  AcademyGroup({
    required this.groupId,
    required this.academyId,
    required this.name,
    this.grade,
    this.subject,
    this.teacherUserId,
    this.groupType = 'academy_tutoring_group',
    this.searchable = false,
    this.friendVerificationRequired = true,
    this.maxMembers = 20,
    this.styleBorderColor,
    this.styleBadgeText,
    this.scheduleJson,
    this.createdAt,
  });

  factory AcademyGroup.fromJson(Map<String, dynamic> json) {
    return AcademyGroup(
      groupId: json['group_id'] ?? json['id'] ?? '',
      academyId: json['academy_id'] ?? '',
      name: json['name'] ?? '',
      grade: json['grade'],
      subject: json['subject'],
      teacherUserId: json['teacher_user_id'],
      groupType: json['group_type'] ?? 'academy_tutoring_group',
      searchable: json['searchable'] == true || json['searchable'] == 1,
      friendVerificationRequired:
          json['friend_verification_required'] == true ||
          json['friend_verification_required'] == 1,
      maxMembers: json['max_members'] ?? 20,
      styleBorderColor: json['style_border_color'],
      styleBadgeText: json['style_badge_text'],
      scheduleJson: json['schedule_json'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
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
    this.role = 'student',
    this.status = 'active',
    this.joinedAt,
    this.removedAt,
  });

  factory AcademyGroupMember.fromJson(Map<String, dynamic> json) {
    return AcademyGroupMember(
      memberId: json['member_id'] ?? json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      userId: json['user_id'] ?? '',
      role: json['role'] ?? 'student',
      status: json['status'] ?? 'active',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'])
          : null,
      removedAt: json['removed_at'] != null
          ? DateTime.tryParse(json['removed_at'])
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
  final String? checkedByUserId;
  final DateTime? checkedAt;
  final String? note;

  AttendanceLog({
    required this.logId,
    required this.groupId,
    required this.userId,
    required this.date,
    required this.status,
    this.checkedByUserId,
    this.checkedAt,
    this.note,
  });

  factory AttendanceLog.fromJson(Map<String, dynamic> json) {
    return AttendanceLog(
      logId: json['log_id'] ?? json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      userId: json['user_id'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'present',
      checkedByUserId: json['checked_by_user_id'],
      checkedAt: json['checked_at'] != null
          ? DateTime.tryParse(json['checked_at'])
          : null,
      note: json['note'],
    );
  }
}

class AttendanceStats {
  final String userId;
  final String groupId;
  final int days;
  final int totalRecords;
  final int present;
  final int late;
  final int absent;
  final double attendanceRate;
  final double lateRate;
  final double absenceRate;
  final int consecutiveAttendance;

  AttendanceStats({
    required this.userId,
    required this.groupId,
    required this.days,
    required this.totalRecords,
    required this.present,
    required this.late,
    required this.absent,
    required this.attendanceRate,
    required this.lateRate,
    required this.absenceRate,
    required this.consecutiveAttendance,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      userId: json['user_id'] ?? '',
      groupId: json['group_id'] ?? '',
      days: json['days'] ?? 30,
      totalRecords: json['total_records'] ?? 0,
      present: json['present'] ?? 0,
      late: json['late'] ?? 0,
      absent: json['absent'] ?? 0,
      attendanceRate: (json['attendance_rate'] ?? 0.0).toDouble(),
      lateRate: (json['late_rate'] ?? 0.0).toDouble(),
      absenceRate: (json['absence_rate'] ?? 0.0).toDouble(),
      consecutiveAttendance: json['consecutive_attendance'] ?? 0,
    );
  }
}

class TuitionPayment {
  final String paymentId;
  final String academyId;
  final String userId;
  final int amount;
  final String monthLabel;
  final String? method;
  final DateTime? paidAt;
  final String? receiptUrl;
  final String? memo;

  TuitionPayment({
    required this.paymentId,
    required this.academyId,
    required this.userId,
    required this.amount,
    required this.monthLabel,
    this.method,
    this.paidAt,
    this.receiptUrl,
    this.memo,
  });

  factory TuitionPayment.fromJson(Map<String, dynamic> json) {
    return TuitionPayment(
      paymentId: json['payment_id'] ?? json['id'] ?? '',
      academyId: json['academy_id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: json['amount'] ?? 0,
      monthLabel: json['month_label'] ?? '',
      method: json['method'],
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'])
          : null,
      receiptUrl: json['receipt_url'],
      memo: json['memo'],
    );
  }
}

class FinanceLedger {
  final String ledgerId;
  final String academyId;
  final String category;
  final int amount;
  final String? description;
  final String transactionDate;
  final String? recordedByUserId;
  final DateTime? createdAt;

  FinanceLedger({
    required this.ledgerId,
    required this.academyId,
    required this.category,
    required this.amount,
    this.description,
    required this.transactionDate,
    this.recordedByUserId,
    this.createdAt,
  });

  factory FinanceLedger.fromJson(Map<String, dynamic> json) {
    return FinanceLedger(
      ledgerId: json['ledger_id'] ?? json['id'] ?? '',
      academyId: json['academy_id'] ?? '',
      category: json['category'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'],
      transactionDate: json['transaction_date'] ?? '',
      recordedByUserId: json['recorded_by_user_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class ParentConsultNote {
  final String noteId;
  final String academyId;
  final String studentUserId;
  final String? parentName;
  final String? parentContact;
  final String? topic;
  final String? content;
  final String? consultedByUserId;
  final DateTime? consultedAt;
  final String? followUpDate;

  ParentConsultNote({
    required this.noteId,
    required this.academyId,
    required this.studentUserId,
    this.parentName,
    this.parentContact,
    this.topic,
    this.content,
    this.consultedByUserId,
    this.consultedAt,
    this.followUpDate,
  });

  factory ParentConsultNote.fromJson(Map<String, dynamic> json) {
    return ParentConsultNote(
      noteId: json['note_id'] ?? json['id'] ?? '',
      academyId: json['academy_id'] ?? '',
      studentUserId: json['student_user_id'] ?? '',
      parentName: json['parent_name'],
      parentContact: json['parent_contact'],
      topic: json['topic'],
      content: json['content'],
      consultedByUserId: json['consulted_by_user_id'],
      consultedAt: json['consulted_at'] != null
          ? DateTime.tryParse(json['consulted_at'])
          : null,
      followUpDate: json['follow_up_date'],
    );
  }
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

  GroupAssignment({
    required this.assignmentId,
    required this.groupId,
    required this.senderUserId,
    required this.kind,
    required this.refId,
    this.title,
    this.message,
    this.dueDate,
    this.createdAt,
  });

  factory GroupAssignment.fromJson(Map<String, dynamic> json) {
    return GroupAssignment(
      assignmentId: json['assignment_id'] ?? json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      senderUserId: json['sender_user_id'] ?? '',
      kind: json['kind'] ?? '',
      refId: json['ref_id'] ?? '',
      title: json['title'],
      message: json['message'],
      dueDate: json['due_date'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class GroupSubmission {
  final String submissionId;
  final String assignmentId;
  final String userId;
  final String status;
  final DateTime? submittedAt;
  final String? dataJson;

  GroupSubmission({
    required this.submissionId,
    required this.assignmentId,
    required this.userId,
    this.status = 'pending',
    this.submittedAt,
    this.dataJson,
  });

  factory GroupSubmission.fromJson(Map<String, dynamic> json) {
    return GroupSubmission(
      submissionId: json['submission_id'] ?? json['id'] ?? '',
      assignmentId: json['assignment_id'] ?? '',
      userId: json['user_id'] ?? '',
      status: json['status'] ?? 'pending',
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'])
          : null,
      dataJson: json['data_json'],
    );
  }
}

class StudentAssignmentTask {
  const StudentAssignmentTask({
    required this.assignment,
    required this.submission,
  });

  final GroupAssignment assignment;
  final GroupSubmission submission;

  factory StudentAssignmentTask.fromJson(Map<String, dynamic> json) {
    return StudentAssignmentTask(
      assignment: GroupAssignment.fromJson(json),
      submission: GroupSubmission.fromJson({
        'submission_id': json['submission_id'],
        'assignment_id': json['assignment_id'],
        'user_id': json['submission_user_id'] ?? json['user_id'],
        'status': json['submission_status'] ?? json['status'],
        'submitted_at': json['submitted_at'],
        'data_json': json['data_json'],
      }),
    );
  }
}

class StudentScheduleTask {
  const StudentScheduleTask({
    required this.taskId,
    required this.date,
    required this.title,
  });

  final String taskId;
  final String date;
  final String title;

  factory StudentScheduleTask.fromJson(Map<String, dynamic> json) {
    return StudentScheduleTask(
      taskId: json['task_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class SubmissionReport {
  final String reportId;
  final String submissionId;
  final double? correctRate;
  final int? timeSpentSeconds;
  final List<String>? weakTags;
  final String? feedback;
  final DateTime? createdAt;

  SubmissionReport({
    required this.reportId,
    required this.submissionId,
    this.correctRate,
    this.timeSpentSeconds,
    this.weakTags,
    this.feedback,
    this.createdAt,
  });

  factory SubmissionReport.fromJson(Map<String, dynamic> json) {
    return SubmissionReport(
      reportId: json['report_id'] ?? json['id'] ?? '',
      submissionId: json['submission_id'] ?? '',
      correctRate: json['correct_rate'] != null
          ? (json['correct_rate'] as num).toDouble()
          : null,
      timeSpentSeconds: json['time_spent_seconds'],
      weakTags: json['weak_tags'] != null
          ? List<String>.from(json['weak_tags'])
          : null,
      feedback: json['feedback'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
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
  final DateTime? createdAt;

  TimetablePreference({
    required this.preferenceId,
    required this.groupId,
    required this.userId,
    required this.dayOfWeek,
    required this.timeSlot,
    this.priority = 1,
    this.createdAt,
  });

  factory TimetablePreference.fromJson(Map<String, dynamic> json) {
    return TimetablePreference(
      preferenceId: json['preference_id'] ?? json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      userId: json['user_id'] ?? '',
      dayOfWeek: json['day_of_week'] ?? '',
      timeSlot: json['time_slot'] ?? '',
      priority: json['priority'] ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class TimetablePlan {
  final String planId;
  final String groupId;
  final String planJson;
  final String version;
  final DateTime? generatedAt;
  final bool applied;

  TimetablePlan({
    required this.planId,
    required this.groupId,
    required this.planJson,
    this.version = 'v1',
    this.generatedAt,
    this.applied = false,
  });

  factory TimetablePlan.fromJson(Map<String, dynamic> json) {
    return TimetablePlan(
      planId: json['plan_id'] ?? json['id'] ?? '',
      groupId: json['group_id'] ?? '',
      planJson: json['plan_json'] ?? '',
      version: json['version'] ?? 'v1',
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'])
          : null,
      applied: json['applied'] == true || json['applied'] == 1,
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
  final String? lastConsultNoteId;
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
    this.lastConsultNoteId,
    this.summaryJson,
    this.createdAt,
  });

  factory StudentOverviewSnapshot.fromJson(Map<String, dynamic> json) {
    return StudentOverviewSnapshot(
      snapshotId: json['snapshot_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      academyId: json['academy_id'] ?? '',
      groupId: json['group_id'],
      overallScore: json['overall_score'] != null
          ? (json['overall_score'] as num).toDouble()
          : null,
      attendanceRate: json['attendance_rate'] != null
          ? (json['attendance_rate'] as num).toDouble()
          : null,
      tuitionStatus: json['tuition_status'],
      lastConsultNoteId: json['last_consult_note_id'],
      summaryJson: json['summary_json'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String baseUrl = ApiContract.baseUrl;
  static const String _cacheNamespace = 'api_cache_v1_';
  static const int _cacheBodySizeLimit = 300000;
  static const Duration _fallbackCacheTtl = Duration(minutes: 10);

  static String resourceUrl(String source) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return ApiContract.url(trimmed);
  }

  String? _token;
  http.Client _httpClient = http.Client();
  static final Map<String, _CachedApiResponse> _memoryCache = {};
  static final Map<String, Future<http.Response>> _inflightCacheRequests = {};
  int _cacheGeneration = 0;

  /// 필요한 변수는 메모리에 적재된 현재 JWT다.
  /// 작동 원리: 라우트가 생성되는 순간 토큰 존재 여부를 동기적으로 확인해, 앱 시작 후 로그인한 세션도 즉시 반영한다.
  bool get hasAuthenticatedSession => _token?.trim().isNotEmpty ?? false;

  Future<String> _ensureToken() async {
    if (_token != null) return _token!;
    final prefs = await SharedPreferences.getInstance();
    _token =
        prefs.getString('jwt_token') ?? await AuthStorage.instance.readToken();
    if (_token != null) return _token!;
    throw ApiException(statusCode: 401, message: 'Missing auth token');
  }

  /// 필요한 변수는 새 인증 토큰과 선택 사용자명이다.
  /// 기존 사용자와 토큰이 달라지면 이전 네임스페이스를 먼저 비워 계정 간 응답 혼입을 막는다.
  Future<void> setToken(String token, {String? username}) async {
    if (_token != null && _token != token) {
      await clearUserCache(token: _token);
    }
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    if (username != null) {
      await prefs.setString('username', username);
    }
    await AuthStorage.instance.saveToken(token, username: username);
  }

  /// 현재 토큰을 변수로 사용해 해당 사용자의 메모리·영속 캐시와 진행 GET을 정리한다.
  /// 캐시 세대를 올린 뒤 인증 정보를 지워, 늦게 끝난 요청이 로그아웃 후 캐시를 되살리지 못하게 한다.
  Future<void> clearToken() async {
    await clearUserCache(token: _token);
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');
    await AuthStorage.instance.clear();
  }

  Future<UserProfile> getMyProfile() async {
    final res = await _get<Map<String, dynamic>>(
      '/auth/me',
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return UserProfile.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<UserProfile> updateMyProfile({
    String? username,
    String? name,
    String? grade,
    String? track,
    String? subject,
    String? school,
    String? email,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (username != null && username.trim().isNotEmpty) {
      body['username'] = username.trim();
    }
    if (name != null && name.trim().isNotEmpty) body['name'] = name.trim();
    if (grade != null && grade.trim().isNotEmpty) body['grade'] = grade.trim();
    if (track != null && track.trim().isNotEmpty) body['track'] = track.trim();
    if (subject != null && subject.trim().isNotEmpty) {
      body['subject'] = subject.trim();
    }
    if (school != null) body['school'] = school.trim();
    if (email != null) body['email'] = email.trim();
    if (password != null && password.isNotEmpty) body['password'] = password;

    final res = await _put<Map<String, dynamic>>(
      '/auth/me',
      body,
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return UserProfile.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> deleteMyProfile({required String password}) async {
    await _delete('/auth/me', body: {'password': password});
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<ApiResponse<T>> _get<T>(
    String path, {
    T Function(dynamic)? parser,
    Map<String, String>? query,
    bool useCache = false,
    bool forceRefresh = false,
    Duration? cacheTtl,
  }) async {
    await _ensureToken();
    final uri = ApiContract.uri(path, query: query);
    final key = _cacheKey(path, query);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final cached = useCache && !forceRefresh ? await _readCache(key) : null;
    final ttlToUse = cacheTtl ?? _fallbackCacheTtl;

    if (useCache && cached != null && cached.isFresh(nowMs)) {
      return _parseCachedBody<T>(cached, parser);
    }

    final requestHeaders = <String, String>{
      ..._headers,
      if (cached?.etag != null && cached!.etag!.isNotEmpty)
        'If-None-Match': cached.etag!,
      if (cached?.lastModified != null && cached!.lastModified.isNotEmpty)
        'If-Modified-Since': cached.lastModified,
    };

    final requestGeneration = _cacheGeneration;

    /// 필요한 변수는 캐시 키·조건부 요청 헤더·현재 캐시 세대다.
    /// 네트워크에서는 원시 응답만 합치고, 각 호출자는 자신의 parser로 별도 변환한다.
    Future<http.Response> requestRaw() async {
      final logSuffix = cached == null
          ? 'network'
          : (cached.etag != null && cached.etag!.isNotEmpty) ||
                cached.lastModified.isNotEmpty
          ? 'revalidate'
          : 'network';
      log('GET $uri ($logSuffix)', name: 'ApiClient');

      final res = await _httpClient.get(uri, headers: requestHeaders);
      await _clearTokenOnUnauthorized(res);

      if (useCache && res.statusCode == 304 && cached != null) {
        return _cachedHttpResponse(cached);
      }

      if (useCache &&
          res.statusCode >= 200 &&
          res.statusCode < 300 &&
          requestGeneration == _cacheGeneration) {
        await _saveCache(
          key,
          keyBody: res.body,
          ttl: ttlToUse,
          statusCode: res.statusCode,
          etag: res.headers['etag'],
          lastModified: res.headers['last-modified'],
        );
      }
      return res;
    }

    final future = _inflightCacheRequests.putIfAbsent(key, requestRaw);
    try {
      final response = await future;
      return _parse(response, parser);
    } finally {
      if (identical(_inflightCacheRequests[key], future)) {
        _inflightCacheRequests.remove(key);
      }
    }
  }

  /// 필요한 변수는 요청 경로·정렬된 쿼리·현재 토큰이다.
  /// 토큰 전체를 SHA-256으로 단방향 변환해 사용자별 키를 만들고 원문 노출을 피한다.
  String _cacheKey(String path, Map<String, String>? query) {
    final sortedPairs =
        query == null ? <MapEntry<String, String>>[] : query.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final normalizedQuery = sortedPairs
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final normalizedPath = normalizedQuery.isEmpty
        ? path
        : '$path?$normalizedQuery';
    final userTag = _userCacheTag(_token);
    return '${userTag}_$normalizedPath';
  }

  /// 필요한 변수는 선택 토큰이며, UTF-8 바이트를 SHA-256으로 해시한다.
  /// 토큰이 없을 때만 고정 anonymous 네임스페이스를 반환한다.
  String _userCacheTag(String? token) {
    if (token == null || token.isEmpty) return 'anonymous';
    return sha256.convert(utf8.encode(token)).toString();
  }

  /// 필요한 변수는 무효화할 API 경로와 현재 사용자 태그다.
  /// 쿼리 유무와 관계없이 동일 경로로 시작하는 메모리·영속 캐시 및 진행 요청을 제거한다.
  Future<void> invalidateCachePath(String path) async {
    final prefix = '${_userCacheTag(_token)}_$path';
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
    _inflightCacheRequests.removeWhere((key, _) => key.startsWith(prefix));
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('$_cacheNamespace$prefix'))
        .toList(growable: false);
    await Future.wait(keys.map(prefs.remove));
  }

  /// 필요한 변수는 정리 대상 토큰이며 생략 시 현재 토큰을 사용한다.
  /// 사용자 해시로 시작하는 모든 캐시를 제거하고 세대를 증가시켜 지연 응답의 저장을 차단한다.
  Future<void> clearUserCache({String? token}) async {
    final prefix = '${_userCacheTag(token ?? _token)}_';
    _cacheGeneration += 1;
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
    _inflightCacheRequests.removeWhere((key, _) => key.startsWith(prefix));
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('$_cacheNamespace$prefix'))
        .toList(growable: false);
    await Future.wait(keys.map(prefs.remove));
  }

  /// 필요한 변수는 테스트용 HTTP 클라이언트다.
  /// 실제 네트워크 없이 동시 GET 병합과 parser 분리를 검증할 때만 전송 계층을 교체한다.
  @visibleForTesting
  void setHttpClientForTest(http.Client client) {
    _httpClient.close();
    _httpClient = client;
  }

  /// 필요한 변수는 확인할 토큰이다. 테스트에서 SHA-256 사용자 격리 값을 직접 검증한다.
  @visibleForTesting
  String userCacheTagForTest(String token) => _userCacheTag(token);

  /// 필요한 변수는 경로·원시 JSON·TTL이다. 네트워크 없이 현재 사용자 캐시를 준비한다.
  @visibleForTesting
  Future<void> seedCacheForTest(
    String path,
    String body, {
    Duration ttl = const Duration(minutes: 5),
  }) => _saveCache(
    _cacheKey(path, null),
    keyBody: body,
    ttl: ttl,
    statusCode: 200,
  );

  /// 필요한 변수는 경로다. 현재 사용자 메모리 캐시 존재 여부를 테스트에 반환한다.
  @visibleForTesting
  bool hasMemoryCacheForTest(String path) =>
      _memoryCache.containsKey(_cacheKey(path, null));

  Future<_CachedApiResponse?> _readCache(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_cacheNamespace$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final cached = _CachedApiResponse.fromJson(decoded);
        _memoryCache[key] = cached;
        return cached;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveCache(
    String key, {
    required String keyBody,
    required Duration ttl,
    required int statusCode,
    String? etag,
    String? lastModified,
  }) async {
    if (keyBody.length > _cacheBodySizeLimit) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _CachedApiResponse(
      savedAt: now,
      ttlMs: ttl.inMilliseconds,
      body: keyBody,
      statusCode: statusCode,
      etag: etag,
      lastModified: lastModified ?? '',
    );
    _memoryCache[key] = cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cacheNamespace$key',
        jsonEncode(cached.toJsonMap()),
      );
    } catch (_) {}
  }

  ApiResponse<T> _parseCachedBody<T>(
    _CachedApiResponse cached,
    T Function(dynamic)? parser,
  ) {
    return _parse(_cachedHttpResponse(cached), parser);
  }

  /// 필요한 변수는 저장된 원시 본문·상태 코드다.
  /// 캐시 데이터도 네트워크 응답과 같은 객체로 복원해 parser 적용 지점을 하나로 유지한다.
  http.Response _cachedHttpResponse(_CachedApiResponse cached) {
    return http.Response(
      cached.body,
      cached.statusCode,
      headers: const {
        'content-type': 'application/json; charset=utf-8',
        'from-cache': '1',
      },
    );
  }

  /// 필요한 변수는 POST 경로·JSON 본문·선택 parser와 교체 가능한 HTTP 클라이언트다.
  /// 인증 헤더를 붙여 동일 전송 계층으로 보내므로 런타임 API도 네트워크 없이 계약 테스트할 수 있다.
  Future<ApiResponse<T>> _post<T>(
    String path,
    Map<String, dynamic> body, {
    T Function(dynamic)? parser,
  }) async {
    await _ensureToken();
    final uri = ApiContract.uri(path);
    log('POST $uri', name: 'ApiClient');
    final res = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    await _clearTokenOnUnauthorized(res);
    return _parse(res, parser);
  }

  Future<ApiResponse<T>> _put<T>(
    String path,
    Map<String, dynamic> body, {
    T Function(dynamic)? parser,
  }) async {
    await _ensureToken();
    final uri = ApiContract.uri(path);
    log('PUT $uri', name: 'ApiClient');
    final res = await _httpClient.put(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    await _clearTokenOnUnauthorized(res);
    return _parse(res, parser);
  }

  Future<ApiResponse<T>> _patch<T>(
    String path,
    Map<String, dynamic> body, {
    T Function(dynamic)? parser,
  }) async {
    await _ensureToken();
    final uri = ApiContract.uri(path);
    log('PATCH $uri', name: 'ApiClient');
    final res = await _httpClient.patch(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    await _clearTokenOnUnauthorized(res);
    return _parse(res, parser);
  }

  Future<ApiResponse<T>> _delete<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? parser,
  }) async {
    await _ensureToken();
    final uri = ApiContract.uri(path);
    log('DELETE $uri', name: 'ApiClient');
    final res = await _httpClient.delete(
      uri,
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    await _clearTokenOnUnauthorized(res);
    return _parse(res, parser);
  }

  Future<void> _clearTokenOnUnauthorized(http.Response res) async {
    if (res.statusCode == 401) {
      await clearToken();
    }
  }

  ApiResponse<T> _parse<T>(http.Response res, T Function(dynamic)? parser) {
    final responseBody = utf8.decode(res.bodyBytes);
    final dynamic decoded = responseBody.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody);
    final Map<String, dynamic> body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) {
        return ApiResponse<T>(success: true, data: null, message: null);
      }
      final bool wrapped =
          body.containsKey('data') ||
          body.containsKey('success') ||
          body.containsKey('message');
      if (wrapped) {
        return ApiResponse.fromJson(body, parser);
      }
      return ApiResponse<T>(
        success: true,
        data: parser != null ? parser(body) : body as T?,
        message: null,
      );
    }
    throw ApiException(
      statusCode: res.statusCode,
      message: body['message'] ?? body['detail'] ?? 'Unknown error',
      retryAfterSeconds: int.tryParse(res.headers['retry-after'] ?? ''),
    );
  }

  // -------------------------------------------------------------------------
  // Study groups (existing)
  // -------------------------------------------------------------------------

  Future<List<StudyGroup>> listStudyGroups() async {
    final res = await _get(
      '/social/study-groups/mine',
      parser: parseStudyGroupListPayload,
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
    return res.data ?? const [];
  }

  /// 필요한 변수는 그룹 ID다.
  /// 작동 원리는 캐시 없이 일정 API를 호출해 서버의 당일 만료 처리가 즉시 화면에
  /// 반영되도록 한다.
  Future<List<StudyGroupSchedule>> listStudyGroupSchedules(
    String groupId,
  ) async {
    final res = await _get(
      '/social/study-groups/$groupId/schedules',
      parser: (d) => ((d['schedules'] as List?) ?? const [])
          .map(
            (item) => StudyGroupSchedule.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      useCache: false,
    );
    return res.data ?? const [];
  }

  /// 필요한 변수는 그룹 ID, 일정 제목, YYYY-MM-DD 날짜와 선택 HH:MM 시간이다.
  /// 작동 원리는 서버에 그룹장 권한 검증을 요청하고 성공한 신규 일정만 반환한다.
  Future<StudyGroupSchedule> createStudyGroupSchedule({
    required String groupId,
    required String title,
    required String scheduledDate,
    String? scheduledTime,
  }) async {
    final res = await _post(
      '/social/study-groups/$groupId/schedules',
      {
        'title': title.trim(),
        'scheduled_date': scheduledDate,
        if (scheduledTime != null && scheduledTime.trim().isNotEmpty)
          'scheduled_time': scheduledTime.trim(),
      },
      parser: (d) =>
          StudyGroupSchedule.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    return res.data ??
        StudyGroupSchedule(
          scheduleId: '',
          groupId: groupId,
          title: title,
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          createdAt: '',
        );
  }

  /// 필요한 변수는 조회할 소셜 그룹 ID다.
  /// 작동 원리는 소셜 그룹 멤버 API의 사용자 ID·닉네임을 그대로 모델로 변환하고 짧은 메모리 캐시로 반복 시트 열기 요청을 줄이는 것이다.
  Future<List<StudyGroupMember>> listStudyGroupMembers(String groupId) async {
    final res = await _get(
      '/social/study-groups/$groupId/members',
      parser: (data) {
        final items = data is List ? data : const <dynamic>[];
        return _parseListItemsSafely<StudyGroupMember>(
          items,
          StudyGroupMember.fromJson,
          source: 'study_group_members',
        );
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
    return res.data ?? const [];
  }

  Future<StudyGroup> createStudyGroup({
    required String name,
    String? description,
    String? password,
    int? maxMembers,
    bool? isPublic,
    int? logoIndex,
    bool? lockEnabled,
    String? inviteCode,
  }) async {
    final res = await _post('/social/study-groups', {
      'name': name,
      'description': description,
      'password': password,
      if (maxMembers != null) 'max_members': maxMembers,
      if (isPublic != null) 'is_public': isPublic,
      if (logoIndex != null) 'logo_index': logoIndex,
      if (lockEnabled != null) 'lock_enabled': lockEnabled,
      if (inviteCode != null && inviteCode.trim().isNotEmpty)
        'invite_code': inviteCode.trim(),
    }, parser: (d) => StudyGroup.fromJson(d));
    return res.data ??
        StudyGroup(
          id: '',
          name: name,
          description: description,
          memberCount: 0,
        );
  }

  Future<void> joinStudyGroup({
    required String groupId,
    String? password,
  }) async {
    await _post('/social/study-groups/$groupId/join', {'password': password});
  }

  Future<StudyGroup> joinStudyGroupByInviteCode({
    required String inviteCode,
    String? password,
  }) async {
    final res = await _post(
      '/social/study-groups/join-by-code',
      {'invite_code': inviteCode.trim(), 'password': password},
      parser: (d) => StudyGroup.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    return res.data ?? StudyGroup(id: '', name: '', memberCount: 0);
  }

  Future<StudyGroupInviteMeta> fetchStudyGroupInviteMeta(
    String inviteCode,
  ) async {
    final res = await _get(
      '/social/study-groups/invite/${inviteCode.trim()}',
      parser: (d) =>
          StudyGroupInviteMeta.fromJson(Map<String, dynamic>.from(d as Map)),
      useCache: true,
      cacheTtl: const Duration(minutes: 5),
    );
    return res.data ??
        StudyGroupInviteMeta(
          groupId: '',
          name: '',
          description: '',
          maxMembers: 0,
          members: 0,
          lockEnabled: false,
          inviteCode: inviteCode.trim(),
        );
  }

  Future<List<FriendProfile>> listFriends() async {
    final res = await _get(
      '/social/friends',
      parser: (d) {
        return _parseListItemsSafely<FriendProfile>(
          (d['friends'] as List<dynamic>?) ?? const [],
          FriendProfile.fromJson,
          source: 'friend_list',
        );
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return res.data ?? const [];
  }

  Future<List<FriendRequest>> listFriendRequests() async {
    final res = await _get(
      '/social/friend-requests',
      parser: (d) {
        return _parseListItemsSafely<FriendRequest>(
          (d['requests'] as List<dynamic>?) ?? const [],
          FriendRequest.fromJson,
          source: 'friend_request_list',
        );
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return res.data ?? const [];
  }

  Future<FriendRequest> sendFriendRequest({
    String? toUserId,
    String? username,
    String? message,
  }) async {
    final target = (toUserId ?? username ?? '').trim();
    final res = await _post(
      '/social/friend-requests',
      {
        'username': target,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
      parser: (d) =>
          FriendRequest.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    await invalidateCachePath('/social/friend-requests');
    return res.data ??
        FriendRequest(
          requestId: '',
          fromUserId: '',
          toUserId: target,
          status: 'pending',
          username: target,
          direction: 'outgoing',
          message: message,
        );
  }

  Future<void> acceptFriendRequest(String requestId) async {
    await _post('/social/friend-requests/$requestId/accept', {});
    await invalidateCachePath('/social/friend-requests');
    await invalidateCachePath('/social/friends');
    await invalidateCachePath('/social/friends/rankings');
  }

  Future<List<SharedFlowItem>> listSharedFlows(
    String groupId, {
    int? limit,
    List<String>? tags,
    String? userId,
    String? from,
    String? to,
  }) async {
    final res = await _get(
      '/social/study-groups/$groupId/shared-flows',
      parser: (d) {
        // Backend returns List<SharedFlowItem> directly, not wrapped in 'items'
        return (d as List).map((e) => SharedFlowItem.fromJson(e)).toList();
      },
      query: {
        if (limit != null) 'limit': '$limit',
        if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
    return res.data ?? const [];
  }

  Future<ApiResponse<void>> shareFlow(String groupId, String flowId) async {
    return _post('/social/study-groups/$groupId/shared-flows', {
      'flow_id': flowId,
    });
  }

  Future<ApiResponse<List<ExamItem>>> listExams() async {
    return _get(
      '/exams',
      parser: (d) {
        return (d['items'] as List).map((e) => ExamItem.fromJson(e)).toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 3),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> saveExamEditorPaper({
    String? paperId,
    required String title,
    required bool twoPerPage,
    String gradingAreaDirection = 'bottom',
    String? expectedUpdatedAt,
    required List<Map<String, dynamic>> items,
  }) async {
    return _post('/exam-editor/papers', {
      if (paperId != null) 'paper_id': paperId,
      'title': title,
      'two_per_page': twoPerPage,
      'grading_area_direction': gradingAreaDirection,
      if (expectedUpdatedAt != null) 'expected_updated_at': expectedUpdatedAt,
      'items': items,
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
  }

  Future<ApiResponse<Map<String, dynamic>>> getExamEditorPaper(
    String paperId,
  ) async {
    return _get(
      '/exam-editor/papers/$paperId',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> deployExamEditorPaper(
    String paperId,
  ) async {
    return _post(
      '/exam-editor/papers/$paperId/deploy',
      {},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> searchExamEditorProblems({
    String? hashTag,
    String? text,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 50,
  }) async {
    return _get(
      '/exam-editor/problems/search',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      query: {
        'page': '$page',
        'page_size': '$pageSize',
        if (hashTag != null && hashTag.trim().isNotEmpty)
          'hash_tag': hashTag.trim(),
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
        if (dateFrom != null && dateFrom.trim().isNotEmpty)
          'date_from': dateFrom.trim(),
        if (dateTo != null && dateTo.trim().isNotEmpty)
          'date_to': dateTo.trim(),
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> importExamEditorTray({
    required String sourceExamId,
    required List<int> itemIndexes,
  }) async {
    return _post('/exam-editor/tray/import', {
      'source_exam_id': sourceExamId,
      'item_indexes': itemIndexes,
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
  }

  Future<ApiResponse<Map<String, dynamic>>> arrangeExamEditorAi({
    String? paperId,
    required List<Map<String, dynamic>> items,
    String? instruction,
  }) async {
    return _post('/exam-editor/arrange/ai', {
      if (paperId != null) 'paper_id': paperId,
      'items': items,
      if (instruction != null && instruction.trim().isNotEmpty)
        'instruction': instruction.trim(),
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
  }

  // -------------------------------------------------------------------------
  // Quest generation / variants / tray (Goal 2)
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> searchQuests({
    String? hashTag,
    String? questId,
    String? text,
    String? textQuery,
    bool? isVariant,
    bool? isMcqBranch,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (hashTag != null && hashTag.trim().isNotEmpty)
        'hash_tag': hashTag.trim(),
      if (questId != null && questId.trim().isNotEmpty)
        'quest_id': questId.trim(),
      if ((text ?? textQuery) != null && (text ?? textQuery)!.trim().isNotEmpty)
        'text': (text ?? textQuery)!.trim(),
      if (isVariant != null) 'is_variant': '$isVariant',
      if (isMcqBranch != null) 'is_mcq_branch': '$isMcqBranch',
    };
    final res = await _get<List<Map<String, dynamic>>>(
      '/quests',
      query: query,
      parser: (d) {
        if (d is List) {
          return d
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        if (d is Map<String, dynamic>) {
          final map = Map<String, dynamic>.from(d);
          final items =
              map['quests'] ?? map['items'] ?? map['data'] ?? const <dynamic>[];
          return items is List
              ? items
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
              : const <Map<String, dynamic>>[];
        }
        return const <Map<String, dynamic>>[];
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
    return res.data ?? const <Map<String, dynamic>>[];
  }

  /// 필요한 변수는 마켓 검색·필터와 페이지 위치다.
  /// 작동 원리는 서버가 조건에 맞는 소량의 목록만 반환하게 해 전체 마켓 원장을 내려받지 않는 것이다.
  Future<MarketplaceListingPage> listMarketplaceListings({
    String? query,
    String? kind,
    String? gradeBand,
    String? price,
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await _get<MarketplaceListingPage>(
      '/marketplace/listings',
      query: {
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
        if (gradeBand != null && gradeBand.trim().isNotEmpty)
          'grade_band': gradeBand.trim(),
        if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
        'offset': '$offset',
        'limit': '$limit',
      },
      parser: (data) {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final rawItems = map['items'];
        final items = rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        return MarketplaceListingPage(
          items: items,
          total: int.tryParse(map['total']?.toString() ?? '') ?? items.length,
          nextOffset: int.tryParse(map['next_offset']?.toString() ?? ''),
        );
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return response.data ?? const MarketplaceListingPage(items: [], total: 0);
  }

  /// 필요한 변수는 로그인 사용자의 보유 마켓 자료다.
  /// 작동 원리는 서버가 미완료 자료를 먼저, 이수 완료 자료를 마지막에 반환하게 해 학습 모달에 그대로 표시하는 것이다.
  Future<List<Map<String, dynamic>>> listOwnedMarketplaceItems() async {
    final response = await _get<Map<String, dynamic>>(
      '/marketplace/my-items',
      parser: (data) => Map<String, dynamic>.from(data as Map),
      useCache: false,
    );
    final rawItems = response.data?['items'];
    return rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
  }

  /// 필요한 변수는 보유 문제세트 ID다.
  /// 작동 원리는 세트의 모든 문항을 단일 API 응답으로 받아 문항 수만큼
  /// `/quests`를 순차 요청하던 대기 시간을 없애고 풀이 화면을 즉시 시작하는 것이다.
  Future<List<Map<String, dynamic>>> loadMarketplaceProblemSetQuestions(
    String listingId,
  ) async {
    final response = await _get<List<Map<String, dynamic>>>(
      '/marketplace/my-items/${Uri.encodeComponent(listingId)}/questions',
      parser: (data) {
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final rawItems = map['items'];
        return rawItems is List
            ? rawItems
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 5),
    );
    return response.data ?? const <Map<String, dynamic>>[];
  }

  /// 필요한 변수는 구매할 공개 상품 ID다.
  /// 작동 원리는 서버에서 코인 차감과 보유 등록을 멱등 처리하고 갱신된 상품을 반환하는 것이다.
  Future<Map<String, dynamic>> purchaseMarketplaceListing(
    String listingId,
  ) async {
    final response = await _post<Map<String, dynamic>>(
      '/marketplace/listings/${Uri.encodeComponent(listingId)}/purchase',
      const <String, dynamic>{},
      parser: (data) => Map<String, dynamic>.from(data as Map),
    );
    return response.data ?? const <String, dynamic>{};
  }

  /// 필요한 변수는 보유 상품 ID·현재 문제 위치·완료 여부다.
  /// 작동 원리는 중단 시 위치를 저장하고 마지막 문제까지 끝내면 이수 완료 상태로 바꾸는 것이다.
  Future<void> updateMarketplaceProgress({
    required String listingId,
    required int progressIndex,
    required bool completed,
  }) async {
    await _post<Map<String, dynamic>>(
      '/marketplace/my-items/${Uri.encodeComponent(listingId)}/progress',
      {'progress_index': progressIndex, 'completed': completed},
      parser: (data) => Map<String, dynamic>.from(data as Map),
    );
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
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'hash_tags': hashTags,
        'solves_count': solvesCount,
        'strategy_level': strategyLevel,
        'branch_conditions': branchConditions,
        if (referenceQuestId != null && referenceQuestId.trim().isNotEmpty)
          'reference_quest_id': referenceQuestId.trim(),
        'strict_tags': strictTags,
        if (seed != null) 'seed': seed,
        if (requestId != null && requestId.trim().isNotEmpty)
          'request_id': requestId,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to generate quest',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final quest = payload['quest'];
    if (quest is Map) {
      return Map<String, dynamic>.from(quest);
    }
    final queuedRequestId = (payload['request_id'] ?? requestId)?.toString();
    if (queuedRequestId == null || queuedRequestId.isEmpty) {
      throw ApiException(statusCode: 500, message: 'Missing quest data');
    }
    final pollStartedAt = DateTime.now();
    for (var i = 0; i < 70; i++) {
      final elapsed = DateTime.now().difference(pollStartedAt);
      final delay = elapsed < const Duration(seconds: 2)
          ? const Duration(milliseconds: 200)
          : const Duration(milliseconds: 700);
      await Future<void>.delayed(delay);
      final status = await fetchQuestGenerateStatus(requestId: queuedRequestId);
      final state = status['status']?.toString();
      final statusQuest = status['quest'];
      if (statusQuest is Map) {
        return Map<String, dynamic>.from(statusQuest);
      }
      if (state == 'failed' || state == 'error' || state == 'cancelled') {
        throw ApiException(
          statusCode: 500,
          message: status['error']?.toString() ?? 'Quest generation failed',
        );
      }
    }
    throw ApiException(statusCode: 408, message: 'Quest generation timed out');
  }

  Future<Map<String, dynamic>> cancelQuestGeneration({
    required String requestId,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri(
      ApiPaths.questsGenerateCancel,
    ).replace(queryParameters: {'request_id': requestId});
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to cancel quest generation',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchQuestGenerateStatus({
    required String requestId,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/quests/generate/status',
      query: {'request_id': requestId},
      parser: (d) => d is Map<String, dynamic>
          ? Map<String, dynamic>.from(d)
          : const <String, dynamic>{},
      useCache: true,
      cacheTtl: const Duration(seconds: 1),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> generateVariantFromFlowDraft({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/from-flow-draft');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to generate flow-draft variant',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateVariantFromPromptNote({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/from-prompt-note');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to generate prompt-note variant',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertQuestToMcq({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/variants/convert-mcq');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to convert to MCQ',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gradeVariantSolve({
    required String questId,
    int? selectedIndex,
    String? userAnswer,
    List<int>? flowOrder,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/analysis/solve/variant-grade');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'quest_id': questId,
        if (selectedIndex != null) 'selected_index': selectedIndex,
        if (userAnswer != null) 'user_answer': userAnswer,
        if (flowOrder != null) 'flow_order': flowOrder,
      }),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to grade variant solve',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loadCourseProblemSolve({
    required String courseId,
    required String moduleId,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/courses/v2/runtime/problem-solve/load',
      {'course_id': courseId, 'module_id': moduleId},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return res.data ?? const <String, dynamic>{};
  }

  /// 필요한 변수는 코스·모듈·정오답 수·소요 시간이다.
  /// 모듈 제출 성공 후 코스 목록·상세·런타임 캐시를 한 경로 기준으로 비운다.
  Future<Map<String, dynamic>> submitCourseRuntimeModule({
    required String courseId,
    required String moduleId,
    required int correctCount,
    required int totalCount,
    required int elapsedSeconds,
    Map<String, int>? perProblemElapsedSeconds,
  }) async {
    final res =
        await _post<Map<String, dynamic>>('/courses/v2/runtime/submit', {
          'course_id': courseId,
          'module_id': moduleId,
          'correct_count': correctCount,
          'total_count': totalCount,
          'elapsed_seconds': elapsedSeconds,
          if (perProblemElapsedSeconds != null)
            'per_problem_elapsed_seconds': perProblemElapsedSeconds,
        }, parser: (d) => Map<String, dynamic>.from(d as Map));
    await invalidateCachePath('/courses');
    return res.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitLevelTestAnalysis({
    required Map<String, dynamic> payload,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/academy/analysis/level-test',
      payload,
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return res.data ?? const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listQuestTray({int limit = 100}) async {
    final res = await _get<List<Map<String, dynamic>>>(
      '/quests/tray',
      query: {'limit': '$limit'},
      parser: (d) => (d['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      useCache: true,
      cacheTtl: const Duration(seconds: 20),
    );
    return res.data ?? const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createQuestTrayItem({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = ApiContract.uri('/quests/tray');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to create quest tray item',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<ApiResponse<Map<String, dynamic>>> toggleExamEditorSource(
    bool enabled,
  ) async {
    return _post('/exam-editor/source/toggle', {
      'enabled': enabled,
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
  }

  Future<ApiResponse<SolveAnalysisResponse>> getSolveAnalysis(
    String userId,
  ) async {
    return _get(
      '/solve_analysis/$userId',
      parser: (d) => SolveAnalysisResponse.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
  }

  // -------------------------------------------------------------------------
  // Academy Domain
  // -------------------------------------------------------------------------

  // --- Academy ---

  Future<ApiResponse<Academy>> createAcademy({
    required String name,
    String? address,
    String? phone,
  }) async {
    return _post('/academy', {
      'name': name,
      'address': address,
      'phone': phone,
    }, parser: (d) => Academy.fromJson(d));
  }

  Future<ApiResponse<List<Academy>>> listAcademies() async {
    return _get(
      '/academy',
      parser: (d) {
        return _parseListItemsSafely<Academy>(
          (d['items'] as List<dynamic>?) ?? const [],
          Academy.fromJson,
          source: 'academy_list',
        );
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<Academy>> getAcademy(String academyId) async {
    return _get(
      '/academy/$academyId',
      parser: (d) => Academy.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<Academy>> updateAcademy(
    String academyId, {
    String? name,
    String? address,
    String? phone,
    String? adminUserId,
  }) async {
    return _put('/academy/$academyId', {
      if (name != null) 'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (adminUserId != null) 'admin_user_id': adminUserId,
    }, parser: (d) => Academy.fromJson(d));
  }

  Future<ApiResponse<void>> deleteAcademy(String academyId) async {
    return _delete('/academy/$academyId');
  }

  // --- AcademyGroup ---

  Future<ApiResponse<AcademyGroup>> createAcademyGroup({
    required String academyId,
    required String name,
    String? grade,
    String? subject,
    String groupType = 'academy_tutoring_group',
    bool searchable = false,
    bool friendVerificationRequired = true,
    int maxMembers = 20,
    String? styleBorderColor,
    String? styleBadgeText,
    String? scheduleJson,
  }) async {
    return _post('/academy/groups', {
      'academy_id': academyId,
      'name': name,
      'grade': grade,
      'subject': subject,
      'group_type': groupType,
      'searchable': searchable,
      'friend_verification_required': friendVerificationRequired,
      'max_members': maxMembers,
      'style_border_color': styleBorderColor,
      'style_badge_text': styleBadgeText,
      'schedule_json': scheduleJson,
    }, parser: (d) => AcademyGroup.fromJson(d));
  }

  Future<ApiResponse<List<AcademyGroup>>> listAcademyGroups({
    String? academyId,
    String? groupType,
    bool? searchable,
  }) async {
    return _get(
      '/academy/groups',
      parser: (d) {
        return _parseListItemsSafely<AcademyGroup>(
          (d['items'] as List<dynamic>?) ?? const [],
          AcademyGroup.fromJson,
          source: 'academy_groups',
        );
      },
      query: {
        if (academyId != null) 'academy_id': academyId,
        if (groupType != null) 'group_type': groupType,
        if (searchable != null) 'searchable': searchable.toString(),
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<AcademyGroup>> getAcademyGroup(String groupId) async {
    return _get(
      '/academy/groups/$groupId',
      parser: (d) => AcademyGroup.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<AcademyGroup>> updateAcademyGroup(
    String groupId, {
    String? name,
    String? grade,
    String? subject,
    String? teacherUserId,
    String? groupType,
    bool? searchable,
    bool? friendVerificationRequired,
    int? maxMembers,
    String? styleBorderColor,
    String? styleBadgeText,
    String? scheduleJson,
  }) async {
    return _put('/academy/groups/$groupId', {
      if (name != null) 'name': name,
      if (grade != null) 'grade': grade,
      if (subject != null) 'subject': subject,
      if (teacherUserId != null) 'teacher_user_id': teacherUserId,
      if (groupType != null) 'group_type': groupType,
      if (searchable != null) 'searchable': searchable,
      if (friendVerificationRequired != null)
        'friend_verification_required': friendVerificationRequired,
      if (maxMembers != null) 'max_members': maxMembers,
      if (styleBorderColor != null) 'style_border_color': styleBorderColor,
      if (styleBadgeText != null) 'style_badge_text': styleBadgeText,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
    }, parser: (d) => AcademyGroup.fromJson(d));
  }

  Future<ApiResponse<void>> deleteAcademyGroup(String groupId) async {
    return _delete('/academy/groups/$groupId');
  }

  // --- AcademyGroupMember ---

  Future<ApiResponse<AcademyGroupMember>> addGroupMember({
    required String groupId,
    required String userId,
    String role = 'student',
  }) async {
    return _post('/academy/members', {
      'group_id': groupId,
      'user_id': userId,
      'role': role,
    }, parser: (d) => AcademyGroupMember.fromJson(d));
  }

  Future<ApiResponse<AcademyGroupMember>> inviteGroupMember({
    required String groupId,
    required String invitedUserId,
  }) async {
    return _post('/academy/members/invite', {
      'group_id': groupId,
      'invited_user_id': invitedUserId,
    }, parser: (d) => AcademyGroupMember.fromJson(d));
  }

  Future<ApiResponse<AcademyGroupMember>> acceptInvitation(
    String memberId,
  ) async {
    return _post(
      '/academy/members/$memberId/accept',
      {},
      parser: (d) => AcademyGroupMember.fromJson(d),
    );
  }

  Future<ApiResponse<List<AcademyGroupMember>>> listGroupMembers(
    String groupId,
  ) async {
    return _get(
      '/academy/groups/$groupId/members',
      parser: (d) {
        return _parseListItemsSafely<AcademyGroupMember>(
          (d['items'] as List<dynamic>?) ?? const [],
          AcademyGroupMember.fromJson,
          source: 'academy_group_members',
        );
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 45),
    );
  }

  Future<ApiResponse<void>> removeGroupMember(
    String memberId, {
    String? reason,
  }) async {
    return _delete('/academy/members/$memberId');
  }

  // --- AttendanceLog ---

  Future<ApiResponse<AttendanceLog>> recordAttendance({
    required String groupId,
    required String userId,
    required String date,
    required String status,
    String? note,
  }) async {
    return _post('/academy/attendance', {
      'group_id': groupId,
      'user_id': userId,
      'date': date,
      'status': status,
      'note': note,
    }, parser: (d) => AttendanceLog.fromJson(d));
  }

  Future<ApiResponse<List<AttendanceLog>>> listAttendance({
    String? groupId,
    String? userId,
    String? date,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _get(
      '/academy/attendance',
      parser: (d) {
        return _parseListItemsSafely<AttendanceLog>(
          (d['items'] as List<dynamic>?) ?? const [],
          AttendanceLog.fromJson,
          source: 'academy_attendance',
        );
      },
      query: {
        if (groupId != null) 'group_id': groupId,
        if (userId != null) 'user_id': userId,
        if (date != null) 'date': date,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 45),
    );
  }

  Future<ApiResponse<AttendanceStats>> getAttendanceStats(
    String groupId,
    String userId, {
    int days = 30,
  }) async {
    return _get(
      '/academy/attendance/stats/$groupId/$userId',
      parser: (d) => AttendanceStats.fromJson(d),
      query: {'days': days.toString()},
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
  }

  Future<ApiResponse<AttendanceLog>> updateAttendance(
    String logId, {
    String? status,
    String? note,
  }) async {
    return _put('/academy/attendance/$logId', {
      if (status != null) 'status': status,
      if (note != null) 'note': note,
    }, parser: (d) => AttendanceLog.fromJson(d));
  }

  Future<ApiResponse<void>> deleteAttendance(String logId) async {
    return _delete('/academy/attendance/$logId');
  }

  // --- TuitionPayment ---

  Future<ApiResponse<TuitionPayment>> createTuitionPayment({
    required String academyId,
    required String userId,
    required int amount,
    required String monthLabel,
    String? method,
    String? receiptUrl,
    String? memo,
  }) async {
    return _post('/academy/tuition', {
      'academy_id': academyId,
      'user_id': userId,
      'amount': amount,
      'month_label': monthLabel,
      'method': method,
      'receipt_url': receiptUrl,
      'memo': memo,
    }, parser: (d) => TuitionPayment.fromJson(d));
  }

  Future<ApiResponse<List<TuitionPayment>>> listTuitionPayments({
    String? academyId,
    String? userId,
    String? monthLabel,
  }) async {
    return _get(
      '/academy/tuition',
      parser: (d) {
        return _parseListItemsSafely<TuitionPayment>(
          (d['items'] as List<dynamic>?) ?? const [],
          TuitionPayment.fromJson,
          source: 'academy_tuition',
        );
      },
      query: {
        if (academyId != null) 'academy_id': academyId,
        if (userId != null) 'user_id': userId,
        if (monthLabel != null) 'month_label': monthLabel,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getTuitionSummary(
    String academyId,
    String monthLabel,
  ) async {
    return _get(
      '/academy/tuition/summary/$academyId',
      parser: (d) => d as Map<String, dynamic>,
      query: {'month_label': monthLabel},
      useCache: true,
      cacheTtl: const Duration(hours: 1),
    );
  }

  Future<ApiResponse<void>> deleteTuitionPayment(String paymentId) async {
    return _delete('/academy/tuition/$paymentId');
  }

  // --- FinanceLedger ---

  Future<ApiResponse<FinanceLedger>> createLedgerEntry({
    required String academyId,
    required String category,
    required int amount,
    String? description,
    required String transactionDate,
  }) async {
    return _post('/academy/ledger', {
      'academy_id': academyId,
      'category': category,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate,
    }, parser: (d) => FinanceLedger.fromJson(d));
  }

  Future<ApiResponse<List<FinanceLedger>>> listLedgerEntries({
    String? academyId,
    String? category,
    String? transactionDateFrom,
    String? transactionDateTo,
  }) async {
    return _get(
      '/academy/ledger',
      parser: (d) {
        return _parseListItemsSafely<FinanceLedger>(
          (d['items'] as List<dynamic>?) ?? const [],
          FinanceLedger.fromJson,
          source: 'academy_ledger',
        );
      },
      query: {
        if (academyId != null) 'academy_id': academyId,
        if (category != null) 'category': category,
        if (transactionDateFrom != null)
          'transaction_date_from': transactionDateFrom,
        if (transactionDateTo != null) 'transaction_date_to': transactionDateTo,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> getLedgerSummary(
    String academyId, {
    String? transactionDateFrom,
    String? transactionDateTo,
  }) async {
    return _get(
      '/academy/ledger/summary/$academyId',
      parser: (d) => d as Map<String, dynamic>,
      query: {
        if (transactionDateFrom != null)
          'transaction_date_from': transactionDateFrom,
        if (transactionDateTo != null) 'transaction_date_to': transactionDateTo,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<void>> deleteLedgerEntry(String ledgerId) async {
    return _delete('/academy/ledger/$ledgerId');
  }

  // --- ParentConsultNote ---

  Future<ApiResponse<ParentConsultNote>> createConsultNote({
    required String academyId,
    required String studentUserId,
    String? parentName,
    String? parentContact,
    String? topic,
    String? content,
    String? followUpDate,
  }) async {
    return _post('/academy/consult', {
      'academy_id': academyId,
      'student_user_id': studentUserId,
      'parent_name': parentName,
      'parent_contact': parentContact,
      'topic': topic,
      'content': content,
      'follow_up_date': followUpDate,
    }, parser: (d) => ParentConsultNote.fromJson(d));
  }

  Future<ApiResponse<List<ParentConsultNote>>> listConsultNotes({
    String? academyId,
    String? studentUserId,
  }) async {
    return _get(
      '/academy/consult',
      parser: (d) {
        return _parseListItemsSafely<ParentConsultNote>(
          (d['items'] as List<dynamic>?) ?? const [],
          ParentConsultNote.fromJson,
          source: 'academy_consult',
        );
      },
      query: {
        if (academyId != null) 'academy_id': academyId,
        if (studentUserId != null) 'student_user_id': studentUserId,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
  }

  Future<ApiResponse<void>> deleteConsultNote(String noteId) async {
    return _delete('/academy/consult/$noteId');
  }

  // --- GroupAssignment ---

  Future<ApiResponse<GroupAssignment>> createAssignment({
    required String groupId,
    required String kind,
    required String refId,
    String? title,
    String? message,
    String? dueDate,
  }) async {
    return _post('/academy/assignments', {
      'group_id': groupId,
      'kind': kind,
      'ref_id': refId,
      'title': title,
      'message': message,
      'due_date': dueDate,
    }, parser: (d) => GroupAssignment.fromJson(d));
  }

  Future<ApiResponse<List<GroupAssignment>>> listAssignments({
    String? groupId,
    String? kind,
  }) async {
    return _get(
      '/academy/assignments',
      parser: (d) {
        return _parseListItemsSafely<GroupAssignment>(
          (d['items'] as List<dynamic>?) ?? const [],
          GroupAssignment.fromJson,
          source: 'academy_assignments',
        );
      },
      query: {
        if (groupId != null) 'group_id': groupId,
        if (kind != null) 'kind': kind,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
  }

  Future<ApiResponse<List<StudentAssignmentTask>>> listMyAssignments({
    String? kind,
  }) async {
    return _get(
      '/academy/assignments/my',
      parser: (d) {
        return _parseListItemsSafely<StudentAssignmentTask>(
          (d['items'] as List<dynamic>?) ?? const [],
          StudentAssignmentTask.fromJson,
          source: 'student_assignments',
        );
      },
      query: {if (kind != null) 'kind': kind},
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
  }

  Future<ApiResponse<GroupAssignment>> updateAssignment({
    required String assignmentId,
    String? title,
    String? message,
    String? dueDate,
  }) async {
    return _patch(
      '/academy/assignments/$assignmentId',
      {
        if (title != null) 'title': title,
        if (message != null) 'message': message,
        if (dueDate != null) 'due_date': dueDate,
      },
      parser: (d) => GroupAssignment.fromJson(d),
    );
  }

  Future<ApiResponse<void>> deleteAssignment(String assignmentId) async {
    return _delete('/academy/assignments/$assignmentId');
  }

  Future<ApiResponse<void>> syncMyStudentSchedule(
    Map<DateTime, List<String>> tasksByDate,
  ) async {
    final payload = <String, List<String>>{
      for (final entry in tasksByDate.entries)
        _dateKey(entry.key): List<String>.from(entry.value),
    };
    final response = await _put('/academy/students/me/schedule', {
      'tasks_by_date': payload,
    });
    await invalidateCachePath('/academy/students/me/schedule');
    return response;
  }

  /// 필요한 변수는 로그인 토큰과 개인 일정 API 응답이다.
  /// 작동 원리: 홈 카드에 필요한 일정만 단일 GET 요청으로 읽고 짧은 캐시로 중복 진입을 줄인다.
  Future<ApiResponse<List<StudentScheduleTask>>> listMyStudentSchedule() {
    return _get(
      '/academy/students/me/schedule',
      parser: (d) => _parseListItemsSafely<StudentScheduleTask>(
        (d['items'] as List<dynamic>?) ?? const [],
        StudentScheduleTask.fromJson,
        source: 'student_schedule',
      ),
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
  }

  static String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // --- GroupSubmission ---

  Future<ApiResponse<List<GroupSubmission>>> listSubmissions({
    String? assignmentId,
    String? userId,
    String? status,
  }) async {
    return _get(
      '/academy/submissions',
      parser: (d) {
        return _parseListItemsSafely<GroupSubmission>(
          (d['items'] as List<dynamic>?) ?? const [],
          GroupSubmission.fromJson,
          source: 'academy_submissions',
        );
      },
      query: {
        if (assignmentId != null) 'assignment_id': assignmentId,
        if (userId != null) 'user_id': userId,
        if (status != null) 'status': status,
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 45),
    );
  }

  Future<ApiResponse<GroupSubmission>> submitSubmission(
    String submissionId, {
    String? status,
    String? dataJson,
  }) async {
    return _post(
      '/academy/submissions/$submissionId/submit',
      {
        if (status != null) 'status': status,
        if (dataJson != null) 'data_json': dataJson,
      },
      parser: (d) => GroupSubmission.fromJson(d),
    );
  }

  // --- SubmissionReport ---

  Future<ApiResponse<SubmissionReport>> createSubmissionReport({
    required String submissionId,
    double? correctRate,
    int? timeSpentSeconds,
    List<String>? weakTags,
    String? feedback,
  }) async {
    return _post('/academy/reports', {
      'submission_id': submissionId,
      'correct_rate': correctRate,
      'time_spent_seconds': timeSpentSeconds,
      'weak_tags': weakTags,
      'feedback': feedback,
    }, parser: (d) => SubmissionReport.fromJson(d));
  }

  Future<ApiResponse<SubmissionReport>> getSubmissionReport(
    String reportId,
  ) async {
    return _get(
      '/academy/reports/$reportId',
      parser: (d) => SubmissionReport.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 5),
    );
  }

  Future<ApiResponse<SubmissionReport>> getReportBySubmission(
    String submissionId,
  ) async {
    return _get(
      '/academy/submissions/$submissionId/report',
      parser: (d) => SubmissionReport.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 5),
    );
  }

  // --- Timetable ---

  Future<ApiResponse<TimetablePreference>> createTimetablePreference({
    required String groupId,
    required String dayOfWeek,
    required String timeSlot,
    int priority = 1,
  }) async {
    return _post(
      '/academy/timetable/preferences',
      {
        'group_id': groupId,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
        'priority': priority,
      },
      parser: (d) => TimetablePreference.fromJson(d),
    );
  }

  Future<ApiResponse<List<TimetablePreference>>> listTimetablePreferences({
    String? groupId,
    String? userId,
  }) async {
    return _get(
      '/academy/timetable/preferences',
      parser: (d) {
        return _parseListItemsSafely<TimetablePreference>(
          (d['items'] as List<dynamic>?) ?? const [],
          TimetablePreference.fromJson,
          source: 'academy_timetable_preferences',
        );
      },
      query: {
        if (groupId != null) 'group_id': groupId,
        if (userId != null) 'user_id': userId,
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<void>> deleteTimetablePreference(
    String preferenceId,
  ) async {
    return _delete('/academy/timetable/preferences/$preferenceId');
  }

  Future<ApiResponse<Map<String, dynamic>>> generateTimetable(
    String groupId,
  ) async {
    return _post(
      '/academy/timetable/generate/$groupId',
      {},
      parser: (d) => d as Map<String, dynamic>,
    );
  }

  Future<ApiResponse<List<TimetablePlan>>> listTimetablePlans(
    String groupId,
  ) async {
    return _get(
      '/academy/timetable/plans/$groupId',
      parser: (d) {
        return _parseListItemsSafely<TimetablePlan>(
          (d['items'] as List<dynamic>?) ?? const [],
          TimetablePlan.fromJson,
          source: 'academy_timetable_plans',
        );
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<TimetablePlan>> applyTimetablePlan(String planId) async {
    return _post(
      '/academy/timetable/plans/$planId/apply',
      {},
      parser: (d) => TimetablePlan.fromJson(d),
    );
  }

  // --- StudentOverviewSnapshot ---

  Future<ApiResponse<StudentOverviewSnapshot>> buildStudentOverview({
    required String userId,
    required String academyId,
    String? groupId,
  }) async {
    return _post(
      '/academy/snapshots/build/$userId',
      {'academy_id': academyId, if (groupId != null) 'group_id': groupId},
      parser: (d) => StudentOverviewSnapshot.fromJson(d),
    );
  }

  Future<ApiResponse<List<StudentOverviewSnapshot>>> listSnapshots({
    String? userId,
    String? academyId,
    String? groupId,
    int limit = 50,
  }) async {
    return _get(
      '/academy/snapshots',
      parser: (d) {
        return _parseListItemsSafely<StudentOverviewSnapshot>(
          (d['items'] as List<dynamic>?) ?? const [],
          StudentOverviewSnapshot.fromJson,
          source: 'academy_snapshots',
        );
      },
      query: {
        if (userId != null) 'user_id': userId,
        if (academyId != null) 'academy_id': academyId,
        if (groupId != null) 'group_id': groupId,
        'limit': limit.toString(),
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
  }

  Future<ApiResponse<StudentOverviewSnapshot>> getSnapshot(
    String snapshotId,
  ) async {
    return _get(
      '/academy/snapshots/$snapshotId',
      parser: (d) => StudentOverviewSnapshot.fromJson(d),
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
  }

  Future<ApiResponse<void>> deleteSnapshot(String snapshotId) async {
    return _delete('/academy/snapshots/$snapshotId');
  }
}

class ExamRangeRequest {
  final String key;
  final List<String> tags;
  const ExamRangeRequest({required this.key, required this.tags});
  Map<String, dynamic> toJson() => {'key': key, 'tags': tags};
}

class ExamStatus {
  final String examId;
  final String status;
  final List<ExamItem> items;
  const ExamStatus({
    required this.examId,
    required this.status,
    required this.items,
  });

  factory ExamStatus.fromJson(Map<String, dynamic> json) {
    return ExamStatus(
      examId: (json['exam_id'] ?? json['id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => ExamItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class UserRating {
  final double rating;
  final double ovr;
  final double ovrDelta;
  final double recentAccuracy;
  final int loseStreak;
  const UserRating({
    required this.rating,
    required this.ovr,
    required this.ovrDelta,
    required this.recentAccuracy,
    required this.loseStreak,
  });
  factory UserRating.fromJson(Map<String, dynamic> json) => UserRating(
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    ovr: (json['ovr'] as num?)?.toDouble() ?? 0.0,
    ovrDelta: (json['ovr_delta'] as num?)?.toDouble() ?? 0.0,
    recentAccuracy: (json['recent_accuracy'] as num?)?.toDouble() ?? 0.0,
    loseStreak: (json['lose_streak'] as num?)?.toInt() ?? 0,
  );
}

class LevelTestPlacementQuestion {
  final int itemIndex;
  final int phase;
  final String subjectKey;
  final List<String> hashTags;
  final int difficultyTier;
  final String questId;
  final double problemRating;
  final Map<String, dynamic> quest;

  const LevelTestPlacementQuestion({
    required this.itemIndex,
    required this.phase,
    required this.subjectKey,
    required this.hashTags,
    required this.difficultyTier,
    required this.questId,
    required this.problemRating,
    required this.quest,
  });

  factory LevelTestPlacementQuestion.fromJson(Map<String, dynamic> json) {
    return LevelTestPlacementQuestion(
      itemIndex: (json['item_index'] as num?)?.toInt() ?? 0,
      phase: (json['phase'] as num?)?.toInt() ?? 1,
      subjectKey: (json['subject_key'] ?? '').toString(),
      hashTags: (json['hash_tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      difficultyTier: (json['difficulty_tier'] as num?)?.toInt() ?? 3,
      questId: (json['quest_id'] ?? '').toString(),
      problemRating: (json['problem_rating'] as num?)?.toDouble() ?? 1200.0,
      quest: Map<String, dynamic>.from(json['quest'] as Map? ?? const {}),
    );
  }
}

class LevelTestPlacementSession {
  final String sessionId;
  final String templateId;
  final int questionCount;
  final List<LevelTestPlacementQuestion> questions;

  const LevelTestPlacementSession({
    required this.sessionId,
    required this.templateId,
    required this.questionCount,
    required this.questions,
  });

  factory LevelTestPlacementSession.fromJson(Map<String, dynamic> json) {
    return LevelTestPlacementSession(
      sessionId: (json['session_id'] ?? '').toString(),
      templateId: (json['template_id'] ?? '').toString(),
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map(
            (e) => LevelTestPlacementQuestion.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class LevelTestPlacementResult {
  final String sessionId;
  final double rating;
  final double ovr;
  final double ovrDelta;
  final double recentAccuracy;
  final int loseStreak;
  final double confidence;
  final List<Map<String, dynamic>> strongTags;
  final List<Map<String, dynamic>> weakTags;

  const LevelTestPlacementResult({
    required this.sessionId,
    required this.rating,
    required this.ovr,
    required this.ovrDelta,
    required this.recentAccuracy,
    required this.loseStreak,
    required this.confidence,
    required this.strongTags,
    required this.weakTags,
  });

  factory LevelTestPlacementResult.fromJson(Map<String, dynamic> json) {
    return LevelTestPlacementResult(
      sessionId: (json['session_id'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ovr: (json['ovr'] as num?)?.toDouble() ?? 0.0,
      ovrDelta: (json['ovr_delta'] as num?)?.toDouble() ?? 0.0,
      recentAccuracy: (json['recent_accuracy'] as num?)?.toDouble() ?? 0.0,
      loseStreak: (json['lose_streak'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      strongTags: (json['strong_tags'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      weakTags: (json['weak_tags'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  UserRating toUserRating() {
    return UserRating(
      rating: rating,
      ovr: ovr,
      ovrDelta: ovrDelta,
      recentAccuracy: recentAccuracy,
      loseStreak: loseStreak,
    );
  }
}

class WeaknessTag {
  final String tag;
  final int count;
  final String? updatedAt;
  const WeaknessTag({required this.tag, required this.count, this.updatedAt});
  factory WeaknessTag.fromJson(Map<String, dynamic> json) => WeaknessTag(
    tag: (json['tag'] ?? '').toString(),
    count: (json['count'] as num?)?.toInt() ?? 0,
    updatedAt: json['updated_at']?.toString(),
  );
}

class OxQuizQuestion {
  final int? id;
  final String tag;
  final String question;
  final bool answer;
  const OxQuizQuestion({
    required this.tag,
    required this.question,
    required this.answer,
    this.id,
  });
  factory OxQuizQuestion.fromJson(Map<String, dynamic> json) => OxQuizQuestion(
    id: json['id'] as int?,
    tag: (json['tag'] ?? '').toString(),
    question: (json['question'] ?? '').toString(),
    answer: json['answer'] == true,
  );
}

class TagRating {
  final String tag;
  final double rating;
  final double delta;
  final int attempts;
  const TagRating({
    required this.tag,
    required this.rating,
    required this.delta,
    required this.attempts,
  });
}

class ProblemHabit {
  final int? codebaseId;
  final int? seed;
  final String questTitle;
  const ProblemHabit({this.codebaseId, this.seed, this.questTitle = ''});
}

class FriendRank {
  final int rank;
  final String username;
  final double visibleOvr;
  final bool isMe;
  const FriendRank({
    required this.rank,
    required this.username,
    required this.visibleOvr,
    this.isMe = false,
  });
}

class DirectMessage {
  final String id;
  final String from;
  final String to;
  final String text;
  final DateTime createdAt;
  final bool isMine;
  const DirectMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.createdAt,
    this.isMine = false,
  });
  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
    id: (json['id'] ?? json['message_id'] ?? '').toString(),
    from: (json['from'] ?? json['from_user_id'] ?? '').toString(),
    to: (json['to'] ?? json['to_user_id'] ?? '').toString(),
    text: (json['text'] ?? json['message'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now(),
    isMine: json['is_mine'] == true,
  );
}

class SolveHistoryItem {
  final String? questId;
  final int? codebaseId;
  final int? seed;
  final List<String> hashTags;
  final String createdAt;
  final String? kind;
  final Map<String, dynamic>? data;
  final String? questTitleRaw;
  const SolveHistoryItem({
    this.questId,
    this.codebaseId,
    this.seed,
    this.hashTags = const [],
    required this.createdAt,
    this.kind,
    this.data,
    this.questTitleRaw,
  });
}

class GroupSharedProblem {
  final String id;
  final String shareId;
  const GroupSharedProblem({this.id = '', this.shareId = ''});
}

class GroupSharedExam {
  final String id;
  final String shareId;
  final String examId;
  final String title;
  final String senderName;
  final String createdAt;
  const GroupSharedExam({
    this.id = '',
    this.shareId = '',
    this.examId = '',
    this.title = '',
    this.senderName = '',
    this.createdAt = '',
  });
}

class StudyGroupMessage {
  final String messageId;
  final String userId;
  final String senderName;
  final String text;
  final String messageType;
  final Map<String, dynamic>? payload;
  final String createdAt;
  const StudyGroupMessage({
    this.messageId = '',
    this.userId = '',
    this.senderName = '',
    this.text = '',
    this.messageType = 'text',
    this.payload,
    this.createdAt = '',
  });
}

class StudyGroupNotice {
  final String noticeId;
  final String groupId;
  final String? groupName;
  final String scope;
  final String title;
  final String contentHtml;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;

  const StudyGroupNotice({
    this.noticeId = '',
    this.groupId = '',
    this.groupName,
    this.scope = 'group',
    this.title = '',
    this.contentHtml = '',
    this.createdByUserId = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory StudyGroupNotice.fromJson(Map<String, dynamic> json) {
    return StudyGroupNotice(
      noticeId: json['notice_id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      groupName: json['group_name']?.toString(),
      scope: json['scope']?.toString() ?? 'group',
      title: json['title']?.toString() ?? '',
      contentHtml: json['content_html']?.toString() ?? '',
      createdByUserId: json['created_by_user_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class ServerChatMessage {
  final String assistantMessage;
  final String character;
  final String characterName;
  final String model;
  const ServerChatMessage({
    this.assistantMessage = '',
    this.character = '',
    this.characterName = '',
    this.model = '',
  });

  factory ServerChatMessage.fromJson(Map<String, dynamic> json) {
    return ServerChatMessage(
      assistantMessage: json['assistant_message']?.toString() ?? '',
      character: json['character']?.toString() ?? '',
      characterName: json['character_name']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
    );
  }
}

class QuestSearchResult {
  final List<Map<String, dynamic>> quests;
  final int total;
  final int page;
  final int pageSize;
  const QuestSearchResult({
    required this.quests,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory QuestSearchResult.fromJson(Map<String, dynamic> json) {
    final quests = ((json['quests'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return QuestSearchResult(
      quests: quests,
      total: (json['total'] as num?)?.toInt() ?? quests.length,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? quests.length,
    );
  }
}

extension ExamItemCompat on ExamItem {
  int get itemIndex => this.itemIndex ?? itemCount ?? 0;
  String get status => this.status ?? 'pending';
  String get subjectKey => this.subjectKey ?? '';
  List<String> get hashTags => this.hashTags ?? const [];
  int get difficultyTier => this.difficultyTier ?? 0;
  int get solvesCount => this.solvesCount ?? 0;
  int get strategyLevel => this.strategyLevel ?? 0;
  int get branchConditions => this.branchConditions ?? 0;
  String? get questionType => this.questionType;
  String? get questId => this.questId ?? examId;
  int? get flowCount => this.flowCount ?? itemCount;
  int? get codebaseId => this.codebaseId;
  int? get seed => this.seed;
  dynamic get questTitle => this.questTitle ?? title;
  List<dynamic>? get questOptions => this.questOptions;
  String? get error => this.error;
}

extension SharedFlowItemCompat on SharedFlowItem {
  String get shareId => id;
  String get userId => senderId;
  String get questId => refId;
  String get questTitle => title ?? '';
}

class ContinueState {
  final String targetId;
  final List<dynamic> strokes;
  final String? updatedAt;
  final bool allowBack;
  const ContinueState({
    required this.targetId,
    required this.strokes,
    this.updatedAt,
    this.allowBack = false,
  });
}

extension StudyGroupCompat on StudyGroup {
  String get groupId => id;
  int get maxMembers => memberCount;
  List<String> get memberIds => const [];
  bool get isPublic => true;
  int? get logoIndex => null;
  bool get lockEnabled => false;
  int get members => memberCount;
}

extension ApiClientLegacyCompat on ApiClient {
  // APIClient의 내부 _get 캐시 정책을 URI 단위 GET 호출에도 재사용한다.
  // 입력은 Uri 한 건만 받아, 경로/쿼리를 _cacheKey에 맞게 추출해 캐시 키를 생성한다.
  // 반환은 기존 APIResponse 형태로 통일해 파싱과 캐시 재사용 규칙을 동일하게 적용한다.
  Future<ApiResponse<T>> authedGetJson<T>(
    Uri uri, {
    T Function(dynamic)? parser,
    bool useCache = false,
    bool forceRefresh = false,
    Duration? cacheTtl,
  }) async {
    final previousToken = _token;
    await _ensureToken();
    final effectiveToken = _token;
    if (effectiveToken == null) {
      return ApiResponse<T>(
        success: false,
        data: null,
        message: 'No auth token',
      );
    }

    final oldToken = previousToken;
    if (effectiveToken != oldToken) {
      _token = effectiveToken;
    }

    final query = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      query[key] = value;
    });
    try {
      return await _get<T>(
        uri.path,
        query: query.isEmpty ? null : query,
        parser: parser,
        useCache: useCache,
        forceRefresh: forceRefresh,
        cacheTtl: cacheTtl,
      );
    } finally {
      _token = oldToken;
    }
  }

  // 기존 authedGet 동작은 캐시를 쓰지 않는 Response 반환을 유지한다.
  // 즉시 사용처 호환성을 위해 반환 타입은 유지하되, 내부적으로 최소한 토큰 보장만 수행한다.
  Future<String> requireToken() => _ensureToken();

  Future<http.Response> authedGet(Uri uri, {String? token}) async {
    final previousToken = _token;
    if (token != null && token != previousToken) {
      _token = token;
    } else if (_token == null) {
      await _ensureToken();
    }
    final jwt = token ?? _token!;

    try {
      return http.get(uri, headers: {'Authorization': 'Bearer $jwt'});
    } finally {
      _token = previousToken;
    }
  }

  Future<http.Response> authedPost(
    Uri uri, {
    String? token,
    Object? body,
  }) async {
    final jwt = token ?? await _ensureToken();
    return http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: body is String ? body : (body == null ? null : jsonEncode(body)),
    );
  }

  Future<String?> getUserStorage(String key) async {
    final resp = await _get(
      '/user/storage/$key',
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return (resp.data as Map?)?['value']?.toString();
  }

  Future<void> setUserStorage(String key, String value) async {
    await _put('/user/storage/$key', {'value': value});
  }

  Future<void> deleteUserStorage(String key) async {
    await _delete('/user/storage/$key');
  }

  Future<String> createExam({
    String problemSource = 'default',
    required List<ExamRangeRequest> ranges,
    int? numItems,
    int? difficultyTier,
    int? questionCount,
    String? paperType,
  }) async {
    final res = await _post<Map<String, dynamic>>('/exams', {
      'problem_source': problemSource,
      'ranges': ranges.map((e) => e.toJson()).toList(),
      if (numItems != null) 'num_items': numItems,
      if (questionCount != null) 'question_count': questionCount,
      if (difficultyTier != null) 'difficulty_tier': difficultyTier,
      if (paperType != null) 'paper_type': paperType,
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
    return (res.data?['exam_id'] ?? '').toString();
  }

  Future<ExamStatus> getExamStatus(String examId, {String? courseId}) async {
    final res = await _get<Map<String, dynamic>>(
      '/exams/$examId',
      query: {
        if (courseId != null && courseId.trim().isNotEmpty)
          'course_id': courseId.trim(),
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(seconds: 20),
    );
    return ExamStatus.fromJson(res.data ?? const {});
  }

  String examPdfUrl(String examId, {bool inline = false, String? courseId}) =>
      ApiContract.url(
        ApiPaths.examPdf(examId),
        query: {
          if (inline) 'inline': '1',
          if (courseId != null && courseId.trim().isNotEmpty)
            'course_id': courseId.trim(),
        },
      );

  Future<Map<String, dynamic>> fetchUnitProblems({
    String? moduleId,
    String? courseId,
    int? unitIndex,
    String? textQuery,
  }) async {
    final tags = <String>[];
    int minTier = 2;
    int maxTier = 3;
    int questionCount = 10;

    if (courseId != null && unitIndex != null) {
      try {
        final courseRes = await _get<Map<String, dynamic>>(
          '/courses/$courseId',
          parser: (d) => Map<String, dynamic>.from(d as Map),
          useCache: true,
          cacheTtl: const Duration(minutes: 10),
        );
        final course = courseRes.data ?? const <String, dynamic>{};
        final units = (course['units'] as List<dynamic>? ?? const []);
        if (unitIndex >= 0 && unitIndex < units.length) {
          final unit = Map<String, dynamic>.from(units[unitIndex] as Map);
          dynamic detail = unit['detail'];
          if (detail is String && detail.trim().isNotEmpty) {
            try {
              detail = jsonDecode(detail);
            } catch (_) {}
          }
          if (detail is Map) {
            final hashTagRaw = detail['hash_tags'];
            if (hashTagRaw is List) {
              tags.addAll(hashTagRaw.map((e) => e.toString()));
            }
            final diff = (detail['difficulty_tier'] as num?)?.toInt();
            if (diff != null) {
              minTier = diff.clamp(1, 5);
              maxTier = diff.clamp(1, 5);
            }
            final qCount = (detail['question_count'] as num?)?.toInt();
            if (qCount != null && qCount > 0) {
              questionCount = qCount.clamp(1, 30);
            }
          }
        }
      } catch (_) {}
    }

    if (tags.isEmpty && textQuery != null && textQuery.trim().isNotEmpty) {
      tags.add(textQuery.trim());
    }
    if (tags.isEmpty) {
      return <String, dynamic>{'quests': const <Map<String, dynamic>>[]};
    }

    final quests = <Map<String, dynamic>>[];
    await for (final quest in generateProblemSetStream(
      hashTags: tags,
      minDifficultyTier: minTier,
      maxDifficultyTier: maxTier,
      questionCount: questionCount,
    )) {
      quests.add(quest);
    }
    return <String, dynamic>{'quests': quests, 'pass_rate': 100};
  }

  Stream<Map<String, dynamic>> generateProblemSetStream({
    String? moduleId,
    List<String>? hashTags,
    int? questionCount,
    int? minDifficultyTier,
    int? maxDifficultyTier,
  }) async* {
    if (moduleId != null) {
      final loaded = await fetchUnitProblems(moduleId: moduleId);
      final quests = (loaded['quests'] as List?) ?? const [];
      for (final q in quests) {
        yield Map<String, dynamic>.from(q as Map);
      }
      return;
    }
    final tags = (hashTags ?? const [])
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (tags.isEmpty) return;

    final safeQuestionCount = (questionCount ?? 3).clamp(1, 30).toInt();
    // 필요 변수: 사용자가 고른 최대 난이도와 태그 목록.
    // 작동 원리: 태그 수 검증은 서버의 티어별 규칙에 맡기고 요청한 1~5 티어를 그대로 보존한다.
    final safeMaxTier = (maxDifficultyTier ?? 3).clamp(1, 5).toInt();
    final safeMinTier = (minDifficultyTier ?? 2).clamp(1, safeMaxTier).toInt();

    await _ensureToken();
    final request = http.Request(
      'POST',
      ApiContract.uri('/quests/generate/stream'),
    );
    request.headers.addAll({..._headers, 'Accept': 'text/event-stream'});
    request.body = jsonEncode({
      'hash_tags': tags,
      'question_count': safeQuestionCount,
      'min_difficulty_tier': safeMinTier,
      'max_difficulty_tier': safeMaxTier,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw ApiException(
          statusCode: response.statusCode,
          message: body.isEmpty ? 'Failed to generate problem set' : body,
        );
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty) continue;
        if (data == '[DONE]') break;

        final decoded = jsonDecode(data);
        if (decoded is Map && decoded['error'] != null) {
          throw ApiException(
            statusCode: 500,
            message: decoded['error'].toString(),
          );
        }
        if (decoded is Map) {
          yield Map<String, dynamic>.from(decoded);
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<WeaknessTag>> fetchWeaknessTags() async {
    final res = await _get(
      '/weakness/tags',
      parser: (d) {
        final items = (d['tags'] as List<dynamic>? ?? const []);
        return items
            .map(
              (e) => WeaknessTag.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
      useCache: true,
      cacheTtl: const Duration(hours: 1),
    );
    return res.data ?? const [];
  }

  Future<List<ProblemHabit>> fetchProblemHabits({int? days, int? limit}) async {
    final res = await _get(
      '/habit/problem',
      query: {
        if (days != null) 'days': '$days',
        if (limit != null) 'limit': '$limit',
      },
      parser: (d) {
        final items = (d['items'] as List<dynamic>? ?? const []);
        return items.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return ProblemHabit(
            codebaseId: (m['codebase_id'] as num?)?.toInt(),
            seed: int.tryParse((m['seed'] ?? '').toString()),
            questTitle: (m['quest_title'] ?? '').toString(),
          );
        }).toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return res.data ?? const [];
  }

  Future<Map<String, dynamic>> replayProblemHabit({
    String? questId,
    int? codebaseId,
    Object? seed,
  }) async {
    if (codebaseId == null || seed == null) {
      return <String, dynamic>{};
    }
    final res = await _post<Map<String, dynamic>>('/habit/problem/replay', {
      'codebase_id': codebaseId,
      'seed': seed.toString(),
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
    return res.data ?? <String, dynamic>{};
  }

  Future<List<OxQuizQuestion>> generateOxQuiz({
    required List<String> tags,
    int perTag = 3,
  }) async {
    final cleaned = tags.where((e) => e.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return const [];
    final res = await _post(
      '/ox_quiz/generate',
      {'tags': cleaned, 'per_tag': perTag},
      parser: (d) {
        final items = (d['questions'] as List<dynamic>? ?? const []);
        return items
            .map(
              (e) =>
                  OxQuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      },
    );
    return res.data ?? const [];
  }

  Future<SolveAnalysisResponse> submitSolveAnalysis({
    String? examId,
    List<Map<String, dynamic>>? solves,
    Map<String, dynamic>? payload,
    List<int>? studentWorkImage,
    List<int>? heatmapImage,
    List<int>? problemImage,
  }) async {
    final body = <String, dynamic>{};
    if (payload != null) body.addAll(payload);
    if (examId != null && examId.isNotEmpty) body['exam_id'] = examId;
    if (solves != null) body['solves'] = solves;
    if (studentWorkImage != null) {
      body['student_work_image'] = base64Encode(studentWorkImage);
    }
    if (heatmapImage != null) {
      body['heatmap_image'] = base64Encode(heatmapImage);
    }
    if (problemImage != null) {
      body['problem_image'] = base64Encode(problemImage);
    }
    if (ApiContract.ocrQueueBaseUrl.trim().isNotEmpty) {
      return _submitSolveAnalysisQueued(body);
    }
    final res = await _post<Map<String, dynamic>>(
      '/analysis/solve',
      body,
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return SolveAnalysisResponse.fromJson(res.data ?? const {});
  }

  /// 필요한 변수는 기존 `/analysis/solve` JSON과 Vercel 큐 URL이다.
  /// 작동 원리는 작업을 한 번 등록한 뒤 완료·실패까지 제한 시간 동안 폴링해 기존 응답 형식을 그대로 돌려주는 것이다.
  Future<SolveAnalysisResponse> _submitSolveAnalysisQueued(
    Map<String, dynamic> body,
  ) async {
    final token = await _ensureToken();
    final base = ApiContract.ocrQueueBaseUrl.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final createUri = Uri.parse('$base/jobs');
    final idempotencyKey = sha256
        .convert(
          utf8.encode(
            '$token:${DateTime.now().microsecondsSinceEpoch}:${jsonEncode(body)}',
          ),
        )
        .toString();
    final created = await _httpClient.post(
      createUri,
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Idempotency-Key': idempotencyKey,
      },
      body: jsonEncode(<String, dynamic>{'mode': 'solve', 'payload': body}),
    );
    await _clearTokenOnUnauthorized(created);
    final createdBody = _decodeQueueResponse(created);
    final jobId = (createdBody['job_id'] ?? '').toString();
    if (jobId.isEmpty) {
      throw ApiException(
        statusCode: created.statusCode,
        message: 'OCR 작업 ID가 없습니다.',
      );
    }

    const pollInterval = Duration(seconds: 1);
    const maxPolls = 240;
    for (var attempt = 0; attempt < maxPolls; attempt++) {
      if (attempt > 0) await Future<void>.delayed(pollInterval);
      final response = await _httpClient.get(
        Uri.parse('$base/jobs/$jobId'),
        headers: <String, String>{'Authorization': 'Bearer $token'},
      );
      await _clearTokenOnUnauthorized(response);
      final job = _decodeQueueResponse(response);
      final jobStatus = (job['status'] ?? '').toString();
      if (jobStatus == 'completed') {
        final result = job['result'];
        if (result is Map) {
          return SolveAnalysisResponse.fromJson(
            Map<String, dynamic>.from(result),
          );
        }
        throw ApiException(statusCode: 502, message: 'OCR 결과 형식이 잘못되었습니다.');
      }
      if (jobStatus == 'failed') {
        throw ApiException(
          statusCode: 502,
          message: (job['error'] ?? 'OCR worker 처리 실패').toString(),
        );
      }
    }
    throw ApiException(statusCode: 504, message: 'OCR 처리 대기 시간이 초과되었습니다.');
  }

  /// 필요한 변수는 Vercel 큐 HTTP 응답이다.
  /// 작동 원리는 UTF-8 JSON과 상태 코드를 함께 검증해 HTML 오류 페이지나 비정상 응답을 차단한다.
  Map<String, dynamic> _decodeQueueResponse(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    dynamic decoded;
    try {
      decoded = text.trim().isEmpty ? <String, dynamic>{} : jsonDecode(text);
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'OCR 큐가 JSON이 아닌 응답을 반환했습니다.',
      );
    }
    final body = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: (body['detail'] ?? body['message'] ?? 'OCR 큐 요청 실패')
            .toString(),
      );
    }
    return body;
  }

  Future<UserRating> submitRating({
    String? targetId,
    String? targetType,
    int? rating,
    String? questId,
    bool? isCorrect,
    List<String>? tags,
    List<Map<String, dynamic>>? stepCorrectness,
    num? answerTime,
    String? submissionId,
  }) async {
    final id = questId?.trim();
    if (id == null || id.isEmpty || isCorrect == null) {
      return const UserRating(
        rating: 0,
        ovr: 0,
        ovrDelta: 0,
        recentAccuracy: 0,
        loseStreak: 0,
      );
    }
    final res = await _post<Map<String, dynamic>>('/rating/submit', {
      'quest_id': id,
      'is_correct': isCorrect,
      'tags': tags ?? const <String>[],
      if (answerTime != null) 'answer_time': answerTime,
      'step_correctness': stepCorrectness ?? const <Map<String, dynamic>>[],
      if (submissionId != null && submissionId.trim().isNotEmpty)
        'submission_id': submissionId.trim(),
    }, parser: (d) => Map<String, dynamic>.from(d as Map));
    return UserRating.fromJson(res.data ?? const {});
  }

  Future<LevelTestPlacementSession> startLevelTestPlacement() async {
    final res = await _post<Map<String, dynamic>>(
      '/level-tests/placement/start',
      const <String, dynamic>{},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return LevelTestPlacementSession.fromJson(res.data ?? const {});
  }

  Future<void> submitLevelTestPlacementAnswer({
    required String sessionId,
    required int itemIndex,
    required String questId,
    required bool isCorrect,
    num? answerTime,
    List<Map<String, dynamic>> stepCorrectness = const [],
    List<String> tags = const [],
  }) async {
    await _post<Map<String, dynamic>>(
      '/level-tests/placement/$sessionId/answer',
      {
        'item_index': itemIndex,
        'quest_id': questId,
        'is_correct': isCorrect,
        if (answerTime != null) 'answer_time': answerTime,
        'step_correctness': stepCorrectness,
        'tags': tags,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
  }

  Future<LevelTestPlacementResult> submitLevelTestPlacement(
    String sessionId,
  ) async {
    final res = await _post<Map<String, dynamic>>(
      '/level-tests/placement/$sessionId/submit',
      const <String, dynamic>{},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return LevelTestPlacementResult.fromJson(res.data ?? const {});
  }

  Future<UserRating> fetchUserRating() async {
    final res = await _get<Map<String, dynamic>>(
      '/rating/user',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return UserRating.fromJson(res.data ?? const {});
  }

  Future<UserRating> fetchUserRatingByUserId(String targetUserId) async {
    final id = targetUserId.trim();
    if (id.isEmpty) {
      return const UserRating(
        rating: 0,
        ovr: 0,
        ovrDelta: 0,
        recentAccuracy: 0,
        loseStreak: 0,
      );
    }
    final res = await _get<Map<String, dynamic>>(
      '/rating/user/$id',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return UserRating.fromJson(res.data ?? const {});
  }

  Future<AccountSummary> fetchAccountSummary() async {
    final res = await _get<Map<String, dynamic>>(
      '/account/summary',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
    return AccountSummary.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<AccountSummary> recordActivityScore({
    required int deltaScore,
    required String refId,
    String reason = 'activity_log',
    String? dateKey,
  }) async {
    final body = <String, dynamic>{
      'delta_score': deltaScore,
      'ref_id': refId,
      'reason': reason,
      if (dateKey != null && dateKey.trim().isNotEmpty)
        'date_key': dateKey.trim(),
    };
    final res = await _post<Map<String, dynamic>>(
      '/account/activity-score',
      body,
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return AccountSummary.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> createTextbook(
    Map<String, dynamic> payload,
  ) async {
    return <String, dynamic>{};
  }

  Future<List<DailyQuestItem>> fetchDailyQuests({
    required String courseId,
  }) async {
    final bundle = await fetchDailyQuestBundle(courseId: courseId);
    return bundle.items;
  }

  Future<DailyQuestBundle> fetchDailyQuestBundle({
    required String courseId,
    bool forceRefresh = false,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/challenges/daily-quests',
      query: {'course_id': courseId},
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: !forceRefresh,
      cacheTtl: const Duration(seconds: 20),
    );
    return DailyQuestBundle.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<List<DailyQuestItem>> submitDailyQuestEvent({
    required String courseId,
    required String eventType,
    int value = 1,
  }) async {
    final bundle = await submitDailyQuestEventBundle(
      courseId: courseId,
      eventType: eventType,
      value: value,
    );
    return bundle.items;
  }

  Future<DailyQuestBundle> submitDailyQuestEventBundle({
    required String courseId,
    required String eventType,
    int value = 1,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/challenges/daily-quests/event',
      {'course_id': courseId, 'event_type': eventType, 'value': value},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return DailyQuestBundle.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<List<DailyQuestItem>> completeDailyQuest({
    required String courseId,
    required String questId,
    required int revision,
  }) async {
    final bundle = await completeDailyQuestBundle(
      courseId: courseId,
      questId: questId,
      revision: revision,
    );
    return bundle.items;
  }

  Future<DailyQuestBundle> completeDailyQuestBundle({
    required String courseId,
    required String questId,
    required int revision,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/challenges/daily-quests/complete',
      {'course_id': courseId, 'quest_id': questId, 'revision': revision},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return DailyQuestBundle.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<List<Map<String, dynamic>>> listTextbooks({
    String? category,
    String? tag,
    String? type,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/textbooks',
      query: {
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        if (tag != null && tag.trim().isNotEmpty) 'tag': tag.trim(),
        if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
    final data = res.data ?? const <String, dynamic>{};
    return (data['textbooks'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> getTextbook(String textbookId) async {
    final res = await _get<Map<String, dynamic>>(
      '/textbooks/$textbookId',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 30),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listCourseDocuments(
    String courseId, {
    String? type,
  }) async {
    final path = '/courses/v2/$courseId/documents';
    final res = await _get<Map<String, dynamic>>(
      path,
      query: {if (type != null && type.trim().isNotEmpty) 'type': type.trim()},
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 15),
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      return (data['items'] as List<dynamic>? ??
              data['textbooks'] as List<dynamic>? ??
              const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const [];
  }

  Future<Map<String, dynamic>> getCourseTextbook(
    String courseId,
    String textbookId,
  ) async {
    final res = await _get<Map<String, dynamic>>(
      '/courses/v2/$courseId/textbooks/$textbookId',
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(minutes: 15),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> startCourseTextbookRuntime({
    required String courseId,
    required String moduleId,
    required String textbookId,
    int? pageFrom,
    int? pageTo,
    int? minMinutes,
    bool? enforceMinMinutes,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/courses/v2/runtime/textbook-view/start',
      {
        'course_id': courseId,
        'module_id': moduleId,
        'textbook_id': textbookId,
        if (pageFrom != null) 'page_from': pageFrom,
        if (pageTo != null) 'page_to': pageTo,
        if (minMinutes != null) 'min_minutes': minMinutes,
        if (enforceMinMinutes != null) 'enforce_min_minutes': enforceMinMinutes,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> heartbeatCourseTextbookRuntime({
    required String courseId,
    required String moduleId,
    required String textbookId,
    required int currentPage,
    int? pageFrom,
    int? pageTo,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/courses/v2/runtime/textbook-view/heartbeat',
      {
        'course_id': courseId,
        'module_id': moduleId,
        'textbook_id': textbookId,
        'page': currentPage,
        if (pageFrom != null) 'page_from': pageFrom,
        if (pageTo != null) 'page_to': pageTo,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return res.data ?? <String, dynamic>{};
  }

  /// 필요한 변수는 코스·모듈·교재·현재 페이지와 선택 범위다.
  /// 최소 체류 검증 완료 응답을 받은 뒤 관련 코스 캐시를 즉시 무효화한다.
  Future<Map<String, dynamic>> completeCourseTextbookRuntime({
    required String courseId,
    required String moduleId,
    required String textbookId,
    required int currentPage,
    int? pageFrom,
    int? pageTo,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/courses/v2/runtime/textbook-view/complete',
      {
        'course_id': courseId,
        'module_id': moduleId,
        'textbook_id': textbookId,
        'page': currentPage,
        if (pageFrom != null) 'page_from': pageFrom,
        if (pageTo != null) 'page_to': pageTo,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    await invalidateCachePath('/courses');
    return res.data ?? <String, dynamic>{};
  }

  Future<List<StudyGroup>> listMyStudyGroups() async {
    return listStudyGroups();
  }

  /// 필요한 변수는 그룹 ID와 풀이를 재현할 문제·분석 데이터다.
  /// 작동 원리는 서버 공유 API에 원문을 POST하고 성공 직후 그룹 Flow GET 캐시를 비우는 것이다.
  Future<SharedFlowItem> shareFlowToGroup({
    required String groupId,
    required String questId,
    required int codebaseId,
    required int seed,
    required String statusJson,
    String? questTitle,
    String allFormulas = '',
    String answerRiddle = '',
    List<String> tags = const [],
    int? difficulty,
  }) async {
    final response = await _post(
      '/social/study-groups/$groupId/shared-flows',
      {
        'codebase_id': codebaseId,
        'seed': seed,
        if (questId.trim().isNotEmpty) 'quest_id': questId.trim(),
        if (questTitle != null && questTitle.trim().isNotEmpty)
          'quest_title': questTitle.trim(),
        'status_json': statusJson,
        'all_formulas': allFormulas,
        'answer_riddle': answerRiddle,
        'tags': tags,
        if (difficulty != null) 'difficulty': difficulty,
      },
      parser: (data) =>
          SharedFlowItem.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    await invalidateCachePath('/social/study-groups/$groupId/shared-flows');
    return response.data ??
        SharedFlowItem(
          id: '',
          groupId: groupId,
          senderId: '',
          kind: 'flow',
          refId: questId,
          title: questTitle,
        );
  }

  /// 필요한 변수는 공유 ID다.
  /// 작동 원리는 소유권 검증이 포함된 서버 DELETE를 실행하고 모든 그룹 Flow 캐시를 제거하는 것이다.
  Future<void> deleteSharedFlow(String shareId) async {
    await _delete('/social/study-groups/shared-flows/${shareId.trim()}');
    await invalidateCachePath('/social/study-groups');
  }

  /// 필요한 변수는 공유 ID다.
  /// 작동 원리는 서버에서 필기·수식이 포함된 공유 Flow 원문을 조회해 화면 모델로 변환하는 것이다.
  Future<SharedFlowItem> getSharedFlow(String shareId) async {
    final response = await _get(
      '/social/study-groups/shared-flows/${shareId.trim()}',
      parser: (data) =>
          SharedFlowItem.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    return response.data ??
        SharedFlowItem(
          id: shareId,
          groupId: '',
          senderId: '',
          kind: 'flow',
          refId: '',
        );
  }

  Future<QuestSearchResult> fetchQuestPage({
    int page = 1,
    int pageSize = 20,
    String? hashTag,
    String? questId,
    String? textQuery,
  }) async {
    final quests = await searchQuests(
      page: page,
      pageSize: pageSize,
      hashTag: hashTag,
      questId: questId,
      textQuery: textQuery,
    );
    return QuestSearchResult(
      quests: quests,
      total: quests.length,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> generateCubicProblem({int? seed}) async =>
      <String, dynamic>{};

  Future<ContinueState?> loadContinueStrokes({
    String? kind,
    String? targetId,
  }) async => null;

  Future<void> saveContinueStrokes({
    String? kind,
    required String targetId,
    required List<dynamic> strokes,
    bool? forcedExit,
    bool? completed,
    bool allowBack = false,
  }) async {}

  Future<List<SolveHistoryItem>> fetchSolveHistory({
    int? days,
    String? tag,
    String? kind,
    int? limit,
    String? userId,
    String? from,
    String? to,
    String? before,
  }) async {
    final res = await _get(
      '/history/solve',
      query: {
        if (days != null) 'days': '$days',
        if (limit != null) 'limit': '$limit',
        if (kind != null && kind.isNotEmpty) 'kind': kind,
      },
      parser: (d) {
        final items = (d['items'] as List<dynamic>? ?? const []);
        return items.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final data = m['data'] is Map
              ? Map<String, dynamic>.from(m['data'] as Map)
              : null;
          final tagsRaw = data?['tags'];
          final tags = tagsRaw is List
              ? tagsRaw.map((x) => x.toString()).toList()
              : const <String>[];
          final questTitleRaw = data?['quest_title']?.toString();
          return SolveHistoryItem(
            createdAt: (m['created_at'] ?? '').toString(),
            kind: m['kind']?.toString(),
            questId: m['quest_id']?.toString(),
            codebaseId: (m['codebase_id'] as num?)?.toInt(),
            seed: (m['seed'] as num?)?.toInt(),
            hashTags: tags,
            data: data,
            questTitleRaw: questTitleRaw,
          );
        }).toList();
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 45),
    );
    return res.data ?? const [];
  }

  Future<List<TagRating>> fetchTagRatings() async {
    final res = await _get(
      '/rating/tags',
      parser: (d) {
        final items = (d['tags'] as List<dynamic>?) ?? const [];
        return items.map((e) {
          final m = e as Map<String, dynamic>;
          return TagRating(
            tag: (m['tag'] ?? '').toString(),
            rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
            delta: (m['delta'] as num?)?.toDouble() ?? 0.0,
            attempts: (m['attempts'] as int?) ?? 0,
          );
        }).toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
    return res.data ?? const [];
  }

  Future<List<FriendRank>> fetchFriendRankings() async {
    final res = await _get(
      '/social/friends/rankings',
      parser: (d) {
        final items = (d['ranks'] as List<dynamic>?) ?? const [];
        return _parseListItemsSafely<FriendRank>(items, (m) {
          return FriendRank(
            rank: (m['rank'] as int?) ?? 0,
            username: (m['username'] ?? '').toString(),
            visibleOvr: (m['visible_ovr'] as num?)?.toDouble() ?? 0.0,
            isMe: m['is_me'] == true,
          );
        }, source: 'friend_rankings');
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 1),
    );
    return res.data ?? const [];
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _post('/social/friend-requests/$requestId/decline', {});
    await invalidateCachePath('/social/friend-requests');
  }

  Future<void> cancelFriendRequest(String requestId) async {
    await _post('/social/friend-requests/$requestId/cancel', {});
    await invalidateCachePath('/social/friend-requests');
  }

  Future<List<DirectMessage>> fetchConversationThreads({
    int limit = 20,
    String? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null && before.isNotEmpty) query['before'] = before;
    final res = await _get(
      '/social/conversations',
      query: query,
      parser: (d) {
        final items = (d['messages'] as List<dynamic>?) ?? const [];
        return _parseListItemsSafely<DirectMessage>(
          items,
          DirectMessage.fromJson,
          source: 'conversation_threads',
        );
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 10),
    );
    return res.data ?? const [];
  }

  Future<List<DirectMessage>> fetchDirectMessages({
    String? peer,
    String? peerUsername,
    int limit = 50,
    String? before,
    String? beforeMessageId,
  }) async {
    final target = peer ?? peerUsername;
    if (target == null || target.isEmpty) return const [];
    final query = <String, String>{'peer': target, 'limit': '$limit'};
    if (before != null && before.isNotEmpty) query['before'] = before;
    final res = await _get(
      '/social/messages',
      query: query,
      parser: (d) {
        final items = (d['messages'] as List<dynamic>?) ?? const [];
        return _parseListItemsSafely<DirectMessage>(
          items,
          DirectMessage.fromJson,
          source: 'direct_messages',
        );
      },
      useCache: true,
      cacheTtl: const Duration(seconds: 10),
    );
    return res.data ?? const [];
  }

  Future<DirectMessage> sendDirectMessage({
    String? to,
    String? peerUsername,
    required String text,
  }) async {
    final target = (to ?? peerUsername ?? '').trim();
    final res = await _post(
      '/social/messages',
      {'peer': target, 'text': text.trim()},
      parser: (d) =>
          DirectMessage.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    await invalidateCachePath('/social/conversations');
    await invalidateCachePath('/social/messages');
    return res.data ??
        DirectMessage(
          id: '',
          from: '',
          to: target,
          text: text.trim(),
          createdAt: DateTime.now(),
          isMine: true,
        );
  }

  /// 필요한 변수는 삭제할 대화 상대의 사용자명이다.
  /// 작동 원리는 서버 대화 삭제 API를 호출한 뒤 쪽지 캐시를 함께 비우는 것이다.
  Future<void> deleteConversation([String? peerUsername, String? peer]) async {
    final target = (peerUsername ?? peer ?? '').trim();
    if (target.isEmpty) return;
    await _post('/social/messages/${Uri.encodeComponent(target)}/delete', {});
    await invalidateCachePath('/social/conversations');
    await invalidateCachePath('/social/messages');
  }

  /// 필요한 변수는 삭제할 친구의 사용자명이다.
  /// 작동 원리는 서버 친구 삭제 API를 호출하고 친구·랭킹 캐시를 무효화하는 것이다.
  Future<void> removeFriend(String username) async {
    final target = username.trim();
    if (target.isEmpty) return;
    await _post('/social/friends/remove', {'username': target});
    await invalidateCachePath('/social/friends');
    await invalidateCachePath('/social/friends/rankings');
  }

  Future<List<FriendProfile>> searchFriends({String? query, int? limit}) async {
    final q = (query ?? '').trim();
    if (q.isEmpty) return const [];
    final res = await _post<List<FriendProfile>>(
      '/social/friends/search',
      {'query': q, 'limit': limit ?? 20},
      parser: (d) {
        final users = (d['users'] as List<dynamic>?) ?? const [];
        return _parseListItemsSafely<FriendProfile>(
          users,
          FriendProfile.fromJson,
          source: 'friend_search',
        );
      },
    );
    return res.data ?? const [];
  }

  Future<List<StudyGroup>> searchStudyGroups({
    String? query,
    int? limit,
  }) async {
    final q = (query ?? '').trim();
    if (q.isEmpty) return const [];
    final res = await _get(
      '/social/study-groups/search',
      query: {'q': q, 'limit': '${limit ?? 20}'},
      parser: parseStudyGroupListPayload,
      useCache: true,
      cacheTtl: const Duration(seconds: 30),
    );
    return res.data ?? const [];
  }

  Future<void> joinStudyGroupById({
    required String groupId,
    String? password,
  }) async {
    await joinStudyGroup(groupId: groupId, password: password);
  }

  Future<List<StudyGroupNotice>> listMySystemGroupNotices({
    int limit = 20,
  }) async {
    final res = await _get(
      '/social/study-groups/notices/my/system',
      query: {'limit': '$limit'},
      parser: (d) {
        final items = (d['notices'] as List<dynamic>? ?? const []);
        return items
            .whereType<Map>()
            .map((e) => StudyGroupNotice.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
    return res.data ?? const [];
  }

  Future<List<StudyGroupNotice>> listGlobalSystemNotices({
    int limit = 20,
  }) async {
    final res = await _get(
      '/account/system-notices',
      query: {'limit': '$limit'},
      parser: (d) {
        final items = (d['items'] as List<dynamic>? ?? const []);
        return items
            .whereType<Map>()
            .map((e) => StudyGroupNotice.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 10),
    );
    return res.data ?? const [];
  }

  Future<List<StudyGroupNotice>> listGroupNotices(
    String groupId, {
    int limit = 20,
  }) async {
    final res = await _get(
      '/social/study-groups/$groupId/notices',
      query: {'limit': '$limit'},
      parser: (d) {
        final items = (d['notices'] as List<dynamic>? ?? const []);
        return items
            .whereType<Map>()
            .map((e) => StudyGroupNotice.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
      useCache: true,
      cacheTtl: const Duration(minutes: 2),
    );
    return res.data ?? const [];
  }

  Future<StudyGroupNotice> upsertGroupNotice({
    required String groupId,
    required String title,
    required String contentHtml,
  }) async {
    final res = await _put(
      '/social/study-groups/$groupId/notices',
      {'title': title.trim(), 'content_html': contentHtml},
      parser: (d) => StudyGroupNotice.fromJson(Map<String, dynamic>.from(d)),
    );
    return res.data ?? const StudyGroupNotice();
  }

  Future<void> deleteGroupNoticeByTitle({
    required String groupId,
    required String title,
  }) async {
    await _delete(
      '/social/study-groups/$groupId/notices?title=${Uri.encodeQueryComponent(title.trim())}',
    );
  }

  Future<List<GroupSharedProblem>> listGroupSharedProblems(
    String groupId, {
    int limit = 30,
  }) async {
    final res = await _get(
      '/social/study-groups/$groupId/shared-problems',
      query: {'limit': '$limit'},
      parser: (d) => ((d['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((e) {
            final item = Map<String, dynamic>.from(e);
            return GroupSharedProblem(
              id: item['codebase_id']?.toString() ?? '',
              shareId: item['share_id']?.toString() ?? '',
            );
          })
          .toList(),
      // 하루 보존 리소스는 만료 후 로컬 캐시에서 다시 노출되지 않도록 항상 서버에서 확인한다.
      useCache: false,
    );
    return res.data ?? const [];
  }

  Future<List<GroupSharedExam>> listGroupSharedExams(
    String groupId, {
    int limit = 30,
  }) async {
    final res = await _get(
      '/social/study-groups/$groupId/shared-exams',
      query: {'limit': '$limit'},
      parser: (d) => ((d['items'] as List<dynamic>?) ?? const [])
          .whereType<Map>()
          .map((e) {
            final item = Map<String, dynamic>.from(e);
            return GroupSharedExam(
              id: item['exam_id']?.toString() ?? '',
              shareId: item['share_id']?.toString() ?? '',
              examId: item['exam_id']?.toString() ?? '',
              title: item['title']?.toString() ?? '시험지',
              senderName: item['sender_name']?.toString() ?? '시스템',
              createdAt: item['created_at']?.toString() ?? '',
            );
          })
          .toList(),
      // 하루 보존 리소스는 만료 후 로컬 캐시에서 다시 노출되지 않도록 항상 서버에서 확인한다.
      useCache: false,
    );
    return res.data ?? const [];
  }

  Future<GroupSharedProblem> shareGroupProblem({
    required String groupId,
    required int codebaseId,
    required int seed,
  }) async {
    final res = await _post(
      '/social/study-groups/$groupId/shared-problems',
      {'codebase_id': codebaseId, 'seed': seed},
      parser: (d) {
        final item = Map<String, dynamic>.from(d as Map);
        return GroupSharedProblem(
          id: item['codebase_id']?.toString() ?? '',
          shareId: item['share_id']?.toString() ?? '',
        );
      },
    );
    return res.data ?? const GroupSharedProblem();
  }

  Future<GroupSharedExam> shareGroupExam({
    required String groupId,
    required String examId,
  }) async {
    final res = await _post(
      '/social/study-groups/$groupId/shared-exams',
      {'exam_id': examId.trim()},
      parser: (d) {
        final item = Map<String, dynamic>.from(d as Map);
        return GroupSharedExam(
          id: item['exam_id']?.toString() ?? '',
          shareId: item['share_id']?.toString() ?? '',
          examId: item['exam_id']?.toString() ?? '',
          title: item['title']?.toString() ?? '시험지',
          senderName: item['sender_name']?.toString() ?? '시스템',
          createdAt: item['created_at']?.toString() ?? '',
        );
      },
    );
    return res.data ?? const GroupSharedExam();
  }

  Future<List<StudyGroupMessage>> fetchStudyGroupMessages({
    required String groupId,
    int limit = 30,
    String? before,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null && before.trim().isNotEmpty) {
      query['before'] = before.trim();
    }
    final res = await _get(
      '/social/study-groups/$groupId/messages',
      query: query,
      parser: (d) {
        final items = (d['messages'] as List<dynamic>?) ?? const [];
        return items.map((e) {
          final m = e as Map<String, dynamic>;
          return StudyGroupMessage(
            messageId: (m['message_id'] ?? '').toString(),
            userId: (m['user_id'] ?? '').toString(),
            senderName: (m['sender_name'] ?? '').toString(),
            text: (m['text'] ?? '').toString(),
            messageType: (m['message_type'] ?? 'text').toString(),
            payload: m['payload'] is Map
                ? Map<String, dynamic>.from(m['payload'] as Map)
                : null,
            createdAt: (m['created_at'] ?? '').toString(),
          );
        }).toList();
      },
      // 채팅은 서버 만료 정책을 즉시 반영해야 하므로 영구 SharedPreferences 캐시를 사용하지 않는다.
      useCache: false,
    );
    return res.data ?? const [];
  }

  Future<StudyGroupMessage> sendStudyGroupMessage({
    required String groupId,
    required String text,
  }) async {
    final res = await _post(
      '/social/study-groups/$groupId/messages',
      {'text': text},
      parser: (d) {
        final m = d as Map<String, dynamic>;
        return StudyGroupMessage(
          messageId: (m['message_id'] ?? '').toString(),
          userId: (m['user_id'] ?? '').toString(),
          senderName: (m['sender_name'] ?? '').toString(),
          text: (m['text'] ?? '').toString(),
          messageType: (m['message_type'] ?? 'text').toString(),
          payload: m['payload'] is Map
              ? Map<String, dynamic>.from(m['payload'] as Map)
              : null,
          createdAt: (m['created_at'] ?? '').toString(),
        );
      },
    );
    return res.data ?? const StudyGroupMessage();
  }

  Future<Map<String, dynamic>> getServerChatProfile() async {
    final res = await _get<Map<String, dynamic>>(
      ApiPaths.serverChatConfig,
      parser: (d) => Map<String, dynamic>.from(d as Map),
      useCache: true,
      cacheTtl: const Duration(hours: 1),
    );
    return res.data ?? <String, dynamic>{};
  }

  Future<ServerChatMessage> sendServerChatMessage({
    required String message,
    String? conversationId,
    String? character,
    String? mode,
    bool? ephemeral,
    bool? includeUserData,
    String? questTitle,
    String? flow,
    String? ocr,
  }) async {
    final res = await _post<ServerChatMessage>(
      ApiPaths.serverChatMessage,
      {
        'user_message': message,
        if (character != null && character.trim().isNotEmpty)
          'character': character.trim(),
        if (mode != null && mode.trim().isNotEmpty) 'mode': mode.trim(),
        if (ephemeral != null) 'ephemeral': ephemeral,
        if (includeUserData != null) 'include_user_data': includeUserData,
        if (questTitle != null && questTitle.trim().isNotEmpty)
          'quest_title': questTitle.trim(),
        if (flow != null && flow.trim().isNotEmpty) 'flow': flow.trim(),
        if (ocr != null && ocr.trim().isNotEmpty) 'ocr': ocr.trim(),
      },
      parser: (d) =>
          ServerChatMessage.fromJson(Map<String, dynamic>.from(d as Map)),
    );
    return res.data ?? const ServerChatMessage();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final int? retryAfterSeconds;

  ApiException({
    required this.statusCode,
    required this.message,
    this.retryAfterSeconds,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

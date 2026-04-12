import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

class FlowStatus {
  final int flowNumber;
  final String status; // "O" or "X"

  FlowStatus({required this.flowNumber, required this.status});

  bool get isCorrect => status.toUpperCase() == 'O';
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
          final map = Map<String, dynamic>.from(entry as Map);
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
        text == '없음') {
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
  final int ovr;
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
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      profileImage: json['profile_image'] as String?,
      ovr: json['ovr'] as int? ?? 0,
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
    required this.createdAt,
    required this.creatorId,
    required this.memberIds,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    return StudyGroup(
      groupId: json['group_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      maxMembers: json['max_members'] as int? ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      logoIndex: json['logo_index'] as int?,
      lockEnabled: json['lock_enabled'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
      creatorId: json['creator_id'] as String? ?? '',
      memberIds: List<String>.from(json['member_ids'] as List<dynamic>? ?? []),
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
    final breakdownRaw = json['affection_breakdown'] as Map<String, dynamic>? ?? {};
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

class ApiClient {
  ApiClient._() {
    _assertBaseUrlConfigured();
  }

  static final ApiClient instance = ApiClient._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client = http.Client();
  String? _token;
  bool _loadedPersistedToken = false;

  void _assertBaseUrlConfigured() {
    final isLocal = baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1');
    if (isLocal && kReleaseMode) {
      throw StateError(
        'API_BASE_URL is not configured. Pass --dart-define=API_BASE_URL=<prod> when building.',
      );
    }
  }

  Future<void> setToken(String token, {String? username}) async {
    _token = token;
    await AuthStorage.instance.saveToken(token, username: username);
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
    final uri = Uri.parse('$baseUrl/auth/anonymous');
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

  Future<String?> getUserStorage(String key) async {
    final token = await _ensureToken();
    final encodedKey = Uri.encodeComponent(key);
    final uri = Uri.parse('$baseUrl/user/storage/$encodedKey');
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
    final encodedKey = Uri.encodeComponent(key);
    final uri = Uri.parse('$baseUrl/user/storage/$encodedKey');
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

  Future<void> deleteUserStorage(String key) async {
    final token = await _ensureToken();
    final encodedKey = Uri.encodeComponent(key);
    final uri = Uri.parse('$baseUrl/user/storage/$encodedKey');
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

  Future<String> createExam({
    required List<ExamRangeRequest> ranges,
    required int difficultyTier,
    required int questionCount,
    String paperType = 'aiflow',
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/exams');
    final body = jsonEncode({
      'ranges': ranges.map((range) => range.toJson()).toList(),
      'difficulty_tier': difficultyTier,
      'question_count': questionCount,
      'paper_type': paperType,
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
      throw Exception('Failed to create exam: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return payload['exam_id'] as String;
  }

  Future<ExamStatus> getExamStatus(String examId) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/exams/$examId');
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

  Future<String> examPdfUrl(String examId, {bool inline = false}) async {
    final token = await _ensureToken();
    return '$baseUrl/exams/$examId/pdf?inline=${inline ? '1' : '0'}&token=$token';
  }

  Future<List<Map<String, dynamic>>> searchQuests({
    String? hashTag,
    String? questId,
    String? textQuery,
    int pageSize = 200,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{};
    if (hashTag != null && hashTag.trim().isNotEmpty) {
      params['hash_tag'] = hashTag.trim();
    }
    if (questId != null && questId.trim().isNotEmpty) {
      params['quest_id'] = questId.trim();
    }
    if (textQuery != null && textQuery.trim().isNotEmpty) {
      params['text'] = textQuery.trim();
    }
    if (pageSize > 0) {
      params['page_size'] = pageSize.toString();
    }
    if (params.isEmpty) {
      throw Exception('Search requires hash_tag, quest_id, or text');
    }
    final uri = Uri.parse('$baseUrl/quests').replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to search quests: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return QuestSearchResult.fromJson(payload).quests;
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
    final uri = Uri.parse('$baseUrl/quests/generate');
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
    if (quest == null) {
      throw Exception('Missing quest data in response');
    }
    return quest;
  }

  Future<Map<String, dynamic>> fetchQuestGenerateStatus({
    required String requestId,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse(
      '$baseUrl/quests/generate/status',
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

  Future<List<Map<String, dynamic>>> generateProblemSet({
    required List<String> hashTags,
    required int minDifficultyTier,
    required int maxDifficultyTier,
    required int questionCount,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/quests/generate/batch');
    final body = jsonEncode({
      'hash_tags': hashTags,
      'min_difficulty_tier': minDifficultyTier,
      'max_difficulty_tier': maxDifficultyTier,
      'question_count': questionCount,
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
      String message = 'Failed to generate problem set: ${response.statusCode}';
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          message = detail.trim();
        }
      } catch (_) {}
      throw Exception(message);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final quests = (payload['quests'] as List<dynamic>? ?? [])
        .map((quest) => quest as Map<String, dynamic>)
        .toList();
    if (quests.isEmpty) {
      throw Exception('Missing quests in response');
    }
    return quests;
  }

  Future<Map<String, dynamic>> generateCubicProblem({int? seed}) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/csat/cubic');
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
    final token = await _ensureToken();
    final params = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    final uri = Uri.parse('$baseUrl/quests').replace(queryParameters: params);
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch quests: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return QuestSearchResult.fromJson(payload);
  }

  Future<SolveAnalysisResponse> submitSolveAnalysis({
    required Map<String, dynamic> payload,
    Uint8List? studentWorkImage,
    Uint8List? problemImage,
    Uint8List? heatmapImage,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/analysis/solve');
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
    final uri = Uri.parse('$baseUrl/analysis/ocr');
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
    final uri = Uri.parse('$baseUrl/rating/submit');
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
    final uri = Uri.parse('$baseUrl/rating/user');
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

  Future<List<TagRating>> fetchTagRatings() async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/rating/tags');
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
    final uri = Uri.parse('$baseUrl/weakness/tags');
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
    final uri = Uri.parse('$baseUrl/habit/problem').replace(queryParameters: params);
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
        .map((item) => ProblemHabitItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> recordProblemHabit({
    required int codebaseId,
    required String seed,
    List<String> tags = const [],
    String? questTitle,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/habit/problem');
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
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/habit/problem/replay');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'codebase_id': codebaseId, 'seed': seed}),
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
    final uri = Uri.parse('$baseUrl/ox_quiz/generate');
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
    final params = {
      'tags': tags.join(','),
      'per_tag': perTag.toString(),
    };
    final uri = Uri.parse('$baseUrl/ox_quiz').replace(queryParameters: params);
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
    final uri = Uri.parse('$baseUrl/social/friends/search');
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

  Future<List<FriendProfile>> listFriends() async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/friends');
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

  Future<FriendProfile> addFriend(String username) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/friends/add');
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
    final uri = Uri.parse('$baseUrl/social/friends/remove');
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
    final uri = Uri.parse('$baseUrl/social/friend-requests');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch friend requests: ${response.statusCode}');
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
    final uri = Uri.parse('$baseUrl/social/friend-requests');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'username': username.trim(), if (message != null) 'message': message}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to send friend request: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendRequest.fromJson(payload);
  }

  Future<FriendProfile> acceptFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/friend-requests/$requestId/accept');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to accept friend request: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendProfile.fromJson(payload);
  }

  Future<FriendRequest> cancelFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/friend-requests/$requestId/cancel');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to cancel friend request: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FriendRequest.fromJson(payload);
  }

  Future<FriendRequest> declineFriendRequest(String requestId) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/friend-requests/$requestId/decline');
    final response = await _client.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to decline friend request: ${response.statusCode}');
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
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/study-groups');
    final body = jsonEncode({
      'name': name.trim(),
      'description': description.trim(),
      'max_members': maxMembers,
      'is_public': isPublic,
      'logo_index': logoIndex,
      'lock_enabled': lockEnabled,
      if (lockEnabled && password != null) 'password': password.trim(),
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
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/study-groups/mine');
    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load study groups: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final groups = payload['groups'] as List<dynamic>? ?? [];
    return groups
        .map((g) => StudyGroup.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<StudyGroup> joinStudyGroup({
    required String groupId,
    String? password,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/join');
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

  Future<List<StudyGroupMessage>> fetchStudyGroupMessages({
    required String groupId,
    int limit = 50,
    String? before,
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{'limit': limit.toString()};
    if (before != null) params['before'] = before;
    final uri = Uri.parse(
      '$baseUrl/social/study-groups/$groupId/messages',
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
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/messages');
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
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/topic');
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
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/topic');
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
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/exams');
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
    final uri = Uri.parse('$baseUrl/social/study-groups/$groupId/exams');
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
    final uri = Uri.parse(
      '$baseUrl/social/messages',
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
    final uri = Uri.parse('$baseUrl/social/messages');
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
    final params = <String, String>{
      'limit': limit.toString(),
    };
    if (before != null && before.trim().isNotEmpty) {
      params['before'] = before.trim();
    }
    final uri = Uri.parse('$baseUrl/social/conversations')
        .replace(queryParameters: params);
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
    final uri = Uri.parse('$baseUrl/social/messages/${Uri.encodeComponent(peerUsername)}/delete');
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
    final uri = Uri.parse('$baseUrl/serverchat/config');
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
    final uri = Uri.parse('$baseUrl/serverchat/config');
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
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/serverchat/message');
    final body = <String, dynamic>{
      'user_message': message,
      'mode': mode,
      if (character != null) 'character': character,
      if (questTitle != null) 'quest_title': questTitle,
      if (flow != null) 'flow': flow,
      if (ocr != null) 'ocr': ocr,
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
  }) async {
    final token = await _ensureToken();
    final params = <String, String>{};
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (tag != null && tag.trim().isNotEmpty) {
      params['tag'] = tag.trim();
    }
    final uri = Uri.parse(
      '$baseUrl/textbooks',
    ).replace(queryParameters: params);
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

  Future<Map<String, dynamic>> getTextbook(String textbookId) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/textbooks/$textbookId');
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
    final uri = Uri.parse('$baseUrl/textbooks');
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
}

import 'dart:convert';

import 'package:http/http.dart' as http;

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
  final String? questId;
  final int? flowCount;
  final dynamic questTitle;
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
    this.questId,
    this.flowCount,
    this.questTitle,
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
      questId: json['quest_id'] as String?,
      flowCount: json['flow_count'] as int?,
      questTitle: json['quest_title'],
      error: json['error'] as String?,
    );
  }
}

class ExamStatus {
  final String examId;
  final String status;
  final List<ExamItem> items;

  ExamStatus({
    required this.examId,
    required this.status,
    required this.items,
  });

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

class TestChatResponse {
  final String assistantMessage;
  final String? pairSummary;
  final String prompt;
  final int inputTokenEstimate;
  final int outputTokenEstimate;
  final int totalTokenEstimate;

  TestChatResponse({
    required this.assistantMessage,
    required this.prompt,
    required this.inputTokenEstimate,
    required this.outputTokenEstimate,
    required this.totalTokenEstimate,
    this.pairSummary,
  });

  factory TestChatResponse.fromJson(Map<String, dynamic> json) {
    final total = json['token_estimate'] as int? ?? 0;
    final input = json['input_token_estimate'] as int?;
    final output = json['output_token_estimate'] as int?;
    final resolvedInput = input ?? total;
    final resolvedOutput = output ?? (input != null && total > 0 ? total - input : 0);
    final resolvedTotal = total > 0 ? total : resolvedInput + resolvedOutput;
    return TestChatResponse(
      assistantMessage: json['assistant_message'] as String? ?? '',
      pairSummary: json['pair_summary'] as String?,
      prompt: json['prompt'] as String? ?? '',
      inputTokenEstimate: resolvedInput,
      outputTokenEstimate: resolvedOutput,
      totalTokenEstimate: resolvedTotal,
    );
  }
}

class SolveAnalysisResponse {
  final String analysis;
  final List<dynamic> recognizedText;
  final String ocrSource;
  final String? questId;
  final List<String> questModel;
  final List<String> warnings;
  final bool? isCorrect;
  final List<Map<String, dynamic>> stepCorrectness;

  SolveAnalysisResponse({
    required this.analysis,
    required this.recognizedText,
    required this.ocrSource,
    required this.questModel,
    required this.warnings,
    this.questId,
    this.isCorrect,
    this.stepCorrectness = const [],
  });

  factory SolveAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return SolveAnalysisResponse(
      analysis: json['analysis'] as String? ?? '',
      recognizedText: (json['recognized_text'] as List<dynamic>? ?? []),
      ocrSource: json['ocr_source'] as String? ?? '',
      questId: json['quest_id'] as String?,
      questModel: List<String>.from(json['quest_model'] as List<dynamic>? ?? []),
      warnings: List<String>.from(json['warnings'] as List<dynamic>? ?? []),
      isCorrect: json['is_correct'] as bool?,
      stepCorrectness: (json['step_correctness'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry as Map))
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

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  final http.Client _client = http.Client();
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Future<String> _ensureToken() async {
    if (_token != null) {
      return _token!;
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
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/exams');
    final body = jsonEncode({
      'ranges': ranges.map((range) => range.toJson()).toList(),
      'difficulty_tier': difficultyTier,
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

  Future<TestChatResponse> sendTestChatMessage({
    required String userMessage,
    required int affection,
    required int attendanceDays,
    String? questId,
    String? problemNumber,
    String? solutionNotes,
    Map<String, int>? learningRatings,
    List<Map<String, String>>? recentPairs,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/test-chat/message');
    final body = jsonEncode({
      'user_message': userMessage,
      'affection': affection,
      'attendance_days': attendanceDays,
      if (questId != null) 'quest_id': questId,
      if (problemNumber != null) 'problem_number': problemNumber,
      if (solutionNotes != null) 'solution_notes': solutionNotes,
      if (learningRatings != null) 'learning_ratings': learningRatings,
      if (recentPairs != null) 'recent_pairs': recentPairs,
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
      throw Exception('Failed to send chat: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return TestChatResponse.fromJson(payload);
  }

  Future<SolveAnalysisResponse> submitSolveAnalysis({
    required Map<String, dynamic> payload,
  }) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$baseUrl/analysis/solve');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to analyze solve: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return SolveAnalysisResponse.fromJson(decoded);
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
      body: jsonEncode({
        'query': query.trim(),
        'limit': limit,
      }),
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
}

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _loginPath = String.fromEnvironment(
    'API_LOGIN_PATH',
    defaultValue: '/auth/login',
  );

  static const String _registerPath = String.fromEnvironment(
    'API_REGISTER_PATH',
    defaultValue: '/auth/register',
  );

  static const String _kakaoLoginPath = String.fromEnvironment(
    'API_KAKAO_LOGIN_PATH',
    defaultValue: '/auth/kakao',
  );

  static const String _usernameCheckPath = String.fromEnvironment(
    'API_USERNAME_CHECK_PATH',
    defaultValue: '/auth/username/check',
  );

  static const String _validatePath = String.fromEnvironment(
    'API_VALIDATE_PATH',
    defaultValue: '/auth/validate',
  );

  Uri _resolve(String path) {
    // baseUrl을 기준으로 상대 경로를 resolve합니다.
    return Uri.parse(ApiClient.baseUrl).resolve(path);
  }

  Future<String> login({required String username, required String password}) async {
    final uri = _resolve(_loginPath);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw Exception('로그인 실패 (status ${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (payload['token'] ?? payload['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('토큰이 없습니다.');
    }
    return token;
  }

  Future<String> loginWithKakaoToken({
    required String accessToken,
    String? idToken,
  }) async {
    final uri = _resolve(_kakaoLoginPath);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'provider': 'kakao',
        'access_token': accessToken,
        if (idToken != null) 'id_token': idToken,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('카카오 로그인 실패 (status ${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (payload['token'] ?? payload['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('카카오 토큰이 없습니다.');
    }
    return token;
  }

  Future<String> register({
    required String username,
    required String password,
    required String name,
    required String grade,
    String? profileImageUrl,
    String? email,
    String? track,
    String? subject,
    String? school,
  }) async {
    final uri = _resolve(_registerPath);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'name': name,
        'grade': grade,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty)
          'profile_image': profileImageUrl.trim(),
        if (track != null && track.trim().isNotEmpty) 'track': track.trim(),
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (school != null && school.trim().isNotEmpty) 'school': school.trim(),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('회원가입 실패 (status ${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (payload['token'] ?? payload['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('회원가입 토큰이 없습니다.');
    }
    return token;
  }

  Future<UsernameCheckResult> checkUsername(String username) async {
    final uri = _resolve(_usernameCheckPath);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    if (response.statusCode != 200) {
      throw Exception('아이디 확인 실패 (status ${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return UsernameCheckResult.fromJson(payload);
  }

  Future<FieldValidationResult> validateField({
    required String field,
    required String value,
  }) async {
    final uri = _resolve(_validatePath);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'field': field, 'value': value}),
    );
    if (response.statusCode != 200) {
      throw Exception('필드 검증 실패 (status ${response.statusCode})');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return FieldValidationResult.fromJson(payload);
  }
}

class UsernameCheckResult {
  const UsernameCheckResult({required this.available, this.reason});

  final bool available;
  final String? reason;

  factory UsernameCheckResult.fromJson(Map<String, dynamic> json) {
    return UsernameCheckResult(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

class FieldValidationResult {
  const FieldValidationResult({required this.valid, this.reason});

  final bool valid;
  final String? reason;

  factory FieldValidationResult.fromJson(Map<String, dynamic> json) {
    return FieldValidationResult(
      valid: json['valid'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

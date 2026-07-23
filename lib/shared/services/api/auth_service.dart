import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_contract.dart';

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

  static const String _demoSessionPath = String.fromEnvironment(
    'API_DEMO_SESSION_PATH',
    defaultValue: '/auth/demo-session',
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
    return ApiContract.uri(path);
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
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
        if (subject != null && subject.trim().isNotEmpty)
          'subject': subject.trim(),
        if (school != null && school.trim().isNotEmpty) 'school': school.trim(),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorDetail(response, fallback: '회원가입 실패'));
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (payload['token'] ?? payload['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('회원가입 토큰이 없습니다.');
    }
    return token;
  }

  /// 필요한 변수는 시연 세션 API 주소다.
  /// 작동 원리는 가입 정보 없이 서버가 만든 30분 Test JWT만 받아 일반 인증 저장소에
  /// 넣을 수 있게 반환하며, 클라이언트가 임의 사용자명을 만들지 않는다.
  Future<String> startDemoSession() async {
    final response = await _client.post(
      _resolve(_demoSessionPath),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorDetail(response, fallback: '시연 세션 시작 실패'));
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (payload['token'] ?? payload['access_token']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('시연 세션 토큰이 없습니다.');
    }
    return token;
  }

  /// 필요한 변수는 HTTP 오류 응답과 기본 문구다.
  /// 작동 원리는 FastAPI의 detail을 우선 표시해 사용자가 400 원인을 바로 수정하게 하는 것이다.
  String _errorDetail(http.Response response, {required String fallback}) {
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } catch (_) {
      // JSON이 아닌 프록시 오류는 상태 코드로 안전하게 축약한다.
    }
    return '$fallback (status ${response.statusCode})';
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

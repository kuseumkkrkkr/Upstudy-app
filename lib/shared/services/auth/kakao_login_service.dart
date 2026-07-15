import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'auth_service.dart';

class KakaoLoginResult {
  const KakaoLoginResult({required this.token, required this.displayName});

  final String token;
  final String displayName;
}

class KakaoLoginService {
  KakaoLoginService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  static const String _nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );
  static const String _jsAppKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_APP_KEY',
    defaultValue: '',
  );

  bool get _hasAppKey => _nativeAppKey.isNotEmpty || _jsAppKey.isNotEmpty;

  Future<KakaoLoginResult> signIn() async {
    if (!_hasAppKey) {
      throw StateError(
        'KAKAO_NATIVE_APP_KEY 또는 KAKAO_JAVASCRIPT_APP_KEY가 설정되지 않았습니다.',
      );
    }

    final oauthToken = await _obtainOAuthToken();
    final appToken = await _authService.loginWithKakaoToken(
      accessToken: oauthToken.accessToken,
      idToken: oauthToken.idToken,
    );
    final nickname = await _fetchNickname() ?? '사용자';

    return KakaoLoginResult(token: appToken, displayName: nickname);
  }

  Future<OAuthToken> _obtainOAuthToken() async {
    try {
      if (await isKakaoTalkInstalled()) {
        return await UserApi.instance.loginWithKakaoTalk();
      }
    } catch (error) {
      if (error is PlatformException && error.code == 'CANCELED') {
        rethrow;
      }
    }
    return UserApi.instance.loginWithKakaoAccount();
  }

  Future<String?> _fetchNickname() async {
    try {
      final user = await UserApi.instance.me();
      return user.kakaoAccount?.profile?.nickname ??
          user.kakaoAccount?.email ??
          user.id.toString();
    } catch (_) {
      return null;
    }
  }
}

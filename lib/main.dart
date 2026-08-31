import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/ui/student_density/student_density.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initKakaoSdk();

  final session = await _restoreStartupSession();

  runApp(
    AIFlowApp(initialToken: session.token, initialUsername: session.username),
  );
}

Future<_StartupSession> _restoreStartupSession() async {
  final storedToken = (await AuthStorage.instance.readToken())?.trim() ?? '';
  final storedUsername = (await AuthStorage.instance.readUsername())?.trim();
  if (storedToken.isEmpty) return const _StartupSession.signedOut();

  await ApiClient.instance.setToken(storedToken, username: storedUsername);
  try {
    final profile = await ApiClient.instance.getMyProfile().timeout(
      const Duration(seconds: 5),
    );
    final profileUsername = profile.username.trim();
    final displayName = profile.name.trim();
    final username = displayName.isNotEmpty
        ? displayName
        : profileUsername.isNotEmpty
        ? profileUsername
        : storedUsername;
    if (username != null && username.isNotEmpty) {
      await AuthStorage.instance.saveUsername(username);
    }
    return _StartupSession(token: storedToken, username: username);
  } on ApiException catch (error) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      await ApiClient.instance.clearToken();
      return const _StartupSession.signedOut();
    }
    debugPrint('JWT validation failed without auth rejection: $error');
    return _StartupSession(token: storedToken, username: storedUsername);
  } catch (error) {
    debugPrint('JWT validation skipped: $error');
    return _StartupSession(token: storedToken, username: storedUsername);
  }
}

class _StartupSession {
  const _StartupSession({required this.token, this.username});

  const _StartupSession.signedOut() : token = '', username = null;

  final String token;
  final String? username;
}

void _initKakaoSdk() {
  const nativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );
  const jsAppKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_APP_KEY',
    defaultValue: '',
  );

  if (nativeAppKey.isEmpty && jsAppKey.isEmpty) {
    debugPrint(
      'Kakao login disabled: set KAKAO_NATIVE_APP_KEY or KAKAO_JAVASCRIPT_APP_KEY.',
    );
    return;
  }

  KakaoSdk.init(
    nativeAppKey: nativeAppKey.isNotEmpty ? nativeAppKey : jsAppKey,
    javaScriptAppKey: jsAppKey.isNotEmpty ? jsAppKey : nativeAppKey,
  );
}

class AIFlowApp extends StatelessWidget {
  const AIFlowApp({super.key, this.initialToken = '', this.initialUsername});

  final String initialToken;
  final String? initialUsername;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AIFlow',
      theme: _studentDensityTheme(),
      initialRoute: initialToken.isNotEmpty
          ? AppRoutes.studentDashboard
          : AppRoutes.landing,
      routes: appRoutes(),
      onGenerateRoute: onGenerateAppRoute,
    );
  }
}

/// 필요한 변수는 공용 학생 밀도 토큰이다.
/// 작동 원리: 아직 개별 리디자인되지 않은 학생 화면도 동일한 흑백 카드·필드·모달 규칙을 상속한다.
ThemeData _studentDensityTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StudentDensityTokens.dark,
    brightness: Brightness.light,
    surface: StudentDensityTokens.surface,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Noto Sans KR',
    colorScheme: scheme,
    scaffoldBackgroundColor: StudentDensityTokens.background,
    dividerColor: StudentDensityTokens.line,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: StudentDensityTokens.surface,
      foregroundColor: StudentDensityTokens.ink,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: StudentDensityTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudentDensityTokens.radius),
        side: const BorderSide(color: StudentDensityTokens.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: StudentDensityTokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: StudentDensityTokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: StudentDensityTokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: StudentDensityTokens.dark,
          width: 1.5,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: StudentDensityTokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: StudentDensityTokens.surface,
      selectedColor: StudentDensityTokens.dark,
      side: const BorderSide(color: StudentDensityTokens.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: StudentDensityTokens.dark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

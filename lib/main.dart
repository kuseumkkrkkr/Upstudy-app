import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/theme/app_colors.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primaryLight,
      ),
      initialRoute: initialToken.isNotEmpty
          ? AppRoutes.studentDashboard
          : AppRoutes.landing,
      routes: appRoutes(context, isAuthenticated: initialToken.isNotEmpty),
      onGenerateRoute: onGenerateAppRoute,
    );
  }
}

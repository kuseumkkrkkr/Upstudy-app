import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'package:s11/app/router.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/auth/auth_storage.dart';
import 'package:s11/shared/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initKakaoSdk();

  final storedToken = await AuthStorage.instance.readToken() ?? '';
  final storedUsername = await AuthStorage.instance.readUsername();
  if (storedToken.isNotEmpty) {
    await ApiClient.instance.setToken(
      storedToken,
      username: storedUsername,
    );
  }

  runApp(
    AIFlowApp(
      initialToken: storedToken,
      initialUsername: storedUsername,
    ),
  );
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
  const AIFlowApp({
    super.key,
    this.initialToken = '',
    this.initialUsername,
  });

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
          ? AppRoutes.app
          : AppRoutes.landing,
      routes: appRoutes(context),
      onGenerateRoute: onGenerateAppRoute,
    );
  }
}

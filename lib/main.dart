import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'auth/login_page.dart';
import 'auth/sign_up.dart';
import 'landing/landing_page.dart';
import 'pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initKakaoSdk();
  runApp(const AIFlowApp());
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
  const AIFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AIFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF45BF63),
      ),
      home: const LandingPage(),
      routes: {
        LoginPage.routeName: (_) => const LoginPage(),
        BuildpageWidget.routeName: (_) => const BuildpageWidget(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppShell.routeName) {
          final token = settings.arguments as String? ?? '';
          return MaterialPageRoute(builder: (_) => AppShell(token: token));
        }
        return null;
      },
    );
  }
}

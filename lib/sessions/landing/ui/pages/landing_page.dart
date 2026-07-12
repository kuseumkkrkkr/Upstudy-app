import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';
import 'package:s11/sessions/landing/ui/pages/landing_about_page.dart';

class LandingPage extends StatelessWidget {
  static const routeName = '/';
  static const _logoAsset = 'assets/54bba925b2ad92c9.png';
  static const _contactEmail = 'aiflow683@gmail.com';

  const LandingPage({super.key});

  void _goToLogin(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const LoginPage(asDialog: true),
      ),
    );
  }

  void _goToAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LandingAboutPage()));
  }

  Future<void> _contactByEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const {
        'subject': 'AIFlow 문의',
        'body': '안녕하세요. AIFlow 도입 문의드립니다.',
      },
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('메일 앱을 열 수 없습니다. aiflow683@gmail.com 으로 문의해주세요.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
            width: screenWidth,
            height: screenHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black),
            ),
          ),
          Container(
            width: screenWidth,
            height: screenHeight,
            color: Colors.black.withValues(alpha: 0.5),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  color: Colors.black,
                  child: Image.asset(
                    _logoAsset,
                    fit: BoxFit.cover,
                    semanticLabel: 'AIFlow 로고',
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 70,
                    color: const Color(0xFF121712),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _goToLogin(context),
                          child: Text(
                            '로그인',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () => _goToAbout(context),
                          child: Text(
                            '알아보기',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () => _contactByEmail(context),
                          child: Text(
                            '문의하기',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'AIFlow와 함께',
                    style: GoogleFonts.ptSans(
                      color: const Color(0xFFE0E0E0),
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '당신의 수학문제를\n만드세요',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.interTight(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    onPressed: () => _goToLogin(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF45BF63),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(300, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '시작하기 ▶',
                      style: GoogleFonts.interTight(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

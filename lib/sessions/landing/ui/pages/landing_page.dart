import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:s11/sessions/auth/ui/pages/login_page.dart';

class LandingPage extends StatelessWidget {
  static const routeName = '/';
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

  @override
  Widget build(BuildContext context) {
    return _buildMobileLayout(context);
  }

  // 모바일 레이아웃
  Widget _buildMobileLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경 이미지
          Image.network(
            'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080',
            width: screenWidth,
            height: screenHeight,
            fit: BoxFit.cover,
          ),

          // 오버레이
          Container(
            width: screenWidth,
            height: screenHeight,
            color: Colors.black.withOpacity(0.5),
          ),

          // 상단 헤더
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  color: const Color(0xFF1B402B),
                  child: const Icon(
                    Icons.search_outlined,
                    color: Colors.white,
                    size: 50,
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
                          onPressed: null,
                          child: Text(
                            '알아보기',
                            style: GoogleFonts.interTight(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: null,
                          child: Text(
                            '체험하기',
                            style: GoogleFonts.interTight(
                              color: Colors.white54,
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

          // 메인 콘텐츠
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

                  // ✅ 시작하기 → 로그인
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

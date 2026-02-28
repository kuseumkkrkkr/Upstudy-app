import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: LayoutBuilder(
        builder: (context, constraints) {
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // 모바일 레이아웃 - 반응형 (~ 768px)
  Widget _buildMobileLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경 이미지
          Image.network(
            'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw5fHxib29rfGVufDB8fHx8MTc2ODA1MTUxNXww&ixlib=rb-4.1.0&q=80&w=1080',
            width: screenWidth,
            height: screenHeight,
            fit: BoxFit.cover,
          ),
          // 어두운 오버레이
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
                          onPressed: () {
                            print('로그인 clicked');
                          },
                          child: Text(
                            '로그인',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () {
                            print('알아보기 clicked');
                          },
                          child: Text(
                            '알아보기',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () {
                            print('체험하기 clicked');
                          },
                          child: Text(
                            '체험하기',
                            style: GoogleFonts.interTight(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
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
                      fontWeight: FontWeight.normal,
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
                    onPressed: () {
                      print('Button pressed ...');
                    },
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
                      style: GoogleFonts.interTight(
                        fontSize: 20,
                        fontWeight: FontWeight.normal,
                      ),
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

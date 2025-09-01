import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:omj/home_page.dart';
import 'package:omj/more_page.dart';
import 'package:omj/editor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _idx = 0;

  // Global navigator key to perform navigation without relying on BuildContext
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  // Define the widgets for each tab
  final List<Widget> _pages = [
    const mainEditor(), // Placeholder for Home Page
    const MorePage(), // Placeholder for More Page
    const MainEditor(), // 자동완성 예시만들기
  ];

  void _onItemTapped(BuildContext ctx, int index) {
    setState(() {
      _idx = index;
    });
    _navKey.currentState
        ?.pop(); // Close the drawer using the global navigator key
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      // 한국어 로케일 추가
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      // 기본 로케일을 한국어로 설정
      locale: const Locale('ko', 'KR'),
      home: Builder(
        // Provide a BuildContext that is a descendant of MaterialApp so Navigator is available
        builder: (BuildContext appContext) {
          return Scaffold(
            backgroundColor: Colors.white, // Set Scaffold background to white
            //상단바입니다 앱바는 닫아놔도 됨 ==========================
            appBar: AppBar(
              title: Text(
                'ChatDocs',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Make the text bold
                  color: Colors
                      .black, // Set text color to black for better visibility on white background
                ),
              ),
              backgroundColor: Colors.white, // Set AppBar background to white
              iconTheme: IconThemeData(
                color: Colors.black,
              ), // Ensure drawer icon is black
            ),
            //========================================================

            //왼쪽 패널 선택칸 ========================================
            drawer: Drawer(
              backgroundColor: Colors.grey[200],
              //왼쪽열림
              //========================================================
              child: Builder(
                builder: (BuildContext drawerContext) {
                  return ListView(
                    children: <Widget>[
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Text(
                          '도구상자',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      //====================================================== 리스트타이틀
                      ListTile(
                        leading: Icon(Icons.home),
                        title: Text('홈'),
                        onTap: () => _onItemTapped(drawerContext, 0),
                      ),
                      ListTile(
                        leading: Icon(Icons.lightbulb),
                        title: Text('개요'),
                        onTap: () => _onItemTapped(drawerContext, 1),
                      ),
                      ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('에디터'),
                        onTap: () => _onItemTapped(drawerContext, 2),
                      ),

                      //====================================================== 여기까지 리스트
                      // 기능을 추가하려면 위에 ListTile 을 복붙하면 편합니다
                      //======================================================
                    ],
                  );
                },
              ),
            ),

            //=========================================================================
            //중앙라인
            //=========================================================================
            body: _pages[_idx], // Display the selected page
            //글작성 버튼
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _idx = 2;
                });
              },
              tooltip: '이대로 글쓰기',
              backgroundColor: Colors.white, // 배경색을 흰색으로 설정
              child: const Icon(
                Icons.edit, // 연필 모양 아이콘
                color: Colors.black, // 아이콘 색상을 검은색으로 설정
              ),
            ),
          );
        },
      ),
    );
  }
}

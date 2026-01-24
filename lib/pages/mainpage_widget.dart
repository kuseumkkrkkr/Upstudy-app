import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dialog_service.dart';
import '../widgets/menu_button.dart';
import '../widgets/header_bar.dart';
import 'character_chat_debug_page.dart';
import 'data_open_page.dart';
import 'quick_generate_page.dart';
import 'solution_view_page.dart';

class MainpageWidget extends StatefulWidget {
  const MainpageWidget({super.key});

  @override
  State<MainpageWidget> createState() => _MainpageWidgetState();
}

class _MainpageWidgetState extends State<MainpageWidget> {
  // 메뉴 아이템 데이터
  final List<Map<String, String>> menuItems = [
    {
      'title': '빠른 생성',
      'image':
          'https://images.unsplash.com/photo-1517770413964-df8ca61194a6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw4fHxib29rfGVufDB8fHx8MTc2ODYyNzYxNHww&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '고급 생성',
      'image':
          'https://images.unsplash.com/photo-1676302447092-14a103558511?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwzfHwlRUMlODglOTglRUQlOTUlOTl8ZW58MHx8fHwxNzY4NjI3OTI0fDA&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '시험지 보기',
      'image':
          'https://images.unsplash.com/photo-1628498188904-036f5e25e93e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwzfHxzdGFycnklMjBuaWdodHxlbnwwfHx8fDE3Njg2MTUzNTd8MA&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '풀이보기',
      'image':
          'https://images.unsplash.com/photo-1460925895917-afdab827c52f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxkYXRhfGVufDB8fHx8MTc2ODYyODA3M3ww&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {'title': 'data open', 'image': ''},
  ];

  void _onMenuItemPressed(String title) {
    if (title.toLowerCase() == 'data open') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DataOpenPage()),
      );
      return;
    }
    if (title == '빠른 생성') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QuickGeneratePage()),
      );
      return;
    }
    if (title == '풀이보기') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SolutionViewPage()),
      );
      return;
    }
    DialogService.openDialog(context, title: title);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Column(
            children: [
              // 상단 헤더
              HeaderBar(
                onSearchPressed: () =>
                    DialogService.openDialog(context, title: '검색'),
                onMenuPressed: () =>
                    DialogService.openDialog(context, title: '메뉴'),
              ),

              // 메뉴 버튼 목록
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CharacterChatDebugPage(),
                        ),
                      );
                    },
                    child: const Text('캐릭터챗'),
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: menuItems
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MenuButton(
                              title: item['title']!,
                              imageUrl: item['image']!,
                              onTap: () => _onMenuItemPressed(item['title']!),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

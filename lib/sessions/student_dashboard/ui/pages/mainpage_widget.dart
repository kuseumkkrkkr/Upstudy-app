import 'package:flutter/material.dart';
import 'package:s11/shared/services/api/dialog_service.dart';
import 'package:s11/shared/ui/components/menu_button.dart';
import 'package:s11/shared/ui/app_bar/header_bar.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/sessions/admin_data/session/data_open_page.dart';
import 'package:s11/sessions/tryout_solve/session/quick_generate_page.dart';
import 'package:s11/sessions/tryout_solve/ui/pages/solution_view_page.dart';

class MainpageWidget extends StatefulWidget {
  const MainpageWidget({super.key});

  @override
  State<MainpageWidget> createState() => _MainpageWidgetState();
}

class _MainpageWidgetState extends State<MainpageWidget> {
  // 메인 메뉴 목록
  final List<Map<String, String>> menuItems = [
    {
      'title': '문제 풀이',
      'image':
          'https://images.unsplash.com/photo-1517770413964-df8ca61194a6?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw4fHxib29rfGVufDB8fHx8MTc2ODYyNzYxNHww&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '문제 생성',
      'image':
          'https://images.unsplash.com/photo-1676302447092-14a103558511?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwzfHwlRUMlODglOTglRUQlOTUlOTl8ZW58MHx8fHwxNzY4NjI3OTI0fDA&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '학습 분석',
      'image':
          'https://images.unsplash.com/photo-1628498188904-036f5e25e93e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwzfHxzdGFycnklMjBuaWdodHxlbnwwfHx8fDE3Njg2MTUzNTd8MA&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {
      'title': '풀이보기',
      'image':
          'https://images.unsplash.com/photo-1460925895917-afdab827c52f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxkYXRhfGVufDB8fHx8MTc2ODYyODA3M3ww&ixlib=rb-4.1.0&q=80&w=1080',
    },
    {'title': '데이터 열기', 'image': ''},
  ];

  void _onMenuItemPressed(String title) {
    if (title == '데이터 열기') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DataOpenPage()));
      return;
    }
    if (title == '문제 생성') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QuickGeneratePage()));
      return;
    }
    if (title == '풀이보기') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SolutionViewPage()));
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
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              // 헤더 영역
              Builder(
                builder: (context) => HeaderBar(
                  onSearchPressed: () =>
                      DialogService.openDialog(context, title: '검색'),
                  onMenuPressed: () => toggleAppDrawer(context),
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

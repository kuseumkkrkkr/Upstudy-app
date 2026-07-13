// UTF-8 only: This file must be read/written as UTF-8.
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../shared/theme/app_colors.dart';
import '../shared/ui/ios26/ios26_chrome.dart';
import '../widgets/design_tokens.dart';
import '../widgets/teacher_app_drawer.dart';

class TeacherStorePage extends StatefulWidget {
  const TeacherStorePage({super.key});

  static const routeName = '/teacher-store';

  @override
  State<TeacherStorePage> createState() => _TeacherStorePageState();
}

class _TeacherStorePageState extends State<TeacherStorePage> {
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic> _summary = const <String, dynamic>{};

  int get _balance => (_summary['balance_points'] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> get _items {
    final raw = _summary['items'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await ApiClient.instance.fetchTeacherStoreSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상점 로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _topUp(int amount) async {
    await _runBusy(() => ApiClient.instance.topUpTeacherStoreTest(amount));
  }

  Future<void> _purchase(String itemId) async {
    await _runBusy(() => ApiClient.instance.purchaseTeacherStoreItem(itemId));
  }

  Future<void> _runBusy(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);
    try {
      final summary = await action();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상점 처리 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: const TeacherAppDrawer(
        currentRoute: TeacherStorePage.routeName,
      ),
      body: Builder(
        builder: (scaffoldContext) => SafeArea(
          child: Column(
            children: [
              Ios26TopBar(
                brandColor: kCourseGreen,
                title: '스토어',
                onBack: () => Navigator.maybePop(context),
                onMenu: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                items: const [
                  Ios26NavItem(label: '상품', active: true),
                  Ios26NavItem(label: '포인트'),
                ],
                trailingIcons: [
                  Ios26ActionIcon(
                    icon: Icons.refresh_rounded,
                    label: '새로고침',
                    onTap: _busy ? null : _load,
                  ),
                ],
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          children: [
                            _BalancePanel(
                              balance: _balance,
                              busy: _busy,
                              onTopUp: _topUp,
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 720;
                                return Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: _items
                                      .map(
                                        (item) => SizedBox(
                                          width: compact
                                              ? constraints.maxWidth
                                              : (constraints.maxWidth - 14) / 2,
                                          child: _StoreItemCard(
                                            item: item,
                                            busy: _busy,
                                            onPurchase: _purchase,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
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

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({
    required this.balance,
    required this.busy,
    required this.onTopUp,
  });

  final int balance;
  final bool busy;
  final ValueChanged<int> onTopUp;

  @override
  Widget build(BuildContext context) {
    const amounts = [100, 500, 1000, 5000, 10000];
    return Ios26FrostedCard(
      radius: 26,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$balance P',
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '테스트 포인트 충전',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.62)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amounts
                .map(
                  (amount) => _StoreAction(
                    label: '+$amount P',
                    icon: Icons.add_rounded,
                    dark: false,
                    onTap: busy ? null : () => onTopUp(amount),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  const _StoreItemCard({
    required this.item,
    required this.busy,
    required this.onPurchase,
  });

  final Map<String, dynamic> item;
  final bool busy;
  final ValueChanged<String> onPurchase;

  @override
  Widget build(BuildContext context) {
    final itemId = item['item_id']?.toString() ?? '';
    final owned = item['owned'] == true;
    final price = (item['price_points'] as num?)?.toInt() ?? 0;
    return Ios26FrostedCard(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(_iconFor(itemId), color: kCourseGreen, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            item['title']?.toString() ?? itemId,
            style: const TextStyle(
              color: kCourseGreen,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['description']?.toString() ?? '',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.66),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                '$price P',
                style: const TextStyle(
                  color: kCourseGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _StoreAction(
                onTap: owned || busy || itemId.isEmpty
                    ? null
                    : () => onPurchase(itemId),
                dark: !owned,
                icon: owned ? Icons.check_rounded : Icons.arrow_forward_rounded,
                label: owned ? '보유 중' : '구매',
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String itemId) {
    switch (itemId) {
      case 'textbook_db':
        return Icons.library_books_rounded;
      case 'exam_db':
        return Icons.assignment_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}

/// 포인트 충전과 상품 구매 동작을 공통 캡슐 UI로 표현한다.
/// [onTap]이 null이면 보유 중 또는 처리 중 상태로 비활성화한다.
class _StoreAction extends StatelessWidget {
  const _StoreAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.48 : 1,
      child: Material(
        color: dark ? Colors.black : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: dark ? null : Border.all(color: AppColors.surfaceBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: dark ? Colors.white : Colors.black),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

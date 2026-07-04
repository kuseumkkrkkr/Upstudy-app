import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:s11/sessions/friend/friend.dart';
import 'package:s11/sessions/legacy_cleanup/session/study_center.dart'
    as study_center;
import 'package:s11/sessions/student_dashboard/session/main_student_page.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/ui/drawer/app_drawer.dart';
import 'package:s11/shared/ui/ios26/ios26_chrome.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  static const List<_PlanTier> _plans = <_PlanTier>[
    _PlanTier(
      name: 'Go',
      price: '9,900',
      caption: 'Entry Access',
      summary: '가벼운 학습 루틴과 기본 AI 학습 흐름용.',
      features: <String>['일일 학습 루틴', '기본 문제 흐름', '문서함 동기화'],
    ),
    _PlanTier(
      name: 'Basic',
      price: '19,000',
      caption: 'Core Track',
      summary: '개인 학습 관리와 기본 진도 추적 중심.',
      features: <String>['루틴 리포트', '북마크 확장', '기본 복습 큐'],
    ),
    _PlanTier(
      name: 'Standard',
      price: '39,000',
      caption: 'Balanced Suite',
      summary: '교재, 시험지, 학습 흐름을 균형 있게 묶은 구성.',
      features: <String>['심화 진도 분석', '시험지 워크스페이스', '복습 추천'],
    ),
    _PlanTier(
      name: 'Elite',
      price: '69,000',
      caption: 'Performance Deck',
      summary: '대량 학습과 고강도 피드백을 위한 상위 구성.',
      features: <String>['우선 처리 큐', '심화 성취 추적', '확장 학습 보드'],
    ),
    _PlanTier(
      name: 'Prime',
      price: '99,000',
      caption: 'Full Access',
      summary: '현재 테스트 빌드 기본 보유 상태. 전체 상점 디자인 기준 요금제.',
      features: <String>['전체 프리미엄 해금', '실험 기능 우선 접근', '최상위 학습 대시보드'],
      isOwned: true,
      isFeatured: true,
    ),
  ];

  static const Color _brand = Color(0xFF1B402B);
  static const Color _bg = Color(0xFFF6F6F3);
  static const Color _panel = Color(0xFFFFFFFF);
  static const Color _panelSoft = Color(0xFFF0F0EC);
  static const Color _line = Color(0xFFD8D9D2);
  static const Color _lineStrong = Color(0xFF171717);
  static const Color _text = Color(0xFF111111);
  static const Color _textSoft = Color(0xFF4F4F4A);
  static const Color _textMuted = Color(0xFF75756E);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 920;

    return Scaffold(
      backgroundColor: _bg,
      drawer: const AppDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFF9F9F6), Color(0xFFF1F1EC)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 28,
                    18,
                    compact ? 16 : 28,
                    28,
                  ),
                  child: Column(
                    children: <Widget>[
                      _HeroPanel(compact: compact),
                      const SizedBox(height: 18),
                      compact
                          ? Column(
                              children: <Widget>[
                                _OwnedStatusCard(plan: _plans.last),
                                const SizedBox(height: 18),
                                _PlanGrid(plans: _plans, compact: compact),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 4,
                                  child: _PlanGrid(
                                    plans: _plans,
                                    compact: compact,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 2,
                                  child: _OwnedStatusCard(plan: _plans.last),
                                ),
                              ],
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

  Widget _buildHeader(BuildContext context) {
    return Ios26TopBar(
      brandColor: _brand,
      onMenu: () => toggleAppDrawer(context),
      trailing: const _MarketplaceCoinBalance(),
      onTitleTap: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainStudentPage()),
        (Route<dynamic> route) => false,
      ),
      items: <Ios26NavItem>[
        Ios26NavItem(
          label: '학습터',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const study_center.SoWidget()),
          ),
        ),
        Ios26NavItem(
          label: '문서함',
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        Ios26NavItem(
          label: '친구/소셜',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SoWidget())),
        ),
        const Ios26NavItem(label: '마켓플레이스', active: true),
      ],
    );
  }
}

class _MarketplaceCoinBalance extends StatefulWidget {
  const _MarketplaceCoinBalance();

  @override
  State<_MarketplaceCoinBalance> createState() =>
      _MarketplaceCoinBalanceState();
}

class _MarketplaceCoinBalanceState extends State<_MarketplaceCoinBalance> {
  late final Future<AccountSummary> _summary = ApiClient.instance
      .fetchAccountSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final account = snapshot.data;
        if (account == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFD59B19)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                color: Color(0xFFD59B19),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${account.totalPoints}',
                style: GoogleFonts.spaceGrotesk(
                  color: MarketplacePage._text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF0F0EB)],
        ),
        border: Border.all(color: MarketplacePage._lineStrong, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 2,
            spreadRadius: -1,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _HeroCopy(compact: compact),
                const SizedBox(height: 18),
                const _HeroDial(),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: _HeroCopy(compact: compact)),
                const SizedBox(width: 24),
                const _HeroDial(),
              ],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'BLACK EDITION STORE',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Marketplace',
          style: GoogleFonts.oswald(
            color: MarketplacePage._text,
            fontSize: compact ? 40 : 56,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '검은 금속 패널 감성으로 정리한 테스트 전용 상점 화면입니다. 현재는 Prime 요금제가 항상 활성화된 상태로 표시됩니다.',
          style: GoogleFonts.spaceGrotesk(
            color: MarketplacePage._textSoft,
            fontSize: compact ? 14 : 15,
            height: 1.6,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeroDial extends StatelessWidget {
  const _HeroDial();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFE6E6E1)],
        ),
        border: Border.all(color: MarketplacePage._lineStrong, width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 14),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 3,
            spreadRadius: -1,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 154,
          height: 154,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF101010),
            border: Border.all(color: const Color(0xFF000000)),
          ),
          child: Center(
            child: Text(
              'PRIME\nACTIVE',
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 28,
                height: 1.1,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({required this.plans, required this.compact});

  final List<_PlanTier> plans;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: plans
          .map(
            (plan) => SizedBox(
              width: compact ? double.infinity : 290,
              child: _PlanCard(plan: plan),
            ),
          )
          .toList(),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final _PlanTier plan;

  @override
  Widget build(BuildContext context) {
    final Color frame = plan.isOwned
        ? const Color(0xFFECECEC)
        : Colors.white.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            plan.isFeatured ? const Color(0xFFFFFFFF) : const Color(0xFFF8F8F4),
            const Color(0xFFEFEFEA),
          ],
        ),
        border: Border.all(
          color: plan.isOwned ? MarketplacePage._lineStrong : frame,
          width: plan.isOwned ? 1.4 : 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 2,
            spreadRadius: -1,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  plan.name,
                  style: GoogleFonts.oswald(
                    color: MarketplacePage._text,
                    fontSize: 32,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: plan.isOwned ? Colors.black : const Color(0xFFE9E9E3),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF161616)),
                ),
                child: Text(
                  plan.isOwned ? 'OWNED' : plan.caption,
                  style: GoogleFonts.spaceGrotesk(
                    color: plan.isOwned ? Colors.white : MarketplacePage._text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'KRW ${plan.price}',
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '/ month',
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            plan.summary,
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._textSoft,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          for (final feature in plan.features) ...<Widget>[
            _FeatureRow(label: feature),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: plan.isOwned
                      ? const <Color>[Color(0xFF101010), Color(0xFF232323)]
                      : const <Color>[Color(0xFF191919), Color(0xFF2B2B2B)],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  plan.isOwned ? 'Prime 사용 중' : '준비 중',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedStatusCard extends StatelessWidget {
  const _OwnedStatusCard({required this.plan});

  final _PlanTier plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: MarketplacePage._panel,
        border: Border.all(color: MarketplacePage._lineStrong, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TEST STATUS',
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MarketplacePage._panelSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: MarketplacePage._line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plan.name,
                  style: GoogleFonts.oswald(
                    color: MarketplacePage._text,
                    fontSize: 34,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '현재 테스트 조건상 항상 보유 처리됩니다.',
                  style: GoogleFonts.spaceGrotesk(
                    color: MarketplacePage._textSoft,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _statusLine('상태', 'ACTIVE'),
                const SizedBox(height: 10),
                _statusLine('권한', 'FULL MARKET ACCESS'),
                const SizedBox(height: 10),
                _statusLine('빌드', 'TEST MODE'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._textMuted,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: MarketplacePage._text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: MarketplacePage._text,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanTier {
  const _PlanTier({
    required this.name,
    required this.price,
    required this.caption,
    required this.summary,
    required this.features,
    this.isOwned = false,
    this.isFeatured = false,
  });

  final String name;
  final String price;
  final String caption;
  final String summary;
  final List<String> features;
  final bool isOwned;
  final bool isFeatured;
}

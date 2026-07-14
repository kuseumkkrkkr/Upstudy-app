import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:s11/sessions/student_dashboard/ui/pages/mainpage_widget.dart';
import 'package:s11/sessions/student_dashboard/business/student_dashboard_data.dart';
import 'package:s11/sessions/auth/ui/pages/profile_page.dart';

/// 학생 대시보드 화면.
class BuildboxCopyWidget extends StatelessWidget {
  BuildboxCopyWidget({
    super.key,
    StudentDashboardData? data,
    String? username,
    String? grade,
    String? profileImageUrl,
    double? completionRate,
    List<int>? activityLevels,
    String? dailyGraphLabel,
  }) : data = (data ?? StudentDashboardData.demo).copyWith(
         username: username,
         grade: grade,
         profileImageUrl: profileImageUrl,
         completionRate: completionRate,
         activityLevels: activityLevels,
         dailyGraphLabel: dailyGraphLabel,
       );

  final StudentDashboardData data;

  // Public getters keep backward-compatibility with existing usages.
  String get username => data.username;
  String get grade => data.grade;
  String get profileImageUrl => data.profileImageUrl;

  /// 필요한 변수는 데모 대시보드 데이터와 현재 화면 문맥이다.
  /// 작동 원리는 레거시 진입에서도 편집 버튼을 실제 프로필 화면으로 연결해 빈 액션을 남기지 않는 것이다.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 15),
                _buildProfileSection(),
                const SizedBox(height: 15),
                _buildIconSection(),
                const SizedBox(height: 15),
                _buildGraphSection(),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MainpageWidget()),
                    );
                  },
                  child: const Text('기존 메인 페이지로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 필요한 변수는 현재 Navigator 문맥이다.
  /// 작동 원리는 HTML 상단 편집 아이콘을 프로필 수정 화면으로 이동시키는 것이다.
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'LearningMate',
            style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 40),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              profileImageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                grade,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 15),
                    decoration: const BoxDecoration(
                      color: Color(0xFF32FF00),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 30),
          Expanded(
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _buildGithubTiles(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconSection() {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(
          5,
          (index) => Container(
            width: 150,
            height: 150,
            margin: const EdgeInsets.only(right: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFCFCFCF),
              shape: BoxShape.circle,
            ),
            child: index == 0 ? const Icon(Icons.light_sharp, size: 100) : null,
          ),
        ),
      ),
    );
  }

  Widget _buildGraphSection() {
    final completionRate = data.completionRate.clamp(0.0, 1.0).toDouble();
    final percentageText = '${(completionRate * 100).round()}%';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            percent: completionRate,
            radius: 120,
            lineWidth: 30,
            animation: true,
            progressColor: const Color(0xFF037A00),
            backgroundColor: Colors.grey[300]!,
            center: Text(
              percentageText,
              style: GoogleFonts.interTight(
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 50),
          Expanded(
            child: Container(
              height: 350,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFADADAD), Color(0xFF23FF00)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                data.dailyGraphLabel,
                style: GoogleFonts.inter(fontSize: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGithubTiles() {
    Color colorFor(int level) {
      switch (level) {
        case 1:
          return const Color(0xFFc6e48b);
        case 2:
          return const Color(0xFF7bc96f);
        case 3:
          return const Color(0xFF239a3b);
        case 4:
          return const Color(0xFF196127);
        default:
          return const Color(0xFFebedf0);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 활동',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: data.activityLevels
              .map(
                (level) => Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorFor(level),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

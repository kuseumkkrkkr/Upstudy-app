import 'package:flutter/material.dart';
import 'teacher_login_page.dart';
import 'teacher_dashboard_page.dart';
import '../services/api_client.dart';

class AuthWrapper extends StatefulWidget {
  final String? message;
  const AuthWrapper({super.key, this.message});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final isTeacher = await ApiClient.instance.isAuthenticated();

      if (!mounted) return;

      if (isTeacher) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
          _message = widget.message ?? '로그인이 필요합니다.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
        _message = '인증 확인 중 오류가 발생했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const TeacherDashboardPage();
    }

    return TeacherLoginPage(message: _message);
  }
}

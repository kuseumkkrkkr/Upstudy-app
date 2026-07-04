import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:s11_teacher/services/auth_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String tokenWithRole(String role) {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'sub': 'user-1', 'role': role})))
        .replaceAll('=', '');
    return 'header.$payload.signature';
  }

  test('does not trust legacy teacher role when jwt role is student', () async {
    final studentToken = tokenWithRole('student');
    SharedPreferences.setMockInitialValues({
      'auth.jwt': studentToken,
      'auth.role': 'teacher',
    });

    final token = await AuthStorage.instance.readToken();
    final role = await AuthStorage.instance.readRole();
    final prefs = await SharedPreferences.getInstance();

    expect(token, isNull);
    expect(role, isNull);
    expect(prefs.getString('auth.jwt'), studentToken);
    expect(prefs.getString('auth.role'), isNull);
  });

  test('migrates legacy teacher token into teacher namespace', () async {
    final teacherToken = tokenWithRole('teacher');
    SharedPreferences.setMockInitialValues({
      'auth.jwt': teacherToken,
      'auth.username': 'teacher@example.com',
      'auth.role': 'teacher',
    });

    final token = await AuthStorage.instance.readToken();
    final role = await AuthStorage.instance.readRole();
    final username = await AuthStorage.instance.readUsername();
    final prefs = await SharedPreferences.getInstance();

    expect(token, teacherToken);
    expect(role, 'teacher');
    expect(username, 'teacher@example.com');
    expect(prefs.getString('teacher.auth.jwt'), teacherToken);
    expect(prefs.getString('teacher.auth.role'), 'teacher');
    expect(prefs.getString('auth.jwt'), isNull);
    expect(prefs.getString('auth.role'), isNull);
  });

  test('clears invalid token from teacher namespace', () async {
    final studentToken = tokenWithRole('student');
    SharedPreferences.setMockInitialValues({
      'teacher.auth.jwt': studentToken,
      'teacher.auth.role': 'teacher',
    });

    final token = await AuthStorage.instance.readToken();
    final role = await AuthStorage.instance.readRole();
    final prefs = await SharedPreferences.getInstance();

    expect(token, isNull);
    expect(role, isNull);
    expect(prefs.getString('teacher.auth.jwt'), isNull);
    expect(prefs.getString('teacher.auth.role'), isNull);
  });
}

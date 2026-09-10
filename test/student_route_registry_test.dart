import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:s11/app/router.dart';
import 'package:s11/app/student_route_registry.dart';

void main() {
  test('student route registry covers all 86 reference screen states', () {
    final ids = StudentRouteRegistry.all.map((spec) => spec.id).toList();
    expect(ids, hasLength(86));
    expect(ids.toSet(), hasLength(86));
    expect(StudentRouteRegistry.byId('academy-find')?.demoOnly, isTrue);
    expect(StudentRouteRegistry.byId('school-exam-prep')?.demoOnly, isFalse);
    expect(
      StudentRouteRegistry.byId('home')?.activeNav,
      StudentNavSection.home,
    );
    expect(
      StudentRouteRegistry.byId('student-runtime')?.shell,
      StudentShellKind.immersive,
    );
    expect(
      StudentRouteRegistry.byId('book-reader')?.destination.screenId,
      'book-reader',
    );
  });

  test('dashboard scene links resolve without losing the requested scene', () {
    for (final scene in const [
      'today-tasks',
      'rating-detail',
      'achievements',
    ]) {
      final name = '/student/dashboard?scene=$scene';
      final route = onGenerateAppRoute(RouteSettings(name: name));
      expect(route, isA<MaterialPageRoute<void>>());
      expect(route?.settings.name, name);
    }
  });
}

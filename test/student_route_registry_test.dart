import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:s11/app/router.dart';
import 'package:s11/app/student_route_registry.dart';

void main() {
  test('student route registry covers all 86 reference screen states', () {
    expect(const StudentDestination('legacy-id').screenId, 'legacy-id');
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
    final store = StudentRouteRegistry.byId('store')!.destination;
    expect(store.routeName, '/store');
    expect(store.requiresAuth, isTrue);
    expect(store.demoOnly, isTrue);
  });

  test('audit manifest and typed registry contain the same screen IDs', () {
    final manifest =
        jsonDecode(
              File(
                'design/student/audits/student-parity.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final manifestIds = (manifest['screens'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((screen) => screen['id'] as String)
        .toSet();
    final registryIds = StudentRouteRegistry.all.map((spec) => spec.id).toSet();

    expect(manifest['screenCount'], registryIds.length);
    expect(manifestIds, registryIds);
    expect(StudentRouteRegistry.searchable, hasLength(31));
  });

  test('every registry route has a MaterialApp or generated route target', () {
    final staticRoutes = appRoutes();
    final unresolved = <String>[];
    for (final spec in StudentRouteRegistry.all) {
      if (staticRoutes.containsKey(spec.route)) continue;
      final generated = onGenerateAppRoute(RouteSettings(name: spec.route));
      if (generated == null) unresolved.add('${spec.id}:${spec.route}');
    }
    expect(unresolved, isEmpty);
  });

  test('dashboard scene links resolve without losing the requested scene', () {
    for (final scene in const [
      'today-tasks',
      'rating-detail',
      'achievements',
      'activity-history',
      'study-mode',
      'market-filter',
      'market-preview',
    ]) {
      final name = '/student/dashboard?scene=$scene';
      final route = onGenerateAppRoute(RouteSettings(name: name));
      expect(route, isA<MaterialPageRoute<void>>());
      expect(route?.settings.name, name);
    }
  });

  test('social friend tab link preserves the selected tab', () {
    final route = onGenerateAppRoute(
      const RouteSettings(name: '/social?tab=friends'),
    );
    expect(route, isA<MaterialPageRoute<void>>());
    expect(route?.settings.name, '/social?tab=friends');
  });

  test('social friend scenes resolve to their initial modal', () {
    for (final scene in const ['friend-add', 'friend-requests']) {
      final route = onGenerateAppRoute(
        RouteSettings(name: '/social?scene=$scene'),
      );
      expect(route, isA<MaterialPageRoute<void>>());
    }
  });

  test('internal scene deep links generate routes', () {
    const links = [
      '/student/dashboard?scene=course-select',
      '/learning-tools?scene=timer',
      '/bookbag?scene=book-library',
      '/arena?scene=arena-ranking',
      '/groups?scene=group-find',
      '/social?scene=direct-chat',
    ];
    for (final name in links) {
      final route = onGenerateAppRoute(RouteSettings(name: name));
      expect(route, isA<MaterialPageRoute<void>>(), reason: name);
      expect(route?.settings.name, name);
    }
  });
}

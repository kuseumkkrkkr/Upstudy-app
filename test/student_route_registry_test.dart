import 'package:flutter_test/flutter_test.dart';
import 'package:s11/app/student_route_registry.dart';

void main() {
  test('student route registry covers all 86 reference screen states', () {
    final ids = StudentRouteRegistry.all.map((spec) => spec.id).toList();
    expect(ids, hasLength(86));
    expect(ids.toSet(), hasLength(86));
    expect(StudentRouteRegistry.byId('academy-find')?.demoOnly, isTrue);
    expect(StudentRouteRegistry.byId('school-exam-prep')?.demoOnly, isFalse);
  });
}

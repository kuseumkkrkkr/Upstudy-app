import 'package:flutter_test/flutter_test.dart';
import 'package:s11/shared/services/api/api_client.dart';
import 'package:s11/shared/services/api/student_facing_api_error.dart';

void main() {
  test('그룹 목록 응답은 null과 잘못된 항목을 안전하게 건너뛴다', () {
    expect(parseStudyGroupListPayload(null), isEmpty);
    expect(parseStudyGroupListPayload(const <String, dynamic>{}), isEmpty);

    final groups = parseStudyGroupListPayload({
      'groups': [
        {
          'group_id': 17,
          'name': '수학 그룹',
          'member_count': '3',
          'max_members': 12,
          'member_ids': [1, '2'],
        },
        null,
        '잘못된 항목',
      ],
    });

    expect(groups, hasLength(1));
    expect(groups.single.id, '17');
    expect(groups.single.memberCount, 3);
    expect(groups.single.memberIds, ['1', '2']);
  });

  test('원시 API 예외 대신 학생용 상태 안내를 반환한다', () {
    final notFound = studentFacingApiError(
      ApiException(statusCode: 404, message: 'Not Found'),
      fallback: '불러오지 못했어요.',
      notFound: '자료를 찾지 못했어요.',
    );
    final unavailable = studentFacingApiError(
      ApiException(statusCode: 503, message: 'upstream timeout'),
      fallback: '불러오지 못했어요.',
      unavailable: '연결이 잠시 불안정해요.',
    );

    expect(notFound, '자료를 찾지 못했어요.');
    expect(unavailable, '연결이 잠시 불안정해요.');
    expect(notFound, isNot(contains('ApiException')));
    expect(unavailable, isNot(contains('upstream')));
  });
}

import 'package:s11/shared/services/api/api_client.dart';

/// 필요한 변수는 API·네트워크 오류와 화면별 기본 안내 문구다.
/// 작동 원리: HTTP 상태별로 학생이 취할 수 있는 행동만 안내하고 서버 경로·예외 형식은 화면에서 숨긴다.
String studentFacingApiError(
  Object error, {
  required String fallback,
  String? notFound,
  String? unavailable,
}) {
  if (error is! ApiException) {
    return '$fallback 네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
  }

  if (error.statusCode == 401) {
    return '로그인 시간이 만료되었어요. 다시 로그인해 주세요.';
  }
  if (error.statusCode == 403) {
    return '이 기능을 사용할 권한이 없어요.';
  }
  if (error.statusCode == 404) {
    return notFound ?? fallback;
  }
  if (error.statusCode == 408) {
    return '$fallback 잠시 후 다시 시도해 주세요.';
  }
  if (error.statusCode == 429) {
    return error.message.trim().isNotEmpty
        ? error.message.trim()
        : '요청이 많아요. 잠시 후 다시 시도해 주세요.';
  }
  if (error.statusCode >= 500) {
    return unavailable ?? '$fallback 잠시 후 다시 시도해 주세요.';
  }
  return fallback;
}

import 'package:shared_preferences/shared_preferences.dart';

class TextbookReaderPreferences {
  // 필요한 변수는 교재 리더의 보기 방식 저장 키다.
  // 작동 원리는 지면형 리더를 새 기본값으로 적용하기 위해 이전 스크롤 전용 설정과 분리해 사용자의 새 선택만 저장하는 것이다.
  static const String pageModeKey = 'settings.textbook_reader_page_mode_v2';

  static Future<bool> loadPageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pageModeKey) ?? true;
  }

  static Future<void> savePageMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pageModeKey, value);
  }
}

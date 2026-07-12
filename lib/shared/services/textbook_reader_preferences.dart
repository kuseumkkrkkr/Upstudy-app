import 'package:shared_preferences/shared_preferences.dart';

class TextbookReaderPreferences {
  static const String pageModeKey = 'settings.textbook_reader_page_mode';

  static Future<bool> loadPageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(pageModeKey) ?? false;
  }

  static Future<void> savePageMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pageModeKey, value);
  }
}

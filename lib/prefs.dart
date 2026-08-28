import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// تخزين محلي بسيط — SharedPreferences أندرويد عبر MethodChannel
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ نفس فلسفة `doc_picker` و`locator`: من غير أي باكدج خارجي.
/// الاستخدام الوحيد دلوقتي: **توكن الجلسة** عشان اللوجين يفضل شغال
/// بعد قفل الأبلكيشن — زي أي أبلكيشن.
///
/// كل الدوال بتبلع الأخطاء وبترجع null/بتكمّل — التخزين المحلي
/// مايكسرش الأبلكيشن أبداً؛ أسوأ حاجة إن اليوزر يسجل دخول تاني.
class Prefs {
  Prefs._();

  static const _channel = MethodChannel('promax/prefs');

  static Future<String?> get(String key) async {
    try {
      return await _channel.invokeMethod<String>('get', {'key': key});
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, String value) async {
    try {
      await _channel.invokeMethod('set', {'key': key, 'value': value});
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    try {
      await _channel.invokeMethod('remove', {'key': key});
    } catch (_) {}
  }
}

import 'package:flutter/services.dart';

/// ═══════════════════════════════════════════════════════════════
/// اللوكيشن — MethodChannel أصلي، من غير أي باكدج
/// ═══════════════════════════════════════════════════════════════
///
/// ⚠️ نفس فلسفة `doc_picker`: الباكدجات الخارجية كسرت البيلد قبل
/// كده، وأندرويد نفسه فيه اللي محتاجينه. أول نداء بيطلب الإذن من
/// المستخدم، واللي بعده بياخد الموقع على طول.
///
/// ⚠️ **بترجع null ومش بترمي.** التشيك إن مايتعطلش عشان اللوكيشن —
/// الزيارة بتتسجل من غير إحداثيات لو الإذن اترفض أو الـGPS مقفول.
class Locator {
  Locator._();

  static const _channel = MethodChannel('promax/locator');

  /// آخر fix ناجح — فولباك لما الطلب الجديد يفشل (٩/٨/٢٠٢٦).
  ///
  /// ⚠️ الفشل الصامت هنا كان بيسجّل «دخل مخزن» و«تشيك إن» من غير
  /// إحداثيات خالص في التراكينج. لو الـGPS اتأخر أو الإذن علّق،
  /// آخر نقطة معروفة من ١٠ دقايق أصدق من لا شيء — المندوب مش
  /// بينتقل كيلومترات في دقايق وهو شغال في نفس المنطقة.
  static (double, double)? _last;
  static DateTime? _lastAt;

  /// (lat, lng) أو null
  ///
  /// [fresh] = **ممنوع الفولباك على الكاش** (١٤ أغسطس ٢٠٢٦).
  ///
  /// ⚠️ كاش الـ١٠ دقايق اتعمل لأحداث التراكينج: «دخل عند عميل» بنقطة
  /// عمرها دقيقتين أحسن من حدث بلا مكان خالص. لكن شاشة «ضيف لوكيشن
  /// العميل» بتكتب **عنوان المحل نفسه** في الداتابيز — ونقطة من ١٠
  /// دقايق فاتت هي بالظبط المشكلة اللي الشاشة اتعملت تحلها (المندوب
  /// عمل تشيك إن وهو في الطريق). كاش هنا = نفس الباج من باب تاني.
  ///
  /// مع `fresh: true` الفشل بيرجع `null` صريح — والشاشة بتقول
  /// «مقدرناش نجيب اللوكيشن، جرّب تاني» بدل ما تحفظ نقطة الطريق.
  static Future<(double, double)?> get({bool fresh = false}) async {
    try {
      // ⚠️ مهلة إجبارية من ناحية Dart كمان — لو الأكتيفيتي اتعادت
      // وديالوج الإذن ضاع، النتيجة الأصلية مش هتيجي أبداً والتشيك
      // إن كان بيعلّق للأبد
      final res = await _channel
          .invokeMethod<Map<Object?, Object?>>('getLocation')
          .timeout(const Duration(seconds: 25), onTimeout: () => null);
      final lat = res?['lat'];
      final lng = res?['lng'];

      if (lat is num && lng is num) {
        _last = (lat.toDouble(), lng.toDouble());
        _lastAt = DateTime.now();
        return _last;
      }
      return fresh ? null : _stale();
    } catch (_) {
      return fresh ? null : _stale();
    }
  }

  /// نقطة **سريعة** لبدء الزيارة (٢١/٩ — بلاغ «العميل بيفتح في 12 ثانية»):
  /// fix عمره أقل من دقيقتين بيرجع فوراً من غير ما نصحّي الـGPS، وغير كده
  /// بنستنى `wait` بالكتير ونرجع بآخر نقطة معروفة. السيرفر عنده فولباك
  /// لوكيشن الفرع للحدث، فالزيارة مابتتعطلش على إشارة ضعيفة.
  static Future<(double, double)?> quick(
      {Duration wait = const Duration(seconds: 4)}) async {
    final at = _lastAt;
    if (_last != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 2)) {
      return _last;
    }

    return get().timeout(wait, onTimeout: _stale);
  }

  /// آخر نقطة لو عمرها أقل من ١٠ دقايق — وإلا null زي الأول
  static (double, double)? _stale() {
    final at = _lastAt;
    if (_last != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 10)) {
      return _last;
    }
    return null;
  }

  /// إشعار محلي بصوت (فلو الليد ٢٦/٨) — heads-up على قناة promax_ops.
  /// «عميل محتمل جمبك» والأبلكيشن في الخلفية: مفيش شيت يترسم،
  /// فالإشعار هو اللي بينده — والدوسة بتفتح الأبلكيشن.
  static const _notify = MethodChannel('promax/notify');

  static Future<void> notify(String title, String body, {int id = 9901}) async {
    try {
      await _notify
          .invokeMethod('show', {'title': title, 'body': body, 'id': id});
    } catch (_) {
      // إذن الإشعارات مقفول — مش مشكلتنا هنا
    }
  }

  /// فتح لينك خارجي (ملاحة جوجل ماب) — بيرجع false لو فشل بصمت
  static Future<bool> openUrl(String url) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

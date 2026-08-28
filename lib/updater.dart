import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'l10n.dart';
import 'version.dart';

/// ═══════════════════════════════════════════════════════════════
/// التحديث الذاتي — الأبلكيشن مش على جوجل بلاي (2026-08-07)
/// ═══════════════════════════════════════════════════════════════
///
/// السيرفر بيقول: آخر إصدار، أقل إصدار مسموح، ورابط الـAPK.
/// الأبلكيشن بيقارن بإصداره ويقرر: يكمّل عادي، يعرض «فيه تحديث»،
/// ولا يتقفل.
///
/// ⚠️ **الفحص مايوقفش الأبلكيشن أبداً لو فشل.** المندوب على شبكة
/// بتقطع؛ لو السيرفر ماردّش، بنكمّل شغل عادي. الحاجة الوحيدة اللي
/// بتوقفه هي رد صريح من السيرفر بإن نسخته أقدم من المسموح.
class UpdateInfo {
  /// آخر إصدار متاح على السيرفر
  final String latest;

  /// أقل إصدار مسموح — أقل منه = الشاشة بتتقفل
  final String minimum;

  final String apkUrl;
  final String note;

  const UpdateInfo({
    required this.latest,
    required this.minimum,
    required this.apkUrl,
    required this.note,
  });

  /// نسخته أقدم من المسموح → إجباري
  bool get forced => isOlder(appVersion, minimum);

  /// فيه أحدث بس نسخته لسه شغالة → اختياري
  bool get available => isOlder(appVersion, latest);

  /// من غير رابط مافيش تحديث ممكن — والقفل من غير حل مصيدة
  bool get canInstall => apkUrl.trim().isNotEmpty;
}

class Updater {
  Updater._();

  static const _channel = MethodChannel('promax/updater');

  /// آخر نتيجة فحص — الشاشات بتقراها من غير ما تعيد الطلب
  static UpdateInfo? info;

  /// المندوب قفل رسالة التحديث الاختياري — مانضايقوش تاني في
  /// نفس الجلسة. **الإجباري مالوش تجاهل.**
  static bool dismissed = false;

  /// ═══ تقدّم التنزيل (2026-08-08) ═══
  ///
  /// ⚠️ **`null` معناها «مانعرفش» مش «صفر».** فيه سيرفرات مابتبعتش
  /// `Content-Length` (ضغط chunked)، وساعتها النسبة مالهاش معنى —
  /// الشاشة بتوري بار غير محدّد بدل ما تكذب وتقول 0%.
  static final ValueNotifier<double?> progress = ValueNotifier(null);

  /// البايتس اللي نزلت — بتتعرض بالميجا جنب النسبة
  static final ValueNotifier<int> received = ValueNotifier(0);

  /// ⚠️ **إجبار وسط الشغل.** النبضة بتبلّغها لما السيرفر يرفع الحد
  /// الأدنى فوق النسخة الشغالة — و`main.dart` بيرمي شاشة التحديث
  /// فوق كل حاجة. مالهاش رجوع: القرار إداري والنسخة دي مش صالحة.
  static final ValueNotifier<bool> forcedNow = ValueNotifier(false);

  static bool _listening = false;

  /// ⚠️ **بيتنادى من `install` مش من `main`.** الاستماع قبل ما يبدأ
  /// أي تنزيل مالوش لازمة، وربطه في `main` كان بيخلّي أي تيست
  /// للأبلكيشن يحتاج القناة الأصلية موجودة.
  static void _listen() {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return null;

      final a = call.arguments as Map?;
      final r = (a?['received'] as num?)?.toInt() ?? 0;
      final t = (a?['total'] as num?)?.toInt() ?? 0;

      received.value = r;
      progress.value = t > 0 ? (r / t).clamp(0.0, 1.0) : null;

      return null;
    });
  }

  /// «12.4 MB» — للعرض جنب البار
  static String mb(int bytes) =>
      '${(bytes / 1048576).toStringAsFixed(1)} MB';

  /// بيسأل السيرفر. بيرجع `null` لو مافيش رد — وده **مش خطأ**.
  static Future<UpdateInfo?> check() async {
    try {
      final d = await Api.I.appVersion();

      info = UpdateInfo(
        latest: '${d['version'] ?? appVersion}',
        minimum: '${d['min_version'] ?? '0.0.0'}',
        apkUrl: '${d['apk_url'] ?? ''}',
        note: '${d['note'] ?? ''}',
      );

      return info;
    } catch (_) {
      return null;
    }
  }

  /// بينزّل ويفتح شاشة التسطيب. بيرجع رسالة الخطأ أو `null` لو تمام.
  ///
  /// ⚠️ النجاح معناه **إن شاشة التسطيب اتفتحت** — مش إن التحديث خلص.
  /// اللي بعد كده بيد المستخدم وأندرويد.
  static Future<String?> install(String url) async {
    _listen();

    // ⚠️ التصفير قبل كل تنزيل — محاولة تانية بعد فشل كانت بتبدأ من
    // النسبة القديمة والمندوب يفتكر إنه كمّل من مكانه
    progress.value = null;
    received.value = 0;

    try {
      await _channel.invokeMethod<bool>('downloadAndInstall', {'url': url});

      return null;
    } on MissingPluginException {
      return L.t('update_mobile_only');
    } on PlatformException catch (e) {
      return e.message ?? L.t('update_failed');
    } catch (e) {
      return '$e';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// إشعارات فاير بيز — طبقة الأبلكيشن
// ═══════════════════════════════════════════════════════════════
//
// الوضعين مكمّلين لبعض مش بدائل:
//
//   • الأبلكيشن **مفتوح**  → بانر جوّه الأبلكيشن (`_IncomingBanner`
//     في `main.dart`) بيتزحلق من فوق. أندرويد أصلاً **مابيعرضش**
//     إشعار نظام والمستخدم جوه الأبلكيشن، فلو اعتمدنا على البوش
//     بس، اللي قاعد شغال مكانش هيعرف حاجة.
//
//   • **باك جراوند أو مقفول** → إشعار نظام عادي، بيتعرض من أندرويد
//     نفسه من غير أي كود دارت (الرسالة جاية من السيرفر وفيها بلوك
//     `notification`). عشان كده مافيش هنا كود بيرسم إشعار.
//
// السيرفر: `POST /api/device-token` بيسجّل،
// و`POST /api/device-token/forget` بيمسح عند الخروج.

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api.dart';
import 'nav.dart';
import 'session.dart';
import 'version.dart';

/// ⚠️ **لازم تكون دالة على المستوى الأعلى (top-level) وعليها
/// `@pragma('vm:entry-point')`.** فاير بيز بيشغّل إيزوليت منفصل خالص
/// للرسايل اللي بتوصل والأبلكيشن مقفول — الإيزوليت ده مابيشوفش أي
/// حاجة جوه كلاس، ولو الدالة اتشالت في الـrelease build (tree
/// shaking) الأبلكيشن بيكراش وقت وصول الإشعار.
///
/// سايبينها فاضية عن قصد: أندرويد بيعرض الإشعار بنفسه، وأي شغل هنا
/// بيتم في إيزوليت مالوش جلسة ولا توكن ولا واجهة.
@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage message) async {}

/// كل حاجة خاصة بالبوش في مكان واحد.
class Push {
  Push._();

  static bool _ready = false;

  /// آخر توكن اتسجّل — بنمسحه بيه عند الخروج
  static String? token;

  /// بيتنادى **مرة واحدة** من `main()` قبل `runApp`.
  ///
  /// ⚠️ **بيبلع أي خطأ عن قصد.** تليفون من غير Google Play Services
  /// (أو إميوليتور AOSP) بيرمي هنا — والأبلكيشن لازم يفضل شغال عادي،
  /// الإشعارات الداخلية مش متوقفة على فاير بيز أصلاً.
  static Future<void> init() async {
    if (_ready) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_onBackground);

      // ⚠️ **الإذن مش اختياري من أندرويد 13.** من غير الطلب ده
      // الإشعار بيوصل التليفون ومايتعرضش — وشكله زي إن السيرفر
      // مابعتش، وده أصعب باج يتشخّص.
      await FirebaseMessaging.instance.requestPermission();

      // فاير بيز بيغيّر التوكن من نفسه (إعادة تنصيب، مسح داتا،
      // ترقية) — الاشتراك ده بيسجّل الجديد أوتوماتيك
      FirebaseMessaging.instance.onTokenRefresh.listen(_send);

      // الرسالة اللي بتوصل والأبلكيشن **مفتوح** — أندرويد مش
      // هيعرضها، فبنحوّلها للبانر بتاعنا. وبنعمل نبضة عشان الداتا
      // اللي وراها (أمر جاهز، عهدة نزلت) تنزل في نفس اللحظة.
      FirebaseMessaging.onMessage.listen((m) {
        Session.I.pulseNow();
      });

      // ═══ الضغط على الإشعار — الحتة اللي كانت ناقصة خالص ═══
      //
      // ⚠️ **الحالتين مختلفتين ولازم الاتنين.**
      //   • `onMessageOpenedApp` = الأبلكيشن كان في الخلفية والمستخدم
      //     دوس على الإشعار
      //   • `getInitialMessage` = الأبلكيشن كان **مقفول** والإشعار هو
      //     اللي فتحه — الحدث ده بيحصل مرة واحدة قبل ما أي مستمع
      //     يتسجّل، فلازم يتقرا صراحةً مش يتستنى
      //
      // من غير الاتنين، كل إشعار بيفتح الشاشة الرئيسية.
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        AppNav.go(m.data['link'] as String?);
        Session.I.pulseNow();
      });

      final initial = await FirebaseMessaging.instance.getInitialMessage();

      if (initial != null) {
        AppNav.go(initial.data['link'] as String?);
      }

      _ready = true;
    } catch (_) {
      // مفيش Google Play Services أو الإعداد ناقص — عادي
    }
  }

  /// بيتنادى بعد كل دخول ناجح وبعد استرجاع الجلسة.
  ///
  /// ⚠️ **بعد الدخول مش قبله.** التوكن بيتربط باليوزر الحالي على
  /// السيرفر — لو اتبعت قبل ما يبقى فيه جلسة، الريكوست بيترفض.
  static Future<void> register() async {
    if (!_ready || Session.I.user == null) return;

    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _send(t);
    } catch (_) {}
  }

  /// بيتنادى **قبل** مسح الجلسة عند الخروج.
  ///
  /// ⚠️ الترتيب مهم: لو اتنادى بعد ما توكن الجلسة يتمسح، الريكوست
  /// مش هيتصدّق عليه والتوكن هيفضل مسجّل على السيرفر — والتليفون لو
  /// اتسلّم لموظف تاني هيفضل واصله إشعارات اللي قبله.
  static Future<void> forget() async {
    final t = token;
    if (t == null) return;

    token = null;

    try {
      await Api.I.forgetDevice(t);
    } catch (_) {
      // شبكة — السيرفر بيشيل التوكنز الميتة لوحده لما فاير بيز
      // يرجّع 404 عليها
    }
  }

  static Future<void> _send(String t) async {
    token = t;

    try {
      await Api.I.registerDevice(t, version: appVersion);
    } catch (_) {
      // مش مشكلة — بيتعاد مع كل فتحة للأبلكيشن
    }
  }
}
